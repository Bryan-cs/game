# Fase 1: Runtime + Debug — Diseño

**Fecha:** 2026-06-11
**Proyecto:** godot-claude-mcp — extensión hacia paridad con godot-mcp-pro (163 tools)
**Fase:** 1 de N (Runtime + Debug, ~32 tools nuevas)
**Estado:** Aprobado por el usuario

## Contexto

El MCP actual tiene 42 tools que operan solo sobre el **editor** de Godot. No hay forma de:

- Ver errores del editor ni del juego (se trabaja a ciegas).
- Inspeccionar o modificar el juego **mientras corre** (proceso separado).
- Simular input para playtests automáticos.
- Medir rendimiento (FPS, memoria, draw calls).

Objetivo de la fase: eliminar esos cuatro puntos ciegos. Beneficiario directo: desarrollo de Nightfall Survivors (Godot 4.6.3).

Decisiones del usuario:

1. Alcance global: paridad completa con godot-mcp-pro, por fases.
2. Fase 1: grupo Runtime + Debug.
3. Arquitectura runtime: **agente autoload** (opción A), no EditorDebuggerPlugin.

## Arquitectura

```
Claude <-MCP stdio-> Node server <-TCP 9080-> Bridge (plugin editor)
                                                  ↑ TCP 9081 (relay)
                                              Runtime Agent (proceso del juego)
```

### Componentes

| Componente | Archivo | Rol |
|---|---|---|
| Servidor MCP | `server/index.js` + `server/tools/*.js` | Define tools, traduce a comandos JSON |
| Bridge editor | `addons/claude_bridge/bridge_server.gd` + `addons/claude_bridge/commands/*.gd` | Ejecuta comandos de editor; relay de comandos runtime |
| Runtime Agent | `addons/claude_bridge/runtime_agent.gd` | Autoload en el juego; ejecuta comandos runtime e input |

### Runtime Agent

- `plugin.gd` registra el autoload `ClaudeRuntime` en ProjectSettings al activar el plugin y lo elimina al desactivarlo.
- El agente solo actúa en builds de debug lanzadas desde el editor (`OS.has_feature("editor")`); en exports release es un nodo inerte que se autodescarta.
- Al arrancar el juego, conecta como **cliente** TCP a `127.0.0.1:9081`, donde el bridge del editor escucha. Reintentos con backoff (1s, 2s, 4s… máx 10s) mientras el juego viva.
- Protocolo idéntico al existente: JSON por líneas `{id, command, params}` → `{id, ok, result|error}`.

### Relay

- Comandos con prefijo `runtime_` o `input_` que lleguen al bridge por el puerto 9080 se reenvían al agente por el 9081; la respuesta vuelve con el mismo `id` al MCP.
- Si no hay agente conectado, el bridge responde inmediatamente con error: `"El juego no está en ejecución. Lanza la escena con godot_run_scene primero."` — nunca un timeout mudo.
- El bridge mantiene mapa `id → peer MCP` para correlacionar respuestas.

### Modularización

- Comandos nuevos del editor: `addons/claude_bridge/commands/<categoria>.gd` (RefCounted con métodos estáticos o instancia con referencia al plugin). `bridge_server.gd` los carga y delega.
- Tools nuevas del MCP: `server/tools/<categoria>.js`, cada módulo exporta `register(server, run)`. `index.js` los importa.
- Los 42 comandos/tools existentes **no se mueven** en esta fase (migración gradual en fases posteriores).

## Tools

### Grupo Editor/Debug (10 tools — comandos en el bridge, sin agente)

| Tool | Comando | Descripción |
|---|---|---|
| `godot_get_errors` | `get_errors` | Errores y warnings del editor capturados vía `OS.add_logger()` (Logger custom registrado por el plugin). Buffer circular de 500 entradas; parámetros: `severity` (error/warning/all), `clear` (bool), `limit`. |
| `godot_get_game_output` | `get_game_output` | stdout/stderr + errores del juego. El agente captura con su propio `OS.add_logger()` + relay al bridge, que los acumula aunque Claude no esté mirando. Mismos parámetros que `get_errors`. |
| `godot_validate_script` | `validate_script` | Carga el .gd con `GDScript.new()` + `reload()`, devuelve errores de compilación con línea. Sustituye el workaround CLI `--check-only`. |
| `godot_search_scripts` | `search_scripts` | Búsqueda de texto/regex en los .gd del proyecto. Devuelve archivo, línea y contexto. Parámetros: `pattern`, `regex` (bool), `path` (subcarpeta). |
| `godot_reload_scripts` | `reload_scripts` | Fuerza recarga de scripts en el editor (`EditorInterface.get_resource_filesystem().scan()` + reload de scripts abiertos). |
| `godot_move_node` | `move_node` | Reparent y/o reorder. Parámetros: `path`, `new_parent`, `index`, `keep_transform` (bool, default true). |
| `godot_rename_node` | `rename_node` | Renombra nodo. Parámetros: `path`, `name`. |
| `godot_get_selection` | `get_selection` | Nodos seleccionados en el editor (rutas + tipos). |
| `godot_set_selection` | `set_selection` | Selecciona nodos por ruta (para dirigir la atención del usuario). |
| `godot_open_script` | `open_script` | Abre script en el editor de scripts en línea N. Parámetros: `path`, `line`. |

