# 🤖 Clayton Agent

**Local RAG Flutter Desktop** — Un agente de IA conversacional que corre 100% en tu máquina. Indexa tus documentos Markdown y responde preguntas sobre ellos usando un modelo de lenguaje local a través de Ollama, sin enviar ningún dato a la nube.

---

[clayton_agent.webm](https://github.com/user-attachments/assets/6cd03160-fa62-4797-9366-0b5c0072bf68)

[ollama run qwen2.5-coder:7b.webm](https://github.com/user-attachments/assets/839e07d0-da5d-4854-b119-c303a9b1346c)

---

## ✨ Características

- **100% Local & Privado** — Ningún dato sale de tu máquina. Ollama y la base de datos vectorial corren íntegramente en local.
- **RAG (Retrieval-Augmented Generation)** — Las respuestas se generan a partir del contexto exacto de tus documentos, no de información genérica del modelo.
- **Streaming de tokens en tiempo real** — La respuesta del LLM se va mostrando palabra a palabra mientras se genera.
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
    ├── views/      # ChatScreen (UI principal)
    └── widgets/    # AgentRoleDialog, TelemetryBadge
```

### Flujo RAG

```
Documento .md  →  Chunking por encabezados  →  Embedding (nomic-embed-text)  →  ObjectBox (HNSW)
                                                                                        ↓
Pregunta del usuario  →  Embedding  →  Búsqueda de vecinos más cercanos  →  Prompt enriquecido
                                                                                        ↓
                                                                         Ollama (qwen2.5-coder:7b)  →  Respuesta en Markdown
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
3. La respuesta se genera en streaming con formato Markdown.

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
