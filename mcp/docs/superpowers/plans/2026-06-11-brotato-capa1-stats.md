# Capa 1: Hoja de Stats — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoja de 13 stats (`HojaStats`) como fuente única de verdad del jugador; daño/vida/crítico/armadura/esquiva/velocidad leen de ahí. Sin cambio visible en el juego.

**Architecture:** Nuevo `scripts/stats.gd` (clase `HojaStats`, RefCounted). `jugador.gd` expone `stats` y conserva las vars legacy (`mult_dano`, `vida_max`, `velocidad`, `prob_critico`, `regen`) como propiedades get/set que leen/escriben la hoja — así `main.gd` (pool de mejoras) sigue funcionando sin tocarlo. `calcular_dano` gana parámetro `tipo` ("melee"/"distancia"/"global"); cada arma declara el suyo. Armadura, esquiva y robo de vida se cablean; suerte y cosecha quedan inertes hasta capas 2-3.

**Tech Stack:** Godot 4.6.3 (GDScript), MCP godot (validación + run + output), git en el proyecto del juego.

**Proyecto del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego` (en adelante `$JUEGO`). Editor de Godot debe estar abierto con el proyecto para las tools MCP.

**Spec:** `docs/superpowers/specs/2026-06-11-brotato-rework-design.md` (sección 3 y capa 1 de la sección 6).

---

### Task 0: Git en el proyecto del juego

El proyecto NO tiene git. Rework de 5 capas sin VCS es inaceptable.

**Files:**
- Create: `$JUEGO\.gitignore`

- [ ] **Step 1: Crear .gitignore**

Contenido de `$JUEGO\.gitignore`:

```gitignore
.godot/
*.tmp
```

- [ ] **Step 2: Inicializar y commit baseline**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git init
git add -A
git commit -m "chore: baseline pre-rework Brotato (estado MVP 2026-06-10)"
```

Expected: commit con ~todos los .gd, .tscn, assets. Verificar con `git log --oneline` (1 commit).

---

### Task 1: HojaStats + test que falla

**Files:**
- Create: `$JUEGO\scripts\stats.gd`
- Create: `$JUEGO\tools\test_stats.gd`
- Create: `$JUEGO\tools\test_stats.tscn`

- [ ] **Step 1: Escribir el test (fallará: `jugador.stats` no existe aún)**

`$JUEGO\tools\test_stats.gd`:

```gdscript
extends Node
## Smoke test Capa 1: hoja de stats como fuente única de verdad.

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
	main._spawner.stop()
	await _esperar(0.4)
	var j = main.jugador
	var s = j.stats
	# 1. La clase vuelca sus datos a la hoja
	_check("vida de clase en hoja", absf(s.vida_max - j.vida_max) < 0.01 and j.vida_max >= 150.0)
	# 2. Daño melee escala con melee_pct y no con distancia_pct (determinista: sin crit ni dano_pct)
	s.critico_pct = 0.0
	s.dano_pct = 0.0
	s.melee_pct = 100.0
	s.distancia_pct = 0.0
	_check("melee x2 con +100% melee", absf(j.calcular_dano(10.0, "melee") - 20.0) < 0.01)
	_check("distancia ignora melee_pct", absf(j.calcular_dano(10.0, "distancia") - 10.0) < 0.01)
	# 3. Propiedad legacy mult_dano hace roundtrip a la hoja (main.gd la usa con *=)
	j.mult_dano *= 1.5
	_check("mult_dano roundtrip", absf(s.dano_pct - 50.0) < 0.01)
	s.dano_pct = 0.0
	# 4. Armadura reduce el daño recibido
	s.armadura = 15.0  # reducción 50%
	j._invulnerable = 0.0
	var antes: float = j.vida
	j.recibir_dano(40.0)
	_check("armadura 15 reduce 50%", absf((antes - j.vida) - 20.0) < 0.5)
	# 5. Esquiva con tope 60%
	s.esquiva_pct = 100.0
	_check("esquiva tope 60", absf(s.prob_esquiva() - 0.6) < 0.001)
	# 6. Velocidad como propiedad sobre la hoja
	var v0: float = j.velocidad
	j.velocidad *= 1.2
	_check("velocidad +20%", absf(j.velocidad - v0 * 1.2) < 0.01)
	# 7. Velocidad de ataque
	s.vel_ataque_pct = 100.0
	_check("cadencia x2", absf(s.mult_cadencia() - 2.0) < 0.01)
	# 8. Robo de vida en melee
	s.robo_vida = 10.0
	var zombi = main._generar_enemigo("zombie")
	zombi.global_position = j.global_position + Vector3(1.5, 1.2, 0.0)
	zombi.velocidad = 0.0
	j.vida = 50.0
	j._ataque_melee(Vector3(1, 0, 0), j.ATAQUES["guerrero"])
	_check("robo de vida cura", j.vida > 50.0)
	print("FIN TEST STATS")
	get_tree().quit()
```

