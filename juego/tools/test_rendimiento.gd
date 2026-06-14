extends Node
## Mide FPS promedio con 90 enemigos en combate activo.

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero")
	main._spawner.stop()
	await get_tree().create_timer(0.4).timeout
	main.jugador.aprender_habilidad("torbellino", 3)
	for i in 90:
		var enemigo = main._generar_enemigo(["zombie", "esqueleto", "demonio_menor", "caballero_oscuro"][i % 4])
		var angulo := randf() * TAU
		var radio := randf_range(4.0, 18.0)
		enemigo.global_position = Vector3(cos(angulo) * radio, 1.2, sin(angulo) * radio)
	# calentamiento
	await get_tree().create_timer(2.0).timeout
	var muestras: Array[float] = []
	for i in 10:
		main.jugador.intentar_habilidad()
		await get_tree().create_timer(0.5).timeout
		muestras.append(Performance.get_monitor(Performance.TIME_FPS))
	var suma := 0.0
	var minimo := 9999.0
	for m in muestras:
		suma += m
		minimo = minf(minimo, m)
	var texto := "FPS promedio: %.0f | minimo: %.0f | enemigos: %d | nodos: %d" % [
		suma / muestras.size(), minimo,
		get_tree().get_nodes_in_group("enemigos").size(),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
	print(texto)
	var archivo := FileAccess.open("user://perf.txt", FileAccess.WRITE)
	archivo.store_string(texto)
	archivo.close()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
