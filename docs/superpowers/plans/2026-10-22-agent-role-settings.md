# Rol del Agente Personalizable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir editar desde la UI el rol del agente que hoy está hardcodeado, persistirlo con `shared_preferences` y usarlo en las consultas sin reindexar.

**Architecture:** Se agrega un `PromptSettingsService` (capa de datos) que lee/escribe el rol en `SharedPreferences` con el texto actual como default. `RagRepositoryImpl` mantiene el rol vigente y lo usa al construir el prompt. `RagBloc` expone eventos/estados para cargar y actualizar el rol, y `ChatScreen` abre un diálogo de edición desde el sidebar.

**Tech Stack:** Flutter 3.47.6 / Dart 3.13.5, `flutter_bloc` 9.1, `get_it` 9.3, `shared_preferences` (nueva).

**Spec:** `docs/superpowers/specs/2026-10-22-agent-role-settings-design.md`

## Global Constraints

- Plataforma: Linux Desktop (GTK3), Flutter/Dart del proyecto actual.
- Única dependencia nueva: `shared_preferences`.
- El rol es un string multilínea libre; no se valida su contenido, salvo que vacío/solo espacios cae al default.
- El default es exactamente el texto que hoy está en `RagRepositoryImpl.prompt`. El primer arranque debe comportarse igual que antes.
- El cambio de rol no debe requerir reinicio ni reindexación.
- Mantener la arquitectura `Service` → `Repository` → `Bloc` → `View`.

## Review Focus

1. Primer arranque sin valor guardado: se usa el ejemplo actual y el prompt enviado a Ollama es equivalente al de antes.
2. Valor guardado vacío o solo espacios: se cae al default en vez de enviar un rol vacío.
3. Fallo al persistir: el rol en memoria no cambia y el BLoC emite `RagErrorState`.
4. El rol nuevo se aplica a la próxima consulta sin reindexar documentos.
5. El diálogo no permite guardar antes de terminar de cargar el rol actual (evita sobrescribirlo con vacío).

---

### Task 1: Servicio de configuración del rol

**Files:**
- Modify: `pubspec.yaml` (vía `flutter pub add shared_preferences`)
- Create: `lib/data/services/prompt_settings_service.dart`
- Test: `test/data/services/prompt_settings_service_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences` de `shared_preferences`.
- Produces:
  - `const String defaultAgentRole` (el texto actual del rol).
  - `abstract class PromptSettingsService { Future<String> loadAgentRole(); Future<void> saveAgentRole(String role); }`
  - `class PromptSettingsServiceImpl implements PromptSettingsService` con constructor `PromptSettingsServiceImpl({required SharedPreferences preferences})` y clave `agent_role`.

- [ ] **Step 1: Agregar la dependencia**

Run: `flutter pub add shared_preferences`
Expected: `pubspec.yaml` incluye `shared_preferences` y `flutter pub get` termina sin errores.

- [ ] **Step 2: Escribir el test que falla**

`test/data/services/prompt_settings_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadAgentRole returns defaultAgentRole when nothing is saved', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    expect(await service.loadAgentRole(), defaultAgentRole);
  });

  test('saveAgentRole persists and loadAgentRole returns the saved role', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    await service.saveAgentRole('Eres un experto en SQL y modelado de datos.');

    expect(
      await service.loadAgentRole(),
      'Eres un experto en SQL y modelado de datos.',
    );
  });

  test('loadAgentRole falls back to default when the saved value is blank', () async {
    SharedPreferences.setMockInitialValues({'agent_role': '   '});
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    expect(await service.loadAgentRole(), defaultAgentRole);
  });
}
```

- [ ] **Step 3: Correr el test para verlo fallar**

Run: `flutter test test/data/services/prompt_settings_service_test.dart`
Expected: FAIL porque `prompt_settings_service.dart` no existe.

- [ ] **Step 4: Implementar el servicio**