`$JUEGO\tools\test_stats.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/test_stats.gd" id="1"]

[node name="TestStats" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Ejecutar el test y verificar que FALLA**

MCP: `godot_run_scene` con `res://tools/test_stats.tscn`, esperar ~4 s (`runtime_wait` o reintento), luego `godot_get_game_output`.

Expected: error de script (`Invalid get index 'stats'` o parse error en test) — el jugador aún no tiene `stats`. Cerrar con `godot_stop_scene` si quedó vivo.

- [ ] **Step 3: Crear `scripts/stats.gd`**

```gdscript
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
```

- [ ] **Step 4: Validar**

MCP: `godot_validate_script` con `res://scripts/stats.gd`. Expected: válido, 0 errores.

- [ ] **Step 5: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/stats.gd tools/test_stats.gd tools/test_stats.tscn
git commit -m "feat(stats): HojaStats + smoke test capa 1 (rojo)"
```

---

### Task 2: jugador.gd lee de la hoja

**Files:**
- Modify: `$JUEGO\scripts\jugador.gd` (vars ~96-109, `_aplicar_clase` ~182, `_aplicar_talentos` ~278, `_atacar` ~777, `_ataque_melee` ~827, `_ataque_proyectil` ~851, `recibir_dano` ~1011, `calcular_dano` ~1060)

- [ ] **Step 1: Sustituir el bloque de vars por hoja + propiedades legacy**

Buscar (líneas 96-105):

```gdscript
var clase := "guerrero"
var vida_max := 120.0
var vida := 120.0
var velocidad := 5.0
var mult_dano := 1.0
var prob_critico := 0.05
var regen := 0.0
var radio_iman := 3.5
var mult_xp := 1.0
var vel_proyectil_mult := 1.0
```

Reemplazar por:

```gdscript
var clase := "guerrero"
var stats := HojaStats.new()
var vida := 120.0
var radio_iman := 3.5
var mult_xp := 1.0
var vel_proyectil_mult := 1.0

# Propiedades legacy sobre la hoja: main.gd y las armas siguen funcionando.
var vida_max: float:
	get: return stats.vida_max
	set(v): stats.vida_max = v
var velocidad: float:
	get: return stats.velocidad_movimiento()
	set(v): stats.velocidad_pct = (v / stats.velocidad_base - 1.0) * 100.0
var mult_dano: float:
	get: return stats.mult_dano("global")
	set(v): stats.dano_pct = (v - 1.0) * 100.0
var prob_critico: float:
	get: return stats.prob_critico()
	set(v): stats.critico_pct = v * 100.0
var regen: float:
	get: return stats.regen
	set(v): stats.regen = v
```

- [ ] **Step 2: `_aplicar_clase` vuelca la clase a la hoja**

Buscar:

```gdscript
func _aplicar_clase() -> void:
	var datos: Dictionary = CLASES[clase]
	vida_max = datos.vida
	velocidad = datos.velocidad
	mult_dano = datos.mult_dano
	prob_critico = datos.critico
	regen = datos.regen
	cadencia_disparo = ATAQUES[clase].cadencia
	if clase == "arquero":
		vel_proyectil_mult = 1.3
```

Reemplazar por:

```gdscript
func _aplicar_clase() -> void:
	var datos: Dictionary = CLASES[clase]
	stats.vida_max = datos.vida
	stats.velocidad_base = datos.velocidad
	stats.dano_pct = (datos.mult_dano - 1.0) * 100.0
	stats.critico_pct = datos.critico * 100.0
	stats.regen = datos.regen
	cadencia_disparo = ATAQUES[clase].cadencia
	if clase == "arquero":
		vel_proyectil_mult = 1.3
```

- [ ] **Step 3: `_aplicar_talentos` escribe la hoja**

Buscar:

```gdscript
func _aplicar_talentos() -> void:
	var t: Dictionary = _estado.talentos
	vida_max *= 1.0 + 0.10 * int(t.get("vida", 0))
	velocidad *= 1.0 + 0.05 * int(t.get("velocidad", 0))
	mult_dano *= 1.0 + 0.08 * int(t.get("dano", 0))
	prob_critico += 0.03 * int(t.get("critico", 0))
	radio_iman *= 1.0 + 0.15 * int(t.get("xp", 0))
