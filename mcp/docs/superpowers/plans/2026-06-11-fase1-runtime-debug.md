# Fase 1: Runtime + Debug — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir 32 tools MCP (10 editor/debug, 15 runtime, 7 input) que permiten ver errores, inspeccionar y manipular el juego en ejecución y simular input.

**Architecture:** Un autoload `ClaudeRuntime` (agente) corre dentro del juego y conecta por TCP a `127.0.0.1:9081`, donde el plugin del editor escucha (`agent_link.gd`). El bridge existente (puerto 9080) hace relay de comandos `runtime_*`/`input_*` al agente con respuestas asíncronas correlacionadas por id. Errores de editor y juego se capturan con `OS.add_logger()` (Godot 4.5+) en buffers circulares consultables.

**Tech Stack:** GDScript (Godot 4.6), Node.js (MCP SDK + zod), TCP JSON-por-líneas.

**Spec:** `docs/superpowers/specs/2026-06-11-fase1-runtime-debug-design.md`

---

## Mapa de archivos

| Archivo | Acción | Responsabilidad |
|---|---|---|
| `addons/claude_bridge/capture_logger.gd` | Crear | Logger subclass: buffer circular de errores/mensajes (compartido editor y juego) |
| `addons/claude_bridge/agent_link.gd` | Crear | TCPServer 9081: conexión con el agente, relay, buffer de log del juego |
| `addons/claude_bridge/runtime_agent.gd` | Crear | Autoload en el juego: ejecuta comandos runtime/input |
| `addons/claude_bridge/commands/editor_debug.gd` | Crear | 10 comandos de editor/debug |
| `addons/claude_bridge/bridge_server.gd` | Modificar | Relay de `runtime_*`/`input_*`, soporte de módulos |
| `addons/claude_bridge/plugin.gd` | Modificar | Registrar autoload, logger de editor, agent_link |
| `server/tools/debug.js` | Crear | Tools MCP grupo editor/debug |
| `server/tools/runtime.js` | Crear | Tools MCP grupo runtime |
| `server/tools/input.js` | Crear | Tools MCP grupo input |
| `server/index.js` | Modificar | Exportar contexto, importar módulos de tools |
| `server/test-e2e.mjs` | Modificar | Verificar registro de 74 tools y llamada a tool nueva |
| `sync-addon.ps1` | Crear | Copia el addon al proyecto Nightfall |
| `.gitignore` | Crear | Excluir node_modules |

**Nota sobre testing:** los comandos GDScript dependen del editor de Godot vivo — no hay framework de unit-test en el proyecto. El plan usa: (a) test e2e de protocolo con fake-Godot (`test-e2e.mjs`), (b) verificación manual por TCP crudo contra el editor real con comandos exactos, (c) smoke final sobre Nightfall Survivors. Cada tarea termina en verificación + commit.

**Comando de verificación TCP crudo** (usado en varias tareas; requiere editor abierto con plugin activo):

```powershell
node -e "const n=require('net');const s=n.createConnection(9080,'127.0.0.1',()=>{s.write(JSON.stringify({id:1,command:'COMANDO',params:{}})+'\n')});let b='';s.on('data',d=>{b+=d;if(b.includes('\n')){console.log(b);process.exit(0)}});setTimeout(()=>{console.log('TIMEOUT');process.exit(1)},8000)"
```

---

### Task 1: .gitignore + CaptureLogger compartido

**Files:**
- Create: `.gitignore`
- Create: `addons/claude_bridge/capture_logger.gd`

- [ ] **Step 1: Crear .gitignore**

```gitignore
server/node_modules/
*.log
```

- [ ] **Step 2: Crear capture_logger.gd**

```gdscript
extends Logger
## Logger que captura errores, warnings y mensajes en un buffer circular
## consultable. Se usa tanto en el editor (errores del editor) como dentro
## del juego (salida del juego). Thread-safe: Godot puede loguear desde
## cualquier hilo.

const MAX_ENTRIES := 500

var _entries: Array = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind := "error"
	match error_type:
		ERROR_TYPE_WARNING:
			kind = "warning"
		ERROR_TYPE_SCRIPT:
			kind = "script_error"
		ERROR_TYPE_SHADER:
			kind = "shader_error"
	_append({
		"kind": kind,
		"message": rationale if rationale != "" else code,
		"file": file,
		"line": line,
		"function": function,
	})


func _log_message(message: String, error: bool) -> void:
	_append({"kind": "stderr" if error else "stdout", "message": message.strip_edges()})


func _append(entry: Dictionary) -> void:
	entry["time_msec"] = Time.get_ticks_msec()
	_mutex.lock()
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_ENTRIES)
	_mutex.unlock()


func entry_count() -> int:
	_mutex.lock()
	var n := _entries.size()
	_mutex.unlock()
	return n


## Devuelve entradas filtradas. severity: all | error | warning.
## from_index permite leer solo lo nuevo desde una marca anterior.
func snapshot(severity := "all", limit := 100, clear := false, from_index := 0) -> Array:
	_mutex.lock()
	var out: Array = []
	for i in range(from_index, _entries.size()):
		var e: Dictionary = _entries[i]
		var k: String = e["kind"]
		if severity == "all" \
				or (severity == "error" and k in ["error", "script_error", "shader_error", "stderr"]) \
				or (severity == "warning" and k == "warning"):
			out.append(e)
	if clear:
		_entries.clear()
	_mutex.unlock()
	if out.size() > limit:
		out = out.slice(out.size() - limit)
	return out
```

- [ ] **Step 3: Validar sintaxis con Godot headless**

```powershell
& "C:\Users\braya\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --check-only --script addons/claude_bridge/capture_logger.gd --path .
```

Esperado: sin errores (exit 0). Nota: `--path .` falla si la carpeta no tiene project.godot; en ese caso validar contra el proyecto Nightfall tras el sync de Task 10, o crear un project.godot mínimo en este repo (preferido):

```ini
; project.godot mínimo para validar scripts del addon
config_version=5
[application]
config/name="godot-claude-mcp-dev"
```

- [ ] **Step 4: Commit**

```powershell
git add .gitignore addons/claude_bridge/capture_logger.gd project.godot
git commit -m "feat: CaptureLogger con buffer circular para errores de editor y juego"
```

---

### Task 2: AgentLink — servidor TCP 9081 + relay

**Files:**
- Create: `addons/claude_bridge/agent_link.gd`

- [ ] **Step 1: Crear agent_link.gd**

