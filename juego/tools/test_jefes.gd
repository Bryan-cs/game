extends Node
## Smoke test del ciclo de jefes: invoca al rey_vacio y verifica la pantalla de fin de partida.

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	main._invocar_jefe("rey_vacio")
	main.jefe.global_position = Vector3(6, 1.2, 0)
	await get_tree().create_timer(0.3).timeout
	main.jefe.recibir_dano(99999.0)
	await get_tree().create_timer(0.4).timeout
	print("fin partida visible: ", main._capa_game_over.visible)
	var orbes := 0
	for nodo in get_tree().current_scene.get_children():
		if nodo.get_script() == preload("res://scripts/proyectil_vacio.gd"):
			orbes += 1
	print("orbes en vuelo: ", orbes)
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://cap_jefes.png")
	get_tree().quit()
