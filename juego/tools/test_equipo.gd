extends Node
## Smoke test EQ1: generación de piezas y aplicación a HojaStats con afinidad.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")
const HojaStatsScript := preload("res://scripts/stats.gd")

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# 1. Generar una pieza Mítica de arma: 5 afijos, todos del pool de 'arma'
	var arma := EquipamientoScript.generar("arma", "Mítica", "ninguna", rng)
	_check("mítica de arma tiene afijos", arma.afijos.size() >= 1)
	var validos := true
	for stat in arma.afijos:
		if not (stat in EquipamientoScript.AFIJOS_SLOT["arma"]):
			validos = false
	_check("afijos pertenecen al slot", validos)

	# 2. Aplicar a la hoja suma dano_pct
	var pieza := EquipamientoScript.generar("arma", "Común", "ninguna", rng)
	pieza.afijos = {"dano_pct": 10.0}  # determinista
	var hoja := HojaStatsScript.new()
	var base: float = hoja.dano_pct
	hoja.aplicar_equipo([pieza], "guerrero")
	_check("equipo suma dano_pct", absf(hoja.dano_pct - (base + 10.0)) < 0.01)

	# 3. Afinidad coincidente da +25%
	var pieza_afin := {"slot": "arma", "rareza": "Común", "afinidad": "guerrero", "afijos": {"dano_pct": 10.0}}
	var hoja2 := HojaStatsScript.new()
	var base2: float = hoja2.dano_pct
	hoja2.aplicar_equipo([pieza_afin], "guerrero")
	_check("afinidad coincidente +25%", absf(hoja2.dano_pct - (base2 + 12.5)) < 0.01)

	# 4. Afinidad distinta NO da bonus
	var hoja3 := HojaStatsScript.new()
	var base3: float = hoja3.dano_pct
	hoja3.aplicar_equipo([pieza_afin], "mago")
	_check("afinidad distinta sin bonus", absf(hoja3.dano_pct - (base3 + 10.0)) < 0.01)

	# 5. Valor de venta por rareza
	_check("venta Mítica = 500", EquipamientoScript.valor_venta("Mítica") == 500)

	print("FIN TEST EQUIPO")
	get_tree().quit()