```

Reemplazar por:

```gdscript
func _aplicar_talentos() -> void:
	var t: Dictionary = _estado.talentos
	stats.vida_max *= 1.0 + 0.10 * int(t.get("vida", 0))
	stats.velocidad_pct += 5.0 * int(t.get("velocidad", 0))
	stats.dano_pct += 8.0 * int(t.get("dano", 0))
	stats.critico_pct += 3.0 * int(t.get("critico", 0))
	radio_iman *= 1.0 + 0.15 * int(t.get("xp", 0))
```

- [ ] **Step 4: `calcular_dano` con tipo de daño**

Buscar:

```gdscript
func calcular_dano(base: float) -> float:
	var dano := base * mult_dano * (1.0 + corrupcion * 0.005)
```

Reemplazar por:

```gdscript
func calcular_dano(base: float, tipo := "global") -> float:
	var dano := base * stats.mult_dano(tipo) * (1.0 + corrupcion * 0.005)
```

(El resto de la función — furia, rey, crítico vía `prob_critico` propiedad — sigue igual; `randf() < prob_critico` ya lee la hoja.)

- [ ] **Step 5: `recibir_dano` con esquiva y armadura**

Buscar:

```gdscript
func recibir_dano(cantidad: float) -> void:
	if _invulnerable > 0.0 or vida <= 0.0:
		return
	cantidad *= maxf(0.4, 1.0 - 0.12 * nivel_habilidad("piel_hierro"))
```

Reemplazar por:

```gdscript
func recibir_dano(cantidad: float) -> void:
	if _invulnerable > 0.0 or vida <= 0.0:
		return
	if randf() < stats.prob_esquiva():
		Efectos.sonido(self, "dash", -8.0)
		return
	cantidad *= 1.0 - stats.reduccion_armadura()
	cantidad *= maxf(0.4, 1.0 - 0.12 * nivel_habilidad("piel_hierro"))
```

- [ ] **Step 6: Velocidad de ataque en `_atacar`**

Buscar:

```gdscript
	_cd_disparo = cadencia_disparo * factor
```

Reemplazar por:

```gdscript
	_cd_disparo = cadencia_disparo * factor / stats.mult_cadencia()
```

- [ ] **Step 7: `_ataque_melee` — tipo melee + robo de vida**

Buscar:

```gdscript
	var dano := calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1))
	var golpeo := false
```

Reemplazar por:

```gdscript
	var dano := calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "melee")
	var golpeo := false
	var golpes := 0
```

Buscar:

```gdscript
		enemigo.recibir_dano(dano)
		golpeo = true
	Efectos.sonido(self, "golpe" if golpeo else "dash", -4.0)
```

Reemplazar por:

```gdscript
		enemigo.recibir_dano(dano)
		golpeo = true
		golpes += 1
	if golpes > 0 and stats.robo_vida > 0.0:
		curar(dano * golpes * stats.robo_vida / 100.0)
	Efectos.sonido(self, "golpe" if golpeo else "dash", -4.0)
```

Buscar (onda de corte del Guerrero, final de `_ataque_melee`):

```gdscript
		var base_onda: float = (datos.dano + datos.por_nivel * (nivel_disparo - 1)) * 0.6
		_lanzar_onda_corte(direccion, calcular_dano(base_onda))
```

Reemplazar por:

```gdscript
		var base_onda: float = (datos.dano + datos.por_nivel * (nivel_disparo - 1)) * 0.6
		_lanzar_onda_corte(direccion, calcular_dano(base_onda, "melee"))
```

- [ ] **Step 8: `_ataque_proyectil` — tipo distancia + robo de vida**

Buscar:

```gdscript
	proyectil.direccion = direccion
	proyectil.velocidad = datos.vel * vel_proyectil_mult
	proyectil.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1))
	proyectil.look_at(proyectil.global_position + direccion, Vector3.UP)
```

Reemplazar por:

```gdscript
	proyectil.direccion = direccion
	proyectil.velocidad = datos.vel * vel_proyectil_mult
	proyectil.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "distancia")
	proyectil.robo_vida = stats.robo_vida
	proyectil.look_at(proyectil.global_position + direccion, Vector3.UP)
