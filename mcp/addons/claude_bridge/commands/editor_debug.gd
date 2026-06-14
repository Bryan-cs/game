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
		if new_parent == node or node.is_ancestor_of(new_parent):
			return _err("No se puede mover un nodo dentro de sí mismo")
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
