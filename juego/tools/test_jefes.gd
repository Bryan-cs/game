extends Node
## Smoke test del ciclo de jefes: mecánicas, victoria, modo infinito con jefes dobles
## y ataque a distancia de todos los jefes.

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	main.oleada = 15
	main._invocar_jefe("rey_vacio")
	main.jefe.global_position = Vector3(6, 1.2, 0)
	await get_tree().create_timer(0.3).timeout
	main.jefe.recibir_dano(99999.0)
	await get_tree().create_timer(0.4).timeout
	print("victoria: ", main._capa_game_over.visible, " | boton seguir: ", main._go_seguir.visible)
	main._continuar_tras_victoria()
	main._enemigos_oleada = 0
	main._entre_oleadas = true
	main.oleada = 20
	main._lanzar_oleada()
	await get_tree().create_timer(0.2).timeout
	var jefes := 0
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.es_jefe:
			jefes += 1
			e.global_position = Vector3(8 * jefes, 1.2, 0)
			e.velocidad = 0.0
	print("jefes simultaneos en oleada 20: ", jefes)
	var vida_antes: float = main.jugador.vida
	await get_tree().create_timer(4.0).timeout
	var orbes := 0
	for nodo in get_tree().current_scene.get_children():
		if nodo.get_script() == preload("res://scripts/proyectil_vacio.gd"):
			orbes += 1
	print("orbes en vuelo: ", orbes, " | vida antes: ", vida_antes, " ahora: ", main.jugador.vida)
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://cap_jefes_dobles.png")
	get_tree().quit()
