extends RefCounted
class_name HojaStats
## Hoja de stats del jugador (rework Brotato, capa 1).
## Fuente única de verdad: daño, vida, crítico, armadura, esquiva, velocidad...

var vida_max := 100.0
var regen := 0.0           # HP por segundo
var robo_vida := 0.0       # % del daño infligido que cura
var dano_pct := 0.0        # % de daño global
var melee_pct := 0.0       # % de daño cuerpo a cuerpo
var distancia_pct := 0.0   # % de daño a distancia
var vel_ataque_pct := 0.0  # % de velocidad de ataque
var critico_pct := 5.0     # % de probabilidad de crítico (x2)
var armadura := 0.0        # reducción = armadura / (armadura + 15)
var esquiva_pct := 0.0     # % de ignorar un golpe (tope 60)
var velocidad_pct := 0.0   # % de velocidad de movimiento
var suerte := 0.0          # mejores rarezas en tienda y cofres (capa 3)
var cosecha := 0.0         # almas extra al final de cada oleada (capa 2)
var velocidad_base := 5.0  # m/s según la clase


func mult_dano(tipo := "global") -> float:
	var m := 1.0 + dano_pct / 100.0
	match tipo:
		"melee":
			m *= 1.0 + melee_pct / 100.0
		"distancia":
			m *= 1.0 + distancia_pct / 100.0
	return m


func velocidad_movimiento() -> float:
	return velocidad_base * (1.0 + velocidad_pct / 100.0)


func mult_cadencia() -> float:
	return 1.0 + vel_ataque_pct / 100.0


func reduccion_armadura() -> float:
	return armadura / (armadura + 15.0) if armadura > 0.0 else 0.0


func prob_critico() -> float:
	return critico_pct / 100.0


func prob_esquiva() -> float:
	return clampf(esquiva_pct, 0.0, 60.0) / 100.0


## Suma los afijos de las piezas equipadas a la hoja. +25% si la afinidad coincide con la clase.
## Se llama UNA vez al iniciar la partida (como los talentos). 'piezas' = Array de Dictionary.
func aplicar_equipo(piezas: Array, clase: String) -> void:
	for pieza in piezas:
		if not (pieza is Dictionary) or not pieza.has("afijos"):
			continue
		var factor := 1.0
		if String(pieza.get("afinidad", "ninguna")) == clase:
			factor += 0.25  # Equipamiento.BONUS_AFINIDAD
		for stat in pieza.afijos:
			var valor: float = float(pieza.afijos[stat]) * factor
			if stat in self:
				set(stat, get(stat) + valor)
