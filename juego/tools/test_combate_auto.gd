extends Node
## Smoke test Capa 0: el ataque primario es 100% automático (sin input).

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)


func _limpiar_enemigos() -> void:
	for e in get_tree().get_nodes_in_group("enemigos"):
		e.queue_free()
	await _esperar(0.1)


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await _esperar(0.4)
	var j = main.jugador

	# 1. Sin enemigos no dispara: _atacar() nunca se llama, así que _cd_disparo queda en 0
	await _limpiar_enemigos()
	j._cd_disparo = 0.0
	await _esperar(0.5)
	_check("sin enemigos no dispara", j._cd_disparo <= 0.01)

	# Usamos un enemigo duro (caballero_oscuro, 130 HP) que sobrevive al primer golpe:
	# así el daño se mide por vida decreciente (no por muerte trivial) y el objetivo
	# sigue válido para comprobar el auto-apuntado.
	await _limpiar_enemigos()
	var enemigo: Node3D = main._generar_enemigo("caballero_oscuro")
	enemigo.global_position = j.global_position + Vector3(1.8, 0.0, 0.0)
	enemigo.velocidad = 0.0
	var vida_inicial: float = enemigo.vida

	# 2. El auto-apuntado elige al enemigo más cercano (contrato de comportamiento).
	await _esperar(0.05)
	_check("apunta al más cercano", is_instance_valid(enemigo) and j._enemigo_cercano() == enemigo)

	# 3. SIN input, el auto-ataque le hace daño (vida baja).
	await _esperar(1.0)
	var recibio_dano: bool = (not is_instance_valid(enemigo)) or enemigo.vida < vida_inicial
	_check("auto-ataque daña sin input", recibio_dano)

	print("FIN TEST COMBATE AUTO")
	get_tree().quit()
