extends Node
## Prueba automática: inicia partidas con clases/mapas distintos, ataca y guarda capturas.

func _ready() -> void:
	await _probar("guerrero", "desierto", "user://cap_guerrero.png")
	await _probar("arquero", "abismo", "user://cap_arquero.png")
	get_tree().quit()


func _probar(clase: String, mapa: String, ruta: String) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	main.menu_seleccion.visible = false
	main._iniciar_partida(clase, mapa)
	await get_tree().create_timer(2.5).timeout
	main.jugador._atacar()
	await get_tree().create_timer(0.15).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(ruta)
	main.queue_free()
	await get_tree().create_timer(0.3).timeout