`lib/data/services/prompt_settings_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

const String defaultAgentRole = """
Responde la siguiente pregunta técnica sobre Dart/Flutter basándote en
la documentación y los plugins provistos en el contexto. Si encuentras
código relevante o patrones de arquitectura en el contexto, úsalos para
armar un ejemplo práctico.
""";

abstract class PromptSettingsService {
  Future<String> loadAgentRole();
  Future<void> saveAgentRole(String role);
}

class PromptSettingsServiceImpl implements PromptSettingsService {
  static const String agentRoleKey = 'agent_role';
  final SharedPreferences _preferences;

  PromptSettingsServiceImpl({required SharedPreferences preferences})
    : _preferences = preferences;

  @override
  Future<String> loadAgentRole() async {
    final saved = _preferences.getString(agentRoleKey)?.trim();
    if (saved == null || saved.isEmpty) {
      return defaultAgentRole;
    }
    return saved;
  }

  @override
  Future<void> saveAgentRole(String role) async {
    await _preferences.setString(agentRoleKey, role);
  }
}
```

- [ ] **Step 5: Correr el test para verlo pasar**

Run: `flutter test test/data/services/prompt_settings_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/services/prompt_settings_service.dart test/data/services/prompt_settings_service_test.dart
git commit -m "feat(settings): add persistent agent role settings service"
```

---

### Task 2: Rol vigente en `RagRepositoryImpl`

**Files:**
- Modify: `lib/domain/repositories/rag_repository.dart:11-34` y `:145-174`
- Test: `test/domain/repositories/rag_repository_test.dart`

**Interfaces:**
- Consumes: `PromptSettingsService`, `defaultAgentRole` (Task 1).
- Produces:
  - `RagRepository` suma `String get agentRole;` y `Future<void> updateAgentRole(String role);`
  - `RagRepositoryImpl({required OllamaService ollamaService, required VectorDbService vectorDbService, required PromptSettingsService promptSettingsService, required String initialAgentRole})`
  - `updateAgentRole` persiste primero y recién después actualiza el rol en memoria.

- [ ] **Step 1: Escribir el test que falla**

En `test/domain/repositories/rag_repository_test.dart` agregar un fake de settings y ajustar el `setUp`:

```dart
class FakePromptSettingsService implements PromptSettingsService {
  String role = defaultAgentRole;
  bool failOnSave = false;

  @override
  Future<String> loadAgentRole() async => role;

  @override
  Future<void> saveAgentRole(String role) async {
    if (failOnSave) throw Exception('save failed');
    this.role = role;
  }
}
```

Ajustar el constructor del repositorio en `setUp`:

```dart
fakeSettings = FakePromptSettingsService();
repository = RagRepositoryImpl(
  ollamaService: mockOllama,
  vectorDbService: mockVectorDb,
  promptSettingsService: fakeSettings,
  initialAgentRole: defaultAgentRole,
);
```

Agregar al `MockOllamaService` un campo `String? lastPrompt;` seteado dentro de `generateResponseStream(String prompt)` y `generateResponse(String prompt)`.

Agregar estos tests:

```dart
test('updateAgentRole persists and uses the new role in the next prompt', () async {
  mockVectorDb.stored.add(
    MarkdownChunk(
      filePath: '/path/doc.md',
      skillName: 'general',
      content: 'Contexto relevante sobre SQL',
      embedding: Float32List(768),
    ),
  );

  await repository.updateAgentRole('Eres un experto en SQL.');

  expect(repository.agentRole, 'Eres un experto en SQL.');
  expect(fakeSettings.role, 'Eres un experto en SQL.');

  await repository.askQuestionStream('¿Qué es un índice?').toList();

  expect(mockOllama.lastPrompt, contains('Eres un experto en SQL.'));
  expect(mockOllama.lastPrompt, isNot(contains('Dart/Flutter')));
});

test('updateAgentRole does not change the role when persistence fails', () async {
  fakeSettings.failOnSave = true;

  await expectLater(
    repository.updateAgentRole('Rol nuevo'),
    throwsA(isA<Exception>()),
  );
  expect(repository.agentRole, defaultAgentRole);
});
```

- [ ] **Step 2: Correr el test para verlo fallar**

Run: `flutter test test/domain/repositories/rag_repository_test.dart`
Expected: FAIL por constructor/API inexistente.

- [ ] **Step 3: Implementar en `rag_repository.dart`**

- En `RagRepository` agregar:

```dart
String get agentRole;
Future<void> updateAgentRole(String role);
```

- En `RagRepositoryImpl` reemplazar el campo `final String? prompt;` por:

