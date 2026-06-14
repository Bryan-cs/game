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


func _cmd_get_groups(_p: Dictionary):
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
