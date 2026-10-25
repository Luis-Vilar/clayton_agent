# 🤖 Clayton Agent

**Local RAG Flutter Desktop** — Un agente de IA conversacional que corre 100% en tu máquina. Indexa tus documentos Markdown y responde preguntas sobre ellos usando un modelo de lenguaje local a través de Ollama, sin enviar ningún dato a la nube.

---

[Videocaptura de pantalla_20261025_091910.webm](https://github.com/user-attachments/assets/e14240e6-237b-4f80-94d9-292d28147cce)


[ollama run qwen2.5-coder:7b.webm](https://github.com/user-attachments/assets/839e07d0-da5d-4854-b119-c303a9b1346c)

---

## ✨ Características

- **100% Local & Privado** — Ningún dato sale de tu máquina. Ollama y la base de datos vectorial corren íntegramente en local.
- **RAG (Retrieval-Augmented Generation)** — Las respuestas se generan a partir del contexto exacto de tus documentos, no de información genérica del modelo.
- **Streaming de tokens en tiempo real** — La respuesta del LLM se va mostrando palabra a palabra mientras se genera.
- **Markdown con resaltado de sintaxis estilo VS Code** — Los bloques de código se renderizan con el tema VS 2015 y detección automática del lenguaje. Durante el streaming, los bloques aún sin cerrar se estabilizan para que el Markdown no se rompa.
- **Contexto ampliado** — Cada consulta recupera hasta **10 fragmentos** relevantes del vector store, en lugar de 4, para respuestas con más cobertura documental.
- **Base de datos vectorial embebida** — Usa [ObjectBox](https://objectbox.io/) con índice HNSW para búsqueda semántica ultrarrápida.
- **Telemetría en vivo** — Muestra tokens/segundo y uso de GPU mientras el modelo genera.
- **Ingesta flexible** — Soporta archivos `.md` individuales o carpetas completas de manera recursiva.
- **Rol del agente personalizable** — Editable desde la UI y persistido localmente, para adaptar el agente a otros dominios además de Flutter.
- **UI de escritorio nativa en Linux** — Construida con Flutter y Material Design 3.

---

## 🏗️ Arquitectura

El proyecto sigue una arquitectura limpia en tres capas:

```
lib/
├── core/           # Bootstrapping e inyección de dependencias (GetIt)
├── data/
│   ├── models/     # MarkdownChunk (entidad ObjectBox + embedding vectorial)
│   └── services/   # OllamaService, VectorDbService, GpuMetricsService, PromptSettingsService
├── domain/
│   ├── models/     # RagStreamUpdate
│   └── repositories/ # RagRepository (lógica RAG: chunking, búsqueda, prompting)
└── presentation/
    ├── blocs/      # RagBloc (flutter_bloc: eventos, estados, streaming)
    ├── views/      # ChatScreen (UI principal y CodeBlockBuilder)
    └── widgets/    # AgentRoleDialog, TelemetryBadge
```

### Flujo RAG

```
Documento .md  →  Chunking por encabezados  →  Embedding (nomic-embed-text)  →  ObjectBox (HNSW)

Pregunta del usuario  →  Embedding  →  Obtención de los 10 chunks más similares
      →  Prompt enriquecido (rol + contexto)  →  Ollama (qwen2.5-coder:7b)
      →  Respuesta Markdown con resaltado de sintaxis estilo VS Code
```

---

## 📋 Requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Flutter SDK | `3.47.6` |
| Dart SDK | `^3.13.5` |
| [Ollama](https://ollama.com) | Última estable |
| Sistema operativo | Linux |

### Modelos de Ollama necesarios

```bash
# Modelo de embeddings (768 dimensiones)
ollama pull nomic-embed-text

# Modelo de generación de texto
ollama pull qwen2.5-coder:7b
```

> [!NOTE]
> Puedes cambiar los modelos en [`lib/data/services/ollama_service.dart`](lib/data/services/ollama_service.dart). Asegúrate de que el modelo de embeddings produzca vectores de **768 dimensiones** para que coincida con el índice HNSW configurado en `MarkdownChunk`.

---

## 🚀 Instalación y ejecución

### 1. Clona el repositorio

```bash
git clone <url-del-repositorio>
cd clayton_agent
```

### 2. Instala las dependencias

```bash
flutter pub get
```

### 3. Genera el código de ObjectBox

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Asegúrate de que Ollama esté corriendo

```bash
ollama serve
```

### 5. Ejecuta la app

```bash
flutter run -d linux
```

---

## 🖥️ Uso

### Indexar documentos

| Acción | Descripción |
|--------|-------------|
| **Subir Archivo(s)** | Abre un selector de archivos para indexar uno o varios `.md` |
| **Subir Carpeta** | Recorre recursivamente un directorio e indexa todos los `.md` encontrados (ideal para carpetas de skills o documentación) |
| **Configurar rol del agente** | Abre un diálogo para editar el rol base del prompt; se guarda localmente y se aplica a la próxima consulta |

### Conversar con tus documentos

1. Escribe tu pregunta en el campo de texto inferior.
2. Presiona **Enter** o el botón de enviar.
3. La respuesta se genera en streaming con formato Markdown y resaltado de sintaxis estilo VS Code en los bloques de código.

### Gestionar la base de conocimiento

- El panel izquierdo muestra todos los archivos actualmente indexados.
- El botón **Limpiar Base de Datos** elimina todos los chunks del vector store para empezar de cero.

---

## 📦 Dependencias principales

| Paquete | Uso |
|---------|-----|
| `flutter_bloc` | Gestión de estado reactiva |
| `objectbox` + `objectbox_flutter_libs` | Base de datos vectorial local con HNSW |
| `dio` | Cliente HTTP para la API de Ollama |
| `flutter_markdown` | Renderizado de respuestas en Markdown |
| `flutter_highlighter` + `highlight` | Resaltado de sintaxis estilo VS Code (tema VS 2015) |
| `markdown` | Parseo del Markdown y detección del lenguaje en bloques de código |
| `file_picker` | Selector nativo de archivos y carpetas |
| `get_it` | Inyección de dependencias |
| `path` | Manipulación de rutas de archivo |
| `shared_preferences` | Persistencia local del rol del agente |

---

## ⚙️ Configuración avanzada

### Cambiar modelos de Ollama

Edita las constantes en [`lib/data/services/ollama_service.dart`](lib/data/services/ollama_service.dart):

```dart
final String embeddingModel = 'nomic-embed-text'; // Modelo para vectores
final String llmModel = 'qwen2.5-coder:7b';       // Modelo generador
```

### Ajustar el contexto recuperado

Por cada pregunta, el repositorio recupera los **10 chunks** más similares y los concatena en el prompt. Puedes cambiar ese número en [`lib/domain/repositories/rag_repository.dart`](lib/domain/repositories/rag_repository.dart):

```dart
final relevantChunks = await vectorDbService.searchSimilarChunks(
  queryFloat32Embedding,
  10, // Número de fragmentos enviados como contexto
);
```

Un valor más alto aporta más contexto pero alarga el prompt y consume más memoria/tiempo del modelo.

### Ventana de contexto de los embeddings

Las llamadas a `/embed` envían `options.num_ctx: 8192` para que las secciones largas de Markdown no se trunquen antes de generar el vector. Está definido en [`lib/data/services/ollama_service.dart`](lib/data/services/ollama_service.dart).

### Resaltado de sintaxis

Los bloques de código de las respuestas se renderizan con `CodeBlockBuilder` en [`lib/presentation/views/chat_screen.dart`](lib/presentation/views/chat_screen.dart):

- Usa `flutter_highlighter` con el tema `vs2015Theme`.
- Detecta el lenguaje indicado tras las comillas del bloque (por ejemplo, `dart`).
- Si el bloque aún no está cerrado durante el streaming, se añade un cierre temporal para que el Markdown se renderice de forma estable.

### Cambiar el rol del agente

El rol base que guía las respuestas ya no está hardcodeado. Se edita desde el botón **Configurar rol del agente** del panel lateral:

- El valor se guarda localmente con `shared_preferences` (clave `agent_role`).
- Si se deja vacío o solo con espacios, se usa el ejemplo por defecto.
- El cambio se aplica a la próxima pregunta, sin reindexar documentos.

El texto por defecto vive en `defaultAgentRole` en [`lib/data/services/prompt_settings_service.dart`](lib/data/services/prompt_settings_service.dart).

### Métricas de GPU

El servicio [`GpuMetricsService`](lib/data/services/gpu_metrics_service.dart) lee el uso de GPU desde `sysfs` en Linux:

- `/sys/class/drm/card1/device/gpu_busy_percent`
- `/sys/class/drm/card0/device/gpu_busy_percent`

Si tu GPU no expone este archivo, el indicador mostrará `0%` sin causar errores.

---

## 🗂️ Generación de `objectbox.g.dart`

ObjectBox requiere un paso de generación de código para crear los adaptadores que conectan tus entidades Dart con la base de datos nativa.

### ¿Qué hace el generador?

A partir de la anotación `@Entity()` en [`lib/data/models/markdown_chunk.dart`](lib/data/models/markdown_chunk.dart), el generador produce `lib/objectbox.g.dart` con:

- El registro de entidades y propiedades (IDs, tipos, flags)
- El índice vectorial HNSW configurado en el campo `embedding` (`dimensions: 768`)
- Los accessors tipados (`MarkdownChunk_`) usados en las queries de búsqueda semántica
- La clase `Store` y `Box<MarkdownChunk>` listas para usar

### Cómo regenerarlo

```bash
# Primera vez o cuando cambias el modelo de datos
dart run build_runner build --delete-conflicting-outputs

# En modo watch (regenera automáticamente al guardar)
dart run build_runner watch --delete-conflicting-outputs
```

### Qué commitearse y qué no

| Archivo | ¿Committear? | Motivo |
|---------|-------------|--------|
| `lib/objectbox-model.json` | ✅ Sí | ObjectBox gestiona IDs únicos desde este fichero para migraciones |
| `lib/objectbox.g.dart` | ❌ No | Código 100% generado; está en `.gitignore` |

> [!IMPORTANT]
> Si modificas `MarkdownChunk` (añades/eliminas propiedades), **siempre** vuelve a correr `build_runner build`. De lo contrario, el archivo `.g.dart` quedará desincronizado con el modelo y la app no compilará.

> [!WARNING]
> Si hay conflictos de merge en `objectbox-model.json`, **no los resuelvas manualmente** fusionando ambas versiones. Consulta la [guía oficial de ObjectBox](https://docs.objectbox.io/getting-started#generate-objectbox-code) para resolver conflictos de UIDs de forma segura.

---

## 📄 Licencia

Este proyecto es de uso privado. Todos los derechos reservados.
