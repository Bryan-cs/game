class_name Efectos
extends Object
## Utilidades estáticas: partículas one-shot y acceso al gestor de sonido.


static func explosion(padre: Node, pos: Vector3, color: Color, cantidad := 24, escala := 1.0) -> void:
	var pool = padre.get_tree().get_first_node_in_group("pool_fx")
	if pool:
		pool.explosion(pos, color, escala)
		return
	var particulas := GPUParticles3D.new()
	particulas.one_shot = true
	particulas.amount = cantidad
	particulas.lifetime = 0.6
	particulas.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0 * escala
	mat.initial_velocity_max = 7.0 * escala
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = color
	particulas.process_material = mat
	var malla := SphereMesh.new()
	malla.radius = 0.07 * escala
	malla.height = 0.14 * escala
	var visual := StandardMaterial3D.new()
	visual.albedo_color = color
	visual.emission_enabled = true
	visual.emission = color
	visual.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.vertex_color_use_as_albedo = true
	malla.material = visual
	particulas.draw_pass_1 = malla
	padre.add_child(particulas)
	particulas.global_position = pos
	particulas.emitting = true
	particulas.finished.connect(particulas.queue_free)


static func explosion_grande(padre: Node, pos: Vector3, color: Color) -> void:
	explosion(padre, pos, color, 40, 2.2)
	explosion(padre, pos + Vector3(0.8, 0.4, 0.5), color.lightened(0.3), 22, 1.4)
	explosion(padre, pos + Vector3(-0.7, 0.6, -0.6), color, 22, 1.4)


static func onda(padre: Node, pos: Vector3, radio: float, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var malla := TorusMesh.new()
	malla.inner_radius = 0.85
	malla.outer_radius = 1.0
	malla.material = mat
	var anillo := MeshInstance3D.new()
	anillo.mesh = malla
	padre.add_child(anillo)
	anillo.global_position = pos
	anillo.scale = Vector3.ONE * 0.3
	var tween := anillo.create_tween()
	tween.tween_property(anillo, "scale", Vector3.ONE * radio, 0.4)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(anillo.queue_free)


static func numero_dano(padre: Node, pos: Vector3, cantidad: float, color := Color(1, 1, 1)) -> void:
	var pool = padre.get_tree().get_first_node_in_group("pool_fx")
	if pool:
		pool.numero(pos, cantidad, color)
		return
	var etiqueta := Label3D.new()
	etiqueta.text = str(int(maxf(cantidad, 1.0)))
	etiqueta.font_size = 56 if cantidad >= 30.0 else 38
	etiqueta.modulate = color
	etiqueta.outline_size = 10
	etiqueta.outline_modulate = Color(0, 0, 0, 0.9)
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.pixel_size = 0.01
	padre.add_child(etiqueta)
	etiqueta.global_position = pos + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.2, 0.2))
	var tween := etiqueta.create_tween()
	tween.tween_property(etiqueta, "global_position", etiqueta.global_position + Vector3.UP * 1.3, 0.55)
	tween.parallel().tween_property(etiqueta, "modulate:a", 0.0, 0.55)
	tween.tween_callback(etiqueta.queue_free)


static func sonido(nodo: Node, nombre: String, volumen_db := 0.0) -> void:
	var gestor = nodo.get_tree().get_first_node_in_group("sonido")
	if gestor:
		gestor.tocar(nombre, volumen_db)
