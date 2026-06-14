extends CanvasLayer
## Inventario estilo Undead Slayer: panel de equipo + grid de mochila con rareza,
## panel de detalle y venta. Botón cerrar siempre visible (EQ2 / rediseño UX).

const EquipamientoScript := preload("res://scripts/equipamiento.gd")
const IconoRenderScript := preload("res://scripts/icono_render.gd")

const NOMBRE_SLOT := {
	"arma": "Arma", "casco": "Casco", "armadura": "Coraza", "botas": "Botas", "anillo": "Anillo",
}

var _estado: Node
var _monedas: Label
var _slots_caja: HBoxContainer
var _grid: GridContainer
var _detalle: VBoxContainer
var _sel := -1  # índice seleccionado en la mochila

var _iconos: Node  # IconoRender (tipado como Node para evitar resolución de class_name en --check-only)
var _texs: Dictionary = {}          # tipo_visual -> Texture2D
var _vp_personaje: SubViewport
var _pivote_pj: Node3D
var _clase_preview := "guerrero"
const CLASES_PREVIEW := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]


func _ready() -> void:
	layer = 26
	visible = false
	_estado = get_node(^"/root/Estado")

	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.025, 0.06, 0.97)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 48)
	add_child(margen)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 16)
	margen.add_child(raiz)

	# --- Cabecera: título + monedas + CERRAR (siempre visible) ---
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 20)
	raiz.add_child(cab)
	var titulo := Label.new()
	titulo.text = "INVENTARIO"
	EstiloUI.titulo_epico(titulo, 34)
	cab.add_child(titulo)
	var empuje := Control.new()
	empuje.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(empuje)
	_monedas = Label.new()
	_monedas.add_theme_font_size_override("font_size", 20)
	_monedas.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_monedas.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cab.add_child(_monedas)
	var cerrar := Button.new()
	cerrar.text = "✕  CERRAR"
	cerrar.custom_minimum_size = Vector2(170, 52)
	cerrar.add_theme_font_size_override("font_size", 20)
	cerrar.pressed.connect(func() -> void: visible = false)
	cab.add_child(cerrar)

	# --- Equipo: 5 slots en fila ---
	var lbl_eq := Label.new()
	lbl_eq.text = "EQUIPO"
	lbl_eq.add_theme_font_size_override("font_size", 16)
	lbl_eq.add_theme_color_override("font_color", Color(0.62, 0.6, 0.78))
	raiz.add_child(lbl_eq)
	_slots_caja = HBoxContainer.new()
	_slots_caja.add_theme_constant_override("separation", 12)
	raiz.add_child(_slots_caja)

	# --- Mochila (grid) + detalle, lado a lado ---
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 18)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(cuerpo)

	# --- Preview 3D del personaje + ciclado de clase ---
	var col_pj := VBoxContainer.new()
	col_pj.add_theme_constant_override("separation", 8)
	cuerpo.add_child(col_pj)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(280, 420)
	col_pj.add_child(cont)
	_vp_personaje = SubViewport.new()
	_vp_personaje.own_world_3d = true
	_vp_personaje.transparent_bg = true
	_vp_personaje.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_vp_personaje)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 40, 0)
	luz.light_energy = 1.3
	_vp_personaje.add_child(luz)
	_pivote_pj = Node3D.new()
	_vp_personaje.add_child(_pivote_pj)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 5.2)
	cam.fov = 32.0
	_vp_personaje.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	var fila_clase := HBoxContainer.new()
	fila_clase.alignment = BoxContainer.ALIGNMENT_CENTER
	col_pj.add_child(fila_clase)
	var b_prev := Button.new()
	b_prev.text = "◀"
	b_prev.pressed.connect(func() -> void: _ciclar_clase(-1))
	fila_clase.add_child(b_prev)
	var lbl_clase := Label.new()
	lbl_clase.name = "LblClase"
	lbl_clase.custom_minimum_size = Vector2(160, 0)
	lbl_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila_clase.add_child(lbl_clase)
	var b_next := Button.new()
	b_next.text = "▶"
	b_next.pressed.connect(func() -> void: _ciclar_clase(1))
	fila_clase.add_child(b_next)

	var col_mochila := VBoxContainer.new()
	col_mochila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(col_mochila)
	var lbl_inv := Label.new()
	lbl_inv.text = "MOCHILA"
	lbl_inv.add_theme_font_size_override("font_size", 16)
	lbl_inv.add_theme_color_override("font_color", Color(0.62, 0.6, 0.78))
	col_mochila.add_child(lbl_inv)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(900, 520)
	col_mochila.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	# Panel de detalle de la pieza seleccionada
	var panel_det := PanelContainer.new()
	panel_det.custom_minimum_size = Vector2(420, 0)
	cuerpo.add_child(panel_det)
	_detalle = VBoxContainer.new()
	_detalle.add_theme_constant_override("separation", 10)
	panel_det.add_child(_detalle)

	_iconos = IconoRenderScript.new()
	add_child(_iconos)


