# Capa 0 — Pivote de combate auto (Undead Slayer) — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el ataque primario del jugador en 100% automático — apunta y dispara solo al enemigo más cercano sin ningún input de combate.

**Architecture:** El ataque primario ya tiene una rama auto-apuntada (`modo_tactil` usa `_enemigo_cercano()`). El pivote elimina la dependencia de input (clic izquierdo / `modo_tactil`) y el apuntado a ratón: el ataque se dispara siempre que el cooldown esté listo y haya un enemigo, apuntando al más cercano. Cambios localizados en `scripts/jugador.gd`; no se reescribe el archivo. Nova/Dash/skills de clase quedan para Capa 1.

**Tech Stack:** Godot 4.6.3, GDScript. Tests = escenas headless `tools/test_*.tscn` ejecutadas por CLI.

**Repos:** El juego vive en `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego` (repo git propio — aquí van los cambios de código y los commits). Spec: `godot-claude-mcp/docs/superpowers/specs/2026-06-13-undead-slayer-rework-design.md`.

**Gotchas de testeo (verificados en el código actual):**
- Lanzar tests por **CLI**, no por `godot_run_scene` (muere silencioso ~2s tras `_iniciar_partida`).
  Binario: `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`.
- `--check-only --script` no resuelve `class_name` recién creados → preferir `preload(...)`.
- El test instancia `main.tscn`, oculta `menu_seleccion`, llama `main._iniciar_partida(clase, mapa)`,
  detiene el spawner con `main._spawner.stop()`, y usa `main._generar_enemigo(tipo)`.

---

### Estado actual del código (referencia)

`scripts/jugador.gd`:
- Línea ~388-390 (`_physics_process`): gatillo de ataque
  ```gdscript
  var quiere_atacar := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or modo_tactil
  if quiere_atacar and _cd_disparo <= 0.0:
      _atacar()
  ```
- Línea ~437-439 (`_animar`): apuntado a ratón
  ```gdscript
  if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not modo_tactil:
      mirada = _punto_apuntado() - global_position
      mirada.y = 0.0
  ```
- Línea ~761-769: `_enemigo_cercano() -> Node3D` (ya existe, devuelve el más cercano o `null`).
- Línea ~772-805 (`_atacar`): elige dirección — rama `modo_tactil` usa `_enemigo_cercano()`, rama
  ratón usa `_punto_apuntado()`.

---

### Task 1: Test de combate auto (rojo)

**Files:**
- Create: `tools/test_combate_auto.gd`
- Create: `tools/test_combate_auto.tscn`

- [ ] **Step 1: Escribir el test que falla**

Crear `tools/test_combate_auto.gd` (mismo patrón que `tools/test_stats.gd`). Usa clase **melee** (guerrero) con el enemigo a quemarropa: el daño es instantáneo y determinista, sin depender del viaje/colisión de un proyectil. Limpia enemigos previos para que `_enemigo_cercano()` apunte al de prueba.

```gdscript
extends Node
## Smoke test Capa 0: el ataque primario es 100% automático (sin input).

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)


func _limpiar_enemigos() -> void:
	for e in get_tree().get_nodes_in_group("enemigos"):
		e.queue_free()
	await _esperar(0.1)


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	main._spawner.stop()
	await _esperar(0.4)
	var j = main.jugador

	# 1. Sin enemigos no dispara: _atacar() nunca se llama, así que _cd_disparo queda en 0
	#    (tras Capa 0, _physics_process solo llama _atacar() si hay enemigo cercano)
	await _limpiar_enemigos()
	j._cd_disparo = 0.0
	await _esperar(0.5)
	_check("sin enemigos no dispara", j._cd_disparo <= 0.01)

	# Enemigo duro (caballero_oscuro, 130 HP) que sobrevive al primer golpe: el daño
	# se mide por vida decreciente (no por muerte trivial) y el objetivo sigue válido
	# para comprobar el auto-apuntado. (Un zombie de 30 HP lo one-shotea el guerrero.)
	await _limpiar_enemigos()
	var enemigo: Node3D = main._generar_enemigo("caballero_oscuro")
	enemigo.global_position = j.global_position + Vector3(1.8, 0.0, 0.0)
	enemigo.velocidad = 0.0
	var vida_inicial: float = enemigo.vida

	# 2. El auto-apuntado elige al enemigo más cercano (contrato de comportamiento).
	await _esperar(0.05)
	_check("apunta al más cercano", is_instance_valid(enemigo) and j._enemigo_cercano() == enemigo)

	# 3. SIN input, el auto-ataque le hace daño (vida baja).
	await _esperar(1.0)
	var recibio_dano: bool = (not is_instance_valid(enemigo)) or enemigo.vida < vida_inicial
	_check("auto-ataque daña sin input", recibio_dano)

	print("FIN TEST COMBATE AUTO")
	get_tree().quit()
```