```gdscript
@tool
extends RefCounted
## Escucha en 127.0.0.1:9081 la conexión del Runtime Agent (autoload dentro
## del juego) y hace de relay: comandos runtime_*/input_* van al agente y la
## respuesta vuelve al cliente MCP correlacionada por id. También acumula la
## salida del juego (push de logs) para poder consultarla incluso tras un crash.

signal log_message(text: String, kind: String)

const MAX_GAME_LOG := 500

var _tcp := TCPServer.new()
var _agent: StreamPeerTCP = null
var _buffer := ""
var _next_id := 1
var _pending: Dictionary = {}  # id -> Callable(ok: bool, payload)
var _game_log: Array = []


func start(port := 9081) -> void:
	var err := _tcp.listen(port, "127.0.0.1")
	if err != OK:
		log_message.emit("AgentLink: no se pudo abrir el puerto %d (error %d)" % [port, err], "error")
	else:
		log_message.emit("AgentLink escuchando en 127.0.0.1:%d" % port, "info")


func stop() -> void:
	if _agent:
		_agent.disconnect_from_host()
		_agent = null
	if _tcp.is_listening():
		_tcp.stop()
	_fail_pending("El editor cerró la conexión con el juego")


func is_agent_connected() -> bool:
	return _agent != null and _agent.get_status() == StreamPeerTCP.STATUS_CONNECTED


func relay(command: String, params: Dictionary, respond: Callable) -> void:
	if not is_agent_connected():
		respond.call(false, "El juego no está en ejecución. Lánzalo con godot_run_scene primero.")
		return
	var id := _next_id
	_next_id += 1
	_pending[id] = respond
	_agent.put_data((JSON.stringify({"id": id, "command": command, "params": params}) + "\n").to_utf8_buffer())


func game_log_snapshot(severity := "all", limit := 100, clear := false) -> Array:
	var out: Array = []
	for e in _game_log:
		var k: String = e.get("kind", "")
		if severity == "all" \
				or (severity == "error" and k in ["error", "script_error", "shader_error", "stderr"]) \
				or (severity == "warning" and k == "warning"):
			out.append(e)
	if clear:
		_game_log.clear()
	if out.size() > limit:
		out = out.slice(out.size() - limit)
	return out


func poll() -> void:
	while _tcp.is_connection_available():
		if _agent != null:
			_agent.disconnect_from_host()
			_fail_pending("Se inició una nueva ejecución del juego")
		_agent = _tcp.take_connection()
		_buffer = ""
		_game_log.append({"kind": "marker", "message": "--- nueva ejecución del juego ---", "time_msec": Time.get_ticks_msec()})
		log_message.emit("Runtime Agent conectado (juego en ejecución)", "ok")

	if _agent == null:
		return
	_agent.poll()
	if _agent.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if _agent.get_status() in [StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR]:
			log_message.emit("Runtime Agent desconectado (el juego terminó)", "info")
			_agent = null
			_fail_pending("El juego terminó o crasheó. Revisa godot_get_game_output.")
		return

	var available := _agent.get_available_bytes()
	if available > 0:
		_buffer += _agent.get_utf8_string(available)
		var idx := _buffer.find("\n")
		while idx >= 0:
			var line := _buffer.substr(0, idx)
			_buffer = _buffer.substr(idx + 1)
			if line.strip_edges() != "":
				_handle_agent_message(line)
			idx = _buffer.find("\n")


func _handle_agent_message(line: String) -> void:
	var msg = JSON.parse_string(line)
	if msg == null or not (msg is Dictionary):
		return
	if msg.has("push"):
		if str(msg["push"]) == "log":
			_game_log.append(msg.get("entry", {}))
			if _game_log.size() > MAX_GAME_LOG:
				_game_log = _game_log.slice(_game_log.size() - MAX_GAME_LOG)
		return
	var id := int(msg.get("id", -1))
	if _pending.has(id):
		var respond: Callable = _pending[id]
		_pending.erase(id)
		if bool(msg.get("ok", false)):
			respond.call(true, msg.get("result"))
		else:
			respond.call(false, str(msg.get("error", "Error desconocido en el juego")))


func _fail_pending(reason: String) -> void:
	for id in _pending:
		var respond: Callable = _pending[id]
		respond.call(false, reason)
	_pending.clear()
```

- [ ] **Step 2: Validar sintaxis** (mismo comando headless de Task 1 con `agent_link.gd`). Esperado: exit 0.

- [ ] **Step 3: Commit**

```powershell
git add addons/claude_bridge/agent_link.gd
git commit -m "feat: AgentLink - relay TCP 9081 entre editor y juego con buffer de logs"
```

---

### Task 3: Bridge — relay asíncrono + soporte de módulos

**Files:**
- Modify: `addons/claude_bridge/bridge_server.gd` (líneas 10-16, 98-121, 221-222)

- [ ] **Step 1: Añadir variables** — tras `var commands_handled := 0` (línea 16):

```gdscript
## Asignados por plugin.gd al activarse.
var agent_link = null
var modules: Array = []
```

- [ ] **Step 2: Insertar relay en `_handle_line`** — entre `commands_handled += 1` y `var response: Dictionary`:

```gdscript
	# Comandos runtime/input van al juego vía relay; la respuesta llega después.
	if command.begins_with("runtime_") or command.begins_with("input_"):
		_relay_to_game(client, id, command, params)
		return
```

- [ ] **Step 3: Añadir `_relay_to_game`** — tras `_handle_line`:

```gdscript
func _relay_to_game(client: StreamPeerTCP, id, command: String, params: Dictionary) -> void:
	if agent_link == null or not agent_link.is_agent_connected():
		var msg := "El juego no está en ejecución. Lánzalo con godot_run_scene primero."
		log_message.emit("✗ %s: %s" % [command, msg], "error")
		_send(client, {"id": id, "ok": false, "error": msg})
		return
	agent_link.relay(command, params, func(ok: bool, payload):
		if not _clients.has(client) or client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		if ok:
			log_message.emit("✓ %s completado" % command, "ok")
			_send(client, {"id": id, "ok": true, "result": payload})
		else:
			log_message.emit("✗ %s: %s" % [command, str(payload)], "error")
			_send(client, {"id": id, "ok": false, "error": str(payload)})
	)
```

- [ ] **Step 4: Fallthrough a módulos en `_dispatch`** — reemplazar la rama final:

```gdscript
		_:
			for m in modules:
				if m.handles(command):
					return m.dispatch(command, p)
			return _err("Comando desconocido: %s" % command)
```

- [ ] **Step 5: Verificar contra editor real** — con Godot abierto (plugin recarga al guardar; si no, desactivar/activar plugin). Comando TCP crudo con `"command":"runtime_get_scene_tree"`.
Esperado: `{"id":1,"ok":false,"error":"El juego no está en ejecución. Lánzalo con godot_run_scene primero."}` — error inmediato, no timeout.

- [ ] **Step 6: Commit**

```powershell
git add addons/claude_bridge/bridge_server.gd
git commit -m "feat: relay asincrono runtime_*/input_* y dispatch modular en bridge"
```

---

### Task 4: Runtime Agent (autoload del juego)

**Files:**
- Create: `addons/claude_bridge/runtime_agent.gd` (base: conexión + ping + push de logs; comandos en Tasks 6-7)

- [ ] **Step 1: Crear runtime_agent.gd**

```gdscript
extends Node
## Autoload "ClaudeRuntime". Corre dentro del juego lanzado desde el editor:
## conecta a AgentLink (127.0.0.1:9081), ejecuta comandos runtime_*/input_*
## y empuja la salida del juego (print + errores) al editor.
## En exports sin feature "editor" queda inerte.

const CaptureLogger = preload("res://addons/claude_bridge/capture_logger.gd")
const PORT := 9081

var _peer: StreamPeerTCP = null
var _buffer := ""
var _retry_delay := 1.0
var _retry_left := 0.0
var _logger = null
var _log_cursor := 0
var _monitors: Dictionary = {}  # id -> {node, signal, recorder, emissions: Array}
var _monitor_seq := 0


func _ready() -> void:
	if not OS.has_feature("editor"):
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # seguir vivo aunque el juego se pause
	_logger = CaptureLogger.new()
	OS.add_logger(_logger)
	_try_connect()


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)


func _try_connect() -> void:
	_peer = StreamPeerTCP.new()
	_buffer = ""
	if _peer.connect_to_host("127.0.0.1", PORT) != OK:
		_schedule_retry()


func _schedule_retry() -> void:
	_peer = null
	_retry_left = _retry_delay
	_retry_delay = minf(_retry_delay * 2.0, 10.0)


func _process(delta: float) -> void:
	if _peer == null:
		_retry_left -= delta
		if _retry_left <= 0.0:
			_try_connect()
		return

	_peer.poll()
	match _peer.get_status():
		StreamPeerTCP.STATUS_CONNECTING:
			pass
		StreamPeerTCP.STATUS_CONNECTED:
			_retry_delay = 1.0
			_flush_logs()
			_read_incoming()
		_:
			_schedule_retry()


func _flush_logs() -> void:
	var total: int = _logger.entry_count()
	if total <= _log_cursor:
		if total < _log_cursor:
			_log_cursor = 0  # el buffer circular se recortó
		return
	var entries: Array = _logger.snapshot("all", 100, false, _log_cursor)
	_log_cursor = total
	for e in entries:
		_send({"push": "log", "entry": e})


func _read_incoming() -> void:
	var available := _peer.get_available_bytes()
	if available <= 0:
		return
	_buffer += _peer.get_utf8_string(available)
	var idx := _buffer.find("\n")
	while idx >= 0:
		var line := _buffer.substr(0, idx)
		_buffer = _buffer.substr(idx + 1)
		if line.strip_edges() != "":
			_handle_line(line)
		idx = _buffer.find("\n")


func _handle_line(line: String) -> void:
	var msg = JSON.parse_string(line)
	if msg == null or not (msg is Dictionary):
		return
	var id = msg.get("id", -1)
	var command := str(msg.get("command", ""))
	var params: Dictionary = msg.get("params", {}) if msg.get("params") is Dictionary else {}
	# Asíncrono: comandos como runtime_wait usan await; cada mensaje responde
	# cuando termina, sin bloquear los demás.
	_run_command(id, command, params)


func _run_command(id, command: String, params: Dictionary) -> void:
	var result = await _dispatch(command, params)
	if result is Dictionary and result.has("__error"):
		_send({"id": id, "ok": false, "error": result["__error"]})
	else:
		_send({"id": id, "ok": true, "result": result})


func _send(data: Dictionary) -> void:
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_peer.put_data((JSON.stringify(data) + "\n").to_utf8_buffer())


func _err(message: String) -> Dictionary:
	return {"__error": message}


func _scene_root() -> Node:
	return get_tree().current_scene


func _resolve(path: String) -> Node:
	var root := _scene_root()
	if root == null:
		return null
	if path == "." or path == "" or path == root.name:
		return root
	return root.get_node_or_null(NodePath(path))


func _dispatch(command: String, p: Dictionary):
	match command:
		"runtime_ping":
			return {"pong": true, "scene": _scene_root().scene_file_path if _scene_root() else ""}
		_:
			return _err("Comando runtime desconocido: %s" % command)
```