```

Buscar (orbe extra del Eco Arcano):

```gdscript
		extra.velocidad = datos.vel * vel_proyectil_mult
		extra.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1))
		extra.look_at(extra.global_position + extra.direccion, Vector3.UP)
```

Reemplazar por:

```gdscript
		extra.velocidad = datos.vel * vel_proyectil_mult
		extra.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "distancia")
		extra.robo_vida = stats.robo_vida
		extra.look_at(extra.global_position + extra.direccion, Vector3.UP)
```

- [ ] **Step 9: Validar**

MCP: `godot_validate_script` con `res://scripts/jugador.gd`. Expected: válido. (El test aún falla: `proyectil.robo_vida` no existe — se añade en Task 3.)

- [ ] **Step 10: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/jugador.gd
git commit -m "feat(stats): jugador lee de HojaStats; esquiva, armadura, vel. ataque y robo de vida"
```

---

### Task 3: Armas declaran tipo + proyectil con robo de vida

**Files:**
- Modify: `$JUEGO\scripts\proyectil.gd`
- Modify: `$JUEGO\scripts\arma_espada.gd:111`, `arma_martillo.gd:34`, `arma_arco.gd:41`, `arma_fuego.gd:41`, `arma_dagas.gd:36`, `arma_rayo.gd:27`

- [ ] **Step 1: `proyectil.gd` — var y curación al impactar**

Buscar:

```gdscript
var vida_util := 3.5
var veneno_dps := 0.0
```

Reemplazar por:

```gdscript
var vida_util := 3.5
var veneno_dps := 0.0
var robo_vida := 0.0  # % del daño que cura al jugador al impactar
```

Buscar:

```gdscript
	if radio_explosion > 0.0:
		Efectos.explosion(get_tree().current_scene, global_position, Color(1.0, 0.5, 0.15), 28, 1.5)
		Efectos.sonido(self, "golpe", -4.0)
		for enemigo in get_tree().get_nodes_in_group("enemigos"):
			if enemigo.global_position.distance_to(global_position) <= radio_explosion:
				enemigo.recibir_dano(dano)
		queue_free()
		return
	Efectos.sonido(self, "golpe", -10.0)
	if veneno_dps > 0.0 and cuerpo.has_method("envenenar"):
		cuerpo.envenenar(veneno_dps, 3.0)
	cuerpo.recibir_dano(dano)
```

Reemplazar por:

```gdscript
	if radio_explosion > 0.0:
		Efectos.explosion(get_tree().current_scene, global_position, Color(1.0, 0.5, 0.15), 28, 1.5)
		Efectos.sonido(self, "golpe", -4.0)
		for enemigo in get_tree().get_nodes_in_group("enemigos"):
			if enemigo.global_position.distance_to(global_position) <= radio_explosion:
				enemigo.recibir_dano(dano)
		_curar_jugador()
		queue_free()
		return
	Efectos.sonido(self, "golpe", -10.0)
	if veneno_dps > 0.0 and cuerpo.has_method("envenenar"):
		cuerpo.envenenar(veneno_dps, 3.0)
	cuerpo.recibir_dano(dano)
	_curar_jugador()
```

Y añadir al final del archivo:

```gdscript
func _curar_jugador() -> void:
	if robo_vida <= 0.0:
		return
	var lista := get_tree().get_nodes_in_group("jugador")
	if not lista.is_empty():
		lista[0].curar(dano * robo_vida / 100.0)
```

- [ ] **Step 2: Las 6 armas pasivas declaran su tipo de daño**

| Archivo | Buscar | Reemplazar |
|---|---|---|
| `arma_espada.gd:111` | `enemigo.recibir_dano(jugador.calcular_dano(base))` | `enemigo.recibir_dano(jugador.calcular_dano(base, "melee"))` |
| `arma_martillo.gd:34` | `var dano := jugador.calcular_dano((20.0 + 8.0 * nivel) * factor * (1.3 if evolucionada else 1.0))` | `var dano := jugador.calcular_dano((20.0 + 8.0 * nivel) * factor * (1.3 if evolucionada else 1.0), "melee")` |
| `arma_arco.gd:41` | `proyectil.dano = jugador.calcular_dano(base)` | `proyectil.dano = jugador.calcular_dano(base, "distancia")` |
| `arma_fuego.gd:41` | `proyectil.dano = jugador.calcular_dano(base)` | `proyectil.dano = jugador.calcular_dano(base, "distancia")` |
| `arma_dagas.gd:36` | `proyectil.dano = jugador.calcular_dano((9.0 + 3.5 * nivel) * (1.4 if evolucionada else 1.0))` | `proyectil.dano = jugador.calcular_dano((9.0 + 3.5 * nivel) * (1.4 if evolucionada else 1.0), "distancia")` |
| `arma_rayo.gd:27` | `var dano := jugador.calcular_dano((12.0 + 5.0 * nivel) * (1.3 if evolucionada else 1.0))` | `var dano := jugador.calcular_dano((12.0 + 5.0 * nivel) * (1.3 if evolucionada else 1.0), "distancia")` |

- [ ] **Step 3: Validar los 7 scripts**

MCP: `godot_validate_script` para `res://scripts/proyectil.gd` y las 6 armas. Expected: todos válidos.

