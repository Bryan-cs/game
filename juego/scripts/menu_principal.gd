extends Control
## Menú principal cinematográfico: luna de sangre, brasas, viñeta y tema gótico.

const MenuAjustesScript := preload("res://scripts/menu_ajustes.gd")
const MenuMisionesScript := preload("res://scripts/menu_misiones.gd")
const MenuTiendaScript := preload("res://scripts/menu_tienda.gd")
const MenuInventarioScript := preload("res://scripts/menu_inventario.gd")
const MenuCofresScript := preload("res://scripts/menu_cofres.gd")
const SonidoScript := preload("res://scripts/sonido.gd")

var _ajustes: CanvasLayer
var _misiones: CanvasLayer
var _tienda: CanvasLayer
var _inventario: CanvasLayer
var _cofres: CanvasLayer
@onready var _estado: Node = get_node(^"/root/Estado")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = EstiloUI.tema()

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

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "NIGHTFALL SURVIVORS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 58)
	caja.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Sobrevive a la noche. La noche evoluciona."
	subtitulo.add_theme_font_size_override("font_size", 18)
	subtitulo.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(subtitulo)

	var oro := Label.new()
	oro.text = "Oro total: %d" % _estado.oro_total
	oro.add_theme_font_size_override("font_size", 18)
	oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(oro)

	var separador := Control.new()
	separador.custom_minimum_size = Vector2(0, 12)
	caja.add_child(separador)

	_boton(caja, "JUGAR", _al_jugar)
	_boton(caja, "INVENTARIO", func() -> void: _inventario.abrir())
	_boton(caja, "COFRES", func() -> void: _cofres.abrir())
	_boton(caja, "MISIONES", func() -> void: _misiones.abrir())
	_boton(caja, "TIENDA · PASE", func() -> void: _tienda.abrir())
	_boton(caja, "AJUSTES", _al_ajustes)
	_boton(caja, "SALIR", _al_salir)

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