### Grupo Runtime (15 tools — relay al agente)

| Tool | Comando | Descripción |
|---|---|---|
| `runtime_get_scene_tree` | `runtime_get_scene_tree` | Árbol de nodos del juego en vivo (nombre, tipo, ruta, script). |
| `runtime_get_node_info` | `runtime_get_node_info` | Propiedades actuales de un nodo en vivo. |
| `runtime_set_property` | `runtime_set_property` | Cambia propiedad en vivo (tuning sin reiniciar). Mismo parser de literales (`Vector2(…)`, `#ff0000`) que el editor. |
| `runtime_call_method` | `runtime_call_method` | Llama método de un nodo con argumentos. |
| `runtime_eval` | `runtime_eval` | Ejecuta GDScript arbitrario en el juego (equivalente runtime de `godot_execute_code`; recibe `scene_root`). |
| `runtime_screenshot` | `runtime_screenshot` | Captura el viewport del juego, devuelve PNG base64 → imagen MCP. |
| `runtime_find_nodes` | `runtime_find_nodes` | Busca nodos en vivo por clase/grupo/nombre (mismos filtros que `godot_find_nodes`). |
| `runtime_pause` | `runtime_pause` | `get_tree().paused = true`. |
| `runtime_resume` | `runtime_resume` | `paused = false`. |
| `runtime_time_scale` | `runtime_time_scale` | `Engine.time_scale` (cámara lenta / fast-forward para tests). |
| `runtime_wait` | `runtime_wait` | Espera N segundos (tiempo de juego) y devuelve snapshot opcional de nodos indicados. Timeout extendido. |
| `runtime_monitor_signal` | `runtime_monitor_signal` | Conecta a una señal y registra emisiones (timestamp + args) en buffer consultable. Acciones: `start`, `read`, `stop`. |
| `runtime_get_performance` | `runtime_get_performance` | Métricas de `Performance`: FPS, process/physics time, memoria estática, draw calls, objetos, nodos huérfanos. Cubre la categoría Profiling. |
| `runtime_get_groups` | `runtime_get_groups` | Lista grupos activos y conteo de miembros (p. ej. cuántos "enemigos" vivos). |
| `runtime_quit` | `runtime_quit` | Cierra el juego limpiamente desde el agente (complementa `godot_stop_scene`). |

### Grupo Input simulation (7 tools — relay al agente)

| Tool | Comando | Descripción |
|---|---|---|
| `input_action_press` | `input_action_press` | `Input.action_press(action, strength)`. |
| `input_action_release` | `input_action_release` | `Input.action_release(action)`. |
| `input_key` | `input_key` | Pulsación de tecla (press, release o tap) vía `InputEventKey` + `Input.parse_input_event()`. |
| `input_mouse_move` | `input_mouse_move` | Mueve ratón a coordenadas de viewport (`InputEventMouseMotion` + `warp_mouse`). |
| `input_mouse_click` | `input_mouse_click` | Click en coordenadas (botón, press+release). Sirve para UI del juego. |
| `input_text` | `input_text` | Escribe texto (secuencia de `InputEventKey` con unicode). |
| `input_sequence` | `input_sequence` | Lista temporizada de pasos `[{type, params, wait_after}]` que combina los anteriores. Playtest scripteado: "mantén move_up 2s, click en (640,360), espera 1s". Timeout extendido. |

Total fase: **32 tools** (10 editor + 15 runtime + 7 input).

## Manejo de errores

- Timeout por defecto 15s (existente); `runtime_wait` e `input_sequence` declaran timeout dinámico: `duración solicitada + 10s`, tope 120s.
- Caída del agente (crash del juego): el bridge rechaza los pendientes runtime con `"El juego terminó o crasheó. Revisa godot_get_game_output."`.
- Comando runtime con juego no lanzado: error accionable inmediato (ver Relay).
- Errores de GDScript dentro de `runtime_eval` / `runtime_call_method`: capturados y devueltos como texto, nunca crashean el agente.

## Testing

1. **Unidad/protocolo:** extender `server/test-e2e.mjs`: arranca Godot headless no sirve para runtime → test con editor abierto (semiautomático) que: crea escena de prueba con un nodo móvil, la lanza, verifica `runtime_get_scene_tree`, simula `input_action_press`, comprueba que la posición cambió, lee `runtime_get_performance`, cierra.
2. **Smoke real:** sesión de playtest sobre Nightfall Survivors — lanzar juego, simular movimiento + disparo, capturar screenshot, leer errores.
3. Criterio de aceptación: las 32 tools responden sin timeout mudo en los tres estados (juego corriendo, juego cerrado, juego crasheado).

## Fuera de alcance (fases futuras)

- UndoRedo en mutaciones de editor.
- Categorías restantes de godot-mcp-pro: AnimationTree, Audio, Partículas, Theme/UI, Resource avanzado, Batch/Refactor, Análisis, Testing/QA declarativo, Navegación extra, Export extra (~85 tools).
- Recording/replay de sesiones de input (el `input_sequence` de esta fase es el bloque base).
- Migración de los 42 comandos existentes a módulos.
