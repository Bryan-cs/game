extends Node
## Smoke test EQ2: equipar/desequipar/vender y aplicación al iniciar partida.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.inventario = []
	estado.equipado = {}
	estado.oro_total = 0
	estado.talentos = {"dano": 0, "velocidad": 0, "critico": 0, "vida": 0, "xp": 0}

	# Inyectar dos piezas deterministas
	var arma := {"slot": "arma", "rareza": "Épica", "afinidad": "guerrero", "afijos": {"dano_pct": 20.0}}
	var casco := {"slot": "casco", "rareza": "Común", "afinidad": "ninguna", "afijos": {"vida_max": 15.0}}
	estado.agregar_pieza(arma)
	estado.agregar_pieza(casco)
	_check("mochila tiene 2 piezas", estado.inventario.size() == 2)

	# Equipar el arma (índice 0)
	estado.equipar(0)
	_check("equipar mueve a slot", estado.equipado.has("arma") and estado.inventario.size() == 1)

	# Vender la pieza restante (casco, Común=10 oro)
	var ganado: int = estado.vender_pieza(0)
	_check("vender da oro por rareza", ganado == 10 and estado.oro_total == 10 and estado.inventario.is_empty())

	# Iniciar partida: el arma equipada (Épica afinidad guerrero) sube dano_pct del guerrero
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)
	await _esperar(0.3)
	# dano_pct base del guerrero = 0; +20 * 1.25 (afinidad) = 25
	_check("equipo aplicado al iniciar (afinidad)", absf(main.jugador.stats.dano_pct - 25.0) < 0.01)

	get_tree().paused = false
	print("FIN TEST INVENTARIO")
	get_tree().quit()
