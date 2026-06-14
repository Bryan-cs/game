extends Node
## Smoke test Capa N5: iniciar un nivel aplica su tema y su jefe.

const NivelesScript := preload("res://scripts/niveles.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.nivel_max_desbloqueado = 40  # desbloquear hasta un nivel del bioma abismo
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	# Nivel 40 (índice) → bioma abismo, jefe rey_vacio
	main._iniciar_partida("guerrero", NivelesScript.tema(40), 40)
	await _esperar(0.3)
	_check("tema del nivel aplicado", main.mapa_actual == NivelesScript.tema(40))
	# Forzar jefe del nivel
	main.tiempo = NivelesScript.segundos_jefe(40) + 0.1
	await _esperar(0.4)
	var jefe_ok: bool = is_instance_valid(main.jefe) and main.jefe.tipo == NivelesScript.jefe(40)
	_check("jefe del nivel correcto", jefe_ok)
	get_tree().paused = false
	print("FIN TEST NIVEL CONFIG")
	get_tree().quit()
