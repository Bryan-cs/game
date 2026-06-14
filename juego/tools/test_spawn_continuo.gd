extends Node
## Smoke test Capa N1: spawn continuo, sin oleadas/tienda, XP puro.

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
	await _esperar(3.0)
	# 1. Spawn continuo: hay enemigos vivos sin sistema de oleadas
	var n = get_tree().get_nodes_in_group("enemigos").size()
	_check("spawn continuo genera enemigos", n > 0)
	# 2. No quedan referencias a oleadas (la variable ya no existe en main)
	_check("sin variable oleada", not ("oleada" in main))
	# 3. La gema da XP pero NO incrementa una moneda de almas de run
	#    (main ya no define sumar_almas)
	_check("sin sumar_almas en director", not main.has_method("sumar_almas"))
	# 4. La partida sigue activa (no se autodetuvo por falta de oleadas)
	_check("partida activa", main.partida_activa)
	print("FIN TEST SPAWN CONTINUO")
	get_tree().quit()