- [ ] **Step 2: Validar sintaxis** (headless `--check-only`). Esperado: exit 0.

- [ ] **Step 3: Commit**

```powershell
git add addons/claude_bridge/runtime_agent.gd
git commit -m "feat: Runtime Agent base - conexion al editor, push de logs, dispatch asincrono"
```

---

### Task 5: plugin.gd — autoload + logger de editor + wiring

**Files:**
- Modify: `addons/claude_bridge/plugin.gd` (archivo completo, 35 líneas → reemplazar)

- [ ] **Step 1: Reemplazar plugin.gd**

```gdscript
@tool
extends EditorPlugin

const BridgeServer = preload("res://addons/claude_bridge/bridge_server.gd")
const BridgeDock = preload("res://addons/claude_bridge/dock.gd")
const AgentLink = preload("res://addons/claude_bridge/agent_link.gd")
const CaptureLogger = preload("res://addons/claude_bridge/capture_logger.gd")
const EditorDebug = preload("res://addons/claude_bridge/commands/editor_debug.gd")

var server: BridgeServer
var dock: Control
var agent_link
var editor_logger


func _enter_tree() -> void:
	editor_logger = CaptureLogger.new()
	OS.add_logger(editor_logger)

	agent_link = AgentLink.new()
	agent_link.start(9081)

	server = BridgeServer.new()
	server.agent_link = agent_link
	server.modules.append(EditorDebug.new(editor_logger, agent_link))
	agent_link.log_message.connect(func(text, kind): server.log_message.emit(text, kind))

	dock = BridgeDock.new()
	dock.name = "Claude Bridge"
	dock.setup(server)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)

	# Arranca automáticamente al activar el plugin
	server.start(dock.get_saved_port())


func _exit_tree() -> void:
	if editor_logger:
		OS.remove_logger(editor_logger)
		editor_logger = null
	if agent_link:
		agent_link.stop()
		agent_link = null
	if server:
		server.stop()
		server = null
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


func _enable_plugin() -> void:
	add_autoload_singleton("ClaudeRuntime", "res://addons/claude_bridge/runtime_agent.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("ClaudeRuntime")


func _process(_delta: float) -> void:
	if server:
		server.poll()
	if agent_link:
		agent_link.poll()
```

**Nota:** `_enable_plugin()` solo se dispara al ACTIVAR el plugin. En el proyecto Nightfall el plugin ya está activo → tras el sync (Task 10) hay que desactivar y reactivar el plugin (Proyecto → Ajustes → Plugins) para que registre el autoload.

- [ ] **Step 2: Este archivo referencia `commands/editor_debug.gd` que aún no existe** — crear stub mínimo para no romper la carga:

```gdscript
@tool
extends RefCounted
## Comandos de editor/debug (Fase 1). Implementación completa en Task 6.

var logger
var agent_link


func _init(p_logger, p_agent_link) -> void:
	logger = p_logger
	agent_link = p_agent_link


func handles(_command: String) -> bool:
	return false


func dispatch(_command: String, _p: Dictionary):
	return {"__error": "no implementado"}
```

Guardar en `addons/claude_bridge/commands/editor_debug.gd`.

- [ ] **Step 3: Validar sintaxis de ambos** (headless `--check-only` sobre `plugin.gd` y `commands/editor_debug.gd`). Esperado: exit 0.

- [ ] **Step 4: Commit**

```powershell
git add addons/claude_bridge/plugin.gd addons/claude_bridge/commands/editor_debug.gd
git commit -m "feat: plugin registra autoload ClaudeRuntime, logger de editor y AgentLink"
```

---

### Task 6: Comandos editor/debug (10)

**Files:**
- Modify: `addons/claude_bridge/commands/editor_debug.gd` (reemplazar stub)

- [ ] **Step 1: Implementación completa**

