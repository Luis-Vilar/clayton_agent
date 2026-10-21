# RAG Markdown Streaming & Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Flutter Linux RAG application to support file and directory Markdown ingestion, stream LLM responses from Ollama in real time, display inferencing speed (tokens/sec) and GPU load in a fixed bottom-right widget, and enforce an 800x600 minimum window size.

**Architecture:** 
- The native GTK runner enforces the minimum window size (800x600).
- A new `GpuMetricsService` reads AMD GPU busy percentage directly from Linux sysfs (`/sys/class/drm/card*/device/gpu_busy_percent`).
- `OllamaService` streams NDJSON responses from `/api/generate` (`stream: true`) via Dio, calculating tokens/sec in real time and parsing final evaluation durations.
- `RagRepository` fixes the chunking filter bug (`> 40` chars inverted), supports ingesting both individual files and directories, and yields an asynchronous stream of response chunks with telemetry.
- `RagBloc` coordinates streaming state updates to the UI.
- `ChatScreen` presents a dual ingestion sidebar with real document titles, real-time Markdown rendering for streaming text, and a persistent bottom-right telemetry badge.

**Tech Stack:** Flutter 3.47.6 / Dart 3.13.5, Linux Desktop (GTK3), Dio 5.11, Flutter BLoC 9.1, ObjectBox 5.3, flutter_markdown 0.7.

