extends ArmaBase
## Cadena Eléctrica: rayo que salta entre enemigos cercanos (GDD sec. 8).
## Evolución: Tormenta Eléctrica (el doble de saltos y mini-explosión por salto).

var _cd := 0.0


func nombre() -> String:
	return "Cadena Eléctrica"


func nombre_evolucion() -> String:
	return "Tormenta Eléctrica"


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var objetivo := _enemigo_mas_cercano()
	if objetivo == null or objetivo.global_position.distance_to(jugador.global_position) > 12.0:
		return
	_cd = maxf(0.15, (1.6 - 0.1 * nivel) / jugador.stats.mult_cadencia())
	var saltos := 2 + nivel / 2
	if evolucionada:
		saltos *= 2
	var dano := jugador.calcular_dano((12.0 + 5.0 * nivel) * (1.3 if evolucionada else 1.0), "distancia")
	var golpeados: Array = []
	var actual: Node3D = objetivo
	var origen: Vector3 = jugador.global_position + Vector3.UP * 0.8
	for salto in saltos + 1:
		if actual == null:
			break
		_segmento_rayo(origen, actual.global_position + Vector3.UP * 0.8)
		actual.recibir_dano(dano)
		if evolucionada:
			Efectos.explosion(get_tree().current_scene, actual.global_position + Vector3.UP * 0.5, Color(0.5, 0.8, 1.0), 10, 0.7)
		golpeados.append(actual)
		origen = actual.global_position + Vector3.UP * 0.8
		# siguiente eslabón: enemigo más cercano al actual no golpeado aún
		var siguiente: Node3D = null
		var mejor := 6.0
		for enemigo in get_tree().get_nodes_in_group("enemigos"):
			if enemigo in golpeados:
				continue
			var d: float = enemigo.global_position.distance_to(actual.global_position)
			if d < mejor:
				mejor = d
				siguiente = enemigo
		actual = siguiente
	# Si no hubo cadena (boss aislado), descarga adicional al 50% en el objetivo original.
	if golpeados.size() == 1 and is_instance_valid(golpeados[0]):
		golpeados[0].recibir_dano(dano * 0.5)
	Efectos.sonido(self, "golpe", -6.0)


func _segmento_rayo(desde: Vector3, hasta: Vector3) -> void:
	var largo := desde.distance_to(hasta)
	if largo < 0.1:
		return
	var malla := BoxMesh.new()
	malla.size = Vector3(0.07, 0.07, largo)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	var segmento := MeshInstance3D.new()
	segmento.mesh = malla
	get_tree().current_scene.add_child(segmento)
	segmento.global_position = (desde + hasta) * 0.5
	segmento.look_at(hasta, Vector3.UP)
	var tween := segmento.create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(segmento.queue_free)
