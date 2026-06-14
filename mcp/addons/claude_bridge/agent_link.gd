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
