extends Control
## Lobby: menú principal con preview 3D del personaje a la izquierda.
## El personaje se gira arrastrando con mouse o touch; al soltar vuelve al centro.

const MenuAjustesScript    := preload("res://scripts/menu_ajustes.gd")
const MenuMisionesScript   := preload("res://scripts/menu_misiones.gd")
const MenuTiendaScript     := preload("res://scripts/menu_tienda.gd")
const MenuInventarioScript := preload("res://scripts/menu_inventario.gd")
const MenuCofresScript     := preload("res://scripts/menu_cofres.gd")
const SonidoScript         := preload("res://scripts/sonido.gd")

const CLASES := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]
const _SENS  := 0.008   # radianes por píxel de arrastre
const _UMBRAL_RETORNO := 0.04  # ángulo mínimo para disparar la animación de vuelta

var _ajustes: CanvasLayer
var _misiones: CanvasLayer
var _tienda: CanvasLayer
var _inventario: CanvasLayer
var _cofres: CanvasLayer
@onready var _estado: Node = get_node(^"/root/Estado")

var _pivote_pj: Node3D
var _lbl_clase: Label
var _clase := "guerrero"

var _arrastrando  := false
var _tween_retorno: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = EstiloUI.tema()

	# Fondo degradado
	var fondo := TextureRect.new()
	var degradado := Gradient.new()
	degradado.colors = PackedColorArray([Color(0.10, 0.06, 0.20), Color(0.015, 0.015, 0.045)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	fondo.texture = textura
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	EstiloUI.luna_sangre(self)
	var brasas := EstiloUI.brasas(self, 46)
	brasas.position = Vector2(960, 1120)

	# Layout principal: izquierda (opciones lobby) | derecha (personaje)
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	# === DERECHA: viewport + overlay de arrastre (se añade al final) ===
	var panel_izq := VBoxContainer.new()
	panel_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_izq.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_izq.add_theme_constant_override("separation", 10)

	# Contenedor que apila el viewport y el overlay uno encima del otro
	var pila := Control.new()
	pila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pila.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pila.custom_minimum_size = Vector2(0, 500)
	panel_izq.add_child(pila)

	var cont_vp := SubViewportContainer.new()
	cont_vp.stretch = false
	cont_vp.anchor_left   = 0.5
	cont_vp.anchor_right  = 0.5
	cont_vp.anchor_top    = 0.0
	cont_vp.anchor_bottom = 1.0
	cont_vp.offset_left   = -350.0
	cont_vp.offset_right  =  350.0
	cont_vp.offset_top    =    0.0
	cont_vp.offset_bottom =    0.0
	pila.add_child(cont_vp)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(700, 490)
	cont_vp.add_child(vp)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 40, 0)
	luz.light_energy = 1.3
	vp.add_child(luz)

	_pivote_pj = Node3D.new()
	vp.add_child(_pivote_pj)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 4.0)
	cam.fov = 52.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)

	# Overlay transparente que captura el drag sin tapar el render
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pila.add_child(overlay)
	overlay.gui_input.connect(_al_input_pj)

	# Flechas para ciclar clase (debajo del viewport)
	var fila_clase := HBoxContainer.new()
	fila_clase.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_izq.add_child(fila_clase)

	var b_prev := Button.new()
	b_prev.text = "◀"
	b_prev.pressed.connect(func() -> void: _ciclar_clase(-1))
	fila_clase.add_child(b_prev)

	_lbl_clase = Label.new()
	_lbl_clase.custom_minimum_size = Vector2(160, 0)
	_lbl_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_clase.add_theme_font_size_override("font_size", 20)
	fila_clase.add_child(_lbl_clase)

	var b_next := Button.new()
	b_next.text = "▶"
	b_next.pressed.connect(func() -> void: _ciclar_clase(1))
	fila_clase.add_child(b_next)

	# === IZQUIERDA: botones del lobby (se añade primero al layout) ===
	var margen_opciones := MarginContainer.new()
	margen_opciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen_opciones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen_opciones.add_theme_constant_override("margin_left", 40)
	layout.add_child(margen_opciones)
	var panel_der := CenterContainer.new()
	panel_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen_opciones.add_child(panel_der)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel_der.add_child(caja)

	var subtitulo_juego := Label.new()
	subtitulo_juego.text = "NIGHTFALL SURVIVORS"
	subtitulo_juego.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo_juego.add_theme_font_size_override("font_size", 18)
	subtitulo_juego.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	caja.add_child(subtitulo_juego)

	var titulo := Label.new()
	titulo.text = "LOBBY"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 58)
	caja.add_child(titulo)

	var oro := Label.new()
	oro.text = "Oro total: %d" % _estado.oro_total
	oro.add_theme_font_size_override("font_size", 18)
	oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(oro)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 12)
	caja.add_child(sep)

	_boton(caja, "JUGAR", _al_jugar)
	_boton(caja, "INVENTARIO", func() -> void: _inventario.abrir())
	_boton(caja, "COFRES", func() -> void: _cofres.abrir())
	_boton(caja, "MISIONES", func() -> void: _misiones.abrir())
	_boton(caja, "TIENDA · PASE", func() -> void: _tienda.abrir())
	_boton(caja, "AJUSTES", _al_ajustes)
	_boton(caja, "SALIR", _al_salir)

	# Personaje pegado al borde derecho
	var margen_pj := MarginContainer.new()
	margen_pj.add_theme_constant_override("margin_left", 220)
	margen_pj.add_theme_constant_override("margin_right", 40)
	margen_pj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen_pj.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen_pj.add_child(panel_izq)
	layout.add_child(margen_pj)

	EstiloUI.vineta(self)

	var version := Label.new()
	version.text = "MVP · Godot 4.6"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.38, 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -130.0
	version.offset_top = -28.0
	add_child(version)

	_ajustes = CanvasLayer.new()
	_ajustes.set_script(MenuAjustesScript)
	add_child(_ajustes)
	_misiones = CanvasLayer.new()
	_misiones.set_script(MenuMisionesScript)
	add_child(_misiones)
	_tienda = CanvasLayer.new()
	_tienda.set_script(MenuTiendaScript)
	add_child(_tienda)
	_inventario = CanvasLayer.new()
	_inventario.set_script(MenuInventarioScript)
	add_child(_inventario)
	_cofres = CanvasLayer.new()
	_cofres.set_script(MenuCofresScript)
	add_child(_cofres)

	var sonido := Node.new()
	sonido.set_script(SonidoScript)
	add_child(sonido)
	sonido.tocar_musica("res://audio/musica.wav")

	if "ultima_clase" in _estado:
		_clase = _estado.ultima_clase
	_construir_personaje()


