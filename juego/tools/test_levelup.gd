extends Node
## Smoke test Capa N3: al subir de nivel se PAUSA y aparecen 3 cards de mejora.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)
	await _esperar(0.3)
	var j = main.jugador

	# Forzar subir de nivel: dar XP suficiente para superar xp_necesaria.
	j.ganar_xp(j.xp_necesaria + 5.0)
	await _esperar(0.3)

	_check("subir de nivel pausa el juego", get_tree().paused)
	_check("aparece el menu de mejoras", main.menu.visible)
	_check("ofrece 3 cards", main._opciones_actuales.size() == 3)

	# Elegir la primera card despausa.
	main._al_elegir_mejora(0)
	await _esperar(0.2)
	_check("elegir card reanuda el juego", not get_tree().paused)

	print("FIN TEST LEVELUP")
	get_tree().quit()
