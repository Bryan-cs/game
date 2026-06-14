class_name Equipamiento
extends RefCounted
## Modelo de datos de equipamiento (rework Undead Slayer, capa EQ1).
## Una pieza es un Dictionary: {slot, rareza, afinidad, afijos:{stat:valor}}.

const SLOTS := ["arma", "casco", "armadura", "botas", "anillo"]

## Rareza → nº de afijos y multiplicador de magnitud (reusa la escala de la tienda).
const RAREZAS := {
	"Común":      {"afijos": 1, "mult": 1.0, "color": Color(0.85, 0.85, 0.85), "venta": 10},
	"Rara":       {"afijos": 2, "mult": 1.3, "color": Color(0.4, 0.65, 1.0),  "venta": 30},
	"Épica":      {"afijos": 3, "mult": 1.7, "color": Color(0.75, 0.4, 1.0),  "venta": 80},
	"Legendaria": {"afijos": 4, "mult": 2.2, "color": Color(1.0, 0.65, 0.2),  "venta": 200},
	"Mítica":     {"afijos": 5, "mult": 3.0, "color": Color(1.0, 0.25, 0.25), "venta": 500},
}
const ORDEN_RAREZA := ["Común", "Rara", "Épica", "Legendaria", "Mítica"]

## Afijos posibles por slot: stat de HojaStats → valor base (se multiplica por rareza.mult).
const AFIJOS_SLOT := {
	"arma":     {"dano_pct": 5.0, "vel_ataque_pct": 4.0, "critico_pct": 3.0},
	"casco":    {"vida_max": 12.0, "armadura": 3.0},
	"armadura": {"vida_max": 18.0, "armadura": 5.0, "esquiva_pct": 3.0},
	"botas":    {"velocidad_pct": 4.0, "esquiva_pct": 3.0},
	"anillo":   {"critico_pct": 4.0, "dano_pct": 4.0, "robo_vida": 2.0},
}

const CLASES := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]
const BONUS_AFINIDAD := 0.25  # +25% a los afijos si la afinidad coincide con la clase

const TIPOS_ARMA := ["espada", "arco", "baston", "daga", "martillo", "escudo"]
## Icono por slot no-arma (tipo_visual fijo).
const ICONO_SLOT := {"casco": "casco", "armadura": "coraza", "botas": "botas", "anillo": "anillo"}


static func valor_venta(rareza: String) -> int:
	return int(RAREZAS.get(rareza, {}).get("venta", 0))


static func generar(slot: String, rareza: String, afinidad: String, rng: RandomNumberGenerator) -> Dictionary:
	var info: Dictionary = RAREZAS[rareza]
	var posibles: Array = AFIJOS_SLOT[slot].keys()
	posibles.shuffle()
	var n: int = mini(int(info.afijos), posibles.size())
	var afijos := {}
	for i in n:
		var stat: String = posibles[i]
		var base: float = AFIJOS_SLOT[slot][stat]
		# Variación ±15% sobre la base, escalada por la rareza.
		afijos[stat] = roundf(base * float(info.mult) * rng.randf_range(0.85, 1.15) * 10.0) / 10.0
	var tipo_visual: String = ICONO_SLOT.get(slot, "")
	if slot == "arma":
		tipo_visual = TIPOS_ARMA[rng.randi_range(0, TIPOS_ARMA.size() - 1)]
	return {"slot": slot, "rareza": rareza, "afinidad": afinidad, "afijos": afijos, "tipo_visual": tipo_visual}


static func generar_aleatoria(rareza: String, rng: RandomNumberGenerator) -> Dictionary:
	var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	# 50% sin afinidad, 50% afinidad a una clase aleatoria.
	var afinidad := "ninguna"
	if rng.randf() < 0.5:
		afinidad = CLASES[rng.randi_range(0, CLASES.size() - 1)]
	return generar(slot, rareza, afinidad, rng)