```gdscript
@tool
extends RefCounted
## Comandos de editor/debug de la Fase 1: errores, validación, búsqueda,
## operaciones de nodo (mover/renombrar), selección y apertura de scripts.

const HANDLED := [
	"get_errors", "get_game_output", "validate_script", "search_scripts",
	"reload_scripts", "move_node", "rename_node", "get_selection",
	"set_selection", "open_script",
]

var logger  # CaptureLogger del proceso del editor
var agent_link  # buffer de logs del juego


func _init(p_logger, p_agent_link) -> void:
	logger = p_logger
	agent_link = p_agent_link


func handles(command: String) -> bool:
	return command in HANDLED


func dispatch(command: String, p: Dictionary):
	match command:
		"get_errors":
			return _cmd_get_errors(p)
		"get_game_output":
			return _cmd_get_game_output(p)
		"validate_script":
			return _cmd_validate_script(p)
		"search_scripts":
			return _cmd_search_scripts(p)
		"reload_scripts":
			return _cmd_reload_scripts()
		"move_node":
			return _cmd_move_node(p)
		"rename_node":
			return _cmd_rename_node(p)
		"get_selection":
			return _cmd_get_selection()
		"set_selection":
			return _cmd_set_selection(p)
		"open_script":
			return _cmd_open_script(p)
	return _err("Comando desconocido: %s" % command)


func _err(message: String) -> Dictionary:
	return {"__error": message}


func _get_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _resolve_node(path: String) -> Node:
	var root := _get_root()
	if root == null:
		return null
	if path == "." or path == "" or path == root.name:
		return root
	return root.get_node_or_null(NodePath(path))


func _cmd_get_errors(p: Dictionary):
	var severity := str(p.get("severity", "all"))
	var limit := int(p.get("limit", 100))
	var clear := bool(p.get("clear", false))
	var entries: Array = logger.snapshot(severity, limit, clear)
	return {"count": entries.size(), "entries": entries}


func _cmd_get_game_output(p: Dictionary):
	var severity := str(p.get("severity", "all"))
	var limit := int(p.get("limit", 100))
	var clear := bool(p.get("clear", false))
	var entries: Array = agent_link.game_log_snapshot(severity, limit, clear)
	return {
		"game_running": agent_link.is_agent_connected(),
		"count": entries.size(),
		"entries": entries,
	}


func _cmd_validate_script(p: Dictionary):
	var path := str(p.get("path", ""))
	if not FileAccess.file_exists(path):
		return _err("El script no existe: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("No se pudo abrir: %s" % path)
	var source := f.get_as_text()
	# Los errores de compilación se imprimen al log del editor: marcamos la
	# posición del buffer antes de compilar y devolvemos solo lo nuevo.
	var mark: int = logger.entry_count()
	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	var new_entries: Array = logger.snapshot("error", 50, false, mark)
	return {"path": path, "valid": err == OK, "errors": new_entries}


func _cmd_search_scripts(p: Dictionary):
	var pattern := str(p.get("pattern", ""))
	if pattern == "":
		return _err("Falta el parámetro 'pattern'")
	var use_regex := bool(p.get("regex", false))
	var base := str(p.get("path", "res://"))
	var include_addons := bool(p.get("include_addons", false))
	var regex: RegEx = null
	if use_regex:
		regex = RegEx.new()
		if regex.compile(pattern) != OK:
			return _err("Regex inválida: %s" % pattern)
	var files: Array = []
	_walk_gd(base, include_addons, files)
	var matches: Array = []
	for file_path in files:
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var line_num := 0
		while not f.eof_reached():
			line_num += 1
			var line := f.get_line()
			var hit := false
			if use_regex:
				hit = regex.search(line) != null
			else:
				hit = line.findn(pattern) >= 0
			if hit:
				matches.append({"file": file_path, "line": line_num, "text": line.strip_edges()})
				if matches.size() >= 200:
					return {"matches": matches, "truncated": true}
	return {"matches": matches, "truncated": false}


func _walk_gd(path: String, include_addons: bool, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if include_addons or entry != "addons":
				_walk_gd(full, include_addons, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _cmd_reload_scripts():
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.get_resource_filesystem().scan_sources()
	return {"rescanned": true}


func _cmd_move_node(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	if node == _get_root():
		return _err("No se puede mover el nodo raíz")
	var keep_transform := bool(p.get("keep_transform", true))
	var new_parent_path := str(p.get("new_parent", ""))
	if new_parent_path != "":
		var new_parent := _resolve_node(new_parent_path)
		if new_parent == null:
			return _err("No se encontró el nuevo padre: %s" % new_parent_path)
		if new_parent == node or new_parent.is_ancestor_of(node) and false:
			pass
		node.reparent(new_parent, keep_transform)
		_set_owner_recursive(node, _get_root())
	if p.has("index"):
		node.get_parent().move_child(node, int(p.get("index")))
	return {
		"moved": str(_get_root().get_path_to(node)),
		"parent": str(_get_root().get_path_to(node.get_parent())) if node.get_parent() != _get_root() else ".",
		"index": node.get_index(),
	}


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)


func _cmd_rename_node(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	var new_name := str(p.get("name", ""))
	if new_name == "":
		return _err("Falta el parámetro 'name'")
	var old_name := str(node.name)
	node.name = new_name
	return {"old_name": old_name, "new_path": str(_get_root().get_path_to(node))}


func _cmd_get_selection():
	var root := _get_root()
	var nodes: Array = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		nodes.append({
			"path": str(root.get_path_to(node)) if root and node != root else ".",
			"type": node.get_class(),
			"name": str(node.name),
		})
	return {"selected": nodes}


func _cmd_set_selection(p: Dictionary):
	var paths: Array = p.get("paths", []) if p.get("paths") is Array else []
	var selection := EditorInterface.get_selection()
	selection.clear()
	var selected: Array = []
	for path in paths:
		var node := _resolve_node(str(path))
		if node != null:
			selection.add_node(node)
			selected.append(str(path))
	return {"selected": selected}


func _cmd_open_script(p: Dictionary):
	var path := str(p.get("path", ""))
	if not FileAccess.file_exists(path):
		return _err("El script no existe: %s" % path)
	var script = load(path)
	if script == null or not (script is Script):
		return _err("No es un script válido: %s" % path)
	var line := int(p.get("line", 1))
	EditorInterface.edit_script(script, line)
	EditorInterface.set_main_screen_editor("Script")
	return {"opened": path, "line": line}
```

**Corrección obligada en `_cmd_move_node`:** la línea `if new_parent == node or new_parent.is_ancestor_of(node) and false:` es un guard mal escrito — sustituir por:

```gdscript
		if new_parent == node or node.is_ancestor_of(new_parent):
			return _err("No se puede mover un nodo dentro de sí mismo")
```

- [ ] **Step 2: Validar sintaxis** (headless `--check-only`). Esperado: exit 0.

- [ ] **Step 3: Verificar contra editor real** — recargar plugin (desactivar/activar) y probar por TCP crudo:
  - `{"command":"get_errors","params":{}}` → `ok:true`, lista (posiblemente vacía).
  - `{"command":"get_game_output","params":{}}` → `ok:true`, `game_running:false`.
  - `{"command":"search_scripts","params":{"pattern":"func _ready"}}` → matches > 0 en proyecto con scripts.

- [ ] **Step 4: Commit**

```powershell
git add addons/claude_bridge/commands/editor_debug.gd
git commit -m "feat: 10 comandos editor/debug (errores, validacion, busqueda, nodos, seleccion)"
```

---

### Task 7: Comandos runtime del agente (15)

**Files:**
- Modify: `addons/claude_bridge/runtime_agent.gd` (ampliar `_dispatch` y añadir implementaciones)

- [ ] **Step 1: Reemplazar `_dispatch` del agente**

```gdscript
func _dispatch(command: String, p: Dictionary):
	match command:
		"runtime_ping":
			return {"pong": true, "scene": _scene_root().scene_file_path if _scene_root() else ""}
		"runtime_get_scene_tree":
			return _cmd_get_scene_tree()
		"runtime_get_node_info":
			return _cmd_get_node_info(p)
		"runtime_set_property":
			return _cmd_set_property(p)
		"runtime_call_method":
			return _cmd_call_method(p)
		"runtime_eval":
			return _cmd_eval(p)
		"runtime_screenshot":
			return await _cmd_screenshot()
		"runtime_find_nodes":
			return _cmd_find_nodes(p)
		"runtime_pause":
			get_tree().paused = true
			return {"paused": true}
		"runtime_resume":
			get_tree().paused = false
			return {"paused": false}
		"runtime_time_scale":
			Engine.time_scale = clampf(float(p.get("scale", 1.0)), 0.01, 20.0)
			return {"time_scale": Engine.time_scale}
		"runtime_wait":
			return await _cmd_wait(p)
		"runtime_monitor_signal":
			return _cmd_monitor_signal(p)
		"runtime_get_performance":
			return _cmd_get_performance()
		"runtime_get_groups":
			return _cmd_get_groups(p)
		"runtime_quit":
			get_tree().quit.call_deferred()
			return {"quitting": true}
		_:
			if command.begins_with("input_"):
				return await _dispatch_input(command, p)
			return _err("Comando runtime desconocido: %s" % command)
```

- [ ] **Step 2: Añadir implementaciones runtime**

