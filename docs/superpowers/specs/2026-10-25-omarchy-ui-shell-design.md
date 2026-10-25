# Diseño: Shell de Escritorio con Estética Omarchy

**Fecha:** 2026-10-25
**Estado:** Pendiente de aprobación
**Rama:** `feature/omarchy`

---

## 1. Contexto e Intención

Clayton Agent es un MVP funcional de RAG local con una UI Material 3 convencional: un `Scaffold` con un panel lateral de 290 px, una lista de mensajes, un `TextField` y un `TelemetryBadge`. La lógica ya está separada en `RagBloc`, `RagRepository` y los servicios, por lo que el atractivo visual se puede mejorar sin tocar el comportamiento.

Se quiere adoptar `flutter_omarchy` no solo como tema, sino como estructura completa de aplicación de escritorio: barra superior, panel lateral redimensionable, barra de estado inferior, controles tipo terminal, toasts y diálogos propios. La referencia visual es la galería de `flutter_omarchy` (estética Omarchy / Tokyo Night).

El objetivo sigue siendo un MVP: se conservan todas las funciones actuales y no se agregan flujos de producto nuevos.

---

## 2. Metas, No-Metas y Anti-Metas

### Metas

- Reemplazar el shell Material por `OmarchyApp` + `OmarchyScaffold`.
- Mantener el chat, la ingesta de Markdown, la limpieza de la base, la configuración del rol, el streaming y la telemetría funcionando igual.
- Dar una jerarquía visual de app de escritorio: barra superior, panel de conocimiento redimensionable, área de chat y barra de estado.
- Reemplazar los controles Material visibles por equivalentes de `flutter_omarchy`.
- Adaptar el resaltado de código a la paleta de Omarchy en lugar del tema VS Code.
- Mantener la UI en español.
- Dejar la suite de tests en verde.

### No-Metas

- Cambiar `RagBloc`, eventos, estados, `RagRepository`, servicios o modelos.
- Agregar pestañas, múltiples sesiones de chat, historial navegable o paleta de comandos.
- Agregar selector de temas o configuración visual persistente.
- Cambiar el modelo, el endpoint o la lógica de Ollama.
- Modificar el runner de Linux o quitar la barra de ventana GTK.
- Cambiar la disposición de datos, la persistencia o la indexación.
- Rediseñar la lógica de streaming o el chunking.

### Anti-Metas

- No introducir regresiones en el streaming por reconstruir widgets costosos en cada token.
- No romper el renderizado de Markdown ni la estabilidad de bloques de código incompletos.
- No dejar restos visuales de Material (snackbars, inputs, diálogos, botones) conviviendo con el shell Omarchy.
- No agregar la paleta de comandos en esta pasada.
- No convertir el refactor de UI en un rediseño de producto.

---

## 3. Restricciones Técnicas

- Flutter 3.47.6 / Dart ^3.13.5, Linux Desktop (CachyOS, GTK3).
- Única dependencia nueva: `flutter_omarchy: ^0.3.0`.
- `flutter_omarchy` está en desarrollo temprano (0.3.0) y su API puede cambiar.
- El equipo no tiene Omarchy instalado: la librería usará su fallback **Tokyo Night** y la fuente configurada en Alacritty (`~/.config/alacritty/alacritty.toml`), con la fuente incluida por el paquete como respaldo.
- `Omarchy.initialize()` debe ejecutarse antes de `runApp` para cargar las fuentes.
- `OmarchyApp` usa `WidgetsApp`, no `MaterialApp`. Los widgets Material que dependan de `Theme`, `ScaffoldMessenger` o `MaterialLocalizations` deben reemplazarse o aislarse.
- No se toca la barra de título nativa: sin Hyprland/Omarchy, una ventana sin decoración sería difícil de mover y cerrar.
- El panel lateral se colapsa automáticamente por debajo de cierto ancho; debe poder reabrirse desde la barra superior.

---

## 4. Enfoques Considerados

Se evaluaron tres estructuras de shell, mostradas al usuario con mockups:

