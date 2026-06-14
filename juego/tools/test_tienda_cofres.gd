extends Node
## Smoke test EQ4: la tienda de cofres instancia y abre cofres vía su lógica.

const MenuCofresScript := preload("res://scripts/menu_cofres.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.inventario = []
	estado.oro_total = 1000
	estado.gemas = 0

	var menu := CanvasLayer.new()
	menu.set_script(MenuCofresScript)
	add_child(menu)
	await _esperar(0.2)
	_check("la tienda instancia sin crash", is_instance_valid(menu))

	menu.abrir()
	await _esperar(0.1)
	_check("abrir muestra la tienda", menu.visible)

	# Abrir un cofre común vía el handler interno
	menu._abrir("comun")
	await _esperar(0.1)
	_check("abrir cofre añade pieza", estado.inventario.size() == 1)
	_check("gastó oro", estado.oro_total < 1000)

	print("FIN TEST TIENDA COFRES")
	get_tree().quit()
