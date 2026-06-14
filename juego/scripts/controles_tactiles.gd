extends CanvasLayer
## Controles táctiles para Android/iOS: joystick virtual + botones de acción.
## Tamaños y posiciones ADAPTATIVOS al viewport (porcentajes, no píxeles fijos).
## Los botones de habilidad aparecen dinámicamente al aprenderlas.

var jugador: Jugador
var vector := Vector3.ZERO

var _id_dedo := -1
var _centro := Vector2.ZERO
var _base: Panel
var _punta: Panel
var _botones_hab := {}
var _contenedor_botones: Control


func _ready() -> void:
	layer = 15
	_construir()
	get_viewport().size_changed.connect(_construir)


func _construir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_botones_hab = {}
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var unidad := clampf(minf(pantalla.x, pantalla.y) * 0.16, 80.0, 170.0)

	_base = _circulo(Color(1, 1, 1, 0.12), unidad * 1.5)
	_base.position = Vector2(pantalla.x * 0.06, pantalla.y - unidad * 1.5 - pantalla.y * 0.06)
	add_child(_base)
	_punta = _circulo(Color(1, 1, 1, 0.25), unidad * 0.6)
	_punta.position = Vector2.ONE * unidad * 0.45
	_base.add_child(_punta)

	_contenedor_botones = Control.new()
	_contenedor_botones.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contenedor_botones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contenedor_botones)

	# Arco de botones abajo-derecha: NOVA y DASH fijos + habilidades dinámicas
	_boton_accion("NOVA", Color(0.25, 0.8, 0.95), 0, func() -> void:
		if jugador:
			jugador.intentar_nova())
	_boton_accion("DASH", Color(0.35, 0.9, 0.45), 1, func() -> void:
		if jugador:
			jugador.intentar_dash())
	refrescar_habilidades()


func refrescar_habilidades() -> void:
	if jugador == null or _contenedor_botones == null:
		return
	var lista: Array = jugador.activas()
	for i in lista.size():
		var hab: Dictionary = lista[i]
		if jugador.nivel_habilidad(hab.id) > 0 and not _botones_hab.has(hab.id):
			var indice_slot: int = i
			_botones_hab[hab.id] = _boton_accion(String(hab.nombre).left(8).to_upper(), Color(1.0, 0.6, 0.2) if i == 0 else Color(0.85, 0.4, 1.0), 2 + i, func() -> void:
				if jugador:
					jugador.intentar_habilidad(indice_slot))


func _boton_accion(texto: String, color: Color, indice: int, accion: Callable) -> Button:
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var unidad := clampf(minf(pantalla.x, pantalla.y) * 0.16, 80.0, 170.0)
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(unidad, unidad)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(color.r, color.g, color.b, 0.25)
	estilo.set_corner_radius_all(int(unidad / 2.0))
	boton.add_theme_stylebox_override("normal", estilo)
	var estilo_pulsado := StyleBoxFlat.new()
	estilo_pulsado.bg_color = Color(color.r, color.g, color.b, 0.55)
	estilo_pulsado.set_corner_radius_all(int(unidad / 2.0))
	boton.add_theme_stylebox_override("pressed", estilo_pulsado)
	boton.add_theme_color_override("font_color", color.lightened(0.4))
	boton.add_theme_font_size_override("font_size", int(unidad * 0.18))
	# Arco alrededor de la esquina inferior derecha
	var angulo := PI * 0.5 + indice * 0.55
	var radio := unidad * 1.9
	var ancla := Vector2(pantalla.x - pantalla.x * 0.05, pantalla.y - pantalla.y * 0.07)
	boton.position = ancla - Vector2(cos(angulo - PI * 0.5), sin(angulo - PI * 0.5)) * radio - Vector2.ONE * unidad * 0.5
	boton.pressed.connect(accion)
	_contenedor_botones.add_child(boton)
	return boton


func _circulo(color: Color, diametro: float) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(diametro, diametro)
	panel.size = Vector2(diametro, diametro)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(int(diametro / 2.0))
	panel.add_theme_stylebox_override("panel", estilo)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _input(evento: InputEvent) -> void:
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var unidad := clampf(minf(pantalla.x, pantalla.y) * 0.16, 80.0, 170.0)
	var radio_joy := unidad * 0.75
	if evento is InputEventScreenTouch:
		if evento.pressed and evento.position.x < pantalla.x * 0.45 and _id_dedo == -1:
			_id_dedo = evento.index
			_centro = evento.position
		elif not evento.pressed and evento.index == _id_dedo:
			_id_dedo = -1
			vector = Vector3.ZERO
			_punta.position = Vector2.ONE * unidad * 0.45
	elif evento is InputEventScreenDrag and evento.index == _id_dedo:
		var desplazamiento: Vector2 = (evento.position - _centro).limit_length(radio_joy)
		vector = Vector3(desplazamiento.x, 0.0, desplazamiento.y) / radio_joy
		_punta.position = Vector2.ONE * unidad * 0.45 + desplazamiento * 0.6