- [ ] **Step 4: Ejecutar el test — debe pasar en verde**

MCP: `godot_run_scene` con `res://tools/test_stats.tscn`; tras ~5 s, `godot_get_game_output`.

Expected (8 líneas PASS, ninguna FAIL):

```
PASS vida de clase en hoja
PASS melee x2 con +100% melee
PASS distancia ignora melee_pct
PASS mult_dano roundtrip
PASS armadura 15 reduce 50%
PASS esquiva tope 60
PASS velocidad +20%
PASS cadencia x2
PASS robo de vida cura
FIN TEST STATS
```

Si alguna línea es FAIL: parar, diagnosticar con el skill superpowers:systematic-debugging, no seguir.

- [ ] **Step 5: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/proyectil.gd scripts/arma_espada.gd scripts/arma_martillo.gd scripts/arma_arco.gd scripts/arma_fuego.gd scripts/arma_dagas.gd scripts/arma_rayo.gd
git commit -m "feat(stats): armas declaran tipo de daño; proyectil con robo de vida"
```

---

### Task 4: Verificación en vivo y benchmark

**Files:** ninguno nuevo (solo verificación).

- [ ] **Step 1: Partida real con tuning en vivo**

1. MCP `godot_run_scene` (escena principal `res://scenes/main.tscn`).
2. Iniciar partida vía input simulado o `runtime_eval`: `get_tree().current_scene._iniciar_partida("guerrero", "bosque")`.
3. `runtime_eval`: `get_tree().get_first_node_in_group("jugador").stats.melee_pct = 200.0` → los números de daño del tajo deben ~triplicarse (verificar con `runtime_screenshot`).
4. `runtime_eval`: `get_tree().get_first_node_in_group("jugador").stats.armadura = 30.0` → daño recibido visiblemente reducido (~67%).
5. `input_sequence` de 15-20 s: moverse + disparar; confirmar que se juega EXACTAMENTE igual que antes con stats por defecto.
6. `runtime_get_performance`: FPS sin regresión.
7. `runtime_quit`.

Expected: comportamiento idéntico al juego pre-capa con stats por defecto; tuning en vivo responde.

- [ ] **Step 2: Benchmark de rendimiento**

MCP `godot_run_scene` con `res://tools/test_rendimiento.tscn`; leer salida con `godot_get_game_output`.

Expected: FPS promedio ≥ 270 (referencia previa: 304 prom / 191 mín con 90 enemigos). Si cae >15%: las propiedades get/set en el hot path son sospechoso nº 1 (verificar `calcular_dano` llamado por frame por la espada).

- [ ] **Step 3: Commit de cierre + actualizar nota Obsidian**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add -A
git commit -m "test: capa 1 stats verificada en vivo (tuning runtime + benchmark)" --allow-empty
```

Añadir a `C:\Users\braya\OneDrive\Documents\Obsidian Vault\Nightfall Survivors\Nightfall Survivors.md` (bajo el callout de sesión más reciente) una línea: rework Brotato capa 1 completada — HojaStats fuente de verdad, esquiva/armadura/robo de vida activos, legacy props para compatibilidad.

---

## Fuera de alcance (capas siguientes, planes propios)

- Capa 2: almas (drop único XP+dinero), level-up acumulado sin pausa, conversión a oro meta.
- Capa 3: timer de oleada, despawn, pantalla post-oleada (stats → tienda), reroll/lock/vender.
- Capa 4: 6 slots, fusión de tiers, habilidades de clase en tienda, tradeoffs de clase definitivos (los de la sección 3 del spec).
- Capa 5: borrar corrupción/fases/Nova/menú viejo; eventos como modificadores; arena r=38; HUD final.
