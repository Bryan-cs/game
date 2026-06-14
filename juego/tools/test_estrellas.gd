extends Node
## Smoke test Capa N4: completar rápido da 3 estrellas y se persiste el máximo.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.estrellas_nivel = {}
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)

	# Forzar jefe justo en el umbral y matarlo de inmediato → tiempo bajo → 3 estrellas.
	main.tiempo = main.SEGUNDOS_HASTA_JEFE + 0.1
	await _esperar(0.4)
	if is_instance_valid(main.jefe):
		main.jefe.recibir_dano(999999.0)
	await _esperar(0.5)

	_check("3 estrellas por completar rápido", estado.estrellas_de(0) == 3)

	# Registrar una calificación peor no debe rebajar el máximo.
	estado.registrar_estrellas(0, 1)
	_check("guarda el máximo (no rebaja)", estado.estrellas_de(0) == 3)

	get_tree().paused = false
	print("FIN TEST ESTRELLAS")
	get_tree().quit()
