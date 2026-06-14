extends Node
## Smoke test EQ3: monedas, apertura de cofres y odds.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.inventario = []
	estado.oro_total = 1000
	estado.gemas = 0

	# 1. Comprar gemas (stub) acredita
	estado.comprar_gemas(100)
	_check("comprar gemas acredita", estado.gemas == 100)

	# 2. Abrir cofre común gasta oro y da pieza al inventario
	var oro_antes: int = estado.oro_total
	var pieza: Dictionary = estado.abrir_cofre("comun")
	var precio: int = estado.COFRES["comun"].precio
	_check("cofre común gasta oro", estado.oro_total == oro_antes - precio)
	_check("cofre común da pieza", not pieza.is_empty() and estado.inventario.size() == 1)
	_check("pieza tiene rareza válida", pieza.get("rareza", "") in EquipamientoScript.ORDEN_RAREZA)

	# 3. Abrir cofre premium gasta gemas
	var gemas_antes: int = estado.gemas
	estado.abrir_cofre("premium")
	_check("cofre premium gasta gemas", estado.gemas == gemas_antes - estado.COFRES["premium"].precio)

	# 4. Sin moneda suficiente no abre
	estado.oro_total = 0
	var vacio: Dictionary = estado.abrir_cofre("comun")
	_check("sin oro no abre", vacio.is_empty())

	# 5. Las odds del premium favorecen rarezas altas vs común (muestreo)
	estado.gemas = 100000
	estado.inventario = []
	var altas_premium := 0
	for i in 400:
		var p: Dictionary = estado.abrir_cofre("premium")
		if p.get("rareza", "Común") in ["Épica", "Legendaria", "Mítica"]:
			altas_premium += 1
	estado.oro_total = 100000
	estado.inventario = []
	var altas_comun := 0
	for i in 400:
		var p2: Dictionary = estado.abrir_cofre("comun")
		if p2.get("rareza", "Común") in ["Épica", "Legendaria", "Mítica"]:
			altas_comun += 1
	_check("premium da más rarezas altas que común", altas_premium > altas_comun)

	print("FIN TEST GACHA")
	get_tree().quit()
