extends Node
## Pool de efectos reutilizables: números de daño (Label3D) y explosiones
## (GPUParticles3D). Evita instanciar/liberar nodos en mitad del combate.

var _etiquetas: Array[Label3D] = []
var _particulas: Array[GPUParticles3D] = []


func _ready() -> void:
	add_to_group("pool_fx")
	for i in 60:
		_etiquetas.append(_nueva_etiqueta())
	for i in 14:
		_particulas.append(_nueva_particula())


func _nueva_etiqueta() -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.outline_size = 10
	etiqueta.outline_modulate = Color(0, 0, 0, 0.9)
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.pixel_size = 0.01
	etiqueta.visible = false
	add_child(etiqueta)
	return etiqueta


func numero(pos: Vector3, cantidad: float, color: Color) -> void:
	var etiqueta: Label3D = null
	for candidata in _etiquetas:
		if not candidata.visible:
			etiqueta = candidata
			break
	if etiqueta == null:
		return  # pool agotado: descartar antes que alocar en plena horda
	etiqueta.text = str(int(maxf(cantidad, 1.0)))
	etiqueta.font_size = 56 if cantidad >= 30.0 else 38
	etiqueta.modulate = Color(color.r, color.g, color.b, 1.0)
	etiqueta.global_position = pos + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.2, 0.2))
	etiqueta.visible = true
	var tween := etiqueta.create_tween()
	tween.tween_property(etiqueta, "global_position", etiqueta.global_position + Vector3.UP * 1.3, 0.55)
	tween.parallel().tween_property(etiqueta, "modulate:a", 0.0, 0.55)
	tween.tween_callback(func() -> void: etiqueta.visible = false)


func _nueva_particula() -> GPUParticles3D:
	var particulas := GPUParticles3D.new()
	particulas.one_shot = true
	particulas.amount = 24
	particulas.lifetime = 0.6
	particulas.explosiveness = 1.0
	particulas.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, -9.0, 0)
	particulas.process_material = mat
	var malla := SphereMesh.new()
	malla.radius = 0.07
	malla.height = 0.14
	var visual := StandardMaterial3D.new()
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.vertex_color_use_as_albedo = true
	visual.emission_enabled = true
	visual.emission = Color(1, 1, 1)
	malla.material = visual
	particulas.draw_pass_1 = malla
	add_child(particulas)
	return particulas


func explosion(pos: Vector3, color: Color, escala := 1.0) -> void:
	var particulas: GPUParticles3D = null
	for candidata in _particulas:
		if not candidata.emitting:
			particulas = candidata
			break
	if particulas == null:
		return
	var mat: ParticleProcessMaterial = particulas.process_material
	mat.color = color
	mat.initial_velocity_min = 3.0 * escala
	mat.initial_velocity_max = 7.0 * escala
	mat.scale_min = 0.5 * escala
	mat.scale_max = 1.2 * escala
	particulas.global_position = pos
	particulas.restart()
