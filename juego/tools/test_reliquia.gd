extends Node
## Smoke: matar un jefe debe abrir el menú de reliquias (1 de 3).

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	main.oleada = 5
	main._invocar_jefe("gigante_putrefacto")
	await get_tree().create_timer(0.2).timeout
	main.jefe.recibir_dano(99999.0)
	await get_tree().create_timer(0.3).timeout
	print("menu reliquia visible: ", main.menu.visible, " | titulo: ", main.menu._titulo.text, " | opciones: ", main._opciones_actuales.size())
	main._al_elegir_mejora(0)
	await get_tree().create_timer(0.2).timeout
	print("reliquias de la run: ", main._reliquias_run)
	get_tree().quit()