```dart
final PromptSettingsService promptSettingsService;
String _agentRole;

RagRepositoryImpl({
  required this.ollamaService,
  required this.vectorDbService,
  required this.promptSettingsService,
  required String initialAgentRole,
}) : _agentRole = initialAgentRole;

@override
String get agentRole => _agentRole;

@override
Future<void> updateAgentRole(String role) async {
  await promptSettingsService.saveAgentRole(role);
  _agentRole = role;
}
```

- En `_buildPromptForQuestion` usar `_agentRole` en lugar de `$prompt`.
- Importar `package:clayton_agent/data/services/prompt_settings_service.dart`.

- [ ] **Step 4: Correr los tests para verlos pasar**

Run: `flutter test test/domain/repositories/rag_repository_test.dart`
Expected: PASS (todos los tests del archivo).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/rag_repository.dart test/domain/repositories/rag_repository_test.dart
git commit -m "feat(rag): use persistent agent role when building prompts"
```

---

### Task 3: Eventos y estados del rol en `RagBloc`

**Files:**
- Modify: `lib/presentation/blocs/rag_event.dart`
- Modify: `lib/presentation/blocs/rag_state.dart`
- Modify: `lib/presentation/blocs/rag_bloc.dart:14-21`
- Test: `test/presentation/blocs/rag_bloc_test.dart`

**Interfaces:**
- Consumes: `RagRepository.agentRole` y `updateAgentRole` (Task 2).
- Produces:
  - `class LoadAgentRoleEvent extends RagEvent {}`
  - `class UpdateAgentRoleEvent extends RagEvent { final String role; UpdateAgentRoleEvent(this.role); }`
  - `class AgentRoleLoadedState extends RagState { final String role; AgentRoleLoadedState(this.role); }`
  - `class AgentRoleUpdatedState extends RagState { final String role; AgentRoleUpdatedState(this.role); }`

- [ ] **Step 1: Escribir los tests que fallan**

En `test/presentation/blocs/rag_bloc_test.dart`, completar `FakeRagRepository`:

```dart
String role = defaultAgentRole;
bool failUpdateRole = false;

@override
String get agentRole => role;

@override
Future<void> updateAgentRole(String role) async {
  if (failUpdateRole) throw Exception('save failed');
  this.role = role;
}
```

Agregar dentro de `group('RagBloc', ...)`:

```dart
test('emits AgentRoleLoadedState on LoadAgentRoleEvent', () async {
  fakeRepo.role = 'Rol persistido';

  final expectation = expectLater(
    bloc.stream,
    emits(isA<AgentRoleLoadedState>().having((s) => s.role, 'role', 'Rol persistido')),
  );

  bloc.add(LoadAgentRoleEvent());
  await expectation;
});

test('emits AgentRoleUpdatedState and persists on UpdateAgentRoleEvent', () async {
  final expectation = expectLater(
    bloc.stream,
    emits(isA<AgentRoleUpdatedState>().having((s) => s.role, 'role', 'Rol nuevo')),
  );

  bloc.add(UpdateAgentRoleEvent('Rol nuevo'));
  await expectation;

  expect(fakeRepo.role, 'Rol nuevo');
});

test('emits RagErrorState when updating the role fails', () async {
  fakeRepo.failUpdateRole = true;

  final expectation = expectLater(bloc.stream, emits(isA<RagErrorState>()));

  bloc.add(UpdateAgentRoleEvent('Rol que falla'));
  await expectation;
});
```

Importar `defaultAgentRole` desde `prompt_settings_service.dart`.

- [ ] **Step 2: Correr los tests para verlos fallar**

Run: `flutter test test/presentation/blocs/rag_bloc_test.dart`
Expected: FAIL por eventos/estados inexistentes.

- [ ] **Step 3: Implementar eventos, estados y handlers**

En `rag_event.dart` agregar las dos clases del bloque Interfaces. En `rag_state.dart` agregar los dos estados. En el constructor de `RagBloc` registrar:

```dart
on<LoadAgentRoleEvent>(_onLoadAgentRole);
on<UpdateAgentRoleEvent>(_onUpdateAgentRole);
```

Y agregar los handlers:

```dart
void _onLoadAgentRole(LoadAgentRoleEvent event, Emitter<RagState> emit) {
  emit(AgentRoleLoadedState(repository.agentRole));
}

