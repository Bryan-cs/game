extends CanvasLayer
## Selección de nivel (carrusel con contexto de Grieta) y personaje (selector tipo lobby).

signal clase_elegida(clave: String, mapa: String, indice_nivel: int)

const NivelesScript := preload("res://scripts/niveles.gd")
const CLASES_ORDEN := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]

var _nivel_sel := 0
var _clase_idx := 0
var _estado: Node
var _slots_nivel: Array
var _lbl_clase:         Label
var _oro:               Label
var _estilo_slot_normal: StyleBoxFlat
var _estilo_slot_sel:    StyleBoxFlat
var _estilo_slot_bloq:   StyleBoxFlat
var _estilo_slot_boss:   StyleBoxFlat
var _estilo_grieta:      StyleBoxFlat
var _panel_grieta:       PanelContainer
var _lbl_grieta_nombre:  Label
var _lbl_grieta_sub:     Label
var _lbl_grieta_rasgo:   Label
var _lbl_sec_nivel:      Label
var _btn_jugar:          Button


func _ready() -> void:
	layer = 25
	_estado = get_node(^"/root/Estado")

	# ── Estilos de slots ─────────────────────────────────────────────────────
	_estilo_slot_normal = _mk_slot(Color(0.09, 0.07, 0.16, 0.88))

	_estilo_slot_sel = _mk_slot(Color(0.17, 0.12, 0.28, 1.0))
	_estilo_slot_sel.border_color = Color(1.0, 0.82, 0.28, 1.0)
	_estilo_slot_sel.set_border_width_all(2)
	_estilo_slot_sel.shadow_color = Color(1.0, 0.8, 0.2, 0.18)
	_estilo_slot_sel.shadow_size  = 6

	_estilo_slot_bloq = _mk_slot(Color(0.07, 0.06, 0.11, 0.60))

	_estilo_slot_boss = _mk_slot(Color(0.20, 0.06, 0.08, 1.0))
	_estilo_slot_boss.border_color = Color(0.92, 0.22, 0.18, 1.0)
	_estilo_slot_boss.set_border_width_all(2)
	_estilo_slot_boss.shadow_color = Color(0.9, 0.18, 0.12, 0.22)
	_estilo_slot_boss.shadow_size  = 6

	_estilo_grieta = StyleBoxFlat.new()
	_estilo_grieta.bg_color     = Color(0.06, 0.10, 0.06, 0.90)
	_estilo_grieta.border_color = Color(0.28, 0.45, 0.30, 0.55)
	_estilo_grieta.set_border_width_all(1)
	_estilo_grieta.set_corner_radius_all(10)
	_estilo_grieta.content_margin_left   = 16
	_estilo_grieta.content_margin_right  = 16
	_estilo_grieta.content_margin_top    = 12
	_estilo_grieta.content_margin_bottom = 12

	# ── Fondo ────────────────────────────────────────────────────────────────
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
	caja.add_theme_constant_override("separation", 16)
	caja.custom_minimum_size = Vector2(620, 0)
	panel.add_child(caja)

	# ── Encabezado ───────────────────────────────────────────────────────────
	var titulo := Label.new()
	titulo.text = "NIGHTFALL SURVIVORS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 34)
	caja.add_child(titulo)

	_oro = Label.new()
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oro.add_theme_font_size_override("font_size", 15)
	_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(_oro)

	# ── CABECERA DE GRIETA ───────────────────────────────────────────────────
	_panel_grieta = PanelContainer.new()
	_panel_grieta.add_theme_stylebox_override("panel", _estilo_grieta)
	caja.add_child(_panel_grieta)

	var caja_grieta := VBoxContainer.new()
	caja_grieta.add_theme_constant_override("separation", 4)
	_panel_grieta.add_child(caja_grieta)

	_lbl_grieta_nombre = Label.new()
	_lbl_grieta_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_grieta_nombre.add_theme_font_size_override("font_size", 20)
	caja_grieta.add_child(_lbl_grieta_nombre)

	_lbl_grieta_sub = Label.new()
	_lbl_grieta_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_grieta_sub.add_theme_font_size_override("font_size", 14)
	caja_grieta.add_child(_lbl_grieta_sub)

	_lbl_grieta_rasgo = Label.new()
	_lbl_grieta_rasgo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_grieta_rasgo.add_theme_font_size_override("font_size", 11)
	caja_grieta.add_child(_lbl_grieta_rasgo)

	# ── SECCIÓN NIVEL ────────────────────────────────────────────────────────
	var sec_nivel := VBoxContainer.new()
	sec_nivel.add_theme_constant_override("separation", 8)
	caja.add_child(sec_nivel)

	_lbl_sec_nivel = Label.new()
	_lbl_sec_nivel.text = "NIVEL"
	_lbl_sec_nivel.add_theme_font_size_override("font_size", 11)
	_lbl_sec_nivel.add_theme_color_override("font_color", Color(0.5, 0.48, 0.62))
	_lbl_sec_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_nivel.add_child(_lbl_sec_nivel)

	var fila_nivel := HBoxContainer.new()
	fila_nivel.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_nivel.add_theme_constant_override("separation", 10)
	sec_nivel.add_child(fila_nivel)

	var btn_n_prev := Button.new()
	btn_n_prev.text = "◀"
	btn_n_prev.add_theme_font_size_override("font_size", 16)
	btn_n_prev.custom_minimum_size = Vector2(44, 88)
	btn_n_prev.pressed.connect(_nav_nivel.bind(-1))
	fila_nivel.add_child(btn_n_prev)

	_slots_nivel = []
	for _i in 3:
		var slot := _crear_slot_nivel()
		fila_nivel.add_child(slot)
		_slots_nivel.append(slot)
	_slots_nivel[1].custom_minimum_size = Vector2(180, 112)

	var btn_n_next := Button.new()
	btn_n_next.text = "▶"
	btn_n_next.add_theme_font_size_override("font_size", 16)
	btn_n_next.custom_minimum_size = Vector2(44, 88)
	btn_n_next.pressed.connect(_nav_nivel.bind(1))
	fila_nivel.add_child(btn_n_next)

	# Separador fino entre secciones
	var linea := ColorRect.new()
	linea.color = Color(0.28, 0.22, 0.42, 0.5)
	linea.custom_minimum_size = Vector2(0, 1)
	caja.add_child(linea)

	# ── SECCIÓN PERSONAJE ────────────────────────────────────────────────────
	var sec_clase := VBoxContainer.new()
	sec_clase.add_theme_constant_override("separation", 8)
	caja.add_child(sec_clase)

	var lbl_clase_sec := Label.new()
	lbl_clase_sec.text = "PERSONAJE"
	lbl_clase_sec.add_theme_font_size_override("font_size", 11)
	lbl_clase_sec.add_theme_color_override("font_color", Color(0.5, 0.48, 0.62))
	lbl_clase_sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_clase.add_child(lbl_clase_sec)

	var fila_clase := HBoxContainer.new()
	fila_clase.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_clase.add_theme_constant_override("separation", 6)
	sec_clase.add_child(fila_clase)

	var btn_c_prev := Button.new()
	btn_c_prev.text = "◀"
	btn_c_prev.add_theme_font_size_override("font_size", 16)
	btn_c_prev.custom_minimum_size = Vector2(44, 44)
	btn_c_prev.pressed.connect(_nav_clase.bind(-1))
	fila_clase.add_child(btn_c_prev)

	_lbl_clase = Label.new()
	_lbl_clase.custom_minimum_size = Vector2(240, 0)
	_lbl_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_clase.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_lbl_clase.add_theme_font_size_override("font_size", 26)
	fila_clase.add_child(_lbl_clase)

	var btn_c_next := Button.new()
	btn_c_next.text = "▶"
	btn_c_next.add_theme_font_size_override("font_size", 16)
	btn_c_next.custom_minimum_size = Vector2(44, 44)
	btn_c_next.pressed.connect(_nav_clase.bind(1))
	fila_clase.add_child(btn_c_next)

	# ── BOTÓN JUGAR ──────────────────────────────────────────────────────────
	_btn_jugar = Button.new()
	_btn_jugar.text = "▶  JUGAR"
	_btn_jugar.custom_minimum_size = Vector2(340, 54)
	_btn_jugar.add_theme_font_size_override("font_size", 21)
	_btn_jugar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_jugar.pressed.connect(_confirmar)
	caja.add_child(_btn_jugar)

	# ── Estado inicial ────────────────────────────────────────────────────────
	_nivel_sel = mini(_estado.nivel_max_desbloqueado, NivelesScript.TOTAL - 1)
	var ultima: String = _estado.ultima_clase if "ultima_clase" in _estado else "guerrero"
	var idx := CLASES_ORDEN.find(ultima)
	_clase_idx = maxi(idx, 0)
	_refrescar()


