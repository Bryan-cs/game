extends ArmaBase
## Dagas Fantasma: dagas espectrales hacia enemigos aleatorios (GDD sec. 8).
## Evolución: Danza Espectral (5 dagas, más daño y perforación).

const MODELO_DAGA := "res://art/models/armas/dagger.gltf"

var _cd := 0.0


func nombre() -> String:
	return "Dagas Fantasma"


func nombre_evolucion() -> String:
	return "Danza Espectral"


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var enemigos := get_tree().get_nodes_in_group("enemigos")
	if enemigos.is_empty():
		return
	_cd = maxf(0.45, 0.9 - 0.05 * nivel)
	var cantidad := 5 if evolucionada else 2
	for i in cantidad:
		var objetivo: Node3D = enemigos.pick_random()
		var direccion: Vector3 = objetivo.global_position - jugador.global_position
		direccion.y = 0.0
		if direccion.length() < 0.2:
			continue
		var proyectil := _proyectil_daga_fantasma()
		proyectil.direccion = direccion.normalized()
		proyectil.velocidad = 19.0
		proyectil.dano = jugador.calcular_dano((9.0 + 3.5 * nivel) * (1.4 if evolucionada else 1.0), "distancia")
		proyectil.perforaciones_restantes = 2 + (3 if evolucionada else 0)
		proyectil.look_at(proyectil.global_position + proyectil.direccion, Vector3.UP)
	Efectos.sonido(self, "dash", -8.0)


func _proyectil_daga_fantasma() -> Area3D:
	var proyectil := Area3D.new()
	proyectil.set_script(ProyectilScript)
	if ResourceLoader.exists(MODELO_DAGA):
		var daga: Node3D = (load(MODELO_DAGA) as PackedScene).instantiate()
		daga.scale = Vector3.ONE * 1.3
		daga.rotation.x = -PI / 2.0
		proyectil.add_child(daga)
	var brillo := SphereMesh.new()
	brillo.radius = 0.14
	brillo.height = 0.28
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.95, 0.85, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brillo.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = brillo
	proyectil.add_child(mesh)
	var forma := SphereShape3D.new()
	forma.radius = 0.3
	var colision := CollisionShape3D.new()
	colision.shape = forma
	proyectil.add_child(colision)
	get_tree().current_scene.add_child(proyectil)
	proyectil.global_position = jugador.global_position + Vector3.UP * 0.5
	return proyectil