```gdscript
func _serialize_node(node: Node, root: Node) -> Dictionary:
	var children := []
	for child in node.get_children():
		children.append(_serialize_node(child, root))
	var info := {
		"name": str(node.name),
		"type": node.get_class(),
		"path": str(root.get_path_to(node)) if node != root else ".",
	}
	var script = node.get_script()
	if script != null:
		info["script"] = script.resource_path
	if not children.is_empty():
		info["children"] = children
	return info


func _cmd_get_scene_tree():
	var root := _scene_root()
	if root == null:
		return _err("No hay escena actual en el juego")
	return {"scene_path": root.scene_file_path, "tree": _serialize_node(root, root)}


func _cmd_get_node_info(p: Dictionary):
	var node := _resolve(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo en el juego: %s" % str(p.get("path", "")))
	var props := {}
	for prop_info in node.get_property_list():
		if prop_info["usage"] & PROPERTY_USAGE_EDITOR:
			var pname: String = prop_info["name"]
			props[pname] = str(node.get(pname))
	return {"name": str(node.name), "type": node.get_class(), "properties": props}


func _cmd_set_property(p: Dictionary):
	var node := _resolve(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo en el juego: %s" % str(p.get("path", "")))
	var prop := str(p.get("property", ""))
	if prop == "":
		return _err("Falta el parámetro 'property'")
	var value = p.get("value")
	if value is String:
		var parsed = str_to_var(value)
		if parsed != null:
			value = parsed
	node.set_indexed(NodePath(prop), value)
	return {"node": str(p.get("path")), "property": prop, "new_value": str(node.get_indexed(NodePath(prop)))}


func _cmd_call_method(p: Dictionary):
	var node := _resolve(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo en el juego: %s" % str(p.get("path", "")))
	var method := str(p.get("method", ""))
	if not node.has_method(method):
		return _err("El nodo no tiene el método '%s'" % method)
	var args: Array = p.get("args", []) if p.get("args") is Array else []
	var parsed_args := []
	for a in args:
		if a is String:
			var v = str_to_var(a)
			parsed_args.append(v if v != null else a)
		else:
			parsed_args.append(a)
	var result = node.callv(method, parsed_args)
	return {"result": str(result)}


func _cmd_eval(p: Dictionary):
	var code := str(p.get("code", ""))
	if code.strip_edges() == "":
		return _err("Falta el parámetro 'code'")
	var indented := ""
	for line in code.split("\n"):
		indented += "\t" + line + "\n"
	var source := "extends RefCounted\nfunc run(scene_root, tree):\n" + indented + "\treturn null\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return _err("Error de compilación en el código GDScript. Revisa la sintaxis.")
	var instance = script.new()
	var result = instance.run(_scene_root(), get_tree())
	return {"result": str(result)}


func _cmd_screenshot():
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return _err("No se pudo capturar el viewport del juego")
	if img.get_width() > 1280:
		var scale := 1280.0 / img.get_width()
		img.resize(1280, int(img.get_height() * scale), Image.INTERPOLATE_BILINEAR)
	var buf := img.save_png_to_buffer()
	return {"image_base64": Marshalls.raw_to_base64(buf), "width": img.get_width(), "height": img.get_height()}


func _cmd_find_nodes(p: Dictionary):
	var root := _scene_root()
	if root == null:
		return _err("No hay escena actual en el juego")
	var type_filter := str(p.get("type", ""))
	var group_filter := str(p.get("group", ""))
	var name_filter := str(p.get("name_contains", ""))
	var found: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if type_filter != "" and not node.is_class(type_filter):
			continue
		if group_filter != "" and not node.is_in_group(group_filter):
			continue
		if name_filter != "" and str(node.name).findn(name_filter) < 0:
			continue
		found.append({
			"path": str(root.get_path_to(node)) if node != root else ".",
			"type": node.get_class(),
			"name": str(node.name),
		})
		if found.size() >= 200:
			break
	return {"count": found.size(), "nodes": found}


func _cmd_wait(p: Dictionary):
	var seconds := clampf(float(p.get("seconds", 1.0)), 0.0, 110.0)
	await get_tree().create_timer(seconds).timeout
	var snapshot := {}
	var watch: Array = p.get("watch", []) if p.get("watch") is Array else []
	for path in watch:
		var node := _resolve(str(path))
		if node == null:
			snapshot[str(path)] = null
			continue
		var info := {"type": node.get_class()}
		if node is Node2D or node is Control:
			info["position"] = str(node.position)
		elif node is Node3D:
			info["position"] = str(node.position)
		snapshot[str(path)] = info
	return {"waited": seconds, "snapshot": snapshot}


func _cmd_monitor_signal(p: Dictionary):
	var action := str(p.get("action", "start"))
	match action:
		"start":
			var node := _resolve(str(p.get("path", "")))
			if node == null:
				return _err("No se encontró el nodo en el juego: %s" % str(p.get("path", "")))
			var sig := str(p.get("signal", ""))
			if not node.has_signal(sig):
				return _err("El nodo no tiene la señal '%s'" % sig)
			var argc := 0
			for s in node.get_signal_list():
				if s["name"] == sig:
					argc = s["args"].size()
					break
			# Script dinámico con la aridad exacta de la señal.
			var arg_names := PackedStringArray()
			for i in argc:
				arg_names.append("a%d" % i)
			var decl := ", ".join(arg_names)
			var uses := ", ".join(arg_names)
			var src := "extends RefCounted\nvar agent\nvar mon_id\nfunc on_emit(%s):\n\tagent.record_emission(mon_id, [%s])\n" % [decl, uses]
			var script := GDScript.new()
			script.source_code = src
			if script.reload() != OK:
				return _err("No se pudo crear el monitor de señal")
			var recorder = script.new()
			_monitor_seq += 1
			var mon_id := "m%d" % _monitor_seq
			recorder.agent = self
			recorder.mon_id = mon_id
			node.connect(sig, Callable(recorder, "on_emit"))
			_monitors[mon_id] = {"node": node, "signal": sig, "recorder": recorder, "emissions": []}
			return {"monitor_id": mon_id, "signal": sig}
		"read":
			var mon_id := str(p.get("monitor_id", ""))
			if not _monitors.has(mon_id):
				return _err("Monitor no encontrado: %s" % mon_id)
			return {"emissions": _monitors[mon_id]["emissions"]}
		"stop":
			var mon_id := str(p.get("monitor_id", ""))
			if not _monitors.has(mon_id):
				return _err("Monitor no encontrado: %s" % mon_id)
			var m: Dictionary = _monitors[mon_id]
			if is_instance_valid(m["node"]) and m["node"].is_connected(m["signal"], Callable(m["recorder"], "on_emit")):
				m["node"].disconnect(m["signal"], Callable(m["recorder"], "on_emit"))
			var emissions: Array = m["emissions"]
			_monitors.erase(mon_id)
			return {"stopped": mon_id, "emissions": emissions}
	return _err("Acción desconocida: %s (usa start, read o stop)" % action)


func record_emission(mon_id: String, args: Array) -> void:
	if not _monitors.has(mon_id):
		return
	var emissions: Array = _monitors[mon_id]["emissions"]
	var str_args := []
	for a in args:
		str_args.append(str(a))
	emissions.append({"time_msec": Time.get_ticks_msec(), "args": str_args})
	if emissions.size() > 200:
		_monitors[mon_id]["emissions"] = emissions.slice(emissions.size() - 200)


func _cmd_get_performance():
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"time_scale": Engine.time_scale,
		"paused": get_tree().paused,
	}


func _cmd_get_groups(p: Dictionary):
	var root := _scene_root()
	if root == null:
		return _err("No hay escena actual en el juego")
	var groups := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		for g in node.get_groups():
			var gname := str(g)
			if gname.begins_with("_"):
				continue  # grupos internos del engine
			groups[gname] = int(groups.get(gname, 0)) + 1
	return {"groups": groups}
```

- [ ] **Step 3: Validar sintaxis** (headless `--check-only`). Esperado: exit 0 (el `_dispatch_input` aún no existe — añadir stub temporal):

```gdscript
func _dispatch_input(_command: String, _p: Dictionary):
	return _err("input no implementado todavía")
```

- [ ] **Step 4: Commit**

```powershell
git add addons/claude_bridge/runtime_agent.gd
git commit -m "feat: 15 comandos runtime en el agente (inspeccion, eval, screenshot, perf, monitores)"
```

---

### Task 8: Comandos input del agente (7)

**Files:**
- Modify: `addons/claude_bridge/runtime_agent.gd` (reemplazar stub `_dispatch_input`)

- [ ] **Step 1: Implementar input**

