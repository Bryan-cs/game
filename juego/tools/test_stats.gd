extends Node
## Smoke test Capa 1: hoja de stats como fuente única de verdad.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await _esperar(0.4)
	var j = main.jugador
	var s = j.stats
	# 1. La clase vuelca sus datos a la hoja
	_check("vida de clase en hoja", absf(s.vida_max - j.vida_max) < 0.01 and j.vida_max >= 150.0)
	# 2. Daño melee escala con melee_pct y no con distancia_pct (determinista: sin crit ni dano_pct)
	s.critico_pct = 0.0
	s.dano_pct = 0.0
	s.melee_pct = 100.0
	s.distancia_pct = 0.0
	_check("melee x2 con +100% melee", absf(j.calcular_dano(10.0, "melee") - 20.0) < 0.01)
	_check("distancia ignora melee_pct", absf(j.calcular_dano(10.0, "distancia") - 10.0) < 0.01)
	# 3. Propiedad legacy mult_dano hace roundtrip a la hoja (main.gd la usa con *=)
	j.mult_dano *= 1.5
	_check("mult_dano roundtrip", absf(s.dano_pct - 50.0) < 0.01)
	s.dano_pct = 0.0
	# 4. Armadura reduce el daño recibido
	s.armadura = 15.0  # reducción 50%
	j._invulnerable = 0.0
	var antes: float = j.vida
	j.recibir_dano(40.0)
	_check("armadura 15 reduce 50%", absf((antes - j.vida) - 20.0) < 0.5)
	# 5. Esquiva con tope 60%
	s.esquiva_pct = 100.0
	_check("esquiva tope 60", absf(s.prob_esquiva() - 0.6) < 0.001)
	# 6. Velocidad como propiedad sobre la hoja
	var v0: float = j.velocidad
	j.velocidad *= 1.2
	_check("velocidad +20%", absf(j.velocidad - v0 * 1.2) < 0.01)
	# 7. Velocidad de ataque
	s.vel_ataque_pct = 100.0
	_check("cadencia x2", absf(s.mult_cadencia() - 2.0) < 0.01)
	# 8. Robo de vida en melee
	s.robo_vida = 10.0
	var zombi = main._generar_enemigo("zombie")
	zombi.global_position = j.global_position + Vector3(1.5, 1.2, 0.0)
	zombi.velocidad = 0.0
	j.vida = 50.0
	j._ataque_melee(Vector3(1, 0, 0), j.ATAQUES["guerrero"])
	_check("robo de vida cura", j.vida > 50.0)
	print("FIN TEST STATS")
	get_tree().quit()