# ---------------------------------------------------------------------------
# Interacción de arrastre
# ---------------------------------------------------------------------------

func _al_input_pj(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_arrastrando = true
			if _tween_retorno:
				_tween_retorno.kill()
		else:
			_arrastrando = false
			_iniciar_retorno()
	elif evento is InputEventMouseMotion and _arrastrando:
		_pivote_pj.rotation.y += evento.relative.x * _SENS
	elif evento is InputEventScreenTouch:
		if evento.pressed:
			_arrastrando = true
			if _tween_retorno:
				_tween_retorno.kill()
		else:
			_arrastrando = false
			_iniciar_retorno()
	elif evento is InputEventScreenDrag and _arrastrando:
		_pivote_pj.rotation.y += evento.relative.x * _SENS


func _iniciar_retorno() -> void:
	# Normalizar acumulación a -PI..PI para que el tween tome el camino más corto
	_pivote_pj.rotation.y = wrapf(_pivote_pj.rotation.y, -PI, PI)
	if absf(_pivote_pj.rotation.y) < _UMBRAL_RETORNO:
		_pivote_pj.rotation.y = 0.0
		return
	_tween_retorno = create_tween()
	_tween_retorno.set_ease(Tween.EASE_OUT)
	_tween_retorno.set_trans(Tween.TRANS_SPRING)
	_tween_retorno.tween_property(_pivote_pj, "rotation:y", 0.0, 1.4)


# ---------------------------------------------------------------------------
# Personaje y clase
# ---------------------------------------------------------------------------

func _ciclar_clase(dir: int) -> void:
	var i: int = CLASES.find(_clase)
	_clase = CLASES[(i + dir + CLASES.size()) % CLASES.size()]
	_construir_personaje()


func _construir_personaje() -> void:
	for h in _pivote_pj.get_children():
		h.queue_free()
	_lbl_clase.text = _clase.capitalize()
	var modelos: Dictionary = load("res://scripts/jugador.gd").MODELOS
	var info: Dictionary = modelos.get(_clase, {})
	if info.has("ruta") and ResourceLoader.exists(info.ruta):
		var modelo: Node3D = (load(info.ruta) as PackedScene).instantiate()
		modelo.scale = Vector3.ONE * 1.0
		modelo.position.y = 0.0
		_pivote_pj.add_child(modelo)


# ---------------------------------------------------------------------------
# Helpers del menú
# ---------------------------------------------------------------------------

func _boton(padre: Node, texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(320, 50)
	boton.add_theme_font_size_override("font_size", 21)
	boton.pressed.connect(accion)
	padre.add_child(boton)


func _al_jugar() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _al_ajustes() -> void:
	_ajustes.abrir()


func _al_salir() -> void:
	get_tree().quit()
