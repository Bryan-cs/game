extends Node
## Prueba visual de skins: un enemigo de cada tipo + élite + jefe alrededor del jugador.

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	var tipos := ["zombie", "esqueleto", "arana_gigante", "demonio_menor", "caballero_oscuro"]
	for i in tipos.size():
		var enemigo = main._generar_enemigo(tipos[i])
		var angulo := PI * 0.25 + PI * 0.5 * i / (tipos.size() - 1)
		enemigo.global_position = Vector3(cos(angulo) * 5.5, 1.2, -sin(angulo) * 5.5)
		enemigo.velocidad = 0.0
	var elite = main._generar_enemigo("caballero_oscuro", true)
	elite.global_position = Vector3(-5.5, 1.2, 1.5)
	elite.velocidad = 0.0
	var jefe = main._generar_enemigo("gigante_putrefacto")
	jefe.global_position = Vector3(5.5, 1.2, 2.0)
	jefe.velocidad = 0.0
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://cap_enemigos.png")
	get_tree().quit()
