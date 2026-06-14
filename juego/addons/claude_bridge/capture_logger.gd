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
