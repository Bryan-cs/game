extends CanvasLayer
## Menú de pausa: reanudar, reiniciar, ajustes o salir al menú principal.

signal reanudar
signal reiniciar
signal abrir_ajustes
signal salir_al_menu


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(320, 0)
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 32)
	caja.add_child(titulo)
	_boton(caja, "REANUDAR", func() -> void: reanudar.emit())
	_boton(caja, "REINICIAR PARTIDA", func() -> void: reiniciar.emit())
	_boton(caja, "AJUSTES", func() -> void: abrir_ajustes.emit())
	_boton(caja, "SALIR AL MENÚ", func() -> void: salir_al_menu.emit())


func _boton(padre: Node, texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, 46)
	boton.add_theme_font_size_override("font_size", 18)
	boton.pressed.connect(accion)
	padre.add_child(boton)
