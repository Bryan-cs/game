extends CanvasLayer
## Panel de metaprogresión: muestra el Árbol de Habilidades Híbrido.
## Dos ramas: GLOBAL (todas las runs) y POR CLASE (solo su clase).
## Los Libros de Talento recogidos en partida se gastan aquí entre runs.

const ArbolTalentosScript := preload("res://scripts/arbol_talentos.gd")
const CLASES := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]

# Paleta centralizada
const _C_PANEL_BG    := Color(0.07, 0.05, 0.14, 0.98)
const _C_PANEL_BDR   := Color(0.40, 0.28, 0.70, 0.75)
const _C_SEP         := Color(0.26, 0.20, 0.42, 0.48)
const _C_LIBROS      := Color(0.76, 0.52, 1.0)
const _C_TAB_ACT_BG  := Color(0.18, 0.12, 0.36, 0.95)
const _C_TAB_ACT_BDR := Color(0.62, 0.42, 0.96)
const _C_TAB_IN_BG   := Color(0.08, 0.06, 0.16, 0.80)
const _C_TAB_IN_BDR  := Color(0.30, 0.26, 0.50)
const _C_MAX_BG      := Color(0.07, 0.16, 0.10, 0.95)
const _C_MAX_BDR     := Color(0.28, 0.80, 0.44, 1.0)
const _C_AVAIL_BG    := Color(0.10, 0.08, 0.22, 0.95)
const _C_AVAIL_BDR   := Color(0.58, 0.38, 0.95, 0.90)
const _C_PROG_BG     := Color(0.07, 0.10, 0.22, 0.92)
const _C_PROG_BDR    := Color(0.36, 0.50, 0.90, 0.72)
const _C_LOCK_BG     := Color(0.05, 0.04, 0.10, 0.88)
const _C_LOCK_BDR    := Color(0.18, 0.15, 0.28, 0.42)

var _estado: Node
var _caja_nodos: VBoxContainer
var _lbl_libros: Label
var _tab_global: Button
var _tab_clase: Button
var _rama := "global"
var _clase_sel := "guerrero"


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_estado = get_node(^"/root/Estado")

	# Fondo oscuro semitransparente
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.84)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	# Panel principal con borde visible
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = _C_PANEL_BG
	panel_style.border_color = _C_PANEL_BDR
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left   = 26
	panel_style.content_margin_right  = 26
	panel_style.content_margin_top    = 22
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.theme = EstiloUI.tema()
	panel.custom_minimum_size = Vector2(720, 620)
	centro.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	# Título
	var titulo := Label.new()
	titulo.text = "ÁRBOL DE TALENTOS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 28)
	v.add_child(titulo)

	# Subtítulo descriptivo
	var subtitulo := Label.new()
	subtitulo.text = "Mejoras permanentes · Persisten entre partidas"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", 12)
	subtitulo.add_theme_color_override("font_color", Color(0.46, 0.42, 0.62))
	v.add_child(subtitulo)

	v.add_child(_separador())

	# Contador de libros — elemento de jerarquía alta
	_lbl_libros = Label.new()
	_lbl_libros.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_libros.add_theme_font_size_override("font_size", 18)
	_lbl_libros.add_theme_color_override("font_color", _C_LIBROS)
	v.add_child(_lbl_libros)

	v.add_child(_separador())

	# Pestañas de rama
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)

	_tab_global = _crear_tab("  GLOBAL  ", func() -> void:
		_rama = "global"
		_reconstruir())
	tabs.add_child(_tab_global)

	_tab_clase = _crear_tab("  POR CLASE  ", func() -> void:
		_rama = "clase"
		_reconstruir())
	tabs.add_child(_tab_clase)

	v.add_child(_separador())

	# Lista de nodos con scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 340)
	v.add_child(scroll)

	_caja_nodos = VBoxContainer.new()
	_caja_nodos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_nodos.add_theme_constant_override("separation", 7)
	scroll.add_child(_caja_nodos)

	v.add_child(_separador())

	# Botón cerrar centrado
	var centro_btn := CenterContainer.new()
	v.add_child(centro_btn)
	var volver := Button.new()
	volver.text = "CERRAR"
	volver.custom_minimum_size = Vector2(200, 42)
	volver.add_theme_font_size_override("font_size", 17)
	volver.pressed.connect(func() -> void: visible = false)
	centro_btn.add_child(volver)


# ---------------------------------------------------------------------------
# Helpers de layout
# ---------------------------------------------------------------------------

