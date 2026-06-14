@tool
extends RefCounted
## Base para módulos portados de godot-mcp-pro.
## Fuente original: base_command.gd de github.com/blasdecrespo/godot-mcp-ck
## (licencia MIT, Copyright (c) 2026 Youichi Uda). Adaptaciones:
## - extends RefCounted (no Node) y sin dependencia de editor_plugin.
## - handles()/dispatch() para el patrón de módulos del bridge.
## - dispatch() traduce {result}/{error} del original a dict plano / {"__error"}.
## - get_editor() usa el singleton EditorInterface (Godot 4.2+).
## - Omitidos get_undo_redo() y get_game_user_dir() (no usados en Fase 2).


## Override en subclases: {"nombre_comando": Callable}
func get_commands() -> Dictionary:
	return {}


func handles(command: String) -> bool:
	return get_commands().has(command)


func dispatch(command: String, p: Dictionary):
	var commands := get_commands()
	if not commands.has(command):
		return {"__error": "Comando desconocido: %s" % command}
	var out = commands[command].call(p)
	if out is Dictionary and out.has("error"):
		var e: Dictionary = out["error"]
		var msg := str(e.get("message", "error"))
		var data: Dictionary = e.get("data", {})
		if data.has("suggestion"):
			msg += ". " + str(data["suggestion"])
		return {"__error": msg}
	if out is Dictionary and out.has("result"):
		return out["result"]
	return out


## --- Helpers idénticos en firma al base_command.gd original ---

func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene() -> Dictionary:
	return error(-32000, "No scene is currently open", {"suggestion": "Use open_scene to open a scene first"})


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if params.has(key):
		return int(params[key])
	return default


func get_editor():
	return EditorInterface


func get_edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	if root.has_node(node_path):
		return root.get_node(node_path)
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
