class_name EstiloUI
extends Object
## Tema gótico compartido: botones negro metálico, bordes finos, glow púrpura,
## títulos metálicos con halo. Dirección de arte: Diablo / V Rising / Hades.

const MORADO := Color(0.62, 0.42, 0.95)
const MORADO_CLARO := Color(0.85, 0.7, 1.0)
const PLATA := Color(0.84, 0.82, 0.9)
const CARMESI := Color(0.78, 0.16, 0.22)
const FONDO_PANEL := Color(0.05, 0.045, 0.09, 0.96)


static func tema() -> Theme:
	var t := Theme.new()
	var normal := _caja(Color(0.08, 0.07, 0.125, 0.92), Color(0.3, 0.24, 0.45))
	var hover := _caja(Color(0.13, 0.1, 0.21, 0.96), MORADO)
	hover.shadow_color = Color(MORADO.r, MORADO.g, MORADO.b, 0.4)
	hover.shadow_size = 8
	var pulsado := _caja(Color(0.05, 0.04, 0.08, 0.96), CARMESI)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pulsado)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", _caja(Color(0.06, 0.055, 0.09, 0.7), Color(0.2, 0.18, 0.28)))
	t.set_color("font_color", "Button", PLATA)
	t.set_color("font_hover_color", "Button", MORADO_CLARO)
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.6, 0.6))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.52))
	var panel := _caja(FONDO_PANEL, Color(0.34, 0.27, 0.52))
	panel.set_content_margin_all(26.0)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", PLATA)
	return t


static func _caja(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.set_corner_radius_all(5)
	s.set_border_width_all(1)
	s.border_color = borde
	s.content_margin_left = 20.0
	s.content_margin_right = 20.0
	s.content_margin_top = 9.0
	s.content_margin_bottom = 9.0
	return s


static func titulo_epico(etiqueta: Label, tam: int, halo := MORADO) -> void:
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", Color(0.9, 0.87, 0.97))
	etiqueta.add_theme_color_override("font_outline_color", Color(halo.r * 0.5, halo.g * 0.5, halo.b * 0.5))
	etiqueta.add_theme_constant_override("outline_size", maxi(3, tam / 7))
	etiqueta.add_theme_color_override("font_shadow_color", Color(halo.r, halo.g, halo.b, 0.55))
	etiqueta.add_theme_constant_override("shadow_offset_x", 0)
	etiqueta.add_theme_constant_override("shadow_offset_y", 5)
	etiqueta.add_theme_constant_override("shadow_outline_size", 10)


static func vineta(padre: Node) -> void:
	var capa := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55)])
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	capa.texture = tex
	capa.stretch_mode = TextureRect.STRETCH_SCALE
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(capa)


static func brasas(padre: Node, cantidad := 40) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = cantidad
	p.lifetime = 7.0
	p.preprocess = 5.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1000, 30, 1)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 75.0
	mat.scale_min = 0.3
	mat.scale_max = 1.0
	var rampa := Gradient.new()
	rampa.colors = PackedColorArray([Color(0.85, 0.4, 1.0, 0.0), Color(0.8, 0.35, 0.95, 0.85), Color(0.9, 0.2, 0.25, 0.0)])
	rampa.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var textura_rampa := GradientTexture1D.new()
	textura_rampa.gradient = rampa
	mat.color_ramp = textura_rampa
	p.process_material = mat
	var punto := Gradient.new()
	punto.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex_punto := GradientTexture2D.new()
	tex_punto.gradient = punto
	tex_punto.fill = GradientTexture2D.FILL_RADIAL
	tex_punto.fill_from = Vector2(0.5, 0.5)
	tex_punto.fill_to = Vector2(0.5, 0.0)
	tex_punto.width = 14
	tex_punto.height = 14
	p.texture = tex_punto
	padre.add_child(p)
	return p


static func luna_sangre(padre: Node) -> void:
	var luna := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.9, 0.25, 0.25, 0.9), Color(0.65, 0.12, 0.2, 0.5), Color(0.4, 0.05, 0.15, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 420
	tex.height = 420
	luna.texture = tex
	luna.anchor_left = 1.0
	luna.anchor_right = 1.0
	luna.offset_left = -520.0
	luna.offset_top = 40.0
	luna.offset_right = -100.0
	luna.offset_bottom = 460.0
	luna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(luna)
