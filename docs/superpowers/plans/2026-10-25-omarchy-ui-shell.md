# Omarchy UI Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la UI Material de Clayton Agent por un shell de escritorio Omarchy, conservando intactas todas las funciones y toda la lógica.

**Architecture:** `OmarchyApp` reemplaza a `MaterialApp`; `OmarchyScaffold` aporta barra superior, panel lateral redimensionable y barra de estado. La presentación se divide en widgets chicos (`KnowledgePanel`, `ChatMessage`, `ChatComposer`) que consumen el `RagBloc` existente sin modificarlo.

**Tech Stack:** Flutter 3.47.6, Dart ^3.13.5, `flutter_omarchy` 0.3.0, `flutter_markdown`, `flutter_highlighter`, `flutter_bloc`.

**Spec:** `docs/superpowers/specs/2026-10-25-omarchy-ui-shell-design.md`

## Global Constraints

- Flutter 3.47.6 / Dart ^3.13.5 / Linux Desktop; no cambiar versiones del SDK.
- Única dependencia nueva: `flutter_omarchy: ^0.3.0`. No agregar otras.
- No modificar `lib/domain/**`, `lib/data/**` ni la lógica de `lib/presentation/blocs/**`.
- La UI sigue en español; conservar los textos existentes salvo los cambios indicados.
- Sin paleta de comandos, pestañas, sesiones múltiples ni selector de temas.
- Sin nombre de modelo en la barra de estado en esta versión.
- Tema fallback Tokyo Night; no instalar Omarchy ni cambiar archivos de configuración del sistema.
- No tocar `linux/runner/**` ni la barra de ventana nativa.
- Conservar streaming, auto-scroll, estabilización de Markdown y resaltado de código.
- Criterio de análisis: `flutter analyze` sin errores nuevos. Hoy reporta 2 `avoid_print` preexistentes.
- Criterio de tests: `flutter test` en verde.

## Review Focus

- **Streaming con un bloque de código sin cerrar:** debe seguir mostrándose estable, sin excepciones ni saltos de layout.
- **Ventana angosta (< 500 px):** el panel debe ocultarse solo, reabrirse desde el menú y no desbordar.
- **Markdown del asistente bajo `OmarchyApp` (sin `MaterialApp`):** texto, selección y enlaces no deben lanzar excepciones.
- **Base vacía y nombres de archivo muy largos:** estado vacío claro y nombres con elipsis, sin overflow.
- **Enviar con Enter mientras se genera:** no debe dispararse una segunda consulta ni quedar el compositor bloqueado.

---

### Task 1: Dependencia, harness de tests y panel de conocimiento

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/support/omarchy_test_app.dart`
- Create: `lib/presentation/widgets/knowledge_panel.dart`
- Create: `test/presentation/widgets/knowledge_panel_test.dart`

**Interfaces:**
- Produces:
  - `const OmarchyThemeData testOmarchyTheme` y `Widget wrapInOmarchy(Widget child)` en `test/support/omarchy_test_app.dart`.
  - `const KnowledgePanel({required List<String> files, required bool isBusy, required VoidCallback onPickFiles, required VoidCallback onPickDirectory, required VoidCallback onClear})`.
  - Keys estables: `knowledge-add-files`, `knowledge-add-folder`, `knowledge-clear`.

- [ ] **Step 1: Agregar la dependencia y verificar que resuelve**

```bash
flutter pub add flutter_omarchy:^0.3.0
flutter pub get
```

Expected: `pubspec.yaml` incluye `flutter_omarchy: ^0.3.0` y `pubspec.lock` queda actualizado.

- [ ] **Step 2: Crear el harness de tests**

`test/support/omarchy_test_app.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

const OmarchyThemeData testOmarchyTheme = OmarchyThemeData(
  colors: OmarchyColorThemes.tokyoNight,
  text: OmarchyTextStyleData.fallback(),
);

