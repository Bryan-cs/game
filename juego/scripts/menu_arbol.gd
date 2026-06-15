extends CanvasLayer
## Panel de metaprogresión: muestra el Árbol de Habilidades Híbrido.
## Dos ramas: GLOBAL (todas las runs) y POR CLASE (solo su clase).
## Los Libros de Talento recogidos en partida se gastan aquí entre runs.

const CLASES := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]

var _estado: Node
var _caja_nodos: VBoxContainer
var _lbl_libros: Label
var _rama := "global"
var _clase_sel := "guerrero"


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_estado = get_node(^"/root/Estado")

	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.78)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	panel.custom_minimum_size = Vector2(660, 610)
	centro.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var titulo := Label.new()
	titulo.text = "ÁRBOL DE TALENTOS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 26)
	v.add_child(titulo)

	_lbl_libros = Label.new()
	_lbl_libros.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_libros.add_theme_font_size_override("font_size", 16)
	_lbl_libros.add_theme_color_override("font_color", Color(0.72, 0.48, 1.0))
	v.add_child(_lbl_libros)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)

	var tab_global := Button.new()
	tab_global.text = "  GLOBAL  "
	tab_global.add_theme_font_size_override("font_size", 15)
	tab_global.pressed.connect(func() -> void:
		_rama = "global"
		_reconstruir())
	tabs.add_child(tab_global)

	var tab_clase := Button.new()
	tab_clase.text = "  POR CLASE  "
	tab_clase.add_theme_font_size_override("font_size", 15)
	tab_clase.pressed.connect(func() -> void:
		_rama = "clase"
		_reconstruir())
	tabs.add_child(tab_clase)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 390)
	v.add_child(scroll)

	_caja_nodos = VBoxContainer.new()
	_caja_nodos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_nodos.add_theme_constant_override("separation", 6)
	scroll.add_child(_caja_nodos)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 4)
	v.add_child(sep)

	var volver := Button.new()
	volver.text = "CERRAR"
	volver.add_theme_font_size_override("font_size", 18)
	volver.pressed.connect(func() -> void: visible = false)
	v.add_child(volver)


func abrir() -> void:
	if "ultima_clase" in _estado:
		_clase_sel = _estado.ultima_clase
	_rama = "global"
	_reconstruir()
	visible = true


func _reconstruir() -> void:
	var libros: int = int(_estado.libros_talento) if "libros_talento" in _estado else 0
	_lbl_libros.text = "Libros de Talento disponibles: %d" % libros
	for h in _caja_nodos.get_children():
		h.queue_free()
	if _rama == "global":
		_construir_nodos(ArbolTalentos.NODOS_GLOBAL)
	else:
		_construir_selector_clase()
		_construir_nodos(ArbolTalentos.NODOS_CLASE.get(_clase_sel, []))


func _construir_selector_clase() -> void:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	_caja_nodos.add_child(fila)

	var b_prev := Button.new()
	b_prev.text = "◀"
	b_prev.pressed.connect(func() -> void:
		var i: int = CLASES.find(_clase_sel)
		_clase_sel = CLASES[(i - 1 + CLASES.size()) % CLASES.size()]
		_reconstruir())
	fila.add_child(b_prev)

	var lbl := Label.new()
	lbl.text = _clase_sel.capitalize()
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 1.0))
	fila.add_child(lbl)

	var b_next := Button.new()
	b_next.text = "▶"
	b_next.pressed.connect(func() -> void:
		var i: int = CLASES.find(_clase_sel)
		_clase_sel = CLASES[(i + 1) % CLASES.size()]
		_reconstruir())
	fila.add_child(b_next)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	_caja_nodos.add_child(sep)


func _construir_nodos(lista: Array) -> void:
	var libros: int = int(_estado.libros_talento) if "libros_talento" in _estado else 0
	var arbol: Dictionary = _estado.arbol_nodos if "arbol_nodos" in _estado else {}

	for nodo in lista:
		var id: String = nodo.id
		var nivel_actual: int = int(arbol.get(id, 0))
		var max_nivel: int = int(nodo.max)
		var comprado: bool = nivel_actual >= max_nivel
		var costos: Array = nodo.costos
		var costo: int = costos[nivel_actual] if nivel_actual < costos.size() else 0
		var puede_comprar: bool = not comprado and libros >= costo

		var p := PanelContainer.new()
		var estilo := StyleBoxFlat.new()
		if comprado:
			estilo.bg_color        = Color(0.08, 0.18, 0.10, 0.95)
			estilo.border_color    = Color(0.25, 0.70, 0.36, 0.85)
		elif puede_comprar:
			estilo.bg_color        = Color(0.10, 0.09, 0.20, 0.95)
			estilo.border_color    = Color(0.55, 0.38, 0.88, 0.70)
		else:
			estilo.bg_color        = Color(0.06, 0.05, 0.10, 0.90)
			estilo.border_color    = Color(0.22, 0.20, 0.30, 0.50)
		estilo.set_border_width_all(1)
		estilo.set_corner_radius_all(6)
		estilo.content_margin_left   = 12
		estilo.content_margin_right  = 12
		estilo.content_margin_top    = 8
		estilo.content_margin_bottom = 8
		p.add_theme_stylebox_override("panel", estilo)
		_caja_nodos.add_child(p)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		p.add_child(fila)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(info)

		var nombre_lbl := Label.new()
		nombre_lbl.text = nodo.nombre
		nombre_lbl.add_theme_font_size_override("font_size", 15)
		var col_nombre := Color(0.68, 0.92, 0.72) if comprado else Color(0.92, 0.88, 1.0)
		nombre_lbl.add_theme_color_override("font_color", col_nombre)
		info.add_child(nombre_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = nodo.desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.58, 0.56, 0.70))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_lbl)

		var derecha := VBoxContainer.new()
		derecha.custom_minimum_size = Vector2(120, 0)
		derecha.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_child(derecha)

		var nivel_lbl := Label.new()
		nivel_lbl.text = "Nv. %d / %d" % [nivel_actual, max_nivel]
		nivel_lbl.add_theme_font_size_override("font_size", 13)
		nivel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var col_nivel := Color(0.42, 0.92, 0.52) if comprado else Color(0.78, 0.76, 0.90)
		nivel_lbl.add_theme_color_override("font_color", col_nivel)
		derecha.add_child(nivel_lbl)

		if comprado:
			var lbl_max := Label.new()
			lbl_max.text = "MAX ✓"
			lbl_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_max.add_theme_font_size_override("font_size", 12)
			lbl_max.add_theme_color_override("font_color", Color(0.38, 0.88, 0.50))
			derecha.add_child(lbl_max)
		else:
			var btn := Button.new()
			btn.text = "  %d libro%s  " % [costo, "s" if costo > 1 else ""]
			btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = not puede_comprar
			btn.pressed.connect(func() -> void:
				if _estado.comprar_nodo_arbol(id):
					_reconstruir())
			derecha.add_child(btn)
