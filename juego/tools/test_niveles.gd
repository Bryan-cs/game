extends Node
## Smoke test Capa N5: la tabla de 60 niveles es coherente.

const NivelesScript := preload("res://scripts/niveles.gd")

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	_check("hay 60 niveles", NivelesScript.TOTAL == 60 and NivelesScript.NOMBRES.size() == 60)
	# Nombres únicos
	var vistos := {}
	var unicos := true
	for n in NivelesScript.NOMBRES:
		if vistos.has(n):
			unicos = false
		vistos[n] = true
	_check("nombres únicos", unicos)
	# Dificultad monótona creciente
	var monotona := true
	for i in range(1, 60):
		if NivelesScript.escala(i) <= NivelesScript.escala(i - 1):
			monotona = false
	_check("dificultad crece por nivel", monotona)
	# Temas y jefes válidos en todo el rango
	var validos := true
	for i in 60:
		if not (NivelesScript.tema(i) in NivelesScript.TEMAS):
			validos = false
		if not (NivelesScript.jefe(i) in NivelesScript.JEFES):
			validos = false
	_check("tema y jefe válidos en los 60", validos)
	# Estrellas: completar rápido = 3, lento = 1
	_check("estrellas por tiempo", NivelesScript.estrellas_por_tiempo(0, 1.0) == 3 and NivelesScript.estrellas_por_tiempo(0, 99999.0) == 1)
	print("FIN TEST NIVELES")
	get_tree().quit()