Widget wrapInOmarchy(Widget child) => OmarchyApp(
  debugShowCheckedModeBanner: false,
  theme: testOmarchyTheme,
  home: child,
);
```

- [ ] **Step 3: Escribir los tests del panel (deben fallar)**

`test/presentation/widgets/knowledge_panel_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/widgets/knowledge_panel.dart';
import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('shows the empty state when there are no files', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: [],
      isBusy: false,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    expect(find.text('Conocimiento local'), findsOneWidget);
    expect(
      find.text('No hay documentos cargados.\nAgrega archivos .md o carpetas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ellipsizes long document names', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: ['un-nombre-de-archivo-extraordinariamente-largo.md'],
      isBusy: false,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    final name = tester.widget<Text>(
      find.text('un-nombre-de-archivo-extraordinariamente-largo.md'),
    );
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables actions while busy', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: [],
      isBusy: true,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    final button = tester.widget<OmarchyButton>(
      find.widgetWithText(OmarchyButton, 'Subir archivo(s)'),
    );
    expect(button.onPressed, isNull);
  });
}

void _noop() {}
```

- [ ] **Step 4: Correr los tests y confirmar que fallan**

Run: `flutter test test/presentation/widgets/knowledge_panel_test.dart -v`

Expected: FAIL porque `knowledge_panel.dart` todavía no existe.

- [ ] **Step 5: Implementar `KnowledgePanel`**

`lib/presentation/widgets/knowledge_panel.dart` debe:

- Usar `Padding` + `Column` con título `Conocimiento local` en `theme.text.bold`.
- Incluir tres `OmarchyButton` con las keys indicadas:
  - `Subir archivo(s)` con `AnsiColor.blue` e icono `OmarchyIcons.codFile`.
  - `Subir carpeta` con `AnsiColor.blue` e icono `OmarchyIcons.codFolder`.
  - `Limpiar base de datos` con `AnsiColor.red` e icono `OmarchyIcons.codTrash`.
  - Todos con `onPressed: isBusy ? null : callback`.
- Mostrar `Documentos indexados (${files.length})`.
- Si `files.isEmpty`, centrar el texto exacto del test con estilo atenuado (`theme.colors.bright.black`).
- Si no, `ListView.builder` con `OmarchyTile` por archivo, icono `codFile` y `Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)`.
- Dejar el botón de limpiar al final, después del área expandible de la lista.

- [ ] **Step 6: Correr los tests y confirmar que pasan**

Run: `flutter test test/presentation/widgets/knowledge_panel_test.dart -v`

Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock test/support/omarchy_test_app.dart lib/presentation/widgets/knowledge_panel.dart test/presentation/widgets/knowledge_panel_test.dart docs/superpowers/specs/2026-10-25-omarchy-ui-shell-design.md docs/superpowers/plans/2026-10-25-omarchy-ui-shell.md
git commit -m "feat(ui): add omarchy dependency and knowledge panel"
```

---

### Task 2: Mensaje de chat, Markdown y código con tema Omarchy

**Files:**
- Create: `lib/presentation/theme/omarchy_markdown.dart`
- Create: `lib/presentation/widgets/chat_message.dart`
- Create: `test/presentation/widgets/chat_message_test.dart`

**Interfaces:**
- Produces:
  - `MarkdownStyleSheet omarchyMarkdownStyleSheet(BuildContext context)`.
  - `Map<String, TextStyle> omarchyCodeTheme(BuildContext context)`.
  - `class OmarchyCodeBlockBuilder extends MarkdownElementBuilder`.
  - `ChatMessage({required bool isUser, required String text, bool isStreaming = false})`.

- [ ] **Step 1: Escribir los tests del mensaje (deben fallar)**