func _separador() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = _C_SEP
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sep


func _crear_tab(texto: String, accion: Callable) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(150, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(accion)
	return btn


func _estilo_tab(btn: Button, activo: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color     = _C_TAB_ACT_BG  if activo else _C_TAB_IN_BG
	s.border_color = _C_TAB_ACT_BDR if activo else _C_TAB_IN_BDR
	s.set_border_width_all(2 if activo else 1)
	s.set_corner_radius_all(6)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 6
	s.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover",  s)
	var col := _C_TAB_ACT_BDR if activo else Color(0.58, 0.54, 0.76)
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", col)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func abrir() -> void:
	if "ultima_clase" in _estado:
		_clase_sel = _estado.ultima_clase
	_rama = "global"
	_reconstruir()
	visible = true


# ---------------------------------------------------------------------------
# Reconstrucción
# ---------------------------------------------------------------------------

func _reconstruir() -> void:
	var libros: int = int(_estado.libros_talento) if "libros_talento" in _estado else 0
	_lbl_libros.text = "◆  Libros de Talento disponibles: %d" % libros
	_estilo_tab(_tab_global, _rama == "global")
	_estilo_tab(_tab_clase,  _rama == "clase")
	for h in _caja_nodos.get_children():
		h.queue_free()
	if _rama == "global":
		_construir_nodos(ArbolTalentosScript.NODOS_GLOBAL)
	else:
		_construir_selector_clase()
		_construir_nodos(ArbolTalentosScript.NODOS_CLASE.get(_clase_sel, []))


func _construir_selector_clase() -> void:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	_caja_nodos.add_child(fila)

	var b_prev := Button.new()
	b_prev.text = "◀"
	b_prev.custom_minimum_size = Vector2(36, 36)
	b_prev.pressed.connect(func() -> void:
		var i: int = CLASES.find(_clase_sel)
		_clase_sel = CLASES[(i - 1 + CLASES.size()) % CLASES.size()]
		_reconstruir())
	fila.add_child(b_prev)

	var lbl := Label.new()
	lbl.text = "  %s  " % _clase_sel.capitalize()
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.86, 1.0))
	fila.add_child(lbl)

	var b_next := Button.new()
	b_next.text = "▶"
	b_next.custom_minimum_size = Vector2(36, 36)
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
		var id: String         = nodo.id
		var nivel_actual: int  = int(arbol.get(id, 0))
		var max_nivel: int     = int(nodo.max)
		var comprado: bool     = nivel_actual >= max_nivel
		var tiene_nivel: bool  = nivel_actual > 0 and not comprado
		var costos: Array      = nodo.costos
		var costo: int         = costos[nivel_actual] if nivel_actual < costos.size() else 0
		var puede_comprar: bool = not comprado and libros >= costo

		# ---- Estado visual del nodo ----
		var bg_col: Color
		var bdr_col: Color
		var bdr_w: int
		var icono: String
		var col_nombre: Color
		var col_desc: Color

		if comprado:
			bg_col    = _C_MAX_BG;   bdr_col = _C_MAX_BDR;   bdr_w = 2
			icono     = "★ "
			col_nombre = Color(0.72, 0.98, 0.76)
			col_desc   = Color(0.48, 0.70, 0.54)
		elif tiene_nivel and puede_comprar:
			bg_col    = _C_PROG_BG;  bdr_col = Color(0.46, 0.62, 0.96, 0.90); bdr_w = 2
			icono     = "◉ "
			col_nombre = Color(0.82, 0.92, 1.0)
			col_desc   = Color(0.58, 0.68, 0.88)
		elif tiene_nivel:
			bg_col    = _C_PROG_BG;  bdr_col = _C_PROG_BDR; bdr_w = 2
			icono     = "◉ "
			col_nombre = Color(0.68, 0.76, 0.96)
			col_desc   = Color(0.44, 0.52, 0.72)
		elif puede_comprar:
			bg_col    = _C_AVAIL_BG; bdr_col = _C_AVAIL_BDR; bdr_w = 2
			icono     = "◈ "
			col_nombre = Color(0.96, 0.92, 1.0)
			col_desc   = Color(0.62, 0.60, 0.82)
		else:
			bg_col    = _C_LOCK_BG;  bdr_col = _C_LOCK_BDR;  bdr_w = 1
			icono     = "▪ "
			col_nombre = Color(0.36, 0.34, 0.50)
			col_desc   = Color(0.26, 0.24, 0.38)

		# ---- Panel del nodo ----
		var p := PanelContainer.new()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color     = bg_col
		estilo.border_color = bdr_col
		estilo.set_border_width_all(bdr_w)
		estilo.set_corner_radius_all(8)
		estilo.content_margin_left   = 14
		estilo.content_margin_right  = 14
		estilo.content_margin_top    = 11
		estilo.content_margin_bottom = 11
		p.add_theme_stylebox_override("panel", estilo)
		_caja_nodos.add_child(p)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 14)
		p.add_child(fila)

		# ---- Columna izquierda: nombre + desc + puntos de progreso ----
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		fila.add_child(info)

		var nombre_lbl := Label.new()
		nombre_lbl.text = icono + nodo.nombre
		nombre_lbl.add_theme_font_size_override("font_size", 16)
		nombre_lbl.add_theme_color_override("font_color", col_nombre)
		info.add_child(nombre_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = nodo.desc
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", col_desc)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_lbl)

		# Puntos de progreso para nodos con más de un nivel
		if max_nivel > 1:
			var dots := ""
			for k in max_nivel:
				dots += ("●  " if k < nivel_actual else "○  ")
			var dots_lbl := Label.new()
			dots_lbl.text = dots.strip_edges()
			dots_lbl.add_theme_font_size_override("font_size", 11)
			var col_dots: Color
			if comprado:
				col_dots = Color(0.38, 0.88, 0.50)
			elif tiene_nivel:
				col_dots = Color(0.52, 0.64, 0.96)
			else:
				col_dots = Color(0.24, 0.22, 0.36)
			dots_lbl.add_theme_color_override("font_color", col_dots)
			info.add_child(dots_lbl)

		# ---- Columna derecha: nivel + acción ----
		var derecha := VBoxContainer.new()
		derecha.custom_minimum_size = Vector2(128, 0)
		derecha.alignment = BoxContainer.ALIGNMENT_CENTER
		derecha.add_theme_constant_override("separation", 4)
		fila.add_child(derecha)

		var nivel_lbl := Label.new()
		nivel_lbl.text = "Nv. %d / %d" % [nivel_actual, max_nivel]
		nivel_lbl.add_theme_font_size_override("font_size", 14)
		nivel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var col_nivel: Color
		if comprado:      col_nivel = Color(0.42, 0.92, 0.52)
		elif tiene_nivel: col_nivel = Color(0.60, 0.72, 0.98)
		else:             col_nivel = Color(0.78, 0.76, 0.90)
		nivel_lbl.add_theme_color_override("font_color", col_nivel)
		derecha.add_child(nivel_lbl)

		if comprado:
			var lbl_max := Label.new()
			lbl_max.text = "✓ MÁXIMO"
			lbl_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_max.add_theme_font_size_override("font_size", 12)
			lbl_max.add_theme_color_override("font_color", Color(0.38, 0.88, 0.50))
			derecha.add_child(lbl_max)
		else:
			var btn := Button.new()
			var libro_str := "libro" if costo == 1 else "libros"
			btn.text = "  ✦ %d %s  " % [costo, libro_str]
			btn.add_theme_font_size_override("font_size", 12)
			btn.custom_minimum_size = Vector2(118, 30)
			btn.disabled = not puede_comprar
			if puede_comprar:
				var bs := StyleBoxFlat.new()
				bs.bg_color     = Color(0.20, 0.10, 0.40, 0.90)
				bs.border_color = Color(0.58, 0.38, 0.95, 0.85)
				bs.set_border_width_all(1)
				bs.set_corner_radius_all(4)
				bs.content_margin_left   = 8
				bs.content_margin_right  = 8
				bs.content_margin_top    = 4
				bs.content_margin_bottom = 4
				btn.add_theme_stylebox_override("normal", bs)
				btn.add_theme_color_override("font_color", Color(0.88, 0.72, 1.0))
			btn.pressed.connect(func() -> void:
				if _estado.comprar_nodo_arbol(id):
					_animar_libros()
					_reconstruir())
			derecha.add_child(btn)


# ---------------------------------------------------------------------------
# Feedback de compra
# ---------------------------------------------------------------------------

func _animar_libros() -> void:
	var t := create_tween()
	t.tween_property(_lbl_libros, "modulate", Color(1.6, 1.2, 0.5), 0.08)
	t.tween_property(_lbl_libros, "modulate", Color(1.0, 1.0, 1.0), 0.40)
