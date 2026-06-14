extends Node
## Smoke test árbol Warlord: guerrero con build completa, Rey de la Masacre se activa solo.

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	var j = main.jugador
	j.aprender_habilidad("embestida", 3)
	j.aprender_habilidad("furia", 2)
	j.aprender_habilidad("sed_batalla", 2)
	j.aprender_habilidad("hoja_gigante", 2)
	j.aprender_habilidad("rey_masacre", 1)
	for i in 14:
		var enemigo = main._generar_enemigo("zombie")
		var angulo := TAU * i / 14.0
		enemigo.global_position = Vector3(cos(angulo) * 5.0, 1.2, sin(angulo) * 5.0)
		enemigo.velocidad = 0.0
	# esperar al chequeo del Rey (cada 0.5 s) y capturar el overlay carmesí
	await get_tree().create_timer(1.2).timeout
	main.jugador.intentar_habilidad()
	await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://cap_habilidades.png")
	print("rey activo: ", j._rey_t > 0.0)
	get_tree().quit()
