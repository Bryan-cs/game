# Capa N4 — Estrellas por tiempo al completar nivel — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Al completar un nivel, otorgar **1-3 estrellas según el tiempo total** (más rápido = más estrellas), persistir la **mejor** calificación por nivel y mostrarla en la pantalla de completado.

**Architecture:** `_completar_nivel()` (de N2) calcula las estrellas con `_estrellas_por_tiempo(tiempo)` y las persiste vía `Estado.registrar_estrellas(nivel_actual, n)` (guarda el máximo). El título de la pantalla de completado muestra ★/☆. Umbrales globales por ahora (los umbrales por nivel llegan en N5 con la tabla `NIVELES`).

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), prefijar `timeout 45`. Binario `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`.

---

### Task 1: Persistir estrellas por nivel en `game_state`

**Files:** Modify `scripts/game_state.gd`

- [ ] **Step 1:** Añadir la var (junto a `nivel_max_desbloqueado`):
```gdscript
var estrellas_nivel := {}  # { indice_nivel(int como String en JSON): mejor_estrellas 0-3 }
```

- [ ] **Step 2:** En `guardar()` añadir al dict `datos`:
```gdscript
		"estrellas_nivel": estrellas_nivel,
```

- [ ] **Step 3:** En `cargar()`:
```gdscript
	var en = datos.get("estrellas_nivel", {})
	estrellas_nivel = en if en is Dictionary else {}
```

- [ ] **Step 4:** Helper que guarda el máximo:
```gdscript
func registrar_estrellas(indice: int, estrellas: int) -> void:
	var clave := str(indice)
	if estrellas > int(estrellas_nivel.get(clave, 0)):
		estrellas_nivel[clave] = estrellas
		guardar()


func estrellas_de(indice: int) -> int:
	return int(estrellas_nivel.get(str(indice), 0))
```

- [ ] **Step 5:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/game_state.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: Calcular y mostrar estrellas en `_completar_nivel`

**Files:** Modify `scripts/main.gd`

- [ ] **Step 1:** Añadir el cálculo de estrellas (umbrales globales; por-nivel = N5). Colócalo junto a `_completar_nivel`:
```gdscript
func _estrellas_por_tiempo(t: float) -> int:
	# Cuanto antes se mate al jefe, más estrellas. Umbral base = aparición del jefe.
	if t <= SEGUNDOS_HASTA_JEFE + 20.0:
		return 3
	if t <= SEGUNDOS_HASTA_JEFE + 45.0:
		return 2
	return 1
```

- [ ] **Step 2:** En `_completar_nivel()`, tras `_estado.desbloquear_nivel(nivel_actual + 1)`, añadir el registro de estrellas y mostrarlas. Insertar antes de `_estado.guardar()`:
```gdscript
	var estrellas := _estrellas_por_tiempo(tiempo)
	_estado.registrar_estrellas(nivel_actual, estrellas)
```
Y cambiar la línea del título:
```gdscript
	_go_titulo.text = "NIVEL %d COMPLETADO" % (nivel_actual + 1)
```
por:
```gdscript
	var glifos := "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
	_go_titulo.text = "NIVEL %d COMPLETADO  %s" % [nivel_actual + 1, glifos]
```

- [ ] **Step 3:** Syntax check de main.gd:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/main.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: Smoke test de estrellas

**Files:** Create `tools/test_estrellas.gd`, `tools/test_estrellas.tscn`

- [ ] **Step 1:** `tools/test_estrellas.gd`:
```gdscript
extends Node
## Smoke test Capa N4: completar rápido da 3 estrellas y se persiste el máximo.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.estrellas_nivel = {}
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)

	# Forzar jefe justo en el umbral y matarlo de inmediato → tiempo bajo → 3 estrellas.
	main.tiempo = main.SEGUNDOS_HASTA_JEFE + 0.1
	await _esperar(0.4)
	if is_instance_valid(main.jefe):
		main.jefe.recibir_dano(999999.0)
	await _esperar(0.5)

	_check("3 estrellas por completar rápido", estado.estrellas_de(0) == 3)

	# Registrar una calificación peor no debe rebajar el máximo.
	estado.registrar_estrellas(0, 1)
	_check("guarda el máximo (no rebaja)", estado.estrellas_de(0) == 3)

	get_tree().paused = false
	print("FIN TEST ESTRELLAS")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_estrellas.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_estrellas.gd" id="1_estr"]

[node name="TestEstrellas" type="Node"]
script = ExtResource("1_estr")
```

- [ ] **Step 3:** Correr (2/2 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_estrellas.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected: `PASS 3 estrellas por completar rápido`, `PASS guarda el máximo (no rebaja)`, `FIN TEST ESTRELLAS`.

---

### Task 4: No-regresión + commit

- [ ] **Step 1:** No-regresión (mata godot entre corridas):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_nivel.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected: 3/3 PASS (el flujo de compleción sigue intacto).

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/main.gd scripts/game_state.gd tools/test_estrellas.gd tools/test_estrellas.tscn
git commit -m "feat(niveles): estrellas 1-3 por tiempo al completar nivel (capa N4)"
```
(Incluye `.uid` si Godot lo generó.)

---

## Self-review

- **Cobertura del spec (Revisión 1b, Capa N4):** estrellas 1-3 por tiempo (Task 2), persistencia del
  máximo por nivel (Task 1), mostradas en la pantalla de completado (Task 2). Umbrales por-nivel = N5.
- **Sin placeholders:** código y comandos exactos.
- **Consistencia:** `Estado.registrar_estrellas(int,int)`, `Estado.estrellas_de(int) -> int`,
  `estrellas_nivel: Dictionary` (claves String por JSON). `_estrellas_por_tiempo(float) -> int` usa
  `SEGUNDOS_HASTA_JEFE` (de N2). `_completar_nivel` existe (N2).
- **Riesgo:** umbral global por ahora; N5 lo hará por nivel desde la tabla `NIVELES`. El glifo ☆/★ se
  muestra en el título reutilizado; N5/UI puede mejorar la presentación.
