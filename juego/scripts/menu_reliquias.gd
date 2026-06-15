extends CanvasLayer
## Menú de Reliquias de Run: oferta (1 de 3) y modo intercambio (máx 3 activas).

signal reliquia_elegida(id: String)
signal intercambio_decidido(nueva_id: String, vieja_id: String)  # vieja_id="" = rechazar

var _botones: VBoxContainer
var _titulo: Label
var _subtitulo: Label


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.68)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(_titulo, 22)
	caja.add_child(_titulo)
	_subtitulo = Label.new()
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.add_theme_font_size_override("font_size", 14)
	_subtitulo.add_theme_color_override("font_color", Color(0.65, 0.55, 0.85))
	_subtitulo.visible = false
	caja.add_child(_subtitulo)
	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 10)
	caja.add_child(_botones)


func mostrar_oferta(opciones: Array) -> void:
	_titulo.text = "✦ RELIQUIA DE RUN — Elige una"
	_subtitulo.visible = false
	_limpiar_botones()
	for opcion in opciones:
		var id: String = opcion.id
		var boton := _crear_boton(
			"[%s]  %s — %s" % [opcion.tipo, opcion.nombre, opcion.desc],
			opcion.color
		)
		boton.pressed.connect(func() -> void:
			visible = false
			reliquia_elegida.emit(id)
		)
		_botones.add_child(boton)
	visible = true
	get_tree().paused = true


func mostrar_intercambio(nueva_id: String, actuales: Array) -> void:
	var nueva: Dictionary = Reliquias.CATALOGO[nueva_id]
	_titulo.text = "LLEVAS 3 RELIQUIAS"
	_subtitulo.text = "Nueva: [%s]  %s — %s\n¿Cuál reemplazas?" % [nueva.tipo, nueva.nombre, nueva.desc]
	_subtitulo.add_theme_color_override("font_color", nueva.color)
	_subtitulo.visible = true
	_limpiar_botones()
	for vieja_id in actuales:
		var vieja: Dictionary = Reliquias.CATALOGO[vieja_id]
		var vid: String = vieja_id
		var nid: String = nueva_id
		var boton := _crear_boton(
			"Cambiar  [%s]  %s — %s" % [vieja.tipo, vieja.nombre, vieja.desc],
			vieja.color
		)
		boton.pressed.connect(func() -> void:
			visible = false
			intercambio_decidido.emit(nid, vid)
		)
		_botones.add_child(boton)
	var nid2: String = nueva_id
	var btn_rechazar := _crear_boton("✕  Rechazar — no cambiar nada", Color(0.5, 0.5, 0.5))
	btn_rechazar.pressed.connect(func() -> void:
		visible = false
		intercambio_decidido.emit(nid2, "")
	)
	_botones.add_child(btn_rechazar)
	visible = true


func _limpiar_botones() -> void:
	for hijo in _botones.get_children():
		hijo.queue_free()


func _crear_boton(texto: String, color: Color) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(520, 52)
	boton.text = texto
	boton.add_theme_color_override("font_color", color)
	boton.add_theme_font_size_override("font_size", 16)
	return boton