```gdscript
func _dispatch_input(command: String, p: Dictionary):
	match command:
		"input_action_press":
			var action := str(p.get("action", ""))
			if not InputMap.has_action(action):
				return _err("La acción '%s' no existe en el Input Map" % action)
			Input.action_press(action, clampf(float(p.get("strength", 1.0)), 0.0, 1.0))
			return {"pressed": action}
		"input_action_release":
			var action := str(p.get("action", ""))
			if not InputMap.has_action(action):
				return _err("La acción '%s' no existe en el Input Map" % action)
			Input.action_release(action)
			return {"released": action}
		"input_key":
			return await _input_key(p)
		"input_mouse_move":
			var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
			get_viewport().warp_mouse(pos)
			var motion := InputEventMouseMotion.new()
			motion.position = pos
			motion.global_position = pos
			Input.parse_input_event(motion)
			return {"mouse_at": str(pos)}
		"input_mouse_click":
			return await _input_mouse_click(p)
		"input_text":
			return await _input_text(p)
		"input_sequence":
			return await _input_sequence(p)
	return _err("Comando input desconocido: %s" % command)


func _input_key(p: Dictionary):
	var key_name := str(p.get("key", ""))
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return _err("Tecla desconocida: '%s' (usa nombres como 'A', 'Space', 'Escape', 'Shift')" % key_name)
	var mode := str(p.get("mode", "tap"))  # tap | press | release
	if mode in ["tap", "press"]:
		_send_key(keycode, true)
	if mode == "tap":
		await get_tree().process_frame
		await get_tree().process_frame
	if mode in ["tap", "release"]:
		_send_key(keycode, false)
	return {"key": key_name, "mode": mode}


func _send_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _input_mouse_click(p: Dictionary):
	var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	var button := MOUSE_BUTTON_LEFT
	match str(p.get("button", "left")):
		"right":
			button = MOUSE_BUTTON_RIGHT
		"middle":
			button = MOUSE_BUTTON_MIDDLE
	get_viewport().warp_mouse(pos)
	var press := InputEventMouseButton.new()
	press.position = pos
	press.global_position = pos
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = pos
	release.global_position = pos
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)
	return {"clicked": str(pos), "button": str(p.get("button", "left"))}


func _input_text(p: Dictionary):
	var text := str(p.get("text", ""))
	for i in text.length():
		var ev := InputEventKey.new()
		ev.unicode = text.unicode_at(i)
		ev.pressed = true
		Input.parse_input_event(ev)
		var rel := InputEventKey.new()
		rel.unicode = text.unicode_at(i)
		rel.pressed = false
		Input.parse_input_event(rel)
		await get_tree().process_frame
	return {"typed": text}


## Pasos: [{type, ...params del tipo, wait_after: segundos}]
## types: action_press, action_release, key, mouse_move, mouse_click, text, wait
func _input_sequence(p: Dictionary):
	var steps: Array = p.get("steps", []) if p.get("steps") is Array else []
	if steps.is_empty():
		return _err("Falta el parámetro 'steps' (lista de pasos)")
	var executed := 0
	for step in steps:
		if not (step is Dictionary):
			continue
		var type := str(step.get("type", ""))
		var result
		match type:
			"action_press":
				result = await _dispatch_input("input_action_press", step)
			"action_release":
				result = await _dispatch_input("input_action_release", step)
			"key":
				result = await _dispatch_input("input_key", step)
			"mouse_move":
				result = await _dispatch_input("input_mouse_move", step)
			"mouse_click":
				result = await _dispatch_input("input_mouse_click", step)
			"text":
				result = await _dispatch_input("input_text", step)
			"wait":
				result = {}
			_:
				return _err("Paso %d: tipo desconocido '%s'" % [executed, type])
		if result is Dictionary and result.has("__error"):
			return _err("Paso %d (%s): %s" % [executed, type, result["__error"]])
		var wait_after := clampf(float(step.get("wait_after", 0.0)), 0.0, 30.0)
		if type == "wait":
			wait_after = clampf(float(step.get("seconds", 1.0)), 0.0, 30.0)
		if wait_after > 0.0:
			await get_tree().create_timer(wait_after).timeout
		executed += 1
	return {"steps_executed": executed}
```

- [ ] **Step 2: Eliminar el stub `_dispatch_input` de Task 7** (queda solo esta implementación).

- [ ] **Step 3: Validar sintaxis** (headless `--check-only`). Esperado: exit 0.

- [ ] **Step 4: Commit**

```powershell
git add addons/claude_bridge/runtime_agent.gd
git commit -m "feat: 7 comandos de simulacion de input en el agente"
```

---

### Task 9: Tools MCP en el servidor Node

**Files:**
- Modify: `server/index.js` (líneas 644-648, antes de crear el transport)
- Create: `server/tools/debug.js`
- Create: `server/tools/runtime.js`
- Create: `server/tools/input.js`

- [ ] **Step 1: Crear server/tools/debug.js**

```js
import { z } from "zod";

const severity = z.enum(["all", "error", "warning"]).optional().describe("Filtro (por defecto all)");
const limit = z.number().optional().describe("Máximo de entradas (por defecto 100)");
const clear = z.boolean().optional().describe("Vaciar el buffer tras leer");

export function registerDebugTools(server, { run }) {
  server.tool(
    "godot_get_errors",
    "Devuelve los errores y warnings recientes del EDITOR de Godot (buffer circular de 500). Úsala tras operaciones que puedan fallar en silencio.",
    { severity, limit, clear },
    async (args) => run("get_errors", args)
  );

  server.tool(
    "godot_get_game_output",
    "Devuelve la salida del JUEGO (print, errores, warnings) acumulada por el editor. Funciona incluso después de que el juego haya terminado o crasheado.",
    { severity, limit, clear },
    async (args) => run("get_game_output", args)
  );

  server.tool(
    "godot_validate_script",
    "Compila un script .gd y devuelve si es válido junto con los errores de compilación capturados. Sustituye la validación por CLI headless.",
    { path: z.string().describe("Ruta res:// del script") },
    async (args) => run("validate_script", args)
  );

  server.tool(
    "godot_search_scripts",
    "Busca texto o regex en los scripts .gd del proyecto. Devuelve archivo, línea y texto de cada coincidencia (máx. 200).",
    {
      pattern: z.string().describe("Texto o regex a buscar"),
      regex: z.boolean().optional().describe("Interpretar pattern como regex"),
      path: z.string().optional().describe("Carpeta base (por defecto res://)"),
      include_addons: z.boolean().optional().describe("Incluir addons (por defecto false)"),
    },
    async (args) => run("search_scripts", args)
  );

  server.tool(
    "godot_reload_scripts",
    "Fuerza un re-escaneo del sistema de archivos y de los scripts en el editor.",
    {},
    async () => run("reload_scripts", {})
  );

  server.tool(
    "godot_move_node",
    "Mueve un nodo: cambia su padre (reparent conservando transform global por defecto) y/o su posición entre hermanos.",
    {
      path: z.string().describe("Ruta del nodo a mover"),
      new_parent: z.string().optional().describe("Ruta del nuevo padre ('.' = raíz)"),
      index: z.number().optional().describe("Posición entre hermanos (0 = primero)"),
      keep_transform: z.boolean().optional().describe("Conservar transform global (por defecto true)"),
    },
    async (args) => run("move_node", args)
  );

  server.tool(
    "godot_rename_node",
    "Renombra un nodo de la escena abierta.",
    {
      path: z.string().describe("Ruta del nodo"),
      name: z.string().describe("Nuevo nombre"),
    },
    async (args) => run("rename_node", args)
  );

  server.tool(
    "godot_get_selection",
    "Devuelve los nodos seleccionados actualmente en el editor.",
    {},
    async () => run("get_selection", {})
  );

  server.tool(
    "godot_set_selection",
    "Selecciona nodos en el editor (dirige la atención del usuario a esos nodos).",
    { paths: z.array(z.string()).describe("Rutas de los nodos a seleccionar") },
    async (args) => run("set_selection", args)
  );

  server.tool(
    "godot_open_script",
    "Abre un script en el editor de scripts de Godot, en la línea indicada.",
    {
      path: z.string().describe("Ruta res:// del script"),
      line: z.number().optional().describe("Línea (por defecto 1)"),
    },
    async (args) => run("open_script", args)
  );
}
```

- [ ] **Step 2: Crear server/tools/runtime.js**