> **Notas aprendidas en ejecución:**
> - **Runner:** correr UNA sola instancia de Godot a la vez (el autoload `ClaudeRuntime` del bridge
>   puede colgar el arranque si hay otra instancia viva). Si una corrida queda colgada (~6 MB sin
>   avanzar) deja una ventana azul abierta; matar `Godot_v4.6.3-stable_win64_console.exe` y reintentar.
>   Prefijar con `timeout 45` evita cuelgues indefinidos.
> - **Tests de daño:** usar un enemigo que sobreviva. Un enemigo que muere de un golpe vuelve trivial
>   tanto la aserción de daño (`not is_instance_valid` ya es `true`) como cualquier check que necesite
>   el objetivo vivo. El guerrero hace melee + onda de corte (~35) y one-shotea un zombie de 30 HP.
> - **Apuntado:** verificar el contrato de comportamiento (`_enemigo_cercano() == objetivo`), no la
>   rotación visual del modelo (frágil: spawn diferido, wrapping de ángulo, timing).

**Optimización del review:** `_physics_process` calcula `_enemigo_cercano()` UNA vez por frame y lo
pasa a `_animar(entrada, delta, objetivo)` y `_atacar(objetivo)` (antes podían ser hasta 3 barridos
del grupo `enemigos` por frame). `modo_tactil` se conserva (lo escribe `main.gd`; no es código muerto).

Crear `tools/test_combate_auto.tscn` (copiar estructura de `tools/test_stats.tscn`, ajustar nombre/script):

```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_combate_auto.gd" id="1_cmbt"]

[node name="TestCombateAuto" type="Node"]
script = ExtResource("1_cmbt")
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run (desde el dir del juego):
```bash
"C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_combate_auto.tscn
```
Expected: imprime `FAIL auto-ataque daña sin input` (el ataque hoy requiere clic/`modo_tactil`, y el test no envía input). El test 1 puede pasar; el clave (2) falla.

---

### Task 2: Ataque primario auto-apunta siempre al más cercano

**Files:**
- Modify: `scripts/jugador.gd` (`_atacar`, ~772-785)

- [ ] **Step 1: Reescribir la selección de dirección en `_atacar()`**

Reemplazar el bloque de selección de dirección (las líneas que hoy son):
```gdscript
	var datos: Dictionary = ATAQUES[clase]
	var direccion: Vector3
	if modo_tactil:
		var objetivo := _enemigo_cercano()
		if objetivo == null:
			return
		direccion = objetivo.global_position - global_position
	else:
		direccion = _punto_apuntado() - global_position
	direccion.y = 0.0
	if direccion.length() < 0.2:
		return
	direccion = direccion.normalized()
```
por (apunta SIEMPRE al más cercano; sin enemigo, no ataca):
```gdscript
	var datos: Dictionary = ATAQUES[clase]
	var objetivo := _enemigo_cercano()
	if objetivo == null:
		return
	var direccion: Vector3 = objetivo.global_position - global_position
	direccion.y = 0.0
	if direccion.length() < 0.2:
		return
	direccion = direccion.normalized()
```

- [ ] **Step 2: Verificación rápida de sintaxis**

Run:
```bash
"C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/jugador.gd
```
Expected: sin errores de parseo (sale sin imprimir errores). `_punto_apuntado()` queda sin uso aquí pero sigue definido — se elimina en Task 3.

---

### Task 3: Disparar por cooldown sin input + quitar apuntado a ratón

**Files:**
- Modify: `scripts/jugador.gd` (`_physics_process` ~388-390, `_animar` ~437-439)

- [ ] **Step 1: Auto-disparo por cooldown en `_physics_process`**

Reemplazar:
```gdscript
		var quiere_atacar := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or modo_tactil
		if quiere_atacar and _cd_disparo <= 0.0:
			_atacar()
```
por:
```gdscript
		# Combate 100% auto: dispara solo cuando hay objetivo y el cooldown está listo.
		if _cd_disparo <= 0.0 and _enemigo_cercano() != null:
			_atacar()
