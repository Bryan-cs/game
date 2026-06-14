@tool
extends RefCounted
## Servidor TCP que recibe comandos JSON (una línea por mensaje) desde el
## servidor MCP de Claude Code y los ejecuta dentro del editor de Godot.

signal log_message(text: String, kind: String)  # kind: info | ok | error | cmd
signal status_changed(running: bool, port: int)
signal client_count_changed(count: int)

var _tcp := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var _buffers: Dictionary = {}  # client -> String
var _running := false
var _port := 9080

var commands_handled := 0

## Asignados por plugin.gd al activarse.
var agent_link = null
var modules: Array = []


func is_running() -> bool:
	return _running


func get_port() -> int:
	return _port


func start(port: int) -> void:
	stop()
	_port = port
	var err := _tcp.listen(_port, "127.0.0.1")
	if err != OK:
		log_message.emit("No se pudo abrir el puerto %d (error %d). ¿Está ocupado?" % [_port, err], "error")
		status_changed.emit(false, _port)
		return
	_running = true
	log_message.emit("Servidor iniciado en 127.0.0.1:%d" % _port, "ok")
	status_changed.emit(true, _port)


func stop() -> void:
	for c in _clients:
		c.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	if _tcp.is_listening():
		_tcp.stop()
	if _running:
		log_message.emit("Servidor detenido", "info")
	_running = false
	status_changed.emit(false, _port)
	client_count_changed.emit(0)


func poll() -> void:
	if not _running:
		return

	while _tcp.is_connection_available():
		var client := _tcp.take_connection()
		_clients.append(client)
		_buffers[client] = ""
		log_message.emit("Claude Code conectado", "ok")
		client_count_changed.emit(_clients.size())

	var to_remove: Array[StreamPeerTCP] = []
	for client in _clients:
		client.poll()
		var status := client.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(client)
			continue
		var available := client.get_available_bytes()
		if available > 0:
			var data := client.get_utf8_string(available)
			_buffers[client] = String(_buffers[client]) + data
			_process_buffer(client)

	for client in to_remove:
		_clients.erase(client)
		_buffers.erase(client)
		log_message.emit("Claude Code desconectado", "info")
		client_count_changed.emit(_clients.size())


func _process_buffer(client: StreamPeerTCP) -> void:
	var buf: String = _buffers[client]
	while true:
		var idx := buf.find("\n")
		if idx < 0:
			break
		var line := buf.substr(0, idx)
		buf = buf.substr(idx + 1)
		if line.strip_edges() != "":
			_handle_line(client, line)
	_buffers[client] = buf


func _handle_line(client: StreamPeerTCP, line: String) -> void:
	var msg = JSON.parse_string(line)
	if msg == null or not (msg is Dictionary):
		_send(client, {"id": -1, "ok": false, "error": "JSON inválido"})
		return

	var id = msg.get("id", -1)
	var command: String = str(msg.get("command", ""))
	var params: Dictionary = msg.get("params", {}) if msg.get("params") is Dictionary else {}

	log_message.emit("→ %s" % command, "cmd")
	commands_handled += 1

	# Comandos runtime/input van al juego vía relay; la respuesta llega después.
	if command.begins_with("runtime_") or command.begins_with("input_"):
		_relay_to_game(client, id, command, params)
		return

	var response: Dictionary
	# Se ejecuta dentro del hilo principal del editor.
	var result = _dispatch(command, params)
	if result is Dictionary and result.has("__error"):
		response = {"id": id, "ok": false, "error": result["__error"]}
		log_message.emit("✗ %s: %s" % [command, result["__error"]], "error")
	else:
		response = {"id": id, "ok": true, "result": result}
		log_message.emit("✓ %s completado" % command, "ok")
	_send(client, response)


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


func _send(client: StreamPeerTCP, data: Dictionary) -> void:
	client.put_data((JSON.stringify(data) + "\n").to_utf8_buffer())


func _err(message: String) -> Dictionary:
	return {"__error": message}


# ---------------------------------------------------------------------------
# Comandos
# ---------------------------------------------------------------------------

func _dispatch(command: String, p: Dictionary):
	match command:
		"ping":
			return {"pong": true, "godot_version": Engine.get_version_info()["string"], "project": ProjectSettings.get_setting("application/config/name", "")}
		"get_scene_tree":
			return _cmd_get_scene_tree()
		"open_scene":
			return _cmd_open_scene(p)
		"create_node":
			return _cmd_create_node(p)
		"delete_node":
			return _cmd_delete_node(p)
		"set_property":
			return _cmd_set_property(p)
		"get_node_info":
			return _cmd_get_node_info(p)
		"save_scene":
			return _cmd_save_scene()
		"run_scene":
			return _cmd_run_scene(p)
		"stop_scene":
			return _cmd_stop_scene()
		"list_files":
			return _cmd_list_files(p)
		"read_file":
			return _cmd_read_file(p)
		"write_file":
			return _cmd_write_file(p)
		"attach_script":
			return _cmd_attach_script(p)
		"execute_code":
			return _cmd_execute_code(p)
		"create_scene":
			return _cmd_create_scene(p)
		"instance_scene":
			return _cmd_instance_scene(p)
		"add_input_action":
			return _cmd_add_input_action(p)
		"set_project_setting":
			return _cmd_set_project_setting(p)
		"assign_resource":
			return _cmd_assign_resource(p)
		"create_primitive_mesh":
			return _cmd_create_primitive_mesh(p)
		"create_collision_shape":
			return _cmd_create_collision_shape(p)
		"create_material":
			return _cmd_create_material(p)
		"setup_environment_3d":
			return _cmd_setup_environment_3d(p)
		"create_character":
			return _cmd_create_character(p)
		"create_animation":
			return _cmd_create_animation(p)
		"list_animations":
			return _cmd_list_animations(p)
		"play_animation":
			return _cmd_play_animation(p)
		"create_sprite_animation":
			return _cmd_create_sprite_animation(p)
		"connect_signal":
			return _cmd_connect_signal(p)
		"list_signals":
			return _cmd_list_signals(p)
		"add_to_group":
			return _cmd_add_to_group(p)
		"screenshot":
			return _cmd_screenshot(p)
		"paint_tiles":
			return _cmd_paint_tiles(p)
		"import_asset":
			return _cmd_import_asset(p)
		"create_tileset":
			return _cmd_create_tileset(p)
		"export_project":
			return _cmd_export_project(p)
		"create_shader":
			return _cmd_create_shader(p)
		"duplicate_node":
			return _cmd_duplicate_node(p)
		"find_nodes":
			return _cmd_find_nodes(p)
		"set_physics_layers":
			return _cmd_set_physics_layers(p)
		"create_nav_region":
			return _cmd_create_nav_region(p)
		_:
			for m in modules:
				if m.handles(command):
					return m.dispatch(command, p)
			return _err("Comando desconocido: %s" % command)