`test/presentation/widgets/chat_message_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/widgets/chat_message.dart';
import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('renders user and assistant messages', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const SizedBox(
      width: 600,
      child: Column(children: [
        ChatMessage(isUser: true, text: 'Hola'),
        ChatMessage(
          isUser: false,
          text: '## Título\n\n```dart\nfinal x = 1;\n```',
        ),
      ]),
    )));

    expect(find.text('vos'), findsOneWidget);
    expect(find.text('clayton'), findsOneWidget);
    expect(find.textContaining('Hola'), findsOneWidget);
    expect(find.textContaining('Título'), findsWidgets);
    expect(find.byType(HighlightView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stabilizes an unclosed code fence while streaming', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const SizedBox(
      width: 600,
      child: ChatMessage(
        isUser: false,
        isStreaming: true,
        text: 'Texto\n```dart\nfinal x = 1;',
      ),
    )));

    expect(find.byType(HighlightView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/presentation/widgets/chat_message_test.dart -v`

Expected: FAIL porque `chat_message.dart` no existe.

- [ ] **Step 3: Implementar el tema Markdown**

`lib/presentation/theme/omarchy_markdown.dart`:

- `omarchyMarkdownStyleSheet(context)` devuelve un `MarkdownStyleSheet` explícito usando `OmarchyTheme.of(context)`:
  - `p`: `theme.text.normal`.
  - `a`: `theme.colors.bright.blue` con `TextDecoration.underline`.
  - `em`: `theme.text.italic`.
  - `strong`: `theme.text.bold`.
  - `del`: `theme.text.normal.copyWith(decoration: TextDecoration.lineThrough)`.
  - `code`: `theme.text.normal.copyWith(color: theme.colors.bright.green, backgroundColor: theme.colors.normal.black)`.
  - `h1`–`h6`: `theme.text.bold` con `bright.magenta`, tamaños 22/20/18/16/15/14.
  - `blockquote`: `theme.text.italic` en `bright.yellow`, con borde izquierdo `bright.yellow`.
  - `listBullet`: `theme.text.normal`.
  - `blockSpacing`: `8`, `listIndent`: `18`.
- `omarchyCodeTheme(context)` devuelve un `Map<String, TextStyle>` para `flutter_highlighter` con `root`, `keyword`, `string`, `comment`, `number`, `built_in`, `literal`, `type`, `title`, `attr`, `variable`, `selector-tag`, `selector-id`, `selector-class`, `meta`, `tag`. Usar `background`, `foreground`, `bright.magenta`, `bright.green`, `bright.black`, `bright.yellow`, `bright.cyan` y `bright.blue` del tema.
- `OmarchyCodeBlockBuilder` implementa `visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle)` (no el `visitElementAfter` deprecado): detecta `language-*`, recorta el contenido y devuelve un `Container` con fondo `theme.colors.normal.black`, borde izquierdo `theme.colors.bright.magenta`, padding 12 y un `HighlightView` con `omarchyCodeTheme(context)`.

- [ ] **Step 4: Implementar `ChatMessage`**

`lib/presentation/widgets/chat_message.dart`:

- `StatelessWidget` con los parámetros de la interfaz.
- Etiqueta superior: `vos` para usuario y `clayton` para asistente, en mayúsculas, tamaño 10, color `bright.green` / `bright.cyan`.
- Usuario: `Container` con borde `theme.colors.border`, fondo `theme.colors.normal.black`, texto `theme.text.normal`.
- Asistente: `MarkdownBody` con `styleSheet: omarchyMarkdownStyleSheet(context)` y `builders: {'code': OmarchyCodeBlockBuilder()}`.
- Si `isStreaming`, aplicar la misma estabilización de fences que hoy (`_estabilizarMarkdown`) y `selectable: false`; si no, `selectable: true`.
- Alinear a la derecha/izquierda desde el widget padre (el `ChatMessage` no decide el ancho).
- Mover `_estabilizarMarkdown` desde `chat_screen.dart` a este archivo como función privada.

- [ ] **Step 5: Correr los tests y confirmar que pasan**

Run: `flutter test test/presentation/widgets/chat_message_test.dart -v`

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/theme/omarchy_markdown.dart lib/presentation/widgets/chat_message.dart test/presentation/widgets/chat_message_test.dart
git commit -m "feat(ui): render chat messages with omarchy markdown styles"
```

---

### Task 3: Compositor de chat

**Files:**
- Create: `lib/presentation/widgets/chat_composer.dart`
- Create: `test/presentation/widgets/chat_composer_test.dart`

**Interfaces:**
- Produces:
  - `ChatComposer({required TextEditingController controller, required bool isGenerating, required VoidCallback onSend})`.
  - Keys: `chat-input`, `chat-send`.

- [ ] **Step 1: Escribir los tests del compositor (deben fallar)**

`test/presentation/widgets/chat_composer_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/widgets/chat_composer.dart';
import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('submits the typed text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(wrapInOmarchy(SizedBox(
      width: 600,
      child: ChatComposer(
        controller: controller,
        isGenerating: false,
        onSend: () => sent++,
      ),
    )));

    await tester.enterText(find.byType(EditableText), 'Hola');
    await tester.tap(find.byKey(const Key('chat-send')));
    expect(sent, 1);
  });

  testWidgets('does not submit while generating', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(wrapInOmarchy(SizedBox(
      width: 600,
      child: ChatComposer(
        controller: controller,
        isGenerating: true,
        onSend: () => sent++,
      ),
    )));

    final send = tester.widget<OmarchyButton>(find.byKey(const Key('chat-send')));
    expect(send.onPressed, isNull);
    await tester.enterText(find.byType(EditableText), 'Hola');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(sent, 0);
  });
}
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

Run: `flutter test test/presentation/widgets/chat_composer_test.dart -v`

Expected: FAIL porque `chat_composer.dart` no existe.

- [ ] **Step 3: Implementar `ChatComposer`**

- `OmarchyTextInput` con key `chat-input`, `controller`, `maxLines: 1`, `leading: Text('>', style: theme.text.bold.copyWith(color: theme.colors.bright.green))`, `placeholder: Text('Preguntale al contexto indexado…')`.
- `onSubmitted: (_) { if (!isGenerating) onSend(); }`.
- `trailing`: `OmarchyButton` con key `chat-send`, `style: OmarchyButtonStyle.filled(AnsiColor.blue)`, `onPressed: isGenerating ? null : onSend`, e icono `codSend` (o `OmarchyLoader(size: 16)` cuando genera, dentro del mismo botón deshabilitado).
- Envolver todo en `Padding` con `EdgeInsets.fromLTRB(16, 12, 16, 8)` y un borde superior `theme.colors.border`.

- [ ] **Step 4: Correr los tests y confirmar que pasan**

Run: `flutter test test/presentation/widgets/chat_composer_test.dart -v`

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/chat_composer.dart test/presentation/widgets/chat_composer_test.dart
git commit -m "feat(ui): add omarchy chat composer"
```

---

### Task 4: Shell Omarchy, migración de `main` y tests de integración

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/presentation/views/chat_screen.dart`
- Delete: `lib/presentation/widgets/telemetry_badge.dart`
- Modify: `test/presentation/views/chat_screen_test.dart`

**Interfaces:**
- Consumes: `KnowledgePanel`, `ChatMessage`, `ChatComposer` de las tareas 1–3.
- Produces: `ChatScreen` montado sobre `OmarchyScaffold`; `MyApp` usa `OmarchyApp`.

- [ ] **Step 1: Reescribir los tests de integración (deben fallar)**

En `test/presentation/views/chat_screen_test.dart`:

- Reemplazar el wrapper `MaterialApp` por `wrapInOmarchy(...)` de `test/support/omarchy_test_app.dart`.
- Mantener el test de streaming rápido y el mock actual.
- Agregar/ajustar asserts:
  - `find.text('clayton_agent')` (título de la barra).
  - `find.text('Conocimiento local')`.
  - `find.text('habilidad.md')`.
  - `find.text('1 documento')`.
  - `find.text('● local')`.
- Enviar con `tester.enterText(find.byType(EditableText), ...)` y tocar `find.byKey(const Key('chat-send'))`.
- Al terminar el streaming, `expect(tester.takeException(), isNull)`.
- Test del diálogo: tocar `find.byIcon(OmarchyIcons.codSettingsGear)` y esperar `find.text('Rol del agente')`.
- Test de ventana angosta:
  - `tester.view.physicalSize = const Size(480, 800); tester.view.devicePixelRatio = 1.0;`
  - `addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);`
  - Pump, `expect(find.text('Conocimiento local'), findsNothing)`.
  - Tocar `find.byIcon(OmarchyIcons.codMenu)` y `pumpAndSettle`.
  - `expect(find.text('Conocimiento local'), findsOneWidget)`.
- Test de envío mientras genera:
  - Tras enviar la primera pregunta, obtener el `OmarchyButton` con key `chat-send` y verificar `onPressed == null`.
  - `expect(tester.takeException(), isNull)`.

Run: `flutter test test/presentation/views/chat_screen_test.dart -v`

Expected: FAIL porque el `ChatScreen` actual no tiene `OmarchyScaffold` ni las keys nuevas.

- [ ] **Step 2: Migrar `lib/main.dart`**

```dart
import 'package:clayton_agent/core/injection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

