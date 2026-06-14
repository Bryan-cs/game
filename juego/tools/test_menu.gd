extends Node
## Captura el menú principal renovado.

func _ready() -> void:
	var menu: Control = load("res://scenes/menu_principal.tscn").instantiate()
	add_child(menu)
	menu.position = Vector2.ZERO
	menu.size = get_viewport().get_visible_rect().size
	await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://cap_menu.png")
	get_tree().quit()