Future<void> _onUpdateAgentRole(
  UpdateAgentRoleEvent event,
  Emitter<RagState> emit,
) async {
  try {
    await repository.updateAgentRole(event.role);
    emit(AgentRoleUpdatedState(event.role));
  } catch (e) {
    emit(RagErrorState("Error al guardar el rol del agente: ${e.toString()}"));
  }
}
```

- [ ] **Step 4: Correr los tests para verlos pasar**

Run: `flutter test test/presentation/blocs/rag_bloc_test.dart`
Expected: PASS (todos los tests del archivo).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/blocs/rag_event.dart lib/presentation/blocs/rag_state.dart lib/presentation/blocs/rag_bloc.dart test/presentation/blocs/rag_bloc_test.dart
git commit -m "feat(bloc): add load and update agent role events"
```

---

### Task 4: Diálogo de edición del rol

**Files:**
- Create: `lib/presentation/widgets/agent_role_dialog.dart`
- Test: `test/presentation/widgets/agent_role_dialog_test.dart`

**Interfaces:**
- Consumes: `RagBloc`, `LoadAgentRoleEvent`, `AgentRoleLoadedState`, `UpdateAgentRoleEvent`, `AgentRoleUpdatedState`, `RagErrorState`, `defaultAgentRole` (Tasks 1 y 3).
- Produces: `Future<void> showAgentRoleDialog(BuildContext context)`.

- [ ] **Step 1: Escribir el test que falla**

`test/presentation/widgets/agent_role_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/data/services/gpu_metrics_service.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';
import 'package:clayton_agent/domain/models/rag_stream_update.dart';
import 'package:clayton_agent/domain/repositories/rag_repository.dart';
import 'package:clayton_agent/presentation/blocs/rag_bloc.dart';
import 'package:clayton_agent/presentation/widgets/agent_role_dialog.dart';

class FakeRepo implements RagRepository {
  String role = 'Rol inicial';
  bool failUpdateRole = false;

  @override
  String get agentRole => role;

  @override
  Future<void> updateAgentRole(String role) async {
    if (failUpdateRole) throw Exception('save failed');
    this.role = role;
  }

  @override
  Future<List<String>> ingestFiles(List<String> filePaths) async => [];

  @override
  Future<List<String>> ingestAgentSkillsDirectory(String baseDirectoryPath) async => [];

  @override
  Future<List<String>> getIngestedFileNames() async => [];

  @override
  Future<String> askQuestion(String question) async => '';

  @override
  Stream<RagStreamUpdate> askQuestionStream(String question) => const Stream.empty();

  @override
  Future<void> clearKnowledgeBase() async {}
}

class FakeGpu implements GpuMetricsService {
  @override
  Stream<int> getGpuUsageStream({Duration interval = const Duration(microseconds: 0)}) =>
      Stream.value(0);
}

void main() {
  testWidgets('shows the current role, restores the example and saves the edited role',
      (tester) async {
    final repo = FakeRepo();
    final bloc = RagBloc(repository: repo, gpuMetricsService: FakeGpu());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAgentRoleDialog(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Rol inicial'), findsOneWidget);

    await tester.tap(find.text('Restaurar ejemplo'));
    await tester.pumpAndSettle();
    expect(find.text(defaultAgentRole), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rol editado');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.role, 'Rol editado');
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('save is disabled until the role is loaded', (tester) async {
    final repo = FakeRepo();
    final bloc = RagBloc(repository: repo, gpuMetricsService: FakeGpu());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const AgentRoleDialog(),
        ),
      ),
    );

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar'),
    );
    expect(saveButton.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Correr el test para verlo fallar**

Run: `flutter test test/presentation/widgets/agent_role_dialog_test.dart`
Expected: FAIL porque `agent_role_dialog.dart` no existe.

- [ ] **Step 3: Implementar el diálogo**

`lib/presentation/widgets/agent_role_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/prompt_settings_service.dart';
import '../blocs/rag_bloc.dart';

Future<void> showAgentRoleDialog(BuildContext context) {
  context.read<RagBloc>().add(LoadAgentRoleEvent());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<RagBloc>(),
      child: const AgentRoleDialog(),
    ),
  );
}