func _mk_slot(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.content_margin_left   = 12
	s.content_margin_right  = 12
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	return s


func _crear_slot_nivel() -> PanelContainer:
	var cont := PanelContainer.new()
	cont.custom_minimum_size = Vector2(148, 88)
	cont.add_theme_stylebox_override("panel", _estilo_slot_normal)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	cont.add_child(vbox)
	var lbl_num := Label.new()
	lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_num)
	var lbl_nom := Label.new()
	lbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nom.add_theme_font_size_override("font_size", 11)
	lbl_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_nom.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(lbl_nom)
	var lbl_str := Label.new()
	lbl_str.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_str.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_str)
	return cont


func _refrescar() -> void:
	_oro.text = "Oro total: %d" % _estado.oro_total

	# ── Cabecera de Grieta ───────────────────────────────────────────────────
	var g_sel: Dictionary = Grietas.de_nivel(_nivel_sel)
	if g_sel.is_empty():
		var g_idx: int = _nivel_sel / Grietas.NIVELES_POR_GRIETA
		_estilo_grieta.bg_color     = Color(0.07, 0.06, 0.12, 0.85)
		_estilo_grieta.border_color = Color(0.28, 0.24, 0.38, 0.45)
		_lbl_grieta_nombre.text = "GRIETA " + Grietas.romano(g_idx)
		_lbl_grieta_nombre.add_theme_color_override("font_color", Color(0.40, 0.38, 0.52))
		_lbl_grieta_sub.text = "Próximamente"
		_lbl_grieta_sub.add_theme_color_override("font_color", Color(0.34, 0.32, 0.44))
		_lbl_grieta_rasgo.text = ""
		_lbl_sec_nivel.text = "NIVEL"
		_lbl_sec_nivel.add_theme_color_override("font_color", Color(0.5, 0.48, 0.62))
	else:
		var c: Color = g_sel.color
		_estilo_grieta.bg_color     = Color(c.r * 0.10, c.g * 0.13, c.b * 0.10, 0.92)
		_estilo_grieta.border_color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 0.65)
		_lbl_grieta_nombre.text = g_sel.nombre.to_upper()
		_lbl_grieta_nombre.add_theme_color_override("font_color", c)
		_lbl_grieta_sub.text = g_sel.subtitulo
		_lbl_grieta_sub.add_theme_color_override("font_color", c.lightened(0.28))
		_lbl_grieta_rasgo.text = g_sel.rasgo
		_lbl_grieta_rasgo.add_theme_color_override("font_color", Color(c.r * 0.75, c.g * 0.75, c.b * 0.75))
		var local_n: int = _nivel_sel % Grietas.NIVELES_POR_GRIETA
		_lbl_sec_nivel.text = "NIVEL  %d / %d" % [local_n + 1, Grietas.NIVELES_POR_GRIETA]
		_lbl_sec_nivel.add_theme_color_override("font_color", c.darkened(0.05))

	# ── Carrusel de niveles ──────────────────────────────────────────────────
	for slot_i in 3:
		var nivel_i: int = _nivel_sel - 1 + slot_i
		var cont: PanelContainer = _slots_nivel[slot_i]
		var hijos: Array = cont.get_child(0).get_children()
		var lbl_num: Label = hijos[0]
		var lbl_nom: Label = hijos[1]
		var lbl_str: Label = hijos[2]
		var es_sel: bool = (slot_i == 1)

		# Fuera de rango
		if nivel_i < 0 or nivel_i >= NivelesScript.TOTAL:
			lbl_num.text = ""; lbl_nom.text = ""; lbl_str.text = ""
			cont.modulate.a = 0.0
			continue

		# Nombre del nivel: usa el de la Grieta si existe, si no el de NivelesScript
		var nombre_niv: String = Grietas.nombre_nivel(nivel_i)
		if nombre_niv.is_empty():
			nombre_niv = NivelesScript.nombre(nivel_i)

		var es_boss: bool = Grietas.es_nivel_boss(nivel_i)

		# Bloqueado
		if nivel_i > _estado.nivel_max_desbloqueado:
			cont.modulate = Color(1, 1, 1, 0.50)
			cont.add_theme_stylebox_override("panel", _estilo_slot_bloq)
			lbl_num.text = "%d" % (nivel_i + 1)
			lbl_num.add_theme_font_size_override("font_size", 15)
			lbl_num.add_theme_color_override("font_color", Color(0.38, 0.36, 0.44))
			lbl_nom.text = nombre_niv
			lbl_nom.add_theme_font_size_override("font_size", 10)
			lbl_nom.add_theme_color_override("font_color", Color(0.30, 0.28, 0.36))
			lbl_str.add_theme_font_size_override("font_size", 11)
			if es_boss:
				lbl_str.text = "★ Jefe"
				lbl_str.add_theme_color_override("font_color", Color(0.38, 0.14, 0.12, 0.75))
			else:
				lbl_str.text = "- - -"
				lbl_str.add_theme_color_override("font_color", Color(0.28, 0.26, 0.34))
			continue

		# Desbloqueado
		var estrellas: int = _estado.estrellas_de(nivel_i)
		lbl_nom.text = nombre_niv

		if es_sel:
			if es_boss:
				cont.modulate = Color(1, 1, 1, 1)
				cont.add_theme_stylebox_override("panel", _estilo_slot_boss)
				lbl_num.text = "%d" % (nivel_i + 1)
				lbl_num.add_theme_font_size_override("font_size", 28)
				lbl_num.add_theme_color_override("font_color", Color(1.0, 0.30, 0.22))
				lbl_nom.add_theme_font_size_override("font_size", 12)
				lbl_nom.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68))
				lbl_str.text = "★  JEFE FINAL"
				lbl_str.add_theme_font_size_override("font_size", 13)
				lbl_str.add_theme_color_override("font_color", Color(1.0, 0.32, 0.24))
			else:
				cont.modulate = Color(1, 1, 1, 1)
				cont.add_theme_stylebox_override("panel", _estilo_slot_sel)
				lbl_num.text = "%d" % (nivel_i + 1)
				lbl_num.add_theme_font_size_override("font_size", 28)
				lbl_num.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
				lbl_nom.add_theme_font_size_override("font_size", 12)
				lbl_nom.add_theme_color_override("font_color", Color(0.88, 0.86, 0.72))
				lbl_str.text = "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
				lbl_str.add_theme_font_size_override("font_size", 13)
				lbl_str.add_theme_color_override("font_color", Color(1.0, 0.76, 0.14))
		else:
			if es_boss:
				cont.modulate = Color(1, 1, 1, 0.68)
				cont.add_theme_stylebox_override("panel", _estilo_slot_normal)
				lbl_num.text = "%d" % (nivel_i + 1)
				lbl_num.add_theme_font_size_override("font_size", 15)
				lbl_num.add_theme_color_override("font_color", Color(0.72, 0.28, 0.22))
				lbl_nom.add_theme_font_size_override("font_size", 10)
				lbl_nom.add_theme_color_override("font_color", Color(0.60, 0.26, 0.24))
				lbl_str.text = "★ jefe"
				lbl_str.add_theme_font_size_override("font_size", 11)
				lbl_str.add_theme_color_override("font_color", Color(0.62, 0.22, 0.18, 0.85))
			else:
				cont.modulate = Color(1, 1, 1, 0.68)
				cont.add_theme_stylebox_override("panel", _estilo_slot_normal)
				lbl_num.text = "%d" % (nivel_i + 1)
				lbl_num.add_theme_font_size_override("font_size", 15)
				lbl_num.add_theme_color_override("font_color", Color(0.66, 0.64, 0.76))
				lbl_nom.add_theme_font_size_override("font_size", 10)
				lbl_nom.add_theme_color_override("font_color", Color(0.52, 0.50, 0.62))
				lbl_str.text = "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
				lbl_str.add_theme_font_size_override("font_size", 11)
				lbl_str.add_theme_color_override("font_color", Color(0.66, 0.56, 0.24))

	# ── Clase y botón ────────────────────────────────────────────────────────
	var clave: String = CLASES_ORDEN[_clase_idx]
	var datos: Dictionary = Jugador.CLASES[clave]
	_lbl_clase.text = datos.nombre
	_lbl_clase.add_theme_color_override("font_color", datos.color.lightened(0.22))
	_btn_jugar.disabled = _nivel_sel > _estado.nivel_max_desbloqueado


func _nav_nivel(dir: int) -> void:
	var nuevo: int = clamp(_nivel_sel + dir, 0, mini(_estado.nivel_max_desbloqueado + 10, NivelesScript.TOTAL - 1))
	if nuevo != _nivel_sel:
		_nivel_sel = nuevo
		_refrescar()


func _nav_clase(dir: int) -> void:
	_clase_idx = (_clase_idx + dir + CLASES_ORDEN.size()) % CLASES_ORDEN.size()
	_refrescar()


func _confirmar() -> void:
	visible = false
	var g: Dictionary = Grietas.de_nivel(_nivel_sel)
	var tema: String = g.tema if not g.is_empty() else NivelesScript.tema(_nivel_sel)
	clase_elegida.emit(CLASES_ORDEN[_clase_idx], tema, _nivel_sel)