- **A. Terminal sobria** — `OmarchyScaffold` con barra superior, panel lateral redimensionable, chat central y barra de estado. Mapeo directo a la estructura de `flutter_omarchy`, bajo riesgo y sin conceptos nuevos. **Elegida.**
- **B. Workspace con pestañas** — pestañas de chat/documentos/ajustes, paleta de comandos y menús contextuales. Se descartó por agregar superficies y decisiones de producto que exceden un refactor de UI.
- **C. Chat inmersivo** — panel lateral colapsado a un riel y biblioteca en un drawer superpuesto. Se descartó porque reduce el descubrimiento de los documentos, que son el corazón del producto.

Dentro de A se descartó explícitamente la paleta de comandos (`⌘K`) para esta pasada.

---

## 5. Diseño

### 5.1 Estructura general

```
OmarchyApp
└── BlocProvider<RagBloc>
    └── ChatScreen
        └── OmarchyScaffold
            ├── navigationBar: OmarchyNavigationBar
            ├── leadingPanel: KnowledgePanel
            ├── status: OmarchyStatusBar
            └── child: chat + composer
```

- **Barra superior (`OmarchyNavigationBar`)**
  - Leading: botón de menú para mostrar/ocultar el panel cuando está colapsado.
  - Título: `clayton_agent` (o “Clayton Agent”), con estética de terminal.
  - Trailing: acción de configuración del rol del agente.
  - No incluye `⌘K` ni acciones nuevas.

- **Panel lateral (`leadingPanel` + `OmarchySplitPanel`)**
  - Título “Conocimiento local”.
  - Acciones existentes: subir archivo(s), subir carpeta, limpiar base de datos.
  - Lista de documentos indexados con `OmarchyTile`; estado vacío en texto atenuado.
  - Ancho inicial ~300 px, mínimo ~240 px, máximo ~420 px; redimensionable con `OmarchyResizeDivider`.
  - En ventanas angostas se muestra como `OmarchySidePanel` superpuesto y se abre desde el botón de menú.

- **Área de chat**
  - Lista de mensajes con scroll y auto-scroll al fondo, conservando la lógica actual de `_scrollToBottom`.
  - Mensaje del usuario: bloque alineado a la derecha, borde y etiqueta `vos`/`tú`.
  - Mensaje del asistente: bloque alineado a la izquierda, etiqueta `clayton`, Markdown renderizado y código con resaltado adaptado a Omarchy.
  - Estado vacío: instrucción breve en tono terminal.
  - Indicador de generación: `OmarchyLoader` + mensaje del estado (`RagLoadingState`).

- **Compositor**
  - `OmarchyTextInput` con prefijo `>` y placeholder `Preguntale al contexto indexado…`.
  - Botón de envío tipo `OmarchyButton` (o trailing del input) con estado deshabilitado mientras genera.
  - `Enter` envía; el comportamiento actual se conserva.
  - La telemetría deja de ser un badge separado y pasa a la barra de estado.

- **Barra de estado (`OmarchyStatusBar`)**
  - Izquierda: indicador estático `● local` y cantidad de documentos.
  - Derecha: `tok/s` y `GPU %`, con acentos verdes/amarillos.
  - Durante la generación, el indicador de tokens/GPU se actualiza como hoy.
  - **El nombre del modelo no se muestra en esta versión.** El dato solo existe en `OllamaServiceImpl` y exponerlo requeriría tocar la capa de datos, fuera del alcance de un refactor de UI. Queda para una versión futura junto con la configuración del modelo.

- **Avisos y diálogos**
  - Snackbars → `showOmarchyToast` (éxito, error, base vaciada, archivos indexados).
  - `AlertDialog` del rol → `showOmarchyDialog` + `OmarchyDialog` + `OmarchyTextInput`.
  - El diálogo conserva “Restaurar ejemplo”, “Cancelar” y “Guardar”, y sus estados de carga/error.

### 5.2 Tema y resaltado

