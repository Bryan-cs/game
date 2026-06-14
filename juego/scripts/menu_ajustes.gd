extends CanvasLayer
## Panel de ajustes: volumen, pantalla completa y calidad gráfica.
## Reutilizable desde el menú principal y el menú de pausa.

signal cerrado
signal ajustes_cambiados

var _estado: Node


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_estado = get_node(^"/root/Estado")
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
	caja.custom_minimum_size = Vector2(420, 0)
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)
	var titulo := Label.new()
	titulo.text = "AJUSTES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 28)
	caja.add_child(titulo)

	caja.add_child(_fila_deslizador("Música", "vol_musica"))
	caja.add_child(_fila_deslizador("Efectos", "vol_sfx"))
	caja.add_child(_fila_interruptor("Pantalla completa", "pantalla_completa"))
	caja.add_child(_fila_interruptor("Brillo (glow)", "glow"))
	caja.add_child(_fila_interruptor("Sombras", "sombras"))
	caja.add_child(_fila_interruptor("Números de daño", "numeros_dano"))

	var volver := Button.new()
	volver.text = "VOLVER"
	volver.add_theme_font_size_override("font_size", 18)
	volver.pressed.connect(_al_volver)
	caja.add_child(volver)


func _fila_deslizador(texto: String, clave: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(150, 0)
	fila.add_child(etiqueta)
	var deslizador := HSlider.new()
	deslizador.min_value = 0.0
	deslizador.max_value = 1.0
	deslizador.step = 0.05
	deslizador.value = float(_estado.ajustes[clave])
	deslizador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deslizador.value_changed.connect(func(v: float) -> void:
		_estado.ajustes[clave] = v
		var gestor = get_tree().get_first_node_in_group("sonido")
		if gestor:
			gestor.actualizar_volumenes()
		ajustes_cambiados.emit())
	fila.add_child(deslizador)
	return fila


func _fila_interruptor(texto: String, clave: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(220, 0)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var interruptor := CheckButton.new()
	interruptor.button_pressed = bool(_estado.ajustes[clave])
	interruptor.toggled.connect(func(activo: bool) -> void:
		_estado.ajustes[clave] = activo
		if clave == "pantalla_completa":
			_estado.aplicar_pantalla()
		ajustes_cambiados.emit())
	fila.add_child(interruptor)
	return fila


func abrir() -> void:
	visible = true


func _al_volver() -> void:
	_estado.guardar()
	visible = false
	cerrado.emit()
