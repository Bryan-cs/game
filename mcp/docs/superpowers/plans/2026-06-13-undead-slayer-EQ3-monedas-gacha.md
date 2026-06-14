# EQ3 — Monedas (gemas) + odds de gacha + generar pieza por cofre — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Añadir la moneda premium `gemas`, las tablas de probabilidad de los dos cofres y la lógica de "abrir cofre" (gasta moneda → rolea rareza por odds → genera pieza → al inventario). Solo lógica/datos; la tienda UI y la apertura visual son EQ4.

**Architecture:** Toda la lógica de gacha vive en `game_state.gd` (autoload `Estado`), que ya tiene `oro_total`, `inventario` y `agregar_pieza` (EQ1/EQ2) y usa `Equipamiento` (EQ1) para generar la pieza. Constantes de precios y odds + `abrir_cofre(tipo) -> Dictionary` (la pieza generada, o vacío si no alcanza la moneda) + `comprar_gemas(cantidad)` (stub de pago real). EQ4 conecta esto a botones.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. `class_name` nuevos vía `preload`.

---

### Task 1: Moneda `gemas` + precios + odds + apertura en `game_state.gd`

**Files:** Modify `scripts/game_state.gd`

- [ ] **Step 1:** Var de gemas (junto a `oro_total`):
```gdscript
var gemas := 0
```

- [ ] **Step 2:** Persistencia. En `guardar()`:
```gdscript
		"gemas": gemas,
```
En `cargar()`:
```gdscript
	gemas = int(datos.get("gemas", 0))
```

- [ ] **Step 3:** Constantes de cofres (precios + odds de rareza). Añadir junto a las otras const:
```gdscript
## Cofres de gacha (EQ3). Las odds suman 100; el cofre premium sesga a rarezas altas.
const COFRES := {
	"comun":   {"nombre": "Cofre Común",  "moneda": "oro",   "precio": 150,
		"odds": {"Común": 60.0, "Rara": 28.0, "Épica": 9.0, "Legendaria": 2.5, "Mítica": 0.5}},
	"premium": {"nombre": "Cofre Premium", "moneda": "gemas", "precio": 20,
		"odds": {"Común": 25.0, "Rara": 35.0, "Épica": 25.0, "Legendaria": 12.0, "Mítica": 3.0}},
}
```

- [ ] **Step 4:** Lógica de apertura + compra de gemas (añadir al final). Usa `EquipamientoScript` (ya preargado en EQ2):
```gdscript
func _rolear_rareza(odds: Dictionary) -> String:
	var total := 0.0
	for r in odds:
		total += float(odds[r])
	var x := randf() * total
	var acum := 0.0
	for r in EquipamientoScript.ORDEN_RAREZA:
		if odds.has(r):
			acum += float(odds[r])
			if x <= acum:
				return r
	return "Común"


## Abre un cofre: gasta la moneda, genera una pieza por las odds y la mete al inventario.
## Devuelve la pieza generada, o {} si no hay moneda suficiente o el tipo no existe.
func abrir_cofre(tipo: String) -> Dictionary:
	if not COFRES.has(tipo):
		return {}
	var cofre: Dictionary = COFRES[tipo]
	var precio: int = cofre.precio
	if cofre.moneda == "oro":
		if oro_total < precio:
			return {}
		oro_total -= precio
	else:
		if gemas < precio:
			return {}
		gemas -= precio
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rareza := _rolear_rareza(cofre.odds)
	var pieza: Dictionary = EquipamientoScript.generar_aleatoria(rareza, rng)
	agregar_pieza(pieza)  # ya hace guardar()
	return pieza


## Stub de pago real: acredita gemas como si se hubiera comprado un paquete.
## (El billing real de Google Play es trabajo de plataforma futuro.)
func comprar_gemas(cantidad: int) -> void:
	gemas += cantidad
	guardar()
```

- [ ] **Step 5:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/game_state.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: Smoke test de gacha

**Files:** Create `tools/test_gacha.gd`, `tools/test_gacha.tscn`

- [ ] **Step 1:** `tools/test_gacha.gd`:
```gdscript
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
```

- [ ] **Step 2:** `tools/test_gacha.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_gacha.gd" id="1_gacha"]

[node name="TestGacha" type="Node"]
script = ExtResource("1_gacha")
```

- [ ] **Step 3:** Correr (6/6 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_gacha.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected: 6 PASS + `FIN TEST GACHA`.

---

### Task 3: No-regresión + commit

- [ ] **Step 1:** `test_inventario` 4/4 y `test_equipo` 6/6 (no se rompió game_state/equipo):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_inventario.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_equipo.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/game_state.gd tools/test_gacha.gd tools/test_gacha.tscn
git commit -m "feat(equipo): moneda gemas + odds de gacha + abrir_cofre (EQ3)"
```

---

## Self-review

- **Cobertura del spec (Revisión 1c, EQ3):** moneda `gemas` + persistencia (Task 1), 2 cofres con
  odds (Común=oro / Premium=gemas) (Task 1), `abrir_cofre` gasta moneda + genera pieza por odds + al
  inventario (Task 1), stub `comprar_gemas` (Task 1). UI de tienda y apertura visual = EQ4.
- **Sin placeholders:** odds concretas, código y comandos exactos.
- **Consistencia:** `Estado.abrir_cofre(String)->Dictionary`, `Estado.comprar_gemas(int)`,
  `Estado.COFRES`, `Estado.gemas`. Reusa `Equipamiento.generar_aleatoria` y `ORDEN_RAREZA` (EQ1) y
  `agregar_pieza` (EQ2).
- **Test de odds:** muestreo (400 aperturas) comparando rarezas altas premium vs común; es
  probabilístico pero el margen de las tablas (40% vs 12% en altas) lo hace robusto.
