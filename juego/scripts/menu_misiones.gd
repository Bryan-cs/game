extends CanvasLayer
## Misiones diarias y logros con progreso (GDD sec. 19).

signal cerrado

var _estado: Node
var _caja: VBoxContainer


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
	titulo.text = "MISIONES Y LOGROS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 28)
	contenedor.add_child(titulo)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 420)
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


func _fila(nombre: String, desc: String, progreso: int, meta: int, oro: int, completada: bool) -> void:
	var etiqueta := Label.new()
	var marca := "✓" if completada else "·"
	etiqueta.text = "%s %s — %s  [%d/%d]  +%d oro" % [marca, nombre, desc, progreso, meta, oro]
	etiqueta.add_theme_font_size_override("font_size", 14)
	if completada:
		etiqueta.add_theme_color_override("font_color", Color(0.45, 0.95, 0.5))
	_caja.add_child(etiqueta)


func _reconstruir() -> void:
	for hijo in _caja.get_children():
		hijo.queue_free()
	_seccion("MISIONES DIARIAS (%s)" % _estado.misiones_fecha)
	for mision in _estado.misiones:
		_fila(mision.nombre, mision.desc, _estado.progreso_mision(mision), int(mision.meta), int(mision.oro), bool(mision.completada))
	_seccion("LOGROS")
	for id in _estado.LOGROS:
		var datos: Dictionary = _estado.LOGROS[id]
		var hecho: bool = id in _estado.logros_completados
		var progreso: int = mini(int(_estado.stats.get(datos.stat, 0)), int(datos.meta))
		_fila(datos.nombre, datos.desc, progreso, int(datos.meta), int(datos.oro), hecho)