import 'presentation/blocs/rag_bloc.dart';
import 'presentation/views/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Omarchy.initialize();
  await initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OmarchyApp(
      debugShowCheckedModeBanner: false,
      home: BlocProvider<RagBloc>(
        create: (context) => getIt<RagBloc>(),
        child: const ChatScreen(),
      ),
    );
  }
}
```

- [ ] **Step 3: Reescribir `ChatScreen` sobre `OmarchyScaffold`**

Mantener toda la lógica actual de:
- `initState` → `LoadIngestedFilesEvent`.
- `_scrollToBottom` y `_isScrollScheduled`.
- `_pickMarkdownFiles`, `_pickSkillsDirectory`.
- `_sendQuestion` con guard `_isGenerating`.
- `BlocListener` para `KnowledgeBaseClearedState`, `FileIngestedSuccessState`, `RagLoadedFilesState`, `RagStreamingState`, `RagResponseSuccessState`, `RagErrorState`.
- Lista `_messages`, `_ingestedFiles`, `_currentTps`, `_gpuUsage`, `_isGenerating`.

Cambiar solo la composición visual:

```dart
OmarchyScaffold(
  navigationBar: _ShellNavigationBar(onConfigureRole: () => showAgentRoleDialog(context)),
  leadingPanel: KnowledgePanel(
    files: _ingestedFiles,
    isBusy: _isGenerating,
    onPickFiles: () => _pickMarkdownFiles(context),
    onPickDirectory: () => _pickSkillsDirectory(context),
    onClear: () => context.read<RagBloc>().add(ClearKnowledgeBaseEvent()),
  ),
  panelInitialSize: const PanelSize.absolute(300),
  minPanelSize: const PanelSize.absolute(240),
  maxPanelSize: const PanelSize.absolute(420),
  status: OmarchyStatusBar(
    leading: [
      const OmarchyStatus(accent: AnsiColor.green, child: Text('● local')),
      OmarchyStatus(child: Text(_documentLabel(_ingestedFiles.length))),
    ],
    trailing: [
      OmarchyStatus(
        accent: AnsiColor.yellow,
        child: Text(_currentTps > 0 ? '${_currentTps.toStringAsFixed(1)} tok/s' : '-- tok/s'),
      ),
      OmarchyStatus(
        accent: AnsiColor.blue,
        child: Text('GPU $_gpuUsage%'),
      ),
    ],
  ),
  child: BlocListener<RagBloc, RagState>(
    listener: ...,
    child: Column(
      children: [
        Expanded(child: _messages.isEmpty ? _emptyState(context) : _messageList()),
        BlocBuilder<RagBloc, RagState>(builder: ... OmarchyLoader ...),
        ChatComposer(
          controller: _questionController,
          isGenerating: _isGenerating,
          onSend: () => _sendQuestion(context),
        ),
      ],
    ),
  ),
)
```

Detalles obligatorios:

- `_ShellNavigationBar` es un widget privado en `chat_screen.dart`:
  - `title: const Text('clayton_agent')`.
  - `leading`: si `OmarchyScaffold.leadingPanelMaybeOf(context)?.isHidden == true`, un `OmarchyButton` con `OmarchyIcons.codMenu` que haga `hiddenController.isVisible = true`.
  - `trailing`: `OmarchyTooltip(message: 'Configurar rol del agente', child: OmarchyButton(onPressed: onConfigureRole, child: Icon(OmarchyIcons.codSettingsGear)))`.
- `_messageList`: `ListView.builder` con `controller: _scrollController`, padding 24/16 y cada mensaje en un `Align` + `ConstrainedBox(maxWidth: 760)` + `Padding(vertical: 6)`.
- `_emptyState`: `Center` con `Text('> Haz una pregunta sobre tus documentos Markdown indexados.', style: theme.text.italic.copyWith(color: theme.colors.bright.black))`.
- `_documentLabel(int count) => '$count ${count == 1 ? 'documento' : 'documentos'}'`.
- Reemplazar los `ScaffoldMessenger.showSnackBar` por:
  - Base vaciada: `showOmarchyToast(context: context, accent: AnsiColor.yellow, message: const Text('Base de datos vectorial vaciada por completo.'))`.
  - Archivos indexados: `accent: AnsiColor.green` con el mismo texto actual.
  - Error: `accent: AnsiColor.red` con `'Error: ${state.errorMessage}'`.
- El indicador de `RagLoadingState` usa `OmarchyLoader(size: 14, accent: AnsiColor.blue)` + el texto del estado.
- Eliminar `telemetry_badge.dart` y su import; la telemetría vive en la barra de estado.
- No importar `flutter/material.dart` en `chat_screen.dart`; usar `flutter/widgets.dart`, `flutter_omarchy` y `flutter_markdown`.

- [ ] **Step 4: Correr los tests de integración y ajustar**

Run: `flutter test test/presentation/views/chat_screen_test.dart -v`

Expected: PASS. Si el diálogo Material temporal falla bajo `OmarchyApp`, se resuelve en la tarea 5, no se revierte el shell.

- [ ] **Step 5: Correr toda la suite**

Run: `flutter test`

Expected: PASS (los tests de UI de las tareas 1–3 incluidos).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/presentation/views/chat_screen.dart test/presentation/views/chat_screen_test.dart
git rm lib/presentation/widgets/telemetry_badge.dart
git commit -m "feat(ui): replace material shell with omarchy desktop shell"
```

