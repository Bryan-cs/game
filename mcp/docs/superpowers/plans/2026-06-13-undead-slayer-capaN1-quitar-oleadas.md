# Capa N1 — Quitar oleadas/tienda/almas/fases → spawn continuo — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development o superpowers:executing-plans. Pasos con checkbox (`- [ ]`).

**Goal:** Eliminar el loop de oleadas (Brotato), la tienda de oleada, las almas-como-moneda y las fases de noche; dejar un único flujo de **spawn continuo** que escala con el tiempo, conservando el level-up con cards.

**Architecture:** El director `scripts/main.gd` deja de orquestar oleadas. El `Timer` `_spawner` pasa a generar enemigos de forma continua (ritmo y dureza escalan con `tiempo`), respetando `MAX_ENEMIGOS`. Se borran las funciones del ciclo de oleada, la tienda y `menu_stats`. `gema_xp` da solo XP. El level-up sigue dando cards (se cablea para mostrarse directamente al subir nivel; el comportamiento "pausa + 3 cards" se pule en Capa N3). El jefe-por-nivel y las estrellas son Capas N2/N4 — aquí NO se añaden.

**Tech Stack:** Godot 4.6.3, GDScript. Tests headless `tools/test_*.tscn` por CLI.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama actual: `undead-slayer-capa0` (continuar ahí o crear `undead-slayer-niveles`).

**Gotchas de runner (de Capa 0):** correr UNA instancia de Godot a la vez (el autoload bridge cuelga el arranque si hay otra viva → ventana azul ~6 MB; matar `Godot_v4.6.3-stable_win64_console.exe`). Prefijar con `timeout 45`. Binario: `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`. Tests de daño/combate: usar enemigo durable (`caballero_oscuro`), no zombie de 30 HP.

---

### Inventario de lo que se quita (referencia, `scripts/main.gd`)

- Constantes: `FASES` (29-35), `JEFES_OLEADA` (38), `OLEADA_FINAL` (44), `RELIQUIAS` (47-56).
- Vars: `_timer_oleada`, `_enemigos_oleada`, `_entre_oleadas`, `_mult_oleada`, `oleada`, `fase_noche`, `_presupuesto_spawn`, `_lote_spawn`, `_ofertas_tienda`, `_rerolls`, `_reliquias_run`, `_eligiendo_reliquia`, `menu_stats`, `tienda`.
- Funcs: `_control_oleadas` (825), `_siguiente_oleada` (842), `_terminar_oleada` (853), `_flujo_post_oleada` (872), `_abrir_tienda` (887) y helpers de tienda/precios/reroll, `_lanzar_oleada`, `_activar_fase`, `_ofrecer_reliquia` (698), `_aplicar_reliquia` (716), `_al_terminar_stats`.
- Scripts a borrar: `scripts/tienda_oleada.gd`, `scripts/menu_stats.gd`.
  - **NO borrar `scripts/menu_tienda.gd`** — corregido en ejecución: NO es la tienda de oleada, es
    la **tienda META** (skins/pase) que usa `menu_principal.gd` (preload + `_tienda.set_script`).
    Opera sobre oro meta y debe conservarse.
- HUD: llamadas `actualizar_oleada`, `actualizar_timer_oleada` (se dejan de llamar; los métodos del HUD pueden quedar sin uso, se limpian si es trivial).
- `sumar_almas` y `almas` en `gema_xp.gd`.

> **Conservar:** `oro_partida`/oro meta (`_estado.oro_total`), árbol de talentos, clases, armas/sinergias, `_generar_opciones`/`_aplicar_opcion` (cards), `_evento_aleatorio`, `_generar_ayuda`, jefes (se reusan en N2), `_invocar_jefe`, `_generar_enemigo`, `_tipo_aleatorio`.

---

### Task 1: Smoke test del spawn continuo (rojo→verde)

**Files:** Create `tools/test_spawn_continuo.gd`, `tools/test_spawn_continuo.tscn`

- [ ] **Step 1: Escribir el test**

`tools/test_spawn_continuo.gd`:
```gdscript
extends Node
## Smoke test Capa N1: spawn continuo, sin oleadas/tienda, XP puro.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	await _esperar(3.0)
	# 1. Spawn continuo: hay enemigos vivos sin sistema de oleadas
	var n = get_tree().get_nodes_in_group("enemigos").size()
	_check("spawn continuo genera enemigos", n > 0)
	# 2. No quedan referencias a oleadas (la variable ya no existe en main)
	_check("sin variable oleada", not ("oleada" in main))
	# 3. La gema da XP pero NO incrementa una moneda de almas de run
	#    (main ya no define sumar_almas)
	_check("sin sumar_almas en director", not main.has_method("sumar_almas"))
	# 4. La partida sigue activa (no se autodetuvo por falta de oleadas)
	_check("partida activa", main.partida_activa)
	print("FIN TEST SPAWN CONTINUO")
	get_tree().quit()
```