**Spec:** [2026-10-21-rag-markdown-streaming-design.md](file:///home/fetux/claytonAgent/clayton_agent/docs/superpowers/specs/2026-10-21-rag-markdown-streaming-design.md)

## Global Constraints

- Platform: Linux Desktop (x64) with GTK3 runner.
- Models: Ollama local `nomic-embed-text` (768-dim embeddings) and `qwen2.5-coder:7b`.
- Minimum Window Size: 800x600 px.
- File formats: `.md` and `.markdown`.
- Architecture: Feature/Clean architecture with `get_it`, `flutter_bloc`, `dio`, `objectbox`.

## Review Focus

1. **Large vs Empty Chunks:** In `_splitByMarkdownHeaders`, chunks with `< 20` characters must be ignored, while large chunks (> 40 chars) must NOT be discarded.
2. **Streaming NDJSON Buffering:** Dio stream chunks may split JSON lines mid-byte; `LineSplitter` must be used over UTF-8 decoding to guarantee valid JSON before `jsonDecode`.
3. **Missing or Inaccessible Sysfs Path:** If `/sys/class/drm/card1/device/gpu_busy_percent` doesn't exist or permissions fail, `GpuMetricsService` must catch gracefully and return 0% without crashing.
4. **Zero Duration Division:** If Ollama returns `eval_duration: 0` or stream is instantaneous, TPS calculation must avoid `DivisionByZero` or `NaN` (default to 0.0).
5. **Sidebar Reactive Update:** When new files are ingested or the knowledge base is cleared, the sidebar file list must update immediately without requiring an app restart.

---

### Task 1: Enforce Minimum Window Size (800x600) in Linux Runner

**Files:**
- Modify: `linux/runner/my_application.cc:55-57`

**Interfaces:**
- Consumes: GTK window created in `my_application_activate`
- Produces: Minimum window size request of 800x600 px via GTK API

- [ ] **Step 1: Edit `linux/runner/my_application.cc`**

Set the minimum size request on the GTK window using `gtk_widget_set_size_request`:
```cpp
gtk_window_set_default_size(window, 1280, 720);
gtk_widget_set_size_request(GTK_WIDGET(window), 800, 600);
```

- [ ] **Step 2: Verify compilation**

Run: `flutter build linux --debug`
Expected: Build succeeds with 0 errors.

- [ ] **Step 3: Commit**

```bash
git add linux/runner/my_application.cc
git commit -m "feat(linux): set minimum window size to 800x600"
```

---

### Task 2: Create Linux AMD GPU Metrics Service

**Files:**
- Create: `lib/data/services/gpu_metrics_service.dart`
- Create: `test/data/services/gpu_metrics_service_test.dart`
- Modify: `lib/core/injection.dart`

**Interfaces:**
- Consumes: Path to sysfs file or custom path for testing
- Produces: `abstract class GpuMetricsService { Future<int> getGpuUsagePercent(); }`

- [ ] **Step 1: Write failing unit test for `GpuMetricsService`**

Create `test/data/services/gpu_metrics_service_test.dart` testing:
1. Normal reading returns integer percentage (e.g. "45\n" -> 45).
2. Non-existent file or corrupted file returns 0 without throwing.

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';

void main() {
  test('returns parsed percentage when file exists', () async {
    final tempFile = File('${Directory.systemTemp.path}/gpu_busy_percent_test');
    await tempFile.writeAsString('38\n');
    final service = GpuMetricsServiceImpl(overridePath: tempFile.path);
    final usage = await service.getGpuUsagePercent();
    expect(usage, equals(38));
    await tempFile.delete();
  });

  test('returns 0 when file does not exist', () async {
    final service = GpuMetricsServiceImpl(overridePath: '/non/existent/path');
    final usage = await service.getGpuUsagePercent();
    expect(usage, equals(0));
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/data/services/gpu_metrics_service_test.dart`
Expected: FAIL with compilation error (file not found).

- [ ] **Step 3: Implement `GpuMetricsService`**

Create `lib/data/services/gpu_metrics_service.dart`:
- Scan `/sys/class/drm/card1/device/gpu_busy_percent`, fallback to `/sys/class/drm/card0/device/gpu_busy_percent`.
- Parse integer, clamp 0-100, return 0 on any exception.
- Accept optional `overridePath` in constructor for testing.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/gpu_metrics_service_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Register in `lib/core/injection.dart`**

Register `GpuMetricsService` singleton in `initDependencies()`.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/gpu_metrics_service.dart test/data/services/gpu_metrics_service_test.dart lib/core/injection.dart
git commit -m "feat(services): implement Linux AMD GPU metrics service"
```

---

### Task 3: Ollama Streaming Service & Token Metrics

**Files:**
- Create: `lib/data/models/ollama_stream_chunk.dart`
- Modify: `lib/data/services/ollama_service.dart`
- Create: `test/data/services/ollama_service_test.dart`

**Interfaces:**
- Consumes: Dio client with `stream: true` to `/generate`
- Produces: 
  - `class OllamaStreamChunk { final String text; final bool isDone; final double tokensPerSecond; final int? evalCount; }`
  - `Stream<OllamaStreamChunk> generateResponseStream(String prompt);`

- [ ] **Step 1: Write unit tests for NDJSON stream parser**

Create `test/data/services/ollama_service_test.dart`:
- Test parsing lines of JSON stream chunks:
  `{"model":"qwen2.5-coder:7b","response":"Hello","done":false}`
  `{"model":"qwen2.5-coder:7b","response":" world","done":true,"eval_count":20,"eval_duration":500000000}`
- Verify calculation of TPS: `20 / (500000000 / 1e9) = 40.0`.
- Verify handling of 0 `eval_duration` safely.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/data/services/ollama_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `OllamaStreamChunk` and `generateResponseStream`**

In `lib/data/services/ollama_service.dart`:
- Add `generateResponseStream(String prompt)` to `OllamaService` interface.
- Implement in `OllamaServiceImpl`:
  - `_dio.post<ResponseBody>('/generate', data: {'model': llmModel, 'prompt': prompt, 'stream': true}, options: Options(responseType: ResponseType.stream))`
  - Pipe `response.data!.stream` through `utf8.decoder` -> `LineSplitter()`.
  - For each line: `jsonDecode(line)`.
  - Extract `'response'` string and `'done'` boolean.
  - Track start time `DateTime.now()` and token count for live TPS, and use `eval_count` / `eval_duration` when `done == true`.
  - Yield `OllamaStreamChunk`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/ollama_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/ollama_stream_chunk.dart lib/data/services/ollama_service.dart test/data/services/ollama_service_test.dart
git commit -m "feat(ollama): add streaming response support and token metrics"
```

---

### Task 4: Refactor Markdown Chunking & File Ingestion in `RagRepository`

**Files:**
- Create: `lib/domain/models/rag_stream_update.dart`
- Modify: `lib/domain/repositories/rag_repository.dart`
- Create: `test/domain/repositories/rag_repository_test.dart`

**Interfaces:**
- Consumes: `OllamaService`, `VectorDbService`
- Produces:
  - `Future<List<String>> ingestFiles(List<String> filePaths);`
  - `Future<List<String>> ingestAgentSkillsDirectory(String baseDirectoryPath);`
  - `Future<List<String>> getIngestedFileNames();`
  - `Stream<RagStreamUpdate> askQuestionStream(String question);`

- [ ] **Step 1: Write unit tests for chunking and ingestion logic**

Create `test/domain/repositories/rag_repository_test.dart`:
- Test `_splitByMarkdownHeaders`:
  - Keeps sections with length >= 20 characters.
  - Does NOT discard sections with length > 40 characters (reproducing the bug and verifying the fix).
  - Handles markdown with headings `# Header 1`, `## Header 2`, and plain text.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/domain/repositories/rag_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement repository refactor**

In `lib/domain/repositories/rag_repository.dart`:
- Fix chunk length filter: replace `if (section.trim().length > 40) continue;` with `if (section.trim().length < 20) continue;`.
- Implement `ingestFiles(List<String> filePaths)`: reads files, creates chunks with `filePath: path` and `skillName: p.basenameWithoutExtension(path)`, embeds via `_ollamaService.getEmbedding`, and saves to `_vectorDbService.saveChunks`. Returns list of processed file basenames.
- Update `ingestAgentSkillsDirectory`: returns `List<String>` of unique file basenames ingested.
- Implement `getIngestedFileNames()`: retrieves distinct `filePath` or `skillName` from ObjectBox or stored chunks.
- Implement `askQuestionStream(String question)`:
  - Vectorizes `question`.
  - Queries top 4 nearest neighbors in `VectorDbService`.
  - Builds context and prompt.
  - Calls `_ollamaService.generateResponseStream(prompt)`.
  - Emits `RagStreamUpdate(chunk: chunk.text, isDone: chunk.isDone, tokensPerSecond: chunk.tokensPerSecond)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/repositories/rag_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/rag_stream_update.dart lib/domain/repositories/rag_repository.dart test/domain/repositories/rag_repository_test.dart
git commit -m "feat(rag): fix markdown chunking filter and add file ingestion with streaming"
```

---

### Task 5: Refactor RAG BLoC for Streaming & Telemetry

**Files:**
- Modify: `lib/presentation/blocs/rag_event.dart`
- Modify: `lib/presentation/blocs/rag_state.dart`
- Modify: `lib/presentation/blocs/rag_bloc.dart`
- Create: `test/presentation/blocs/rag_bloc_test.dart`

**Interfaces:**
- Consumes: `RagRepository`, `GpuMetricsService`
- Produces:
  - Events: `IngestFilesEvent(List<String> paths)`, `IngestSkillsDirectoryEvent(String directoryPath)`, `SendQuestionEvent(String question)`, `ClearKnowledgeBaseEvent()`, `LoadIngestedFilesEvent()`
  - States: `RagStreamingState`, `RagResponseSuccessState`, `FileIngestedSuccessState`, `KnowledgeBaseClearedState`, `RagErrorState`

- [ ] **Step 1: Write unit tests for `RagBloc` streaming and events**

Create `test/presentation/blocs/rag_bloc_test.dart`:
- Test `IngestFilesEvent` emits `RagLoadingState` followed by `FileIngestedSuccessState` with file names.
- Test `SendQuestionEvent` emits `RagLoadingState`, then progressive `RagStreamingState` instances, and finally `RagResponseSuccessState` with TPS and GPU percent.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/presentation/blocs/rag_bloc_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement new events, states, and handlers in `RagBloc`**

In `lib/presentation/blocs/`:
- `rag_event.dart`:
  - `class IngestFilesEvent extends RagEvent { final List<String> paths; IngestFilesEvent(this.paths); }`
  - `class LoadIngestedFilesEvent extends RagEvent {}`
- `rag_state.dart`:
  - `class FileIngestedSuccessState extends RagState { final List<String> fileNames; FileIngestedSuccessState(this.fileNames); }`
  - `class RagStreamingState extends RagState { final String question; final String accumulatedAnswer; final double currentTps; final int gpuUsagePercent; RagStreamingState({...}); }`
  - `class RagResponseSuccessState extends RagState { final String question; final String answer; final double finalTps; final int gpuUsagePercent; RagResponseSuccessState({...}); }`
- `rag_bloc.dart`:
  - Inject `GpuMetricsService`.
  - Handle `IngestFilesEvent`: invoke `_repository.ingestFiles(event.paths)` and emit `FileIngestedSuccessState`.
  - Handle `SendQuestionEvent`:
    - Emit `RagLoadingState`.
    - Query `gpuMetricsService.getGpuUsagePercent()`.
    - Listen to `_repository.askQuestionStream(event.question)` using `await emit.forEach(...)`.
    - Accumulate answer buffer and emit `RagStreamingState` for intermediate chunks.
    - Emit `RagResponseSuccessState` on completion.

- [ ] **Step 4: Update injection in `lib/core/injection.dart`**

Pass `gpuMetricsService: getIt()` to `RagBloc`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/presentation/blocs/rag_bloc_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/blocs/ lib/core/injection.dart test/presentation/blocs/rag_bloc_test.dart
git commit -m "feat(bloc): add streaming and hardware telemetry support to RagBloc"
```

---

### Task 6: UI Refactor in `ChatScreen` with Streaming & Fixed Telemetry

**Files:**
- Create: `lib/presentation/widgets/telemetry_badge.dart`
- Modify: `lib/presentation/views/chat_screen.dart`

**Interfaces:**
- Consumes: `RagBloc` state (`RagStreamingState`, `RagResponseSuccessState`, etc.)
- Produces:
  - Sidebar with dual "Cargar Archivo(s)" and "Cargar Carpeta" buttons.
  - Real file names in sidebar list.
  - Real-time streaming response bubble with Markdown rendering.
  - Fixed bottom-right telemetry chip displaying TPS and GPU load.

- [ ] **Step 1: Create `TelemetryBadge` widget**

In `lib/presentation/widgets/telemetry_badge.dart`:
- Create a clean Material 3 card/chip widget:
  - ⚡ Speed: `${tps.toStringAsFixed(1)} tok/s`
  - 🎮 GPU: `${gpuPercent}%`
- When idle (0 tok/s), displays `⚡ -- tok/s | 🎮 ${gpuPercent}%`.

- [ ] **Step 2: Update `ChatScreen`**

In `lib/presentation/views/chat_screen.dart`:
- Add `_pickMarkdownFiles(BuildContext context)`:
  - `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['md', 'markdown'], allowMultiple: true)`.
  - Dispatches `IngestFilesEvent(paths)`.
- Keep `_pickSkillsDirectory(BuildContext context)`:
  - Dispatches `IngestSkillsDirectoryEvent(selectedDirectory)`.
- Update `_ingestedFiles` state when `FileIngestedSuccessState` emits (adding names).
- Update BlocConsumer / BlocListener:
  - When in `RagStreamingState`: update the active assistant message text in `_messages` and record `currentTps` and `gpuUsagePercent`.
  - When in `RagResponseSuccessState`: finalize message and persist `finalTps` and `gpuUsagePercent`.
- Add `Stack` or bottom footer to the right chat panel:
  - Place `TelemetryBadge` fixed at the bottom right.
- Ensure `ListView.builder` autoscrolls smoothly on streaming updates.

- [ ] **Step 3: Verify with `flutter analyze` and `flutter test`**

Run: `flutter analyze`
Expected: 0 issues found.
Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/telemetry_badge.dart lib/presentation/views/chat_screen.dart
git commit -m "feat(ui): update ChatScreen with streaming markdown, dual ingestion and telemetry bar"
```

---

### Task 7: End-to-End Verification & Validation

**Files:**
- Full codebase integration

- [ ] **Step 1: Run comprehensive analyzer and tests**

Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Build Linux Desktop Application**

Run: `flutter build linux --debug`
Expected: Successful build producing `build/linux/x64/debug/bundle/clayton_agent`.

- [ ] **Step 3: Verification with test markdown file**

Create a temporary markdown file, run a smoke test through `RagRepository` querying Ollama streaming, and verify tokens/sec and GPU readings.

- [ ] **Step 4: Final commit**

```bash
git commit --allow-empty -m "chore: complete RAG markdown streaming and telemetry implementation"
```