```js
import { z } from "zod";

export function registerRuntimeTools(server, { run, godot, fail }) {
  server.tool(
    "runtime_get_scene_tree",
    "Árbol de nodos del JUEGO EN EJECUCIÓN (no del editor). Requiere el juego corriendo (godot_run_scene).",
    {},
    async () => run("runtime_get_scene_tree", {})
  );

  server.tool(
    "runtime_get_node_info",
    "Propiedades actuales de un nodo del juego en ejecución (estado en vivo).",
    { path: z.string().describe("Ruta relativa a la escena actual; '.' = raíz") },
    async (args) => run("runtime_get_node_info", args)
  );

  server.tool(
    "runtime_set_property",
    "Cambia una propiedad de un nodo del juego EN VIVO, sin reiniciar. Ideal para tuning (velocidad, vida, daño…). Acepta literales como 'Vector2(10, 20)'.",
    {
      path: z.string().describe("Ruta del nodo en el juego"),
      property: z.string().describe("Propiedad, admite 'position:x'"),
      value: z.any().describe("Nuevo valor"),
    },
    async (args) => run("runtime_set_property", args)
  );

  server.tool(
    "runtime_call_method",
    "Llama un método de un nodo del juego en ejecución con argumentos opcionales.",
    {
      path: z.string().describe("Ruta del nodo en el juego"),
      method: z.string().describe("Nombre del método"),
      args: z.array(z.any()).optional().describe("Argumentos; las cadenas con literales de Godot se convierten"),
    },
    async (args) => run("runtime_call_method", args)
  );

  server.tool(
    "runtime_eval",
    "Ejecuta GDScript arbitrario DENTRO del juego en ejecución. El código recibe 'scene_root' (escena actual) y 'tree' (SceneTree). Usa 'return' para devolver un valor.",
    { code: z.string().describe("Cuerpo de una función GDScript") },
    async (args) => run("runtime_eval", args)
  );

  server.tool(
    "runtime_screenshot",
    "Captura el viewport del JUEGO en ejecución y devuelve la imagen. Para VER el juego tal y como lo ve el jugador.",
    {},
    async () => {
      try {
        const r = await godot("runtime_screenshot", {});
        return {
          content: [
            { type: "image", data: r.image_base64, mimeType: "image/png" },
            { type: "text", text: `Captura del juego (${r.width}x${r.height})` },
          ],
        };
      } catch (err) {
        return fail(err);
      }
    }
  );

  server.tool(
    "runtime_find_nodes",
    "Busca nodos en el juego en ejecución por clase, grupo y/o nombre (máx. 200).",
    {
      type: z.string().optional().describe("Clase de Godot (incluye subclases)"),
      group: z.string().optional().describe("Nombre de grupo"),
      name_contains: z.string().optional().describe("Fragmento del nombre"),
    },
    async (args) => run("runtime_find_nodes", args)
  );

  server.tool("runtime_pause", "Pausa el juego en ejecución (get_tree().paused = true).", {}, async () =>
    run("runtime_pause", {})
  );

  server.tool("runtime_resume", "Reanuda el juego pausado.", {}, async () => run("runtime_resume", {}));

  server.tool(
    "runtime_time_scale",
    "Cambia Engine.time_scale del juego (cámara lenta o avance rápido). 1.0 = normal.",
    { scale: z.number().describe("Factor de tiempo, 0.01 a 20") },
    async (args) => run("runtime_time_scale", args)
  );

  server.tool(
    "runtime_wait",
    "Espera N segundos de juego y devuelve un snapshot opcional de los nodos vigilados (tipo y posición). Útil para observar evolución: '¿dónde está el enemigo tras 3s?'.",
    {
      seconds: z.number().describe("Segundos a esperar (máx. 110)"),
      watch: z.array(z.string()).optional().describe("Rutas de nodos a fotografiar al terminar"),
    },
    async (args) => run("runtime_wait", args, Math.min((args.seconds || 1) * 1000 + 10000, 120000))
  );

  server.tool(
    "runtime_monitor_signal",
    "Monitoriza emisiones de una señal del juego. action='start' (devuelve monitor_id), 'read' (emisiones acumuladas), 'stop' (desconecta y devuelve todo).",
    {
      action: z.enum(["start", "read", "stop"]),
      path: z.string().optional().describe("Nodo (solo para start)"),
      signal: z.string().optional().describe("Señal (solo para start)"),
      monitor_id: z.string().optional().describe("Id devuelto por start (para read/stop)"),
    },
    async (args) => run("runtime_monitor_signal", args)
  );

  server.tool(
    "runtime_get_performance",
    "Métricas de rendimiento del juego en vivo: FPS, tiempos de process/física, memoria, draw calls, nodos, nodos huérfanos.",
    {},
    async () => run("runtime_get_performance", {})
  );

  server.tool(
    "runtime_get_groups",
    "Lista los grupos activos del juego con el número de miembros de cada uno (p. ej. cuántos 'enemigos' vivos hay).",
    {},
    async () => run("runtime_get_groups", {})
  );

  server.tool("runtime_quit", "Cierra el juego en ejecución limpiamente desde dentro.", {}, async () =>
    run("runtime_quit", {})
  );
}
```

- [ ] **Step 3: Crear server/tools/input.js**

```js
import { z } from "zod";

export function registerInputTools(server, { run }) {
  server.tool(
    "input_action_press",
    "Mantiene pulsada una acción del Input Map del juego (p. ej. 'move_up'). Queda pulsada hasta input_action_release.",
    {
      action: z.string().describe("Nombre de la acción del Input Map"),
      strength: z.number().optional().describe("Fuerza 0-1 (por defecto 1)"),
    },
    async (args) => run("input_action_press", args)
  );

  server.tool(
    "input_action_release",
    "Suelta una acción mantenida con input_action_press.",
    { action: z.string().describe("Nombre de la acción") },
    async (args) => run("input_action_release", args)
  );

  server.tool(
    "input_key",
    "Simula una tecla en el juego. mode: 'tap' (pulsar y soltar), 'press' (mantener), 'release' (soltar).",
    {
      key: z.string().describe("Nombre de la tecla: 'A', 'Space', 'Escape', 'Shift'…"),
      mode: z.enum(["tap", "press", "release"]).optional().describe("Por defecto tap"),
    },
    async (args) => run("input_key", args)
  );

  server.tool(
    "input_mouse_move",
    "Mueve el ratón del juego a coordenadas de viewport.",
    { x: z.number(), y: z.number() },
    async (args) => run("input_mouse_move", args)
  );

  server.tool(
    "input_mouse_click",
    "Click del ratón en coordenadas del viewport del juego (sirve para UI y para apuntar).",
    {
      x: z.number(),
      y: z.number(),
      button: z.enum(["left", "right", "middle"]).optional().describe("Por defecto left"),
    },
    async (args) => run("input_mouse_click", args)
  );

  server.tool(
    "input_text",
    "Escribe texto en el juego (p. ej. en un LineEdit con foco).",
    { text: z.string().describe("Texto a escribir") },
    async (args) => run("input_text", args)
  );

  server.tool(
    "input_sequence",
    "Ejecuta una secuencia temporizada de inputs — playtest scripteado. Cada paso: {type, ...params, wait_after}. Tipos: action_press, action_release, key, mouse_move, mouse_click, text, wait. Ejemplo: mantener 'move_up' 2s, click en (640,360), esperar 1s.",
    {
      steps: z
        .array(
          z.object({
            type: z.enum(["action_press", "action_release", "key", "mouse_move", "mouse_click", "text", "wait"]),
            action: z.string().optional(),
            strength: z.number().optional(),
            key: z.string().optional(),
            mode: z.string().optional(),
            x: z.number().optional(),
            y: z.number().optional(),
            button: z.string().optional(),
            text: z.string().optional(),
            seconds: z.number().optional().describe("Solo para type=wait"),
            wait_after: z.number().optional().describe("Segundos de espera tras el paso (máx. 30)"),
          })
        )
        .describe("Pasos de la secuencia"),
    },
    async (args) => {
      const totalWait = (args.steps || []).reduce(
        (acc, s) => acc + (s.wait_after || 0) + (s.type === "wait" ? s.seconds || 1 : 0),
        0
      );
      return run("input_sequence", args, Math.min(totalWait * 1000 + 15000, 120000));
    }
  );
}
```

- [ ] **Step 4: Wiring en server/index.js** — añadir imports arriba (tras `import net from "node:net";`):

```js
import { registerDebugTools } from "./tools/debug.js";
import { registerRuntimeTools } from "./tools/runtime.js";
import { registerInputTools } from "./tools/input.js";
```

Y antes de `const transport = new StdioServerTransport();`:

```js
const ctx = { run, godot, ok, fail };
registerDebugTools(server, ctx);
registerRuntimeTools(server, ctx);
registerInputTools(server, ctx);
```

- [ ] **Step 5: Verificar carga** — `node server/index.js` arranca sin excepción (Ctrl+C tras ver el mensaje "Listo"):