class AgentRoleDialog extends StatefulWidget {
  const AgentRoleDialog({super.key});

  @override
  State<AgentRoleDialog> createState() => _AgentRoleDialogState();
}

class _AgentRoleDialogState extends State<AgentRoleDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RagBloc, RagState>(
      listener: (context, state) {
        if (state is AgentRoleUpdatedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Rol del agente actualizado.')),
          );
          Navigator.of(context).pop();
        } else if (state is RagErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${state.errorMessage}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        // Si el rol ya estaba cargado antes de montar el diálogo, el listener
        // no se dispara: se toma el estado actual aquí (evita quedar en spinner).
        if (!_loaded && state is AgentRoleLoadedState) {
          _controller.text = state.role;
          _loaded = true;
        }
        return AlertDialog(
          title: const Text('Rol del agente'),
          content: _loaded
              ? SizedBox(
                  width: 560,
                  child: TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Describe el papel del agente y el dominio de las respuestas.',
                    ),
                  ),
                )
              : const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
          actions: [
            TextButton(
              onPressed: _loaded
                  ? () => setState(() => _controller.text = defaultAgentRole)
                  : null,
              child: const Text('Restaurar ejemplo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _loaded
                  ? () => context.read<RagBloc>().add(
                      UpdateAgentRoleEvent(_controller.text),
                    )
                  : null,
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Correr el test para verlo pasar**

Run: `flutter test test/presentation/widgets/agent_role_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/agent_role_dialog.dart test/presentation/widgets/agent_role_dialog_test.dart
git commit -m "feat(ui): add agent role edit dialog"
```

---

### Task 5: Wiring final (sidebar + inyección) y verificación

**Files:**
- Modify: `lib/presentation/views/chat_screen.dart:206-218`
- Modify: `lib/core/injection.dart:15-58`
- Test: suite completa

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: botón “Configurar rol del agente” en el sidebar; `PromptSettingsService` registrado en GetIt y rol inicial cargado antes de construir `RagRepositoryImpl`.

- [ ] **Step 1: Agregar el botón al sidebar**

En `chat_screen.dart`, después del botón “Subir Carpeta”, agregar:

```dart
OutlinedButton.icon(
  onPressed: _isGenerating ? null : () => showAgentRoleDialog(context),
  icon: const Icon(Icons.tune, size: 18),
  label: const Text('Configurar rol del agente'),
),
```

E importar `../widgets/agent_role_dialog.dart`.

- [ ] **Step 2: Registrar el servicio y cargar el rol inicial en `injection.dart`**

Agregar imports de `shared_preferences` y `prompt_settings_service.dart`. Antes de registrar `RagRepository`:

```dart
final preferences = await SharedPreferences.getInstance();
getIt.registerSingleton<SharedPreferences>(preferences);
getIt.registerLazySingleton<PromptSettingsService>(
  () => PromptSettingsServiceImpl(preferences: getIt()),
);
final initialAgentRole = await getIt<PromptSettingsService>().loadAgentRole();
```

Y cambiar el registro del repositorio:

```dart
getIt.registerLazySingleton<RagRepository>(
  () => RagRepositoryImpl(
    ollamaService: getIt(),
    vectorDbService: getIt(),
    promptSettingsService: getIt(),
    initialAgentRole: initialAgentRole,
  ),
);
```

- [ ] **Step 3: Verificar analyzer y tests**

Run: `flutter analyze`
Expected: 0 errores (los `info` preexistentes de `avoid_print` pueden seguir).

Run: `flutter test`
Expected: todos los tests PASS.

- [ ] **Step 4: Verificar el build de Linux**

Run: `flutter build linux --debug`
Expected: build exitoso en `build/linux/x64/debug/bundle/clayton_agent`.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/views/chat_screen.dart lib/core/injection.dart
git commit -m "feat(ui): wire agent role settings into sidebar and injection"
```

---

### Task 6: Verificación final

**Files:**
- Ninguno nuevo.

- [ ] **Step 1: Correr la suite completa y el analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 errores y todos los tests PASS.

- [ ] **Step 2: Commit final**

```bash
git commit --allow-empty -m "chore: complete customizable persistent agent role"
```