```

- [ ] **Step 2: Quitar el apuntado a ratón en `_animar`**

Reemplazar:
```gdscript
	var mirada := entrada
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not modo_tactil:
		mirada = _punto_apuntado() - global_position
		mirada.y = 0.0
```
por (mira hacia el objetivo auto cuando hay enemigo; si no, hacia el movimiento):
```gdscript
	var mirada := entrada
	var obj_mirada := _enemigo_cercano()
	if obj_mirada != null:
		mirada = obj_mirada.global_position - global_position
		mirada.y = 0.0
```

- [ ] **Step 3: Eliminar `_punto_apuntado()` (ya sin uso)**

Borrar la función completa `_punto_apuntado()` (~líneas 749-758):
```gdscript
func _punto_apuntado() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position + Vector3.FORWARD
	var raton := get_viewport().get_mouse_position()
	var plano := Plane(Vector3.UP, global_position.y)
	var punto = plano.intersects_ray(cam.project_ray_origin(raton), cam.project_ray_normal(raton))
	if punto == null:
		return global_position + Vector3.FORWARD
	return punto
```

- [ ] **Step 4: Verificar que ya no quedan referencias a `_punto_apuntado`**

Run:
```bash
"C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/jugador.gd
```
Expected: sin errores de parseo ni "identifier not found". (Si aparece, queda alguna referencia a `_punto_apuntado` por limpiar.)

---

### Task 4: Verde — el test de combate auto pasa

**Files:** ninguno (verificación)

- [ ] **Step 1: Ejecutar el test de Capa 0**

Run:
```bash
"C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_combate_auto.tscn
```
Expected: las 3 líneas en PASS y `FIN TEST COMBATE AUTO`:
```
PASS sin enemigos no dispara
PASS auto-ataque daña sin input
PASS apunta al enemigo (derecha)
FIN TEST COMBATE AUTO
```

- [ ] **Step 2: No-regresión — el test de stats sigue verde**

Run:
```bash
"C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_stats.tscn
```
Expected: todas las líneas en PASS y `FIN TEST STATS`. (Confirma que `_ataque_melee` y la hoja de stats no se rompieron.)

---

### Task 5: Actualizar comentarios de cabecera y commit

**Files:**
- Modify: `scripts/jugador.gd` (líneas 3, 87, 125 — comentarios)

- [ ] **Step 1: Corregir comentarios que mienten sobre el modelo de combate**

Línea 3, cambiar:
```gdscript
## Personaje jugable: juego activo — disparo manual (clic), Nova (Q) y Dash (Espacio).
```
por:
```gdscript
## Personaje jugable: combate 100% auto — el ataque primario apunta y dispara solo al más cercano.
```

Línea ~87, cambiar:
```gdscript
## Ataque primario por clase (clic / auto en táctil).
```
por:
```gdscript
## Ataque primario por clase (automático: apunta al enemigo más cercano).
```

Línea ~125, cambiar:
```gdscript
# Disparo manual (clic izquierdo, apunta al cursor; en táctil apunta solo)
```
por:
```gdscript
# Disparo automático: apunta al enemigo más cercano cada vez que el cooldown está listo
```

- [ ] **Step 2: Commit (en el repo del juego)**

```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/jugador.gd tools/test_combate_auto.gd tools/test_combate_auto.tscn
git commit -m "feat(combate): ataque primario 100% auto al mas cercano (capa 0 Undead Slayer)"
```

---

## Self-review

- **Cobertura del spec (Cambio A, parte primaria):** ataque auto-apunta al más cercano (Task 2),
  dispara por cooldown sin input (Task 3 step 1), sin apuntado a ratón (Task 3 steps 2-3). Nova/Dash/
  skills quedan explícitamente para Capa 1 (fuera de alcance aquí, según spec §7).
- **Reuso (DRY):** se reutiliza `_enemigo_cercano()` existente en vez de crear `_objetivo_auto()`.
- **Sin placeholders:** todos los pasos muestran código exacto y comandos con salida esperada.
- **Consistencia de tipos:** `_enemigo_cercano()` devuelve `Node3D` o `null`; se compara con `!= null`
  y se usa `.global_position` (existe en `enemigo.gd` / `CharacterBody3D`). `_raiz_visual()` existe.
- **Nota:** el input de Nova/Dash/habilidad_1/2 (`_physics_process` ~391-398) se deja intacto en
  Capa 0; Capa 1 lo convierte a auto-cast. No estorba (solo responde a teclas, ausentes en el test).
```

