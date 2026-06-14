extends Node
## Smoke test Capa N2: aparece jefe, matarlo completa el nivel y desbloquea el siguiente.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.nivel_max_desbloqueado = 0
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)

	# Forzar la aparición del jefe sin esperar 60 s reales.
	main.tiempo = main.SEGUNDOS_HASTA_JEFE + 0.1
	await _esperar(0.4)
	var jefe_vivo: bool = is_instance_valid(main.jefe) and main.jefe.es_jefe
	_check("aparece el jefe del nivel", jefe_vivo)

	# Matar al jefe (daño masivo) y comprobar compleción.
	if jefe_vivo:
		main.jefe.recibir_dano(999999.0)
	await _esperar(0.5)
	_check("nivel completado pausa la partida", not main.partida_activa and get_tree().paused)
	_check("desbloquea el siguiente nivel", estado.nivel_max_desbloqueado >= 1)

	get_tree().paused = false
	print("FIN TEST NIVEL")
	get_tree().quit()