---

### Task 5: Diálogo de rol con Omarchy

**Files:**
- Modify: `lib/presentation/widgets/agent_role_dialog.dart`
- Modify: `test/presentation/widgets/agent_role_dialog_test.dart`

**Interfaces:**
- Consumes: `wrapInOmarchy`, `OmarchyDialog`, `showOmarchyDialog`, `OmarchyTextInput`, `OmarchyButton`, `OmarchyLoader`, `showOmarchyToast`.
- Produces: `showAgentRoleDialog(BuildContext context)` abre un diálogo Omarchy y conserva el contrato actual (carga, restaurar, guardar).

- [ ] **Step 1: Adaptar los tests (deben fallar con el diálogo Material)**

En `test/presentation/widgets/agent_role_dialog_test.dart`:

- Reemplazar `MaterialApp` por `wrapInOmarchy(...)`.
- Reemplazar el `Scaffold`/`ElevatedButton` que abre el diálogo por `Center` + `OmarchyButton` con texto `abrir`.
- `tester.enterText(find.byType(TextField), ...)` → `tester.enterText(find.byType(EditableText), ...)`.
- `find.widgetWithText(FilledButton, 'Guardar')` → `find.widgetWithText(OmarchyButton, 'Guardar')`.
- Después de guardar y hacer `pumpAndSettle`, agregar `await tester.pump(const Duration(seconds: 5));` para drenar el timer del toast de éxito antes de que termine el test.
- Mantener los dos casos: guardar rol editado y guardar deshabilitado hasta cargar.