```powershell
cd server; node --check index.js; node --check tools/debug.js; node --check tools/runtime.js; node --check tools/input.js
```

Esperado: sin salida (sintaxis OK en los 4).

- [ ] **Step 6: Commit**

```powershell
git add server/tools server/index.js
git commit -m "feat: 32 tools MCP nuevas (debug, runtime, input) en modulos separados"
```

---

### Task 10: Test e2e de protocolo

**Files:**
- Modify: `server/test-e2e.mjs`

- [ ] **Step 1: Ampliar el test** — reemplazar el archivo:

```js
import net from "node:net";
import { spawn } from "node:child_process";

// Falso Godot: responde a cualquier comando
const fake = net.createServer((sock) => {
  let buf = "";
  sock.on("data", (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      const msg = JSON.parse(line);
      console.log("[fake-godot] recibido:", msg.command);
      if (msg.command === "get_errors") {
        sock.write(JSON.stringify({ id: msg.id, ok: true, result: { count: 0, entries: [] } }) + "\n");
      } else if (msg.command === "runtime_get_scene_tree") {
        sock.write(
          JSON.stringify({ id: msg.id, ok: false, error: "El juego no está en ejecución. Lánzalo con godot_run_scene primero." }) + "\n"
        );
      } else {
        sock.write(JSON.stringify({ id: msg.id, ok: true, result: { pong: true, godot_version: "4.6-test", project: "Demo" } }) + "\n");
      }
    }
  });
});

const EXPECTED_MIN_TOOLS = 74; // 42 originales + 32 de la Fase 1
let failures = 0;

fake.listen(9080, "127.0.0.1", () => {
  const child = spawn("node", ["index.js"], { stdio: ["pipe", "pipe", "inherit"] });
  let out = "";
  child.stdout.on("data", (d) => {
    out += d;
    const lines = out.split("\n");
    out = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      let m;
      try {
        m = JSON.parse(line);
      } catch {
        continue;
      }
      if (m.id === 1) {
        child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
        child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }) + "\n");
      }
      if (m.id === 2) {
        const tools = m.result.tools.map((t) => t.name);
        console.log(`[test] tools registradas: ${tools.length}`);
        if (tools.length < EXPECTED_MIN_TOOLS) {
          console.log(`FAIL: se esperaban >= ${EXPECTED_MIN_TOOLS} tools`);
          failures++;
        }
        for (const required of ["godot_get_errors", "runtime_get_scene_tree", "input_sequence", "runtime_screenshot"]) {
          if (!tools.includes(required)) {
            console.log(`FAIL: falta la tool ${required}`);
            failures++;
          }
        }
        child.stdin.write(
          JSON.stringify({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "godot_get_errors", arguments: {} } }) + "\n"
        );
      }
      if (m.id === 3) {
        if (m.result.isError) {
          console.log("FAIL: godot_get_errors devolvió error");
          failures++;
        } else {
          console.log("[test] godot_get_errors OK");
        }
        child.stdin.write(
          JSON.stringify({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "runtime_get_scene_tree", arguments: {} } }) + "\n"
        );
      }
      if (m.id === 4) {
        const text = JSON.stringify(m.result.content);
        if (!m.result.isError || !text.includes("no está en ejecución")) {
          console.log("FAIL: runtime_get_scene_tree debía devolver error accionable, recibido:", text);
          failures++;
        } else {
          console.log("[test] error accionable de runtime OK");
        }
        console.log(failures === 0 ? "TEST OK" : `TEST FAIL (${failures})`);
        child.kill();
        fake.close();
        process.exit(failures === 0 ? 0 : 1);
      }
    }
  });
  child.stdin.write(
    JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "test", version: "1.0" } } }) + "\n"
  );
});
setTimeout(() => {
  console.log("TIMEOUT");
  process.exit(1);
}, 15000);
```

- [ ] **Step 2: Ejecutar** (con el editor de Godot CERRADO o el puerto 9080 libre — el fake ocupa el puerto):

```powershell
cd server; node test-e2e.mjs
```

Esperado: `TEST OK`, exit 0. Si Godot está abierto con el plugin activo, cerrar primero o parar el servidor del dock.

- [ ] **Step 3: Commit**

```powershell
git add server/test-e2e.mjs
git commit -m "test: e2e verifica 74 tools y rutas de error del relay runtime"
```

---

### Task 11: Sync al proyecto Nightfall + smoke test real

**Files:**
- Create: `sync-addon.ps1`
- Modify: `README.md` (sección de tools)

- [ ] **Step 1: Crear sync-addon.ps1**

```powershell
# Copia el addon al proyecto del juego. Uso: .\sync-addon.ps1
$dest = "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego\addons\claude_bridge"
robocopy "addons\claude_bridge" $dest /MIR /NJH /NJS
if ($LASTEXITCODE -le 7) { Write-Host "Sync OK -> $dest"; exit 0 } else { Write-Host "Sync FALLO ($LASTEXITCODE)"; exit 1 }
```

- [ ] **Step 2: Ejecutar sync**

```powershell
.\sync-addon.ps1
```

Esperado: `Sync OK`.

- [ ] **Step 3: Reactivar plugin en Nightfall** — el editor debe estar abierto con el proyecto:
1. Proyecto → Ajustes del proyecto → Plugins → desactivar "Claude Bridge" → activar de nuevo (registra el autoload `ClaudeRuntime` vía `_enable_plugin`).
2. Verificar autoload: Proyecto → Ajustes → Autoloads debe listar `ClaudeRuntime`.
3. Si el editor estaba abierto durante el sync, reiniciarlo si los scripts del addon no recargan limpio.

- [ ] **Step 4: Smoke test completo vía tools MCP** (sesión de Claude Code con el MCP reiniciado para cargar las tools nuevas):
1. `godot_status` → pong.
2. `godot_get_errors` → ok (buffer del editor).
3. `godot_run_scene` → lanza la escena principal de Nightfall.
4. Esperar ~3 s → `godot_get_game_output` → `game_running: true` y entradas del log.
5. `runtime_get_scene_tree` → árbol del juego con Player.
6. `runtime_get_performance` → FPS > 0.
7. `input_sequence` con: `action_press move_up` + `wait_after 1`, `action_release move_up`, `mouse_click` en el centro → `steps_executed: 3`.
8. `runtime_screenshot` → imagen del juego.
9. `runtime_get_groups` → grupos del juego (enemigos, etc.).
10. `godot_stop_scene` → `runtime_get_scene_tree` ahora devuelve error accionable inmediato.

Criterio de aceptación (de la spec): ninguna tool produce timeout mudo en los tres estados (corriendo, cerrado, crasheado).

- [ ] **Step 5: Actualizar README.md** — añadir a la lista de tools las 32 nuevas en tres secciones (Debug, Runtime, Input) con una línea por tool (usar las descripciones de los archivos `server/tools/*.js`).

- [ ] **Step 6: Commit final**

```powershell
git add sync-addon.ps1 README.md
git commit -m "feat: script de sync al proyecto del juego y docs de las 32 tools de Fase 1"
```

---

## Self-review (hecho al escribir el plan)

- **Cobertura de spec:** 10 editor (Task 6) + 15 runtime (Task 7) + 7 input (Task 8) = 32 ✓; relay con error accionable (Task 3) ✓; logs persistentes tras crash (Tasks 2, 4) ✓; timeouts dinámicos (Task 9: runtime_wait, input_sequence) ✓; autoload inerte sin feature editor (Task 4) ✓; testing (Tasks 10-11) ✓.
- **Consistencia de tipos:** protocolo `{id, command, params}` / `{id, ok, result|error}` idéntico en bridge, agent_link y agente ✓; `handles()/dispatch()` entre bridge y editor_debug ✓; push `{push:"log", entry}` entre agente y agent_link ✓.
- **Riesgos conocidos:** (1) `Logger`/`OS.add_logger` requiere Godot 4.5+ — proyecto en 4.6.3 ✓. (2) `_enable_plugin` no se dispara en proyectos con el plugin ya activo — mitigado en Task 11 paso 3. (3) El editor recarga scripts de addon de forma inconsistente — mitigado con reinicio del editor en Task 11.
