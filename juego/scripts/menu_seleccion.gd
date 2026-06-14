extends CanvasLayer
## Selección de personaje y mapa al inicio de la partida (GDD secciones 6 y 13).

signal clase_elegida(clave: String, mapa: String, indice_nivel: int)

const NivelesScript := preload("res://scripts/niveles.gd")

var _nivel_sel := 0
var _botones_nivel := {}
var _estado: Node
var _oro: Label
var _nombre_nivel: Label


func _ready() -> void:
	layer = 25
	_estado = get_node(^"/root/Estado")
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.03, 0.06, 0.92)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = "NIGHTFALL SURVIVORS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 34)
	caja.add_child(titulo)

	_oro = Label.new()
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(_oro)

	var sub_nivel := Label.new()
	sub_nivel.text = "Elige el nivel"
	sub_nivel.add_theme_font_size_override("font_size", 15)
	sub_nivel.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	caja.add_child(sub_nivel)

	_nombre_nivel = Label.new()
	_nombre_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre_nivel.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	caja.add_child(_nombre_nivel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 220)
	caja.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	_nivel_sel = mini(_estado.nivel_max_desbloqueado, NivelesScript.TOTAL - 1)
	for i in NivelesScript.TOTAL:
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(96, 50)
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_al_pulsar_nivel.bind(i))
		grid.add_child(boton)
		_botones_nivel[i] = boton
	_refrescar_niveles()

	var sub_clase := Label.new()
	sub_clase.text = "Elige tu personaje"
	sub_clase.add_theme_font_size_override("font_size", 15)
	sub_clase.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	caja.add_child(sub_clase)

	for clave in Jugador.CLASES:
		var datos: Dictionary = Jugador.CLASES[clave]
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(620, 46)
		boton.text = "%s — %s" % [datos.nombre, datos.desc]
		boton.add_theme_font_size_override("font_size", 16)
		boton.add_theme_color_override("font_color", datos.color.lightened(0.35))
		boton.pressed.connect(_al_elegir.bind(clave))
		caja.add_child(boton)


func _refrescar_niveles() -> void:
	_oro.text = "Oro total: %d" % _estado.oro_total
	for i in _botones_nivel:
		var boton: Button = _botones_nivel[i]
		var desbloqueado: bool = i <= _estado.nivel_max_desbloqueado
		if desbloqueado:
			var estrellas: int = _estado.estrellas_de(i)
			var glifos := "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
			boton.disabled = false
			boton.text = "%d\n%s%s" % [i + 1, ("✦ " if i == _nivel_sel else ""), glifos]
		else:
			boton.disabled = true
			boton.text = "🔒\n%d" % (i + 1)
	if _nombre_nivel:
		_nombre_nivel.text = "%d. %s" % [_nivel_sel + 1, NivelesScript.nombre(_nivel_sel)]


func _al_pulsar_nivel(i: int) -> void:
	if i <= _estado.nivel_max_desbloqueado:
		_nivel_sel = i
		_refrescar_niveles()


func _al_elegir(clave: String) -> void:
	visible = false
	clase_elegida.emit(clave, NivelesScript.tema(_nivel_sel), _nivel_sel)
