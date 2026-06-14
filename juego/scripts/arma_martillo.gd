extends ArmaBase
## Martillo Sísmico: golpes de tierra en área sobre el enemigo más cercano (GDD sec. 8).
## Evolución: Terremoto (cada golpe genera 2 réplicas).

var _cd := 0.0


func nombre() -> String:
	return "Martillo Sísmico"


func nombre_evolucion() -> String:
	return "Terremoto"


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var objetivo := _enemigo_mas_cercano()
	if objetivo == null or objetivo.global_position.distance_to(jugador.global_position) > 11.0:
		return
	_cd = maxf(1.4, 3.0 - 0.15 * nivel)
	_golpe_sismico(objetivo.global_position, 1.0)
	if evolucionada:
		for k in 2:
			var offset := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			_golpe_sismico(objetivo.global_position + offset, 0.7)
	Efectos.sonido(self, "nova", -4.0)


func _golpe_sismico(centro: Vector3, factor: float) -> void:
	var radio := (2.5 + 0.2 * nivel) * factor
	var dano := jugador.calcular_dano((20.0 + 8.0 * nivel) * factor * (1.3 if evolucionada else 1.0), "melee")
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - centro
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		if enemigo.has_method("aplicar_empuje") and hacia.length() > 0.1:
			enemigo.aplicar_empuje(hacia.normalized() * 5.0)
		enemigo.recibir_dano(dano)
	Efectos.onda(get_tree().current_scene, centro, radio, Color(0.75, 0.6, 0.35))
	Efectos.explosion(get_tree().current_scene, centro + Vector3.UP * 0.3, Color(0.6, 0.5, 0.3), 18, 1.2)