func _get_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _cmd_get_scene_tree():
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta en el editor")
	return {"scene_path": root.scene_file_path, "tree": _serialize_node(root)}


func _serialize_node(node: Node) -> Dictionary:
	var children := []
	for child in node.get_children():
		children.append(_serialize_node(child))
	var info := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(_get_root().get_path_to(node)) if node != _get_root() else ".",
	}
	var script = node.get_script()
	if script != null:
		info["script"] = script.resource_path
	if not children.is_empty():
		info["children"] = children
	return info


func _cmd_open_scene(p: Dictionary):
	var path: String = str(p.get("path", ""))
	if not FileAccess.file_exists(path):
		return _err("La escena no existe: %s" % path)
	EditorInterface.open_scene_from_path(path)
	return {"opened": path}


func _resolve_node(path: String) -> Node:
	var root := _get_root()
	if root == null:
		return null
	if path == "." or path == "" or path == "/root" or path == root.name:
		return root
	return root.get_node_or_null(NodePath(path))


func _cmd_create_node(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta. Usa open_scene o crea una primero.")
	var type: String = str(p.get("type", ""))
	var node_name: String = str(p.get("name", type))
	var parent_path: String = str(p.get("parent", "."))

	if not ClassDB.class_exists(type):
		return _err("La clase '%s' no existe en Godot" % type)
	if not ClassDB.can_instantiate(type):
		return _err("La clase '%s' no se puede instanciar" % type)

	var parent := _resolve_node(parent_path)
	if parent == null:
		return _err("No se encontró el nodo padre: %s" % parent_path)

	var node: Node = ClassDB.instantiate(type)
	node.name = node_name
	parent.add_child(node)
	node.owner = root

	# Propiedades iniciales opcionales
	var props: Dictionary = p.get("properties", {}) if p.get("properties") is Dictionary else {}
	for key in props:
		_apply_property(node, str(key), props[key])

	return {"created": str(root.get_path_to(node)), "type": type}


func _cmd_delete_node(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	if node == _get_root():
		return _err("No se puede eliminar el nodo raíz de la escena")
	var path := str(p.get("path", ""))
	node.get_parent().remove_child(node)
	node.queue_free()
	return {"deleted": path}


func _apply_property(node: Node, prop: String, value) -> bool:
	var final_value = value
	# Permite literales de Godot como "Vector2(100, 200)" o "Color(1,0,0)"
	if value is String:
		var parsed = str_to_var(value)
		if parsed != null:
			final_value = parsed
	node.set_indexed(NodePath(prop), final_value)
	return true


func _cmd_set_property(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	var prop: String = str(p.get("property", ""))
	if prop == "":
		return _err("Falta el parámetro 'property'")
	_apply_property(node, prop, p.get("value"))
	return {"node": str(p.get("path")), "property": prop, "new_value": str(node.get_indexed(NodePath(prop)))}


func _cmd_get_node_info(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	var props := {}
	for prop_info in node.get_property_list():
		var usage: int = prop_info["usage"]
		if usage & PROPERTY_USAGE_EDITOR:
			var pname: String = prop_info["name"]
			props[pname] = str(node.get(pname))
	return {"name": node.name, "type": node.get_class(), "properties": props}


func _cmd_save_scene():
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	EditorInterface.save_scene()
	return {"saved": root.scene_file_path}


func _cmd_run_scene(p: Dictionary):
	var path: String = str(p.get("path", ""))
	if path != "":
		EditorInterface.play_custom_scene(path)
		return {"playing": path}
	elif _get_root() != null:
		EditorInterface.play_current_scene()
		return {"playing": _get_root().scene_file_path}
	else:
		EditorInterface.play_main_scene()
		return {"playing": "main_scene"}


func _cmd_stop_scene():
	EditorInterface.stop_playing_scene()
	return {"stopped": true}


func _cmd_list_files(p: Dictionary):
	var dir_path: String = str(p.get("path", "res://"))
	var recursive: bool = bool(p.get("recursive", true))
	var files: Array = []
	_walk_dir(dir_path, recursive, files)
	return {"files": files}


func _walk_dir(path: String, recursive: bool, out: Array) -> void:
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
			if recursive and entry != "addons":
				_walk_dir(full, recursive, out)
		else:
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _cmd_read_file(p: Dictionary):
	var path: String = str(p.get("path", ""))
	if not FileAccess.file_exists(path):
		return _err("El archivo no existe: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("No se pudo abrir: %s" % path)
	return {"path": path, "content": f.get_as_text()}


func _cmd_write_file(p: Dictionary):
	var path: String = str(p.get("path", ""))
	var content: String = str(p.get("content", ""))
	if not path.begins_with("res://"):
		return _err("La ruta debe empezar con res://")
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _err("No se pudo escribir: %s" % path)
	f.store_string(content)
	f.close()
	EditorInterface.get_resource_filesystem().scan()
	return {"written": path, "bytes": content.length()}


func _cmd_attach_script(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node", "")))
	var script_path: String = str(p.get("script", ""))
	if not FileAccess.file_exists(script_path):
		return _err("El script no existe: %s" % script_path)
	var script = load(script_path)
	if script == null:
		return _err("No se pudo cargar el script: %s" % script_path)
	node.set_script(script)
	return {"node": str(p.get("node")), "script": script_path}


func _cmd_execute_code(p: Dictionary):
	var code: String = str(p.get("code", ""))
	if code.strip_edges() == "":
		return _err("Falta el parámetro 'code'")

	var indented := ""
	for line in code.split("\n"):
		indented += "\t" + line + "\n"

	var source := "@tool\nextends RefCounted\nfunc run(scene_root):\n" + indented + "\treturn null\n"
	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	if err != OK:
		return _err("Error de compilación en el código GDScript (error %d). Revisa la sintaxis." % err)
	var instance = script.new()
	var result = instance.run(_get_root())
	return {"result": str(result)}


# ---------------------------------------------------------------------------
# Escenas y proyecto
# ---------------------------------------------------------------------------

func _cmd_create_scene(p: Dictionary):
	var path: String = str(p.get("path", ""))
	var root_type: String = str(p.get("root_type", "Node2D"))
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return _err("La ruta debe empezar con res:// y terminar en .tscn")
	if not ClassDB.class_exists(root_type) or not ClassDB.can_instantiate(root_type):
		return _err("Tipo raíz inválido: %s" % root_type)
	var root_name: String = str(p.get("root_name", path.get_file().get_basename().to_pascal_case()))
	var root: Node = ClassDB.instantiate(root_type)
	root.name = root_name
	var packed := PackedScene.new()
	packed.pack(root)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		return _err("No se pudo guardar la escena (error %d)" % err)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)
	return {"created": path, "root": root_name, "root_type": root_type}


func _cmd_instance_scene(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var scene_path: String = str(p.get("scene", ""))
	if not FileAccess.file_exists(scene_path):
		return _err("La escena no existe: %s" % scene_path)
	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene):
		return _err("No se pudo cargar como PackedScene: %s" % scene_path)
	var inst: Node = packed.instantiate()
	if p.has("name"):
		inst.name = str(p["name"])
	var parent := _resolve_node(str(p.get("parent", ".")))
	if parent == null:
		inst.free()
		return _err("No se encontró el nodo padre: %s" % str(p.get("parent")))
	parent.add_child(inst)
	inst.owner = root
	var props: Dictionary = p.get("properties", {}) if p.get("properties") is Dictionary else {}
	for key in props:
		_apply_property(inst, str(key), props[key])
	return {"instanced": str(root.get_path_to(inst)), "scene": scene_path}


func _ensure_input_action(action: String, keys: Array, joy_buttons: Array = []) -> bool:
	var setting := "input/" + action
	if ProjectSettings.has_setting(setting):
		return false
	var events: Array = []
	for key_name in keys:
		var ev := InputEventKey.new()
		var code := OS.find_keycode_from_string(str(key_name))
		if code == KEY_NONE:
			continue
		ev.physical_keycode = code
		events.append(ev)
	for btn in joy_buttons:
		var jev := InputEventJoypadButton.new()
		jev.button_index = int(btn)
		events.append(jev)
	ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": events})
	return true


func _cmd_add_input_action(p: Dictionary):
	var action: String = str(p.get("name", ""))
	if action == "":
		return _err("Falta el parámetro 'name'")
	var keys: Array = p.get("keys", []) if p.get("keys") is Array else []
	var joy: Array = p.get("joy_buttons", []) if p.get("joy_buttons") is Array else []
	var setting := "input/" + action
	if ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, null)
	_ensure_input_action(action, keys, joy)
	ProjectSettings.save()
	return {"action": action, "keys": keys}


func _cmd_set_project_setting(p: Dictionary):
	var setting: String = str(p.get("setting", ""))
	if setting == "":
		return _err("Falta el parámetro 'setting'")
	var value = p.get("value")
	if value is String:
		var parsed = str_to_var(value)
		if parsed != null:
			value = parsed
	ProjectSettings.set_setting(setting, value)
	ProjectSettings.save()
	return {"setting": setting, "value": str(ProjectSettings.get_setting(setting))}


# ---------------------------------------------------------------------------
# Recursos, mallas, colisiones y materiales
# ---------------------------------------------------------------------------

func _cmd_assign_resource(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node")))
	var res_path: String = str(p.get("resource", ""))
	var res = load(res_path)
	if res == null:
		return _err("No se pudo cargar el recurso: %s" % res_path)
	var prop: String = str(p.get("property", ""))
	node.set_indexed(NodePath(prop), res)
	return {"node": str(p.get("node")), "property": prop, "resource": res_path}


func _parse_color(p: Dictionary, key: String, fallback: Color) -> Color:
	if p.has(key):
		return Color.from_string(str(p[key]), fallback)
	return fallback


func _cmd_create_primitive_mesh(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node")))
	if not (node is MeshInstance3D):
		return _err("El nodo debe ser un MeshInstance3D")
	var shape: String = str(p.get("shape", "box"))
	var mesh: Mesh
	match shape:
		"box":
			var m := BoxMesh.new()
			m.size = Vector3(float(p.get("x", 1.0)), float(p.get("y", 1.0)), float(p.get("z", 1.0)))
			mesh = m
		"sphere":
			var m := SphereMesh.new()
			m.radius = float(p.get("radius", 0.5))
			m.height = float(p.get("height", m.radius * 2.0))
			mesh = m
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = float(p.get("radius", 0.5))
			m.height = float(p.get("height", 2.0))
			mesh = m
		"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = float(p.get("radius", 0.5))
			m.bottom_radius = float(p.get("radius", 0.5))
			m.height = float(p.get("height", 2.0))
			mesh = m
		"plane":
			var m := PlaneMesh.new()
			m.size = Vector2(float(p.get("x", 10.0)), float(p.get("z", 10.0)))
			mesh = m
		"torus":
			var m := TorusMesh.new()
			m.inner_radius = float(p.get("radius", 0.3))
			m.outer_radius = float(p.get("radius", 0.3)) + 0.5
			mesh = m
		_:
			return _err("Forma desconocida: %s (usa box, sphere, capsule, cylinder, plane o torus)" % shape)
	if p.has("color"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _parse_color(p, "color", Color.WHITE)
		mesh.surface_set_material(0, mat)
	node.mesh = mesh
	return {"node": str(p.get("node")), "mesh": shape}


func _cmd_create_collision_shape(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node")))
	var shape_name: String = str(p.get("shape", ""))
	if node is CollisionShape2D:
		match shape_name:
			"rectangle":
				var s := RectangleShape2D.new()
				s.size = Vector2(float(p.get("x", 32.0)), float(p.get("y", 32.0)))
				node.shape = s
			"circle":
				var s := CircleShape2D.new()
				s.radius = float(p.get("radius", 16.0))
				node.shape = s
			"capsule":
				var s := CapsuleShape2D.new()
				s.radius = float(p.get("radius", 14.0))
				s.height = float(p.get("height", 48.0))
				node.shape = s
			_:
				return _err("Forma 2D desconocida: %s (usa rectangle, circle o capsule)" % shape_name)
	elif node is CollisionShape3D:
		match shape_name:
			"box":
				var s := BoxShape3D.new()
				s.size = Vector3(float(p.get("x", 1.0)), float(p.get("y", 1.0)), float(p.get("z", 1.0)))
				node.shape = s
			"sphere":
				var s := SphereShape3D.new()
				s.radius = float(p.get("radius", 0.5))
				node.shape = s
			"capsule":
				var s := CapsuleShape3D.new()
				s.radius = float(p.get("radius", 0.5))
				s.height = float(p.get("height", 2.0))
				node.shape = s
			"cylinder":
				var s := CylinderShape3D.new()
				s.radius = float(p.get("radius", 0.5))
				s.height = float(p.get("height", 2.0))
				node.shape = s
			_:
				return _err("Forma 3D desconocida: %s (usa box, sphere, capsule o cylinder)" % shape_name)
	else:
		return _err("El nodo debe ser CollisionShape2D o CollisionShape3D")
	return {"node": str(p.get("node")), "shape": shape_name}


func _cmd_create_material(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node")))
	if not (node is GeometryInstance3D):
		return _err("El nodo debe ser un nodo 3D con geometría (p. ej. MeshInstance3D)")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _parse_color(p, "color", Color.WHITE)
	mat.metallic = float(p.get("metallic", 0.0))
	mat.roughness = float(p.get("roughness", 0.7))
	if p.has("emission"):
		mat.emission_enabled = true
		mat.emission = _parse_color(p, "emission", Color.WHITE)
		mat.emission_energy_multiplier = float(p.get("emission_energy", 1.0))
	node.material_override = mat
	return {"node": str(p.get("node")), "color": str(mat.albedo_color)}


func _cmd_setup_environment_3d(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var created: Array = []

	if root.get_node_or_null("WorldEnvironment") == null:
		var we := WorldEnvironment.new()
		we.name = "WorldEnvironment"
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = _parse_color(p, "sky_color", Color(0.38, 0.55, 0.83))
		sky_mat.ground_bottom_color = _parse_color(p, "ground_color", Color(0.2, 0.17, 0.13))
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		if bool(p.get("glow", false)):
			env.glow_enabled = true
		we.environment = env
		root.add_child(we)
		we.owner = root
		created.append("WorldEnvironment")

	if bool(p.get("sun", true)) and root.get_node_or_null("Sol") == null:
		var sun := DirectionalLight3D.new()
		sun.name = "Sol"
		sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		sun.shadow_enabled = true
		root.add_child(sun)
		sun.owner = root
		created.append("Sol (DirectionalLight3D)")

	if bool(p.get("floor", false)):
		var floor_body := StaticBody3D.new()
		floor_body.name = "Suelo"
		root.add_child(floor_body)
		floor_body.owner = root
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "MeshInstance3D"
		var plane := PlaneMesh.new()
		plane.size = Vector2(40.0, 40.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _parse_color(p, "floor_color", Color(0.45, 0.55, 0.4))
		plane.surface_set_material(0, mat)
		mesh_inst.mesh = plane
		floor_body.add_child(mesh_inst)
		mesh_inst.owner = root
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(40.0, 0.2, 40.0)
		col.shape = box
		col.position.y = -0.1
		floor_body.add_child(col)
		col.owner = root
		created.append("Suelo (StaticBody3D con colisión)")

	return {"created": created}


# ---------------------------------------------------------------------------
# Creación de personajes completos
# ---------------------------------------------------------------------------

const SCRIPT_PLATFORMER_2D := """extends CharacterBody2D

@export var speed := 300.0
@export var jump_velocity := -420.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
"""

const SCRIPT_TOPDOWN_2D := """extends CharacterBody2D

@export var speed := 250.0


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity = input * speed
	move_and_slide()
"""

const SCRIPT_FPS_3D := """extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.3, 1.3)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
"""

const SCRIPT_THIRD_PERSON_3D := """extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var spring_arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -1.2, 0.4)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
"""


func _write_script_file(path: String, content: String) -> bool:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(content)
	f.close()
	return true


func _cmd_create_character(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta. Crea o abre una escena primero.")

	var char_name: String = str(p.get("name", "Player"))
	var style: String = str(p.get("style", "platformer"))
	var color := _parse_color(p, "color", Color(0.29, 0.64, 1.0))
	var parent := _resolve_node(str(p.get("parent", ".")))
	if parent == null:
		return _err("No se encontró el nodo padre: %s" % str(p.get("parent")))

	# Registrar acciones de entrada (WASD + flechas + espacio) si no existen
	var actions_created := 0
	if _ensure_input_action("move_left", ["A", "Left"]):
		actions_created += 1
	if _ensure_input_action("move_right", ["D", "Right"]):
		actions_created += 1
	if _ensure_input_action("move_forward", ["W", "Up"]):
		actions_created += 1
	if _ensure_input_action("move_back", ["S", "Down"]):
		actions_created += 1
	if _ensure_input_action("jump", ["Space"], [0]):
		actions_created += 1
	if actions_created > 0:
		ProjectSettings.save()

	var script_template: String
	var body: Node
	var created_nodes: Array = []

	match style:
		"platformer", "topdown":
			script_template = SCRIPT_PLATFORMER_2D if style == "platformer" else SCRIPT_TOPDOWN_2D
			var b := CharacterBody2D.new()
			b.name = char_name
			parent.add_child(b)
			b.owner = root
			body = b

			var poly := Polygon2D.new()
			poly.name = "Cuerpo"
			poly.polygon = PackedVector2Array([
				Vector2(-14, -24), Vector2(14, -24), Vector2(14, 24), Vector2(-14, 24)
			])
			poly.color = color
			b.add_child(poly)
			poly.owner = root
			created_nodes.append("Cuerpo (Polygon2D, reemplázalo por tu Sprite2D)")

			var col := CollisionShape2D.new()
			col.name = "CollisionShape2D"
			var rect := RectangleShape2D.new()
			rect.size = Vector2(28, 48)
			col.shape = rect
			b.add_child(col)
			col.owner = root
			created_nodes.append("CollisionShape2D")

			if bool(p.get("with_camera", true)):
				var cam := Camera2D.new()
				cam.name = "Camera2D"
				cam.position_smoothing_enabled = true
				b.add_child(cam)
				cam.owner = root
				created_nodes.append("Camera2D (con suavizado)")

		"fps", "third_person":
			script_template = SCRIPT_FPS_3D if style == "fps" else SCRIPT_THIRD_PERSON_3D
			var b := CharacterBody3D.new()
			b.name = char_name
			parent.add_child(b)
			b.owner = root
			body = b

			var mesh_inst := MeshInstance3D.new()
			mesh_inst.name = "Cuerpo"
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.4
			capsule.height = 1.8
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			capsule.surface_set_material(0, mat)
			mesh_inst.mesh = capsule
			mesh_inst.position.y = 0.9
			b.add_child(mesh_inst)
			mesh_inst.owner = root
			created_nodes.append("Cuerpo (MeshInstance3D con cápsula)")

			var col := CollisionShape3D.new()
			col.name = "CollisionShape3D"
			var cap_shape := CapsuleShape3D.new()
			cap_shape.radius = 0.4
			cap_shape.height = 1.8
			col.shape = cap_shape
			col.position.y = 0.9
			b.add_child(col)
			col.owner = root
			created_nodes.append("CollisionShape3D")

			if style == "fps":
				var cam := Camera3D.new()
				cam.name = "Camera3D"
				cam.position = Vector3(0, 1.6, 0)
				b.add_child(cam)
				cam.owner = root
				created_nodes.append("Camera3D (primera persona)")
			else:
				var arm := SpringArm3D.new()
				arm.name = "SpringArm3D"
				arm.position = Vector3(0, 1.5, 0)
				arm.spring_length = 4.0
				b.add_child(arm)
				arm.owner = root
				var cam := Camera3D.new()
				cam.name = "Camera3D"
				arm.add_child(cam)
				cam.owner = root
				created_nodes.append("SpringArm3D + Camera3D (tercera persona)")
		_:
			return _err("Estilo desconocido: %s (usa platformer, topdown, fps o third_person)" % style)

	# Crear y adjuntar el script de movimiento
	var script_path: String = str(p.get("script_path", "res://scripts/%s.gd" % char_name.to_snake_case()))
	if not _write_script_file(script_path, script_template):
		return _err("No se pudo escribir el script en %s" % script_path)
	EditorInterface.get_resource_filesystem().scan()
	var script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	if script != null:
		body.set_script(script)
		created_nodes.append("Script adjuntado: %s" % script_path)
	else:
		created_nodes.append("Script creado en %s (adjúntalo con attach_script si no aparece)" % script_path)

	return {
		"character": str(root.get_path_to(body)),
		"style": style,
		"nodes": created_nodes,
		"input_actions": "move_left/right/forward/back + jump (WASD, flechas y espacio)",
		"tip": "Guarda la escena con save_scene y ejecútala con run_scene para probarlo"
	}


# ---------------------------------------------------------------------------
# Animaciones
# ---------------------------------------------------------------------------

func _find_or_create_player(player_path: String) -> AnimationPlayer:
	var root := _get_root()
	if player_path != "":
		var n := _resolve_node(player_path)
		if n is AnimationPlayer:
			return n
		return null
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	return player


func _cmd_create_animation(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var player := _find_or_create_player(str(p.get("player", "")))
	if player == null:
		return _err("El nodo indicado en 'player' no es un AnimationPlayer")

	var anim_name: String = str(p.get("name", "anim"))
	var anim := Animation.new()
	anim.length = float(p.get("length", 1.0))
	anim.loop_mode = Animation.LOOP_LINEAR if bool(p.get("loop", false)) else Animation.LOOP_NONE

	var tracks: Array = p.get("tracks", []) if p.get("tracks") is Array else []
	for track_data in tracks:
		if not (track_data is Dictionary):
			continue
		var idx := anim.add_track(Animation.TYPE_VALUE)
		var node_path: String = str(track_data.get("node", "."))
		var prop: String = str(track_data.get("property", ""))
		anim.track_set_path(idx, NodePath(node_path + ":" + prop))
		var keyframes: Array = track_data.get("keyframes", []) if track_data.get("keyframes") is Array else []
		for kf in keyframes:
			if not (kf is Dictionary):
				continue
			var value = kf.get("value")
			if value is String:
				var parsed = str_to_var(value)
				if parsed != null:
					value = parsed
			anim.track_insert_key(idx, float(kf.get("time", 0.0)), value)

	var lib: AnimationLibrary
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, anim)

	return {
		"animation": anim_name,
		"player": str(root.get_path_to(player)),
		"tracks": anim.get_track_count(),
		"note": "Las rutas de los tracks son relativas al padre del AnimationPlayer"
	}


func _cmd_list_animations(p: Dictionary):
	var player := _find_or_create_player(str(p.get("player", "")))
	if player == null:
		return _err("No se encontró el AnimationPlayer")
	return {"animations": Array(player.get_animation_list())}


func _cmd_play_animation(p: Dictionary):
	var player := _find_or_create_player(str(p.get("player", "")))
	if player == null:
		return _err("No se encontró el AnimationPlayer")
	var anim_name: String = str(p.get("name", ""))
	if not player.has_animation(anim_name):
		return _err("No existe la animación '%s'" % anim_name)
	player.play(anim_name)
	return {"playing": anim_name, "note": "Vista previa en el editor"}


func _cmd_create_sprite_animation(p: Dictionary):
	var node := _resolve_node(str(p.get("node", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("node")))
	if not (node is AnimatedSprite2D):
		return _err("El nodo debe ser un AnimatedSprite2D")

	var tex_path: String = str(p.get("texture", ""))
	var texture = load(tex_path)
	if texture == null or not (texture is Texture2D):
		return _err("No se pudo cargar la textura: %s" % tex_path)

	var hframes := int(p.get("hframes", 1))
	var vframes := int(p.get("vframes", 1))
	if hframes < 1 or vframes < 1:
		return _err("hframes y vframes deben ser al menos 1")
	var fw: float = texture.get_width() / float(hframes)
	var fh: float = texture.get_height() / float(vframes)

	var frames: SpriteFrames = node.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()
		node.sprite_frames = frames

	var anims: Array = p.get("animations", []) if p.get("animations") is Array else []
	var created: Array = []
	for anim_data in anims:
		if not (anim_data is Dictionary):
			continue
		var anim_name: String = str(anim_data.get("name", "default"))
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(anim_data.get("fps", 8.0)))
		frames.set_animation_loop(anim_name, bool(anim_data.get("loop", true)))
		var indices: Array = anim_data.get("frames", []) if anim_data.get("frames") is Array else []
		for i in indices:
			var index := int(i)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			var col_i := index % hframes
			var row_i := floori(index / float(hframes))
			atlas.region = Rect2(col_i * fw, row_i * fh, fw, fh)
			frames.add_frame(anim_name, atlas)
		created.append(anim_name)

	return {"node": str(p.get("node")), "animations": created, "frame_size": "%dx%d" % [int(fw), int(fh)]}


# ---------------------------------------------------------------------------
# Señales, grupos, captura y tiles
# ---------------------------------------------------------------------------

func _cmd_connect_signal(p: Dictionary):
	var from := _resolve_node(str(p.get("from", "")))
	if from == null:
		return _err("No se encontró el nodo emisor: %s" % str(p.get("from")))
	var to := _resolve_node(str(p.get("to", "")))
	if to == null:
		return _err("No se encontró el nodo receptor: %s" % str(p.get("to")))
	var signal_name: String = str(p.get("signal", ""))
	var method: String = str(p.get("method", ""))
	if not from.has_signal(signal_name):
		return _err("El nodo no tiene la señal '%s'. Usa list_signals para verlas." % signal_name)
	var callable := Callable(to, method)
	if from.is_connected(signal_name, callable):
		return _err("La señal ya estaba conectada")
	var err := from.connect(signal_name, callable, CONNECT_PERSIST)
	if err != OK:
		return _err("No se pudo conectar la señal (error %d)" % err)
	return {"connected": "%s.%s → %s.%s" % [str(p.get("from")), signal_name, str(p.get("to")), method],
		"note": "Conexión persistente: se guarda con la escena. Asegúrate de que el método exista en el script receptor."}


func _cmd_list_signals(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path")))
	var signals: Array = []
	for sig in node.get_signal_list():
		var args: Array = []
		for arg in sig["args"]:
			args.append(str(arg["name"]))
		signals.append({"name": sig["name"], "args": args})
	return {"node": str(p.get("path")), "signals": signals}


func _cmd_add_to_group(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path")))
	var group: String = str(p.get("group", ""))
	if group == "":
		return _err("Falta el parámetro 'group'")
	node.add_to_group(group, true)
	return {"node": str(p.get("path")), "group": group}


func _cmd_screenshot(p: Dictionary):
	var which: String = str(p.get("viewport", "3d"))
	var vp: Viewport
	if which == "2d":
		vp = EditorInterface.get_editor_viewport_2d()
	else:
		vp = EditorInterface.get_editor_viewport_3d(0)
	if vp == null:
		return _err("No se pudo acceder al viewport del editor")
	var img := vp.get_texture().get_image()
	if img == null:
		return _err("No se pudo capturar la imagen")
	# Limitar tamaño para no saturar la conexión
	if img.get_width() > 1280:
		var scale := 1280.0 / img.get_width()
		img.resize(1280, int(img.get_height() * scale), Image.INTERPOLATE_BILINEAR)
	var buf := img.save_png_to_buffer()
	return {"image_base64": Marshalls.raw_to_base64(buf), "width": img.get_width(), "height": img.get_height()}


func _cmd_paint_tiles(p: Dictionary):
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path")))
	var source_id := int(p.get("source_id", 0))
	var cells: Array = p.get("cells", []) if p.get("cells") is Array else []
	var painted := 0
	var is_layer := node.is_class("TileMapLayer")
	var is_tilemap := node is TileMap
	if not is_layer and not is_tilemap:
		return _err("El nodo debe ser un TileMapLayer o TileMap con un TileSet asignado")
	var layer := int(p.get("layer", 0))
	for cell in cells:
		if not (cell is Dictionary):
			continue
		var pos := Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))
		var atlas := Vector2i(int(cell.get("atlas_x", 0)), int(cell.get("atlas_y", 0)))
		if is_layer:
			node.set_cell(pos, source_id, atlas)
		else:
			node.set_cell(layer, pos, source_id, atlas)
		painted += 1
	return {"painted": painted, "node": str(p.get("path"))}


# ---------------------------------------------------------------------------
# Assets externos, TileSets, exportación y utilidades avanzadas
# ---------------------------------------------------------------------------

func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)


func _cmd_import_asset(p: Dictionary):
	var source: String = str(p.get("source", ""))
	var dest: String = str(p.get("dest", ""))
	if source == "":
		return _err("Falta el parámetro 'source' (ruta absoluta del archivo en disco)")
	if not FileAccess.file_exists(source):
		return _err("El archivo de origen no existe: %s" % source)
	if dest == "":
		dest = "res://assets/" + source.get_file()
	if not dest.begins_with("res://"):
		return _err("'dest' debe empezar con res://")
	if dest.ends_with("/"):
		dest = dest + source.get_file()
	var dir := dest.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := DirAccess.copy_absolute(source, ProjectSettings.globalize_path(dest))
	if err != OK:
		return _err("No se pudo copiar el archivo (error %d)" % err)
	EditorInterface.get_resource_filesystem().scan()
	return {
		"imported": dest,
		"source": source,
		"note": "Godot importará el recurso automáticamente. Para .glb/.png espera un momento antes de usarlo con assign_resource."
	}


func _cmd_create_tileset(p: Dictionary):
	var tex_path: String = str(p.get("texture", ""))
	var texture = load(tex_path)
	if texture == null or not (texture is Texture2D):
		return _err("No se pudo cargar la textura: %s" % tex_path)
	var tw := int(p.get("tile_width", 16))
	var th := int(p.get("tile_height", 16))
	if tw < 1 or th < 1:
		return _err("tile_width y tile_height deben ser al menos 1")
	var path: String = str(p.get("path", "res://tilesets/tileset.tres"))
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return _err("La ruta debe empezar con res:// y terminar en .tres")

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(tw, th)
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = Vector2i(tw, th)
	var cols := int(texture.get_width() / tw)
	var rows := int(texture.get_height() / th)
	if cols < 1 or rows < 1:
		return _err("La textura (%dx%d) es más pequeña que un tile (%dx%d)" % [texture.get_width(), texture.get_height(), tw, th])
	var tiles_created := 0
	for yy in range(rows):
		for xx in range(cols):
			src.create_tile(Vector2i(xx, yy))
			tiles_created += 1
	var source_id := tileset.add_source(src)

	# Colisiones: todas las celdas o una lista concreta
	var collided := 0
	var coords_list: Array = []
	if bool(p.get("collision_all", false)):
		for yy in range(rows):
			for xx in range(cols):
				coords_list.append(Vector2i(xx, yy))
	elif p.get("collision_tiles") is Array:
		for c in p["collision_tiles"]:
			if c is Dictionary:
				coords_list.append(Vector2i(int(c.get("x", 0)), int(c.get("y", 0))))
	if not coords_list.is_empty():
		tileset.add_physics_layer()
		var half := Vector2(tw / 2.0, th / 2.0)
		var rect := PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)
		])
		for coords in coords_list:
			var td := src.get_tile_data(coords, 0)
			if td == null:
				continue
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, rect)
			collided += 1

	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := ResourceSaver.save(tileset, path)
	if err != OK:
		return _err("No se pudo guardar el TileSet (error %d)" % err)
	EditorInterface.get_resource_filesystem().scan()

	var result := {
		"tileset": path,
		"source_id": source_id,
		"tiles": tiles_created,
		"grid": "%dx%d" % [cols, rows],
		"collision_tiles": collided
	}
	var node_path: String = str(p.get("assign_to", ""))
	if node_path != "":
		var node := _resolve_node(node_path)
		if node != null and ("tile_set" in node):
			node.tile_set = tileset
			result["assigned_to"] = node_path
		else:
			result["assign_warning"] = "No se encontró un TileMapLayer/TileMap en '%s'" % node_path
	return result


func _cmd_export_project(p: Dictionary):
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return _err("No existe export_presets.cfg. Configura al menos un preset en Proyecto → Exportar (y descarga las plantillas de exportación si faltan).")
	var cfg := ConfigFile.new()
	if cfg.load(presets_path) != OK:
		return _err("No se pudo leer export_presets.cfg")
	var presets: Array = []
	for section in cfg.get_sections():
		if not section.contains("."):
			presets.append({
				"name": str(cfg.get_value(section, "name", "")),
				"platform": str(cfg.get_value(section, "platform", ""))
			})
	var preset_name: String = str(p.get("preset", ""))
	if preset_name == "":
		return {"presets": presets, "note": "Indica 'preset' y 'output' para exportar"}
	var found := false
	for pr in presets:
		if pr["name"] == preset_name:
			found = true
	if not found:
		return _err("Preset '%s' no encontrado. Disponibles: %s" % [preset_name, JSON.stringify(presets)])
	var output: String = str(p.get("output", ""))
	if output == "":
		return _err("Falta 'output' (ruta del ejecutable a generar, p. ej. res://build/juego.exe)")
	var out_abs := ProjectSettings.globalize_path(output) if output.begins_with("res://") else output
	var out_dir := out_abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)

	# Guardar todo antes de exportar para que el binario incluya el estado actual
	ProjectSettings.save()
	EditorInterface.save_all_scenes()

	var flag := "--export-debug" if bool(p.get("debug", false)) else "--export-release"
	var exe := OS.get_executable_path()
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), flag, preset_name, out_abs]
	var out: Array = []
	var code := OS.execute(exe, args, out, true)
	var log_text := ""
	for line in out:
		log_text += str(line)
	if code != 0:
		return _err("Exportación falló (código %d). Últimas líneas del log: %s" % [code, log_text.right(1500)])
	return {"exported": out_abs, "preset": preset_name, "log_tail": log_text.right(500)}


func _cmd_create_shader(p: Dictionary):
	var path: String = str(p.get("path", ""))
	var code: String = str(p.get("code", ""))
	if not path.begins_with("res://") or not path.ends_with(".gdshader"):
		return _err("La ruta debe empezar con res:// y terminar en .gdshader")
	if code.strip_edges() == "":
		return _err("Falta el parámetro 'code' (código del shader, debe incluir shader_type)")
	if not _write_script_file(path, code):
		return _err("No se pudo escribir: %s" % path)
	EditorInterface.get_resource_filesystem().scan()
	var shader = ResourceLoader.load(path, "Shader", ResourceLoader.CACHE_MODE_REPLACE)
	if shader == null:
		return _err("No se pudo cargar el shader. Revisa la sintaxis (¿falta 'shader_type canvas_item;' o 'shader_type spatial;'?)")
	var result := {"shader": path}
	var node_path: String = str(p.get("node", ""))
	if node_path != "":
		var node := _resolve_node(node_path)
		if node == null:
			return _err("No se encontró el nodo: %s" % node_path)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = p.get("parameters", {}) if p.get("parameters") is Dictionary else {}
		for key in params:
			var v = params[key]
			if v is String:
				var parsed = str_to_var(v)
				if parsed != null:
					v = parsed
			mat.set_shader_parameter(str(key), v)
		if node is GeometryInstance3D:
			node.material_override = mat
		elif node is CanvasItem:
			node.material = mat
		else:
			return _err("El nodo debe ser CanvasItem (2D) o GeometryInstance3D (3D)")
		result["assigned_to"] = node_path
	return result


func _cmd_duplicate_node(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var node := _resolve_node(str(p.get("path", "")))
	if node == null:
		return _err("No se encontró el nodo: %s" % str(p.get("path", "")))
	if node == root:
		return _err("No se puede duplicar el nodo raíz")
	var count := int(p.get("count", 1))
	if count < 1 or count > 200:
		return _err("'count' debe estar entre 1 y 200")
	var offset = null
	if p.get("offset") is String:
		offset = str_to_var(str(p["offset"]))
	var parent := node.get_parent()
	if p.has("parent"):
		parent = _resolve_node(str(p["parent"]))
		if parent == null:
			return _err("No se encontró el nodo padre: %s" % str(p.get("parent")))
	var base_name: String = str(p.get("name", node.name))
	var created: Array = []
	for i in range(count):
		var dup := node.duplicate()
		dup.name = base_name
		parent.add_child(dup, true)
		_set_owner_recursive(dup, root)
		if offset != null and ("position" in dup):
			dup.position = node.position + offset * (i + 1)
		created.append(str(root.get_path_to(dup)))
	return {"duplicated": created, "count": created.size()}


func _cmd_find_nodes(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var type_filter: String = str(p.get("type", ""))
	var group: String = str(p.get("group", ""))
	var name_contains: String = str(p.get("name_contains", "")).to_lower()
	if type_filter == "" and group == "" and name_contains == "":
		return _err("Indica al menos un filtro: 'type', 'group' o 'name_contains'")
	var results: Array = []
	_find_walk(root, root, type_filter, group, name_contains, results)
	return {"count": results.size(), "nodes": results}


func _find_walk(node: Node, root: Node, type_filter: String, group: String, name_contains: String, out: Array) -> void:
	var matches := true
	if type_filter != "" and not node.is_class(type_filter):
		matches = false
	if group != "" and not node.is_in_group(group):
		matches = false
	if name_contains != "" and not node.name.to_lower().contains(name_contains):
		matches = false
	if matches:
		out.append({
			"path": "." if node == root else str(root.get_path_to(node)),
			"type": node.get_class(),
			"name": str(node.name)
		})
	for child in node.get_children():
		_find_walk(child, root, type_filter, group, name_contains, out)


func _cmd_set_physics_layers(p: Dictionary):
	var dim: String = str(p.get("dimension", "3d"))
	if dim != "2d" and dim != "3d":
		return _err("'dimension' debe ser '2d' o '3d'")
	var named: Array = []
	var names: Dictionary = p.get("names", {}) if p.get("names") is Dictionary else {}
	for key in names:
		var num := int(str(key))
		if num < 1 or num > 32:
			continue
		ProjectSettings.set_setting("layer_names/%s_physics/layer_%d" % [dim, num], str(names[key]))
		named.append("%d=%s" % [num, str(names[key])])
	if not names.is_empty():
		ProjectSettings.save()

	var result := {"dimension": dim, "named_layers": named}
	var node_path: String = str(p.get("node", ""))
	if node_path != "":
		var node := _resolve_node(node_path)
		if node == null:
			return _err("No se encontró el nodo: %s" % node_path)
		if not ("collision_layer" in node):
			return _err("El nodo '%s' no tiene collision_layer (debe ser CollisionObject2D/3D, TileMapLayer, etc.)" % node_path)
		if p.get("layer") is Array:
			var layer_bits := 0
			for l in p["layer"]:
				var n := int(l)
				if n >= 1 and n <= 32:
					layer_bits |= 1 << (n - 1)
			node.collision_layer = layer_bits
			result["collision_layer"] = layer_bits
		if p.get("mask") is Array:
			var mask_bits := 0
			for l in p["mask"]:
				var n := int(l)
				if n >= 1 and n <= 32:
					mask_bits |= 1 << (n - 1)
			node.collision_mask = mask_bits
			result["collision_mask"] = mask_bits
		result["node"] = node_path
	return result


func _cmd_create_nav_region(p: Dictionary):
	var root := _get_root()
	if root == null:
		return _err("No hay ninguna escena abierta")
	var parent := _resolve_node(str(p.get("parent", ".")))
	if parent == null:
		return _err("No se encontró el nodo padre: %s" % str(p.get("parent")))
	var region := NavigationRegion3D.new()
	region.name = str(p.get("name", "NavRegion"))
	parent.add_child(region)
	region.owner = root

	var navmesh := NavigationMesh.new()
	var group: String = str(p.get("source_group", "nav_source"))
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = group
	navmesh.agent_radius = float(p.get("agent_radius", 0.5))
	navmesh.agent_height = float(p.get("agent_height", 1.8))
	navmesh.cell_size = float(p.get("cell_size", 0.25))
	region.navigation_mesh = navmesh

	var added: Array = []
	var nodes: Array = p.get("nodes", []) if p.get("nodes") is Array else []
	for np in nodes:
		var n := _resolve_node(str(np))
		if n != null:
			n.add_to_group(group, true)
			added.append(str(np))

	var polygons := 0
	if bool(p.get("bake", true)):
		region.bake_navigation_mesh(false)
		polygons = region.navigation_mesh.get_polygon_count()

	return {
		"region": str(root.get_path_to(region)),
		"source_group": group,
		"nodes_in_group": added,
		"polygons": polygons,
		"note": "Los nodos del grupo '%s' aportan geometría. Re-hornea con bake si cambias el nivel." % group
	}
