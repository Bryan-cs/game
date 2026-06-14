# EQ1 — Modelo de equipamiento + aplicar a HojaStats + afinidad — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Modelo de datos de equipamiento (5 slots, 5 rarezas, afijos, afinidad de clase) y su aplicación a `HojaStats`. Sin UI ni cofres todavía (EQ2/EQ3/EQ4).

**Architecture:** Nuevo `scripts/equipamiento.gd` (`class_name Equipamiento`, `RefCounted`): datos puros + generación de piezas. Una pieza es un `Dictionary` `{slot, rareza, afinidad, afijos}`. `HojaStats.aplicar_equipo(piezas, clase)` suma los afijos a la hoja (con +25% si la afinidad de la pieza coincide con la clase). El equipo se aplica UNA vez al iniciar la run (como los talentos); el inventario meta (EQ2) editará qué está equipado y se aplicará en la siguiente partida. Testeable headless, sin tocar nodos.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. `--check-only --script` no resuelve `class_name` nuevos → referenciar vía `preload(...)`.

**Campos de `HojaStats` (scripts/stats.gd):** `vida_max, regen, robo_vida, dano_pct, melee_pct, distancia_pct, vel_ataque_pct, critico_pct, armadura, esquiva_pct, velocidad_pct, suerte, cosecha, velocidad_base`.

---

### Task 1: `scripts/equipamiento.gd`

**Files:** Create `scripts/equipamiento.gd`

- [ ] **Step 1:** Crear el archivo:
```gdscript
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
	return {"slot": slot, "rareza": rareza, "afinidad": afinidad, "afijos": afijos}


static func generar_aleatoria(rareza: String, rng: RandomNumberGenerator) -> Dictionary:
	var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	# 50% sin afinidad, 50% afinidad a una clase aleatoria.
	var afinidad := "ninguna"
	if rng.randf() < 0.5:
		afinidad = CLASES[rng.randi_range(0, CLASES.size() - 1)]
	return generar(slot, rareza, afinidad, rng)
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/equipamiento.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: `HojaStats.aplicar_equipo`

**Files:** Modify `scripts/stats.gd`

- [ ] **Step 1:** Añadir el método al final de `stats.gd` (`HojaStats`):
```gdscript
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
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/stats.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: Smoke test del modelo de equipamiento

**Files:** Create `tools/test_equipo.gd`, `tools/test_equipo.tscn`

- [ ] **Step 1:** `tools/test_equipo.gd`:
```gdscript
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
```

- [ ] **Step 2:** `tools/test_equipo.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_equipo.gd" id="1_eq"]

[node name="TestEquipo" type="Node"]
script = ExtResource("1_eq")
```

- [ ] **Step 3:** Correr (5/5 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_equipo.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected: 5 PASS + `FIN TEST EQUIPO`.

---

### Task 4: No-regresión + commit

- [ ] **Step 1:** `test_stats` sigue 9/9 (HojaStats no se rompió):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_stats.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/equipamiento.gd scripts/stats.gd tools/test_equipo.gd tools/test_equipo.tscn
git commit -m "feat(equipo): modelo de equipamiento + HojaStats.aplicar_equipo con afinidad (EQ1)"
```

---

## Self-review

- **Cobertura del spec (Revisión 1c, EQ1):** 5 slots, 5 rarezas con afijos/mult/venta (Task 1),
  afijos por slot mapeados a campos reales de `HojaStats`, afinidad de clase +25% (Task 2),
  generación aleatoria. UI/inventario (EQ2), monedas/odds (EQ3) y cofres (EQ4) NO se tocan.
- **Sin placeholders:** código y comandos exactos.
- **Consistencia:** `Equipamiento.generar(slot,rareza,afinidad,rng)`,
  `Equipamiento.generar_aleatoria(rareza,rng)`, `Equipamiento.valor_venta(rareza)->int`,
  `HojaStats.aplicar_equipo(Array, String)`. Stats usados (`dano_pct`, `vida_max`, `armadura`,
  `critico_pct`, `vel_ataque_pct`, `velocidad_pct`, `esquiva_pct`, `robo_vida`) existen en `stats.gd`.
- **Decisión:** `aplicar_equipo` usa `set(stat, get(stat)+valor)` con guarda `stat in self`; suma una
  vez al inicio de la run (igual patrón que `_aplicar_talentos`). El recálculo al equipar/desequipar
  en caliente no aplica: el equipo se fija al arrancar la partida; el inventario meta (EQ2) cambia qué
  está equipado y se aplica en la siguiente run.