func abrir() -> void:
	visible = true
	_sel = -1
	if _estado.has_method("get") and "ultima_clase" in _estado:
		_clase_preview = _estado.ultima_clase
	await _pregenerar_iconos()
	_construir_personaje()
	_refrescar()


func _pregenerar_iconos() -> void:
	var tipos := EquipamientoScript.TIPOS_ARMA + EquipamientoScript.ICONO_SLOT.values()
	for t in tipos:
		if not _texs.has(t):
			_texs[t] = await _iconos.generar(t, self)


func _tex_pieza(pieza: Dictionary) -> Texture2D:
	var t: String = pieza.get("tipo_visual", "")
	return _texs.get(t, null)


func _ciclar_clase(dir: int) -> void:
	var i: int = CLASES_PREVIEW.find(_clase_preview)
	i = (i + dir + CLASES_PREVIEW.size()) % CLASES_PREVIEW.size()
	_clase_preview = CLASES_PREVIEW[i]
	_construir_personaje()


func _construir_personaje() -> void:
	for h in _pivote_pj.get_children():
		h.queue_free()
	var lbl := find_child("LblClase", true, false)
	if lbl:
		lbl.text = _clase_preview.capitalize()
	var info: Dictionary = JugadorScriptInfo()
	if info.has("ruta") and ResourceLoader.exists(info.ruta):
		var modelo := (load(info.ruta) as PackedScene).instantiate()
		modelo.scale = Vector3.ONE * 0.8
		modelo.position.y = 0.0
		_pivote_pj.add_child(modelo)
	# Arma equipada visible junto al personaje
	if _estado.equipado.has("arma"):
		var tipo: String = _estado.equipado["arma"].get("tipo_visual", "espada")
		var malla := EquipoScript_malla(tipo)
		if malla:
			malla.position = Vector3(0.45, 1.0, 0.2)
			malla.scale = Vector3.ONE * 0.9
			_pivote_pj.add_child(malla)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(_pivote_pj):
		_pivote_pj.rotate_y(_delta * 0.6)


func JugadorScriptInfo() -> Dictionary:
	var modelos = load("res://scripts/jugador.gd").MODELOS
	return modelos.get(_clase_preview, {})


func EquipoScript_malla(tipo: String) -> Node3D:
	return load("res://scripts/equipo.gd").malla_item(tipo)


# --- Helpers de presentación -------------------------------------------------

func _color_rareza(rareza: String) -> Color:
	return EquipamientoScript.RAREZAS.get(rareza, {}).get("color", Color(0.8, 0.8, 0.8))


func _tier(rareza: String) -> int:
	return EquipamientoScript.ORDEN_RAREZA.find(rareza) + 1


