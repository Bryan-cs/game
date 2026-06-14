extends CanvasLayer
## HUD: vida, XP, nivel, tiempo, oro, kills, barra de jefe y pausa (GDD sección 16).

signal pausa_conmutada

var barra_vida: ProgressBar
var etiqueta_vida: Label
var barra_xp: ProgressBar
var etiqueta_nivel: Label
var etiqueta_tiempo: Label
var etiqueta_kills: Label
var barra_jefe: ProgressBar
var etiqueta_jefe: Label
var etiqueta_pausa: Label
var barra_nova: ProgressBar
var barra_dash: ProgressBar
var barra_habilidad: ProgressBar
var barra_hab2: ProgressBar
var _texto_hab1: Label
var _texto_hab2: Label
var barra_corrupcion: ProgressBar
var etiqueta_oro: Label
var etiqueta_anuncio: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		pausa_conmutada.emit()


func _estilo(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(4)
	return estilo


func _crear_barra(color_fondo: Color, color_relleno: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.add_theme_stylebox_override("background", _estilo(color_fondo))
	barra.add_theme_stylebox_override("fill", _estilo(color_relleno))
	add_child(barra)
	return barra


func _crear_etiqueta(texto: String, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	add_child(etiqueta)
	return etiqueta


func _construir() -> void:
	barra_xp = _crear_barra(Color(0.1, 0.1, 0.18, 0.8), Color(0.25, 0.55, 1.0))
	barra_xp.anchor_right = 1.0
	barra_xp.offset_left = 10.0
	barra_xp.offset_top = 8.0
	barra_xp.offset_right = -10.0
	barra_xp.offset_bottom = 26.0

	etiqueta_nivel = _crear_etiqueta("Nv. 1", 18)
	etiqueta_nivel.position = Vector2(14, 32)

	barra_vida = _crear_barra(Color(0.15, 0.05, 0.05, 0.8), Color(0.85, 0.2, 0.2))
	barra_vida.position = Vector2(14, 60)
	barra_vida.size = Vector2(240, 22)
	etiqueta_vida = Label.new()
	etiqueta_vida.text = "120 / 120"
	etiqueta_vida.set_anchors_preset(Control.PRESET_FULL_RECT)
	etiqueta_vida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_vida.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta_vida.add_theme_font_size_override("font_size", 14)
	barra_vida.add_child(etiqueta_vida)

	etiqueta_tiempo = _crear_etiqueta("00:00", 28)
	etiqueta_tiempo.anchor_left = 0.5
	etiqueta_tiempo.anchor_right = 0.5
	etiqueta_tiempo.offset_left = -50.0
	etiqueta_tiempo.offset_top = 34.0

	etiqueta_kills = _crear_etiqueta("Bajas: 0", 18)
	etiqueta_kills.anchor_left = 1.0
	etiqueta_kills.anchor_right = 1.0
	etiqueta_kills.offset_left = -180.0
	etiqueta_kills.offset_top = 62.0

	etiqueta_oro = _crear_etiqueta("Oro: 0", 18)
	etiqueta_oro.anchor_left = 1.0
	etiqueta_oro.anchor_right = 1.0
	etiqueta_oro.offset_left = -180.0
	etiqueta_oro.offset_top = 84.0
	etiqueta_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	etiqueta_jefe = _crear_etiqueta("GIGANTE PUTREFACTO", 20)
	etiqueta_jefe.anchor_left = 0.5
	etiqueta_jefe.anchor_right = 0.5
	etiqueta_jefe.anchor_top = 1.0
	etiqueta_jefe.anchor_bottom = 1.0
	etiqueta_jefe.offset_left = -130.0
	etiqueta_jefe.offset_top = -96.0
	etiqueta_jefe.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	etiqueta_jefe.visible = false

	barra_jefe = _crear_barra(Color(0.12, 0.02, 0.02, 0.85), Color(0.75, 0.1, 0.1))
	barra_jefe.anchor_left = 0.5
	barra_jefe.anchor_right = 0.5
	barra_jefe.anchor_top = 1.0
	barra_jefe.anchor_bottom = 1.0
	barra_jefe.offset_left = -220.0
	barra_jefe.offset_right = 220.0
	barra_jefe.offset_top = -66.0
	barra_jefe.offset_bottom = -42.0
	barra_jefe.max_value = 1.0
	barra_jefe.visible = false

	barra_corrupcion = _crear_barra(Color(0.1, 0.04, 0.14, 0.8), Color(0.6, 0.2, 0.9))
	barra_corrupcion.position = Vector2(14, 88)
	barra_corrupcion.size = Vector2(240, 14)
	barra_corrupcion.max_value = 100.0
	barra_corrupcion.value = 0.0
	var texto_corrupcion := Label.new()
	texto_corrupcion.text = "Corrupción"
	texto_corrupcion.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_corrupcion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_corrupcion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_corrupcion.add_theme_font_size_override("font_size", 10)
	barra_corrupcion.add_child(texto_corrupcion)

	etiqueta_anuncio = _crear_etiqueta("", 32)
	etiqueta_anuncio.anchor_right = 1.0
	etiqueta_anuncio.offset_top = 96.0
	etiqueta_anuncio.offset_bottom = 140.0
	etiqueta_anuncio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_anuncio.modulate.a = 0.0

	barra_habilidad = _crear_barra(Color(0.15, 0.09, 0.04, 0.85), Color(1.0, 0.6, 0.2))
	barra_habilidad.anchor_top = 1.0
	barra_habilidad.anchor_bottom = 1.0
	barra_habilidad.offset_left = 14.0
	barra_habilidad.offset_right = 194.0
	barra_habilidad.offset_top = -92.0
	barra_habilidad.offset_bottom = -70.0
	barra_habilidad.max_value = 1.0
	barra_habilidad.value = 0.0
	barra_habilidad.visible = false
	_texto_hab1 = Label.new()
	_texto_hab1.text = "E · Habilidad"
	_texto_hab1.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto_hab1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_hab1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_hab1.add_theme_font_size_override("font_size", 13)
	barra_habilidad.add_child(_texto_hab1)

	barra_hab2 = _crear_barra(Color(0.13, 0.05, 0.13, 0.85), Color(0.85, 0.4, 1.0))
	barra_hab2.anchor_top = 1.0
	barra_hab2.anchor_bottom = 1.0
	barra_hab2.offset_left = 14.0
	barra_hab2.offset_right = 194.0
	barra_hab2.offset_top = -118.0
	barra_hab2.offset_bottom = -96.0
	barra_hab2.max_value = 1.0
	barra_hab2.value = 0.0
	barra_hab2.visible = false
	_texto_hab2 = Label.new()
	_texto_hab2.text = "R · Habilidad"
	_texto_hab2.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto_hab2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_hab2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_hab2.add_theme_font_size_override("font_size", 13)
	barra_hab2.add_child(_texto_hab2)

	barra_nova = _crear_barra(Color(0.05, 0.12, 0.15, 0.85), Color(0.25, 0.8, 0.95))
	barra_nova.anchor_top = 1.0
	barra_nova.anchor_bottom = 1.0
	barra_nova.offset_left = 14.0
	barra_nova.offset_right = 194.0
	barra_nova.offset_top = -66.0
	barra_nova.offset_bottom = -44.0
	barra_nova.max_value = 1.0
	barra_nova.value = 1.0
	var texto_nova := Label.new()
	texto_nova.text = "Q · Nova"
	texto_nova.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_nova.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_nova.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_nova.add_theme_font_size_override("font_size", 13)
	barra_nova.add_child(texto_nova)

	barra_dash = _crear_barra(Color(0.05, 0.15, 0.08, 0.85), Color(0.35, 0.9, 0.45))
	barra_dash.anchor_top = 1.0
	barra_dash.anchor_bottom = 1.0
	barra_dash.offset_left = 14.0
	barra_dash.offset_right = 194.0
	barra_dash.offset_top = -40.0
	barra_dash.offset_bottom = -18.0
	barra_dash.max_value = 1.0
	barra_dash.value = 1.0
	var texto_dash := Label.new()
	texto_dash.text = "ESPACIO · Dash"
	texto_dash.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_dash.add_theme_font_size_override("font_size", 13)
	barra_dash.add_child(texto_dash)

	etiqueta_pausa = _crear_etiqueta("PAUSA", 48)
	etiqueta_pausa.anchor_left = 0.5
	etiqueta_pausa.anchor_right = 0.5
	etiqueta_pausa.anchor_top = 0.5
	etiqueta_pausa.anchor_bottom = 0.5
	etiqueta_pausa.offset_left = -80.0
	etiqueta_pausa.offset_top = -30.0
	etiqueta_pausa.visible = false


func actualizar_cooldowns(nova: float, dash: float, hab1: float, hab2: float) -> void:
	barra_nova.value = nova
	barra_dash.value = dash
	barra_habilidad.value = maxf(hab1, 0.0)
	barra_hab2.value = maxf(hab2, 0.0)


func configurar_habilidad(slot: int, texto: String) -> void:
	if slot == 0:
		_texto_hab1.text = texto
		barra_habilidad.visible = true
	else:
		_texto_hab2.text = texto
		barra_hab2.visible = true


func actualizar_corrupcion(valor: float) -> void:
	barra_corrupcion.value = valor


func anunciar(texto: String, color := Color(1.0, 0.85, 0.4)) -> void:
	etiqueta_anuncio.text = texto
	etiqueta_anuncio.add_theme_color_override("font_color", color)
	etiqueta_anuncio.modulate.a = 1.0
	var tween := etiqueta_anuncio.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(etiqueta_anuncio, "modulate:a", 0.0, 1.4)


func actualizar_vida(actual: float, maxima: float) -> void:
	barra_vida.max_value = maxima
	barra_vida.value = maxf(actual, 0.0)
	etiqueta_vida.text = "%d / %d" % [int(maxf(actual, 0.0)), int(maxima)]


func actualizar_xp(actual: float, necesaria: float, nivel: int) -> void:
	barra_xp.max_value = necesaria
	barra_xp.value = actual
	etiqueta_nivel.text = "Nv. %d" % nivel


func actualizar_tiempo(segundos: float) -> void:
	var s := int(segundos)
	etiqueta_tiempo.text = "%02d:%02d" % [s / 60, s % 60]


func actualizar_kills(kills: int) -> void:
	etiqueta_kills.text = "Bajas: %d" % kills


func actualizar_oro(cantidad: int) -> void:
	etiqueta_oro.text = "Oro: %d" % cantidad


func mostrar_jefe(nombre: String) -> void:
	etiqueta_jefe.text = nombre
	etiqueta_jefe.visible = true
	barra_jefe.visible = true
	barra_jefe.value = 1.0


func actualizar_jefe(fraccion: float) -> void:
	barra_jefe.value = fraccion


func ocultar_jefe() -> void:
	etiqueta_jefe.visible = false
	barra_jefe.visible = false


func mostrar_pausa(activa: bool) -> void:
	etiqueta_pausa.visible = activa