- `main.dart` llama a `await Omarchy.initialize()` y usa `OmarchyApp(home: ...)` en lugar de `MaterialApp`.
- El tema se toma de `flutter_omarchy` (config del sistema o fallback Tokyo Night). No se crea un selector de temas.
- `MarkdownBody` recibe un `MarkdownStyleSheet` construido desde `OmarchyTheme` para que títulos, citas, enlaces, listas y texto usen la paleta y la tipografía del shell.
- El `CodeBlockBuilder` actual se reemplaza por un builder que usa los colores de Omarchy (fondo oscuro, borde de acento, tokens ANSI) en lugar de `vs2015Theme`.
- Si `MarkdownBody` o el texto seleccionable requieren un ancestro Material, se envuelve **solo el área de mensajes** en un `Theme`/`Material` transparente derivado de Omarchy. No se reintroduce Material en el shell.

### 5.3 Organización de archivos

Para evitar que `chat_screen.dart` siga creciendo:

- `lib/presentation/views/chat_screen.dart` — composición del shell, listeners del bloc y estado de mensajes.
- `lib/presentation/widgets/knowledge_panel.dart` — panel lateral.
- `lib/presentation/widgets/chat_message.dart` — mensaje de usuario/asistente y estilos Markdown.
- `lib/presentation/widgets/chat_composer.dart` — input y envío.
- `lib/presentation/widgets/agent_role_dialog.dart` — diálogo migrado a Omarchy.
- `lib/presentation/widgets/telemetry_badge.dart` — se elimina o se reemplaza por la composición de `OmarchyStatus` en la barra de estado.
- `lib/presentation/theme/omarchy_markdown.dart` (nombre tentativo) — `MarkdownStyleSheet` y tema de código derivados de Omarchy.

Los nombres definitivos y la división exacta quedan a criterio del implementador, siempre que no se toque la lógica.

### 5.4 Tests

- Los tests de UI se envuelven en `OmarchyApp` con un `OmarchyThemeData` explícito (Tokyo Night + `OmarchyTextStyleData.fallback()`) para no depender de archivos del sistema.
- `chat_screen_test.dart` sigue verificando el panel, el streaming rápido y la apertura del diálogo, adaptando los selectores a los widgets Omarchy.
- `agent_role_dialog_test.dart` se adapta de `FilledButton`/`TextField` a los equivalentes Omarchy.
- No se modifican los tests de bloc, repositorio ni servicio.
- Verificación final: `flutter analyze` sin errores nuevos y `flutter test` en verde.

---

## 6. Decisiones Tomadas

- **Estructura A** (terminal sobria) elegida por el usuario.
- **Sin paleta de comandos** ni `⌘K`.
- **Sin pestañas ni sesiones múltiples**.
- **Marco de ventana nativo** conservado por estar en CachyOS.
- **Tema fallback Tokyo Night** aceptado; no se instala Omarchy.
- **Sin nombre de modelo en la barra de estado** en esta versión; se agrega cuando exista configuración de modelo.
- **Se conserva `flutter_markdown`** y el resaltado de código, adaptando estilos.
- **Se conserva toda la lógica** de streaming, ingesta, rol y telemetría.

---

## 7. Criterios de Aceptación

- La app arranca con `OmarchyApp` y se ve el shell completo (barra superior, panel lateral, área de chat, barra de estado).
- Subir archivos Markdown y carpetas, limpiar la base y editar el rol siguen funcionando.
- El streaming se muestra sin tirones y el Markdown no se rompe durante la generación.
- Los bloques de código se resaltan con la paleta de Omarchy.
- Los avisos aparecen como toasts y el rol se edita en un diálogo Omarchy.
- El panel lateral se redimensiona y se colapsa/reabre en ventanas angostas.
- No quedan controles Material visibles en el flujo principal.
- `flutter analyze` y `flutter test` pasan.
- No hay cambios en `lib/domain`, `lib/data` ni en la lógica de `lib/presentation/blocs`.

---

## 8. Lo que Queda al Implementador

- Elegir iconos concretos de `OmarchyIcons` y el agrupamiento final de acciones.
- Definir los valores exactos de `MarkdownStyleSheet` y del tema de resaltado.
- Decidir si conviene dividir `chat_screen.dart` como se propone o mantener un solo archivo si la división agrega ruido.
- Resolver el wrapper Material mínimo para Markdown si los tests muestran que hace falta.
- Ajustar anchos, paddings y tamaños tipográficos para que se vea bien en 1280×720 y en ventanas más grandes.
- Verificar manualmente el resultado en Linux y adjuntar una captura al cerrar la tarea.