`tools/test_spawn_continuo.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_spawn_continuo.gd" id="1_spwn"]

[node name="TestSpawnContinuo" type="Node"]
script = ExtResource("1_spwn")
```

- [ ] **Step 2: Correr — falla** (hoy `oleada` existe, `sumar_almas` existe, y sin oleada activa puede no spawnear):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_spawn_continuo.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected: al menos `FAIL sin variable oleada` y `FAIL sin sumar_almas en director`.

---

### Task 2: `gema_xp` → XP puro

**Files:** Modify `scripts/gema_xp.gd`

- [ ] **Step 1:** Quitar la moneda de almas. Reemplazar el bloque de recogida:
```gdscript
	if distancia <= 0.8:
		_jugador.ganar_xp(valor)
		get_tree().call_group("partida", "sumar_almas", almas)
		queue_free()
```
por:
```gdscript
	if distancia <= 0.8:
		_jugador.ganar_xp(valor)
		queue_free()
```
Y borrar la línea `var almas := 1` (ya sin uso).

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/gema_xp.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: Spawner continuo en `main.gd`

**Files:** Modify `scripts/main.gd` (`_crear_spawner`, `_process`, nuevo `_spawn_continuo`)

- [ ] **Step 1:** En `_crear_spawner` cambiar el callback del `_spawner`:
```gdscript
	_spawner.timeout.connect(_control_oleadas)
```
por:
```gdscript
	_spawner.timeout.connect(_spawn_continuo)
```

- [ ] **Step 2:** Añadir la función de spawn continuo (sustituye a todo el ciclo de oleadas). Colócala donde estaba `_control_oleadas`:
```gdscript
func _spawn_continuo() -> void:
	if not partida_activa or get_tree().paused:
		return
	var vivos := get_tree().get_nodes_in_group("enemigos").size()
	if vivos >= MAX_ENEMIGOS:
		return
	# La dureza escala con el tiempo: más enemigos por tick a medida que avanza.
	var dificultad := 1.0 + tiempo / 60.0
	var lote := mini(int(2 + dificultad), MAX_ENEMIGOS - vivos)
	for i in maxi(lote, 0):
		_generar_enemigo(_tipo_aleatorio())
```

- [ ] **Step 3:** En `_process`, reemplazar el bloque de oleadas/fases:
```gdscript
	tiempo += delta
	if not _entre_oleadas and _timer_oleada > 0.0:
		_timer_oleada -= delta
		hud.actualizar_timer_oleada(maxf(0.0, _timer_oleada))
		if _timer_oleada <= 0.0:
			_terminar_oleada()
	else:
		hud.actualizar_tiempo(tiempo)
	if oleada > 0 and not _entre_oleadas:
		hud.actualizar_oleada(oleada, get_tree().get_nodes_in_group("enemigos").size(), _enemigos_oleada)
	if fase_noche < FASES.size() - 1 and tiempo >= FASES[fase_noche + 1].t:
		fase_noche += 1
		_activar_fase(fase_noche)
	if is_instance_valid(jefe):
		hud.actualizar_jefe(jefe.vida / jefe.vida_max)
```
por:
```gdscript
	tiempo += delta
	hud.actualizar_tiempo(tiempo)
	if is_instance_valid(jefe):
		hud.actualizar_jefe(jefe.vida / jefe.vida_max)
```

---

### Task 4: Arrancar la partida sin oleadas

**Files:** Modify `scripts/main.gd` (`_iniciar_partida`)

- [ ] **Step 1:** En `_iniciar_partida`, reemplazar el arranque del ciclo de oleadas:
```gdscript
	partida_activa = true
	sonido_mgr.tocar_musica("res://audio/musica.wav")
	_temporizar(1.0, _siguiente_oleada)
```
por:
```gdscript
	partida_activa = true
	sonido_mgr.tocar_musica("res://audio/musica.wav")
```
(El `_spawner` con `autostart=true` ya genera enemigos vía `_spawn_continuo`.)

---

### Task 5: Borrar el ciclo de oleadas, tienda, fases y reliquias

**Files:** Modify `scripts/main.gd`; Delete `scripts/tienda_oleada.gd`, `scripts/menu_tienda.gd`, `scripts/menu_stats.gd`

- [ ] **Step 1:** Borrar de `main.gd` las funciones (y sus cuerpos completos): `_control_oleadas`, `_siguiente_oleada`, `_terminar_oleada`, `_flujo_post_oleada`, `_abrir_tienda` (y helpers `_precio_*`/`_reroll_*`/ofertas de tienda), `_lanzar_oleada`, `_activar_fase`, `_ofrecer_reliquia`, `_aplicar_reliquia`, `_al_terminar_stats`.

