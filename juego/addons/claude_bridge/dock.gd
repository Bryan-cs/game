@tool
extends PanelContainer
## Panel visual de Claude Bridge. Muestra el estado de la conexión,
## permite iniciar/detener el servidor y registra toda la actividad.

const CONFIG_PATH := "user://claude_bridge.cfg"

const COLOR_BG := Color("1a1d23")
const COLOR_CARD := Color("232730")
const COLOR_ACCENT := Color("d97757")
const COLOR_OK := Color("6bcb77")
const COLOR_ERR := Color("e5484d")
const COLOR_TEXT := Color("e8eaed")
const COLOR_DIM := Color("9aa0a6")

var _server  # BridgeServer

var _status_dot: ColorRect
var _status_label: Label
var _clients_label: Label
var _commands_label: Label
var _port_spin: SpinBox
var _toggle_btn: Button
var _log: RichTextLabel
var _copy_btn: Button


func setup(server) -> void:
	_server = server
	_build_ui()
	_server.log_message.connect(_on_log)
	_server.status_changed.connect(_on_status)
	_server.client_count_changed.connect(_on_clients)


func get_saved_port() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		return int(cfg.get_value("bridge", "port", 9080))
	return 9080


func _save_port(port: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bridge", "port", port)
	cfg.save(CONFIG_PATH)


func _build_ui() -> void:
	custom_minimum_size = Vector2(260, 380)

	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_BG
	bg.set_content_margin_all(12)
	add_theme_stylebox_override("panel", bg)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	add_child(main)

	# --- Encabezado -------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)

	var title := Label.new()
	title.text = "Claude Bridge"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(10, 10)
	_status_dot.color = COLOR_ERR
	var dot_wrap := CenterContainer.new()
	dot_wrap.add_child(_status_dot)
	header.add_child(dot_wrap)

	_status_label = Label.new()
	_status_label.text = "Detenido"
	_status_label.add_theme_color_override("font_color", COLOR_DIM)
	_status_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_status_label)

	# --- Tarjeta de control ----------------------------------------------
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	main.add_child(card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)

	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	card_box.add_child(port_row)

	var port_label := Label.new()
	port_label.text = "Puerto"
	port_label.add_theme_color_override("font_color", COLOR_DIM)
	port_label.add_theme_font_size_override("font_size", 12)
	port_row.add_child(port_label)

	_port_spin = SpinBox.new()
	_port_spin.min_value = 1024
	_port_spin.max_value = 65535
	_port_spin.value = get_saved_port()
	_port_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port_spin)

	_toggle_btn = Button.new()
	_toggle_btn.text = "Detener servidor"
	_toggle_btn.pressed.connect(_on_toggle)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_ACCENT
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	_toggle_btn.add_theme_color_override("font_color", Color.WHITE)
	card_box.add_child(_toggle_btn)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	card_box.add_child(stats)

	_clients_label = Label.new()
	_clients_label.text = "● 0 clientes"
	_clients_label.add_theme_color_override("font_color", COLOR_DIM)
	_clients_label.add_theme_font_size_override("font_size", 12)
	stats.add_child(_clients_label)

	_commands_label = Label.new()
	_commands_label.text = "0 comandos"
	_commands_label.add_theme_color_override("font_color", COLOR_DIM)
	_commands_label.add_theme_font_size_override("font_size", 12)
	stats.add_child(_commands_label)

	# --- Registro de actividad -------------------------------------------
	var log_label := Label.new()
	log_label.text = "ACTIVIDAD"
	log_label.add_theme_color_override("font_color", COLOR_DIM)
	log_label.add_theme_font_size_override("font_size", 10)
	main.add_child(log_label)

	var log_panel := PanelContainer.new()
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color("14161b")
	log_style.set_corner_radius_all(8)
	log_style.set_content_margin_all(8)
	log_panel.add_theme_stylebox_override("panel", log_style)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(log_panel)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(_log)

	# --- Ayuda de conexión ------------------------------------------------
	_copy_btn = Button.new()
	_copy_btn.text = "Copiar comando de instalación"
	_copy_btn.tooltip_text = "Copia el comando 'claude mcp add' para pegarlo en tu terminal"
	_copy_btn.pressed.connect(_on_copy)
	main.add_child(_copy_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Limpiar registro"
	clear_btn.flat = true
	clear_btn.add_theme_color_override("font_color", COLOR_DIM)
	clear_btn.pressed.connect(func(): _log.clear())
	main.add_child(clear_btn)


func _on_toggle() -> void:
	if _server.is_running():
		_server.stop()
	else:
		var port := int(_port_spin.value)
		_save_port(port)
		_server.start(port)


func _on_status(running: bool, port: int) -> void:
	_status_dot.color = COLOR_OK if running else COLOR_ERR
	_status_label.text = ("Activo :%d" % port) if running else "Detenido"
	_status_label.add_theme_color_override("font_color", COLOR_OK if running else COLOR_DIM)
	_toggle_btn.text = "Detener servidor" if running else "Iniciar servidor"
	_port_spin.editable = not running


func _on_clients(count: int) -> void:
	_clients_label.text = "● %d cliente%s" % [count, "" if count == 1 else "s"]
	_clients_label.add_theme_color_override("font_color", COLOR_OK if count > 0 else COLOR_DIM)


func _on_log(text: String, kind: String) -> void:
	var time := Time.get_time_string_from_system()
	var color: Color
	match kind:
		"ok": color = COLOR_OK
		"error": color = COLOR_ERR
		"cmd": color = COLOR_ACCENT
		_: color = COLOR_DIM
	_log.append_text("[color=#5f6368]%s[/color]  [color=#%s]%s[/color]\n" % [time, color.to_html(false), text])
	_commands_label.text = "%d comandos" % _server.commands_handled


func _on_copy() -> void:
	var cmd := "claude mcp add godot -- node RUTA/A/godot-claude-mcp/server/index.js"
	DisplayServer.clipboard_set(cmd)
	_on_log.call("Comando copiado. Reemplaza RUTA/A con la ubicación real.", "info")