func _estilo_celda(rareza: String, seleccionada := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var col := _color_rareza(rareza)
	sb.bg_color = Color(0.08, 0.07, 0.12) if not seleccionada else col.darkened(0.55)
	sb.set_border_width_all(3 if not seleccionada else 5)
	sb.border_color = col
	sb.set_corner_radius_all(6)
	return sb


func _texto_afijos(pieza: Dictionary) -> String:
	var t := ""
	for stat in pieza.get("afijos", {}):
		t += "+%s  %s\n" % [str(pieza.afijos[stat]), stat]
	return t


# --- Refresco ----------------------------------------------------------------

func _refrescar() -> void:
	_monedas.text = "Oro: %d      Gemas: %d" % [_estado.oro_total, _estado.gemas]
	_refrescar_equipo()
	_refrescar_mochila()
	_refrescar_detalle()


func _refrescar_equipo() -> void:
	for h in _slots_caja.get_children():
		h.queue_free()
	for slot in EquipamientoScript.SLOTS:
		var celda := Button.new()
		celda.custom_minimum_size = Vector2(150, 92)
		celda.clip_text = true
		celda.add_theme_font_size_override("font_size", 13)
		if _estado.equipado.has(slot):
			var pieza: Dictionary = _estado.equipado[slot]
			var rareza: String = pieza.get("rareza", "Común")
			celda.add_theme_stylebox_override("normal", _estilo_celda(rareza))
			var tex_eq := _tex_pieza(pieza)
			if tex_eq:
				celda.icon = tex_eq
				celda.expand_icon = true
				celda.add_theme_constant_override("icon_max_width", 56)
			celda.text = "%s\n%s\n%s" % [NOMBRE_SLOT.get(slot, slot), rareza, "★".repeat(_tier(rareza))]
			celda.add_theme_color_override("font_color", _color_rareza(rareza))
			celda.pressed.connect(func() -> void:
				_estado.desequipar(slot)
				_sel = -1
				_refrescar())
		else:
			var vacia := StyleBoxFlat.new()
			vacia.bg_color = Color(0.06, 0.055, 0.09)
			vacia.set_border_width_all(2)
			vacia.border_color = Color(0.25, 0.24, 0.32)
			vacia.set_corner_radius_all(6)
			celda.add_theme_stylebox_override("normal", vacia)
			celda.text = NOMBRE_SLOT.get(slot, slot) + "\n(vacío)"
			celda.add_theme_color_override("font_color", Color(0.45, 0.43, 0.55))
			celda.disabled = true
		_slots_caja.add_child(celda)


func _refrescar_mochila() -> void:
	for h in _grid.get_children():
		h.queue_free()
	if _estado.inventario.is_empty():
		var vacio := Label.new()
		vacio.text = "Mochila vacía. Abre cofres para conseguir equipo."
		vacio.add_theme_color_override("font_color", Color(0.5, 0.48, 0.6))
		_grid.add_child(vacio)
		return
	for i in _estado.inventario.size():
		var pieza: Dictionary = _estado.inventario[i]
		var rareza: String = pieza.get("rareza", "Común")
		var celda := Button.new()
		celda.custom_minimum_size = Vector2(120, 120)
		celda.clip_text = true
		celda.add_theme_font_size_override("font_size", 13)
		celda.add_theme_stylebox_override("normal", _estilo_celda(rareza, i == _sel))
		celda.add_theme_stylebox_override("hover", _estilo_celda(rareza, true))
		celda.add_theme_stylebox_override("pressed", _estilo_celda(rareza, true))
		var afin: String = pieza.get("afinidad", "ninguna")
		var marca := "" if afin == "ninguna" else "◆"
		var tex := _tex_pieza(pieza)
		if tex:
			celda.icon = tex
			celda.expand_icon = true
			celda.add_theme_constant_override("icon_max_width", 84)
			celda.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		celda.text = "\n\n%s %s" % ["★".repeat(_tier(rareza)), marca]
		celda.add_theme_color_override("font_color", _color_rareza(rareza))
		var idx: int = i
		celda.pressed.connect(func() -> void:
			_sel = idx
			_refrescar())
		_grid.add_child(celda)


func _refrescar_detalle() -> void:
	for h in _detalle.get_children():
		h.queue_free()
	if _sel < 0 or _sel >= _estado.inventario.size():
		var ayuda := Label.new()
		ayuda.text = "Selecciona una pieza\nde la mochila"
		ayuda.add_theme_color_override("font_color", Color(0.5, 0.48, 0.6))
		ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detalle.add_child(ayuda)
		return
	var pieza: Dictionary = _estado.inventario[_sel]
	var rareza: String = pieza.get("rareza", "Común")
	var titulo := Label.new()
	titulo.text = "%s — %s" % [NOMBRE_SLOT.get(pieza.get("slot", ""), "?"), rareza]
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", _color_rareza(rareza))
	_detalle.add_child(titulo)
	var afin: String = pieza.get("afinidad", "ninguna")
	if afin != "ninguna":
		var laf := Label.new()
		laf.text = "Afinidad: %s (+25%%)" % afin
		laf.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		_detalle.add_child(laf)
	var afijos := Label.new()
	afijos.text = _texto_afijos(pieza)
	afijos.add_theme_font_size_override("font_size", 17)
	_detalle.add_child(afijos)

	var b_eq := Button.new()
	b_eq.text = "EQUIPAR"
	b_eq.custom_minimum_size = Vector2(0, 48)
	b_eq.pressed.connect(func() -> void:
		_estado.equipar(_sel)
		_sel = -1
		_refrescar())
	_detalle.add_child(b_eq)

	var b_vend := Button.new()
	b_vend.text = "VENDER  ·  %d oro" % EquipamientoScript.valor_venta(rareza)
	b_vend.custom_minimum_size = Vector2(0, 44)
	b_vend.pressed.connect(func() -> void:
		_estado.vender_pieza(_sel)
		_sel = -1
		_refrescar())
	_detalle.add_child(b_vend)
