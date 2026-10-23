# Diseño: Rol del Agente Personalizable y Persistente

**Fecha:** 2026-10-22
**Estado:** Pendiente de aprobación

---

## 1. Contexto e Intención

Hoy el papel del agente está hardcodeado en `RagRepositoryImpl` (`lib/domain/repositories/rag_repository.dart:28`):

> "Responde la siguiente pregunta técnica sobre Dart/Flutter basándote en la documentación y los plugins provistos en el contexto..."

Ese texto se antepone al contexto y a la pregunta en `_buildPromptForQuestion`, por lo que la app queda atada a Flutter. Se quiere poder editarlo desde la UI, configurarlo una sola vez y que persista entre reinicios. En el primer arranque debe seguir funcionando exactamente igual que hoy, usando el texto actual como ejemplo por defecto.

---

## 2. Metas, No-Metas y Anti-Metas

### Metas
- Editar el rol del agente desde la UI mediante un diálogo con editor multilínea.
- Persistir el rol con `shared_preferences` (clave única).
- Al iniciar: cargar el rol guardado o, si no existe, el ejemplo actual.
- Aplicar el nuevo rol a la próxima consulta, sin reindexar documentos.
- Mostrar el rol vigente al abrir el editor y permitir restaurar el ejemplo.

### No-Metas
- Múltiples perfiles o roles guardados.
- Editar otras partes del prompt (bloques de contexto, pregunta o instrucción de Markdown).
- Sincronización entre equipos o historial de cambios del rol.
- Cambiar modelo, endpoint o configuración de Ollama.

### Anti-Metas
- No romper la arquitectura existente (`Service` → `Repository` → `Bloc` → `View`).
- No agregar dependencias pesadas ni un motor de configuración para un solo string.
- No exigir reinicio ni reindexación para que el cambio tenga efecto.

---

## 3. Restricciones Técnicas

- Flutter Linux Desktop (GTK3), Dart 3.13.
- Única dependencia nueva: `shared_preferences`.
- El rol es un string multilínea libre; la app no valida su contenido.

---

## 4. Enfoques Considerados

- **A. `shared_preferences` + diálogo de configuración** — elegido. Almacenamiento clave-valor nativo, API mínima y fácil de testear con `setMockInitialValues`.
- **B. Archivo JSON con `path_provider`** — descartado: agrega otra dependencia y obliga a manejar escrituras atómicas y errores a mano.
- **C. Reusar ObjectBox** — descartado: requiere una entidad nueva y regenerar código con `build_runner` solo para un string.

---

## 5. Diseño

### 5.1 Servicio de configuración (nuevo)
`lib/data/services/prompt_settings_service.dart`

```dart
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
```

`PromptSettingsServiceImpl` usa `SharedPreferences` con la clave `agent_role`. `loadAgentRole()` devuelve el valor guardado o `defaultAgentRole` si está vacío.

### 5.2 Repositorio
`RagRepositoryImpl` recibe el rol inicial ya cargado y el servicio de persistencia:
- `initialAgentRole`: rol vigente al construir el repositorio.
- `updateAgentRole(String role)`: persiste vía servicio y actualiza el rol en memoria.
- `_buildPromptForQuestion` usa el rol actual en lugar del campo `prompt` fijo.

`RagRepository` expone `Future<void> updateAgentRole(String role)` y `String get agentRole`.

### 5.3 Inyección
`initDependencies()` registra `PromptSettingsService`, hace `await loadAgentRole()` y construye `RagRepositoryImpl` con ese valor.

### 5.4 BLoC
- Eventos: `LoadAgentRoleEvent`, `UpdateAgentRoleEvent(String role)`.
- Estados: `AgentRoleLoadedState(String role)`, `AgentRoleUpdatedState(String role)`.
- Handlers: cargan el rol actual / persisten el nuevo y emiten el estado correspondiente; errores → `RagErrorState`.

### 5.5 UI
- Botón **“Configurar rol del agente”** en el sidebar izquierdo.
- Abre `AgentRoleDialog` (widget nuevo) con:
  - `TextField` multilínea precargado con el rol vigente.
  - **Restaurar ejemplo** (copia `defaultAgentRole` al campo, sin guardar).
  - **Cancelar** y **Guardar**.
- Al guardar se despacha `UpdateAgentRoleEvent`; el éxito se confirma con un `SnackBar`.
- El diálogo se carga con el rol actual vía `LoadAgentRoleEvent` al abrirse.

### 5.6 Flujo
1. Arranque: se lee el rol guardado; si no hay, se usa `defaultAgentRole`.
2. El usuario abre el diálogo y edita.
3. Guardar → se persiste → siguiente pregunta usa el nuevo rol.
4. Restaurar ejemplo → se rellena el campo; recién se aplica al guardar.

---

## 6. Pruebas

- `PromptSettingsService`: devuelve el default sin valores guardados; guarda y relee.
- `RagRepositoryImpl`: tras `updateAgentRole`, el prompt enviado a Ollama contiene el nuevo rol (capturado con un fake de `OllamaService`).
- `RagBloc`: `UpdateAgentRoleEvent` persiste y emite `AgentRoleUpdatedState`; `LoadAgentRoleEvent` emite `AgentRoleLoadedState`.
- Widget (opcional): el diálogo muestra el rol actual y el botón Guardar dispara el evento.
- La suite existente (12 tests) debe seguir pasando.

---

## 7. Delegado al Implementador

- Estilo visual exacto del diálogo y textos de los botones.
- Nombre final de la clave de `SharedPreferences`.
- Manejo y mensaje de error si falla el guardado.
- Si conviene mostrar además una vista previa del prompt completo.