- [ ] **Step 2:** Borrar las constantes `FASES`, `JEFES_OLEADA`, `OLEADA_FINAL`, `RELIQUIAS` y los `const`/preload de tienda/menu_stats (`MenuStatsScript`, `TiendaOleadaScript`). Borrar las vars listadas en el inventario (`_timer_oleada`, `oleada`, `fase_noche`, `_entre_oleadas`, `_mult_oleada`, `_enemigos_oleada`, `_presupuesto_spawn`, `_lote_spawn`, `_ofertas_tienda`, `_rerolls`, `_reliquias_run`, `_eligiendo_reliquia`, `menu_stats`, `tienda`).

- [ ] **Step 3:** Quitar en `_crear_interfaz` la creación de `menu_stats` y `tienda` (líneas ~498-501 y la equivalente de tienda) y sus `.connect`.

- [ ] **Step 4:** Quitar la rama de reliquia en `_al_elegir_mejora` (el bloque `if _eligiendo_reliquia:`), dejando solo:
```gdscript
func _al_elegir_mejora(indice: int) -> void:
	var opcion: Dictionary = _opciones_actuales[indice]
	_aplicar_opcion(opcion)
	mejoras_pendientes -= 1
	if mejoras_pendientes > 0:
		_mostrar_mejoras_si_toca()
	else:
		get_tree().paused = false
```

- [ ] **Step 5:** Borrar `sumar_almas` (main.gd ~1160) y sus llamadas (líneas ~867, ~1079, ~1156). En `_al_morir_enemigo` (~1063) y el cofre (~1156), donde había `sumar_almas(n)`, cambiarlo por sumar a **oro meta** si correspondía a recompensa, o eliminar si era moneda de run. (Regla: el oro meta usa `_estado.oro_total`/`oro_partida`; las almas de run desaparecen.)

- [ ] **Step 6:** Borrar los archivos de la tienda de OLEADA y de stats (NO `menu_tienda.gd`):
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git rm scripts/tienda_oleada.gd scripts/menu_stats.gd
```
(Si hay `.uid` correspondientes trackeados, `git rm` los incluye. `menu_tienda.gd` se conserva: es
la tienda meta del menú principal.)

- [ ] **Step 7:** Syntax check de main.gd hasta que pase limpio:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/main.gd 2>&1 | grep -iE "error" || echo OK
```
Resolver cada "identifier not found"/"function not found" eliminando la referencia muerta correspondiente (HUD `actualizar_oleada`/`actualizar_timer_oleada`, etc.).

---

### Task 6: Level-up muestra cards directamente

**Files:** Modify `scripts/main.gd` (`_al_subir_nivel`)

- [ ] **Step 1:** Que subir de nivel muestre las cards (antes se mostraban en `_flujo_post_oleada`, ya borrado). En `_al_subir_nivel`, tras `mejoras_pendientes += 1`, añadir:
```gdscript
	_mostrar_mejoras_si_toca()
```
(El pulido "pausa garantizada + 3 cards" es Capa N3; aquí basta con que aparezcan.)

---

### Task 7: Verde — tests pasan

**Files:** ninguno

- [ ] **Step 1:** Correr el smoke test (4/4 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_spawn_continuo.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected:
```
PASS spawn continuo genera enemigos
PASS sin variable oleada
PASS sin sumar_almas en director
PASS partida activa
FIN TEST SPAWN CONTINUO
```

- [ ] **Step 2:** No-regresión combate y stats:
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_combate_auto.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_stats.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected: ambos all-PASS. (Nota: `test_almas.tscn` y `test_loop.tscn` quedan obsoletos — bórralos o márcalos; ya no aplican.)

---

### Task 8: Commit

- [ ] **Step 1:**
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add -A
git commit -m "feat(niveles): quita oleadas/tienda/almas/fases -> spawn continuo (capa N1)"
```

---

## Self-review

- **Cobertura del spec (Revisión 1b, Capa N1):** quita oleadas (Tasks 3-5), tienda+menu_stats (Task 5),
  almas (Tasks 2,5), fases de noche (Tasks 3,5); spawn continuo escala con tiempo (Task 3); level-up
  sigue dando cards (Task 6). Jefe-por-nivel y estrellas NO se tocan aquí (Capas N2/N4).
- **Sin placeholders:** cada edición muestra el bloque exacto a reemplazar y su reemplazo. Las
  eliminaciones se listan por nombre de función + línea de referencia.
- **Riesgo:** `main.gd` es grande (1433 líneas) y muy acoplado; el borrado encadena referencias muertas
  (HUD oleada/timer, callers de `sumar_almas`). El Step 7 de Task 5 (syntax check iterativo) es el
  colchón: resolver cada error hasta limpio antes de correr el smoke test.
- **Obsoletos:** `test_almas.tscn`, `test_loop.tscn` dejan de aplicar (dependen de almas/oleadas).
