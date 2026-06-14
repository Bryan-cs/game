extends CanvasLayer
## Menú de subida de nivel: tres mejoras aleatorias con rareza (GDD secciones 7 y 10).

signal mejora_elegida(indice: int)

var _botones: VBoxContainer
var _titulo: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)
	_titulo = Label.new()
	_titulo.text = "¡SUBES DE NIVEL!  Elige una mejora"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(_titulo, 24)
	caja.add_child(_titulo)
	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 10)
	caja.add_child(_botones)


func mostrar(opciones: Array, titulo := "¡SUBES DE NIVEL!  Elige una mejora") -> void:
	_titulo.text = titulo
	for hijo in _botones.get_children():
		hijo.queue_free()
	for i in opciones.size():
		var opcion: Dictionary = opciones[i]
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(480, 52)
		boton.text = "[%s]  %s — %s" % [opcion.rareza, opcion.titulo, opcion.desc]
		boton.add_theme_color_override("font_color", opcion.color)
		boton.add_theme_font_size_override("font_size", 17)
		boton.pressed.connect(_al_elegir.bind(i))
		_botones.add_child(boton)
	visible = true
	get_tree().paused = true


func _al_elegir(indice: int) -> void:
	visible = false
	mejora_elegida.emit(indice)
