extends CanvasLayer
## Tienda de skins (auras) y pase de temporada (GDD sec. 18).
## Monetización real (compras/anuncios) pendiente de SDKs de tienda — aquí todo es con oro.

signal cerrado

var _estado: Node
var _caja: VBoxContainer
var _oro: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_estado = get_node(^"/root/Estado")
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.7)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var contenedor := VBoxContainer.new()
	contenedor.add_theme_constant_override("separation", 10)
	panel.add_child(contenedor)
	var titulo := Label.new()
	titulo.text = "TIENDA · PASE DE TEMPORADA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 26)
	contenedor.add_child(titulo)
	_oro = Label.new()
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	contenedor.add_child(_oro)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 430)
	contenedor.add_child(scroll)
	_caja = VBoxContainer.new()
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja.add_theme_constant_override("separation", 6)
	scroll.add_child(_caja)
	var volver := Button.new()
	volver.text = "VOLVER"
	volver.pressed.connect(func() -> void:
		visible = false
		cerrado.emit())
	contenedor.add_child(volver)


func abrir() -> void:
	_reconstruir()
	visible = true


func _seccion(texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 19)
	etiqueta.add_theme_color_override("font_color", Color(0.72, 0.55, 1.0))
	_caja.add_child(etiqueta)


func _reconstruir() -> void:
	for hijo in _caja.get_children():
		hijo.queue_free()
	_oro.text = "Oro: %d" % _estado.oro_total

	_seccion("MONEDAS — acelera tu progreso")
	# TODO monetización real: conectar con Google Play Billing / App Store al exportar
	for paquete in [[1000, "$0.99"], [5500, "$3.99"], [12000, "$6.99"]]:
		var fila_oro := HBoxContainer.new()
		fila_oro.add_theme_constant_override("separation", 10)
		var etiqueta_oro := Label.new()
		etiqueta_oro.text = "%d de oro" % paquete[0]
		etiqueta_oro.custom_minimum_size = Vector2(220, 0)
		etiqueta_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		fila_oro.add_child(etiqueta_oro)
		var boton_oro := Button.new()
		boton_oro.custom_minimum_size = Vector2(190, 36)
		boton_oro.add_theme_font_size_override("font_size", 13)
		boton_oro.text = "%s · PRÓXIMAMENTE" % paquete[1]
		boton_oro.disabled = true
		fila_oro.add_child(boton_oro)
		_caja.add_child(fila_oro)

	_seccion("SKINS — AURAS")
	for id in _estado.SKINS:
		var datos: Dictionary = _estado.SKINS[id]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		var nombre := Label.new()
		nombre.text = datos.nombre
		nombre.custom_minimum_size = Vector2(220, 0)
		if id != "ninguna":
			nombre.add_theme_color_override("font_color", datos.color)
		fila.add_child(nombre)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(190, 36)
		boton.add_theme_font_size_override("font_size", 13)
		if id == _estado.skin_activa:
			boton.text = "EQUIPADA"
			boton.disabled = true
		elif id in _estado.skins_desbloqueadas:
			boton.text = "EQUIPAR"
			boton.pressed.connect(func() -> void:
				_estado.equipar_skin(id)
				_reconstruir())
		elif int(datos.precio) < 0:
			boton.text = "PASE DE TEMPORADA"
			boton.disabled = true
		else:
			boton.text = "COMPRAR · %d oro" % int(datos.precio)
			boton.pressed.connect(func() -> void:
				if _estado.comprar_skin(id):
					_estado.equipar_skin(id)
				_reconstruir())
		fila.add_child(boton)
		_caja.add_child(fila)

	_seccion("PASE DE TEMPORADA — Nivel %d  (XP: %d)" % [_estado.pase_nivel_actual(), _estado.pase_xp])
	var nota := Label.new()
	nota.text = "Ganas XP del pase con cada oro obtenido en partida."
	nota.add_theme_font_size_override("font_size", 12)
	nota.add_theme_color_override("font_color", Color(0.55, 0.53, 0.68))
	_caja.add_child(nota)
	for i in _estado.PASE_NIVELES.size():
		var datos: Dictionary = _estado.PASE_NIVELES[i]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		var etiqueta := Label.new()
		etiqueta.text = "Nv %d (%d XP) — %s" % [i + 1, int(datos.xp), datos.nombre]
		etiqueta.custom_minimum_size = Vector2(300, 0)
		fila.add_child(etiqueta)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(140, 34)
		boton.add_theme_font_size_override("font_size", 13)
		if i in _estado.pase_reclamados:
			boton.text = "✓ RECLAMADO"
			boton.disabled = true
		elif _estado.pase_xp >= int(datos.xp):
			boton.text = "RECLAMAR"
			boton.pressed.connect(func() -> void:
				_estado.pase_reclamar(i)
				_reconstruir())
		else:
			boton.text = "BLOQUEADO"
			boton.disabled = true
		fila.add_child(boton)
		_caja.add_child(fila)