Run: `flutter test test/presentation/widgets/agent_role_dialog_test.dart -v`

Expected: FAIL porque el diálogo actual usa Material.

- [ ] **Step 2: Migrar `showAgentRoleDialog` y `AgentRoleDialog`**

- `showAgentRoleDialog` usa `showOmarchyDialog<void>(context: context, builder: (_) => BlocProvider.value(value: bloc, child: const AgentRoleDialog()))`; conservar el `LoadAgentRoleEvent` previo.
- `AgentRoleDialog` devuelve `OmarchyDialog(maxWidth: 640, title: Text('Rol del agente'), content: ..., actions: ...)`.
- Carga: `SizedBox(height: 80, child: Center(child: OmarchyLoader(accent: AnsiColor.blue)))`.
- Editor: `SizedBox(width: 560, child: OmarchyTextInput(controller: _controller, minLines: 4, maxLines: 10, placeholder: Text('Describe el papel del agente y el dominio de las respuestas.')))`.
- Acciones: `OmarchyButton` “Restaurar ejemplo”, “Cancelar” y “Guardar” (este último con `OmarchyButtonStyle.filled(AnsiColor.blue)` y `onPressed: _loaded ? ... : null`).
- Éxito: `showOmarchyToast(context: context, accent: AnsiColor.green, message: const Text('Rol del agente actualizado.'))` y luego `Navigator.of(context).pop()`.
- Error: `showOmarchyToast(context: context, accent: AnsiColor.red, message: Text(state.errorMessage))`.
- No usar `showDialog`, `AlertDialog`, `TextField`, `FilledButton` ni `ScaffoldMessenger`.

- [ ] **Step 3: Correr los tests y confirmar que pasan**

Run: `flutter test test/presentation/widgets/agent_role_dialog_test.dart -v`

Expected: PASS (2 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/agent_role_dialog.dart test/presentation/widgets/agent_role_dialog_test.dart
git commit -m "feat(ui): migrate agent role dialog to omarchy"
```

---

### Task 6: Limpieza y verificación final

**Files:**
- Verify: todo el árbol
- Possibly modify: imports/archivos residuales si `flutter analyze` lo pide

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: rama lista para revisión.

- [ ] **Step 1: Buscar restos de Material y telemetría vieja**

Run: `rg -n "TelemetryBadge|telemetry_badge|ScaffoldMessenger|AlertDialog|FilledButton|TextField|MaterialApp" lib test`

Expected: sin resultados en `lib/presentation` y `lib/main.dart`. En tests solo pueden quedar imports necesarios de Flutter widgets; ningún `MaterialApp`.

- [ ] **Step 2: Formatear**

Run: `dart format lib test`

Expected: archivos formateados sin errores.

- [ ] **Step 3: Analizar**

Run: `flutter analyze`

Expected: solo los 2 `avoid_print` preexistentes (`gpu_metrics_service.dart:59`, `rag_bloc.dart:151`). Cualquier otro issue es un fallo de la tarea.

- [ ] **Step 4: Correr toda la suite**

Run: `flutter test`

Expected: todos los tests pasan.

- [ ] **Step 5: Compilar el bundle Linux**

Run: `flutter build linux --debug`

Expected: build exitoso en `build/linux/x64/debug/bundle/clayton_agent`.

- [ ] **Step 6: Commit de limpieza (si hubo cambios)**

```bash
git add -A
git commit -m "chore(ui): clean up omarchy shell leftovers"
```

Si no hubo cambios, no crear un commit vacío.

---

## Notas de ejecución

- El orden de tareas es intencional: las tareas 1–3 crean widgets aislados y testeables; la 4 los integra y recién ahí cambia el arranque de la app; la 5 elimina el último diálogo Material; la 6 verifica.
- No avanzar a la tarea 5 si la 4 deja tests rojos por el diálogo: primero se resuelve el shell y luego el diálogo.
- Si `OmarchyApp` no provee algo que `MarkdownBody` necesita, envolver **solo** el área de mensajes en un `Theme`/`Material` transparente derivado de Omarchy. No volver a introducir Material en el shell.
- Si `Omarchy.initialize()` falla por fuentes en el entorno de tests, no llamarlo en tests: el harness usa `testOmarchyTheme`.
- No agregar capturas ni documentación nueva salvo que el usuario lo pida.
