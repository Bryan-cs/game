# Capa 2: Almas — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Material único "almas": recoger la gema da XP Y suma moneda de run a la vez; desaparece el oro aleatorio por kill; subir de nivel ya no pausa la partida (las mejoras se resuelven en el respiro entre oleadas); stat Cosecha da almas al avanzar de oleada.

**Architecture:** Se conserva la variable `oro_partida` de `main.gd` como contador de almas (el banking a oro meta 1:1 en victoria/muerte/salir ya existe y queda intacto; capa 3 la gastará en la tienda). `gema_xp.gd` se tiñe de alma (violeta espectral) y al recogerse notifica a main vía `call_group("partida", "sumar_almas", n)`. `_al_subir_nivel` solo acumula `mejoras_pendientes` (ya existía el contador) y el menú se abre en el respiro de `_control_oleadas`. La elección de 4 stats por nivel llega en capa 3 con la pantalla post-oleada; en esta capa el menú viejo se reutiliza, solo cambia CUÁNDO aparece.

**Tech Stack:** Godot 4.6.3 (GDScript). Validación y tests por CLI (`Godot_console.exe`), NUNCA `godot_run_scene` del editor (mata el juego silenciosamente — gotcha capa 1). Verificación en vivo: lanzar juego por CLI + tools runtime.

**Proyecto del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego` (`$JUEGO`, ruta con espacios — siempre entre comillas).

**Binario:** `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`

**Spec:** `docs/superpowers/specs/2026-06-11-brotato-rework-design.md` (sección 2 y capa 2 de la sección 6).

---

### Task 1: Test de almas (rojo)

**Files:**
- Create: `$JUEGO\tools\test_almas.gd`
- Create: `$JUEGO\tools\test_almas.tscn`

- [ ] **Step 1: Escribir el test**

`$JUEGO\tools\test_almas.gd`:

```gdscript
extends Node
## Smoke test Capa 2: almas (XP + moneda), level-up sin pausa, cosecha.

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
	# 1. Matar un enemigo suelta UN alma (sin oro aleatorio aparte)
	var almas0: int = main.oro_partida
	var e = main._generar_enemigo("zombie")
	e.global_position = j.global_position + Vector3(4.0, 1.2, 0.0)
	e.velocidad = 0.0
	e.recibir_dano(99999.0)
	await _esperar(0.2)
	var gemas := get_tree().get_nodes_in_group("gemas")
	_check("kill suelta alma", gemas.size() >= 1)
	_check("kill NO da moneda directa", main.oro_partida == almas0)
	# 2. Recoger el alma da XP y moneda a la vez
	var xp0: float = j.xp
	for g in gemas:
		g.atraer()
	await _esperar(1.2)
	_check("alma da XP", j.xp > xp0 or j.nivel > 1)
	_check("alma da moneda", main.oro_partida > almas0)
	# 3. Subir de nivel NO pausa ni abre menú; acumula
	var pendientes0: int = main.mejoras_pendientes
	j.ganar_xp(60.0)
	await _esperar(0.3)
	_check("level-up no pausa", not get_tree().paused)
	_check("level-up no abre menu", not main.menu.visible)
	_check("mejoras acumuladas", main.mejoras_pendientes > pendientes0)
	# 4. Respiro entre oleadas: cosecha suma almas y el menú pendiente aparece
	j.stats.cosecha = 5.0
	var almas1: int = main.oro_partida
	main._control_oleadas()
	await _esperar(0.3)
	_check("cosecha suma almas al avanzar oleada", main.oro_partida == almas1 + 5)
	_check("menu de mejoras aparece en el respiro", main.menu.visible)
	print("FIN TEST ALMAS")
	get_tree().quit()
```

`$JUEGO\tools\test_almas.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/test_almas.gd" id="1"]

[node name="TestAlmas" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Ejecutar y verificar ROJO**

```powershell
$out = & 'C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe' --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_almas.tscn 2>&1 | ForEach-Object { "$_" }; $out | Where-Object { $_ -match 'PASS|FAIL|FIN' }
```

Expected: al menos `FAIL alma da moneda`, `FAIL level-up no abre menu` y `FAIL cosecha suma almas al avanzar oleada` (el código viejo da oro aleatorio, pausa al subir nivel y no tiene cosecha). Si el proceso cuelga >60 s, matar los DOS procesos Godot más recientes (no los dos más viejos: son el editor del usuario).

- [ ] **Step 3: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add tools/test_almas.gd tools/test_almas.tscn
git commit -m "test(almas): smoke test capa 2 (rojo)"
```

---

### Task 2: Economía de almas

**Files:**
- Modify: `$JUEGO\scripts\gema_xp.gd`
- Modify: `$JUEGO\scripts\main.gd`
- Modify: `$JUEGO\scripts\hud.gd`

- [ ] **Step 1: `gema_xp.gd` — visual de alma + notifica moneda al recogerse**

Buscar:

```gdscript
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.4)
```

Reemplazar por:

```gdscript
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.35, 0.95)
```

Buscar:

```gdscript
	if distancia <= 0.8:
		_jugador.ganar_xp(valor)
		queue_free()
```

Reemplazar por:

```gdscript
	if distancia <= 0.8:
		_jugador.ganar_xp(valor)
		get_tree().call_group("partida", "sumar_almas", almas)
		queue_free()
```

Y bajo `var valor := 1.0` añadir:

```gdscript
var almas := 1
```

(Quedando `var valor := 1.0` y `var almas := 1` en líneas consecutivas.)

- [ ] **Step 2: `main.gd` — grupo "partida" + `sumar_almas`**

Buscar:

```gdscript
func _ready() -> void:
	randomize()
	_crear_interfaz()
```

Reemplazar por:

```gdscript
func _ready() -> void:
	add_to_group("partida")
	randomize()
	_crear_interfaz()
```

Añadir esta función nueva justo después de `func _al_abrir_cofre()` (tras su última línea `	_mostrar_mejoras_si_toca()`):

```gdscript
func sumar_almas(n: int) -> void:
	if not partida_activa:
		return
	oro_partida += n
	hud.actualizar_oro(oro_partida)
```

- [ ] **Step 3: `main.gd` — el kill ya no da oro directo; `_prob_oro` = prob de alma extra**

Buscar:

```gdscript
	_soltar_gema(pos, enemigo.xp)
	if randf() < _prob_oro:
		oro_partida += randi_range(1, 3)
		hud.actualizar_oro(oro_partida)
	if enemigo.es_jefe:
		oro_partida += 100
		hud.actualizar_oro(oro_partida)
```

Reemplazar por:

```gdscript
	_soltar_gema(pos, enemigo.xp)
	if enemigo.es_jefe:
		sumar_almas(100)
```

- [ ] **Step 4: `main.gd` — gema con almas extra según `_prob_oro`**

Buscar (final de `_soltar_gema`):

```gdscript
	var gema := Node3D.new()
	gema.set_script(GemaScript)
	gema.valor = valor
	add_child(gema)
	gema.global_position = Vector3(pos.x, 0.5, pos.z)
```

Reemplazar por:

```gdscript
	var gema := Node3D.new()
	gema.set_script(GemaScript)
	gema.valor = valor
	gema.almas = 1 + (randi_range(1, 2) if randf() < _prob_oro else 0)
	add_child(gema)
	gema.global_position = Vector3(pos.x, 0.5, pos.z)
```

(`rel_craneo` y el evento Lluvia de Sangre siguen funcionando: suben `_prob_oro` → más almas por gema.)

- [ ] **Step 5: `main.gd` — cofre da almas vía sumar_almas**

Buscar:

```gdscript
func _al_abrir_cofre() -> void:
	Efectos.sonido(self, "cofre")
	oro_partida += 25
	hud.actualizar_oro(oro_partida)
	mejoras_pendientes += 1
	_mostrar_mejoras_si_toca()
```

Reemplazar por:

```gdscript
func _al_abrir_cofre() -> void:
	Efectos.sonido(self, "cofre")
	sumar_almas(25)
	mejoras_pendientes += 1
```

(El menú del cofre también queda diferido al respiro — Task 3 conecta el respiro.)

- [ ] **Step 6: `main.gd` — cosecha al avanzar de oleada**

Buscar (en `_control_oleadas`):

```gdscript
		_entre_oleadas = true
		oleada += 1
		_estado.registrar_maximo("oleada_max", oleada)
		hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
```

Reemplazar por:

```gdscript
		_entre_oleadas = true
		oleada += 1
		_estado.registrar_maximo("oleada_max", oleada)
		if is_instance_valid(jugador) and jugador.stats.cosecha > 0.0:
			sumar_almas(int(jugador.stats.cosecha))
		hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
```

- [ ] **Step 7: `hud.gd` — etiqueta "Almas"**

Buscar:

```gdscript
	etiqueta_oro = _crear_etiqueta("Oro: 0", 18)
```

Reemplazar por:

```gdscript
	etiqueta_oro = _crear_etiqueta("Almas: 0", 18)
```

Buscar:

```gdscript
	etiqueta_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
```

Reemplazar por:

```gdscript
	etiqueta_oro.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
```

Buscar:

```gdscript
	etiqueta_oro.text = "Oro: %d" % oro
```

Reemplazar por:

```gdscript
	etiqueta_oro.text = "Almas: %d" % oro
```

- [ ] **Step 8: `main.gd` — texto del game over**

Buscar:

```gdscript
	_go_stats.text = "Sobreviviste %02d:%02d  ·  Bajas: %d  ·  Oro ganado: %d" % [s / 60, s % 60, kills, oro_partida]
```

Reemplazar por:

```gdscript
	_go_stats.text = "Sobreviviste %02d:%02d  ·  Bajas: %d  ·  Almas: %d" % [s / 60, s % 60, kills, oro_partida]
```

- [ ] **Step 9: Validar (3 scripts, EXIT 0 cada uno)**

```powershell
$g = 'C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe'
$p = 'C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego'
foreach ($s in 'gema_xp','main','hud') { & $g --headless --path $p --check-only --script "res://scripts/$s.gd" 2>$null | Out-Null; "$s EXIT: $LASTEXITCODE" }
```

- [ ] **Step 10: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/gema_xp.gd scripts/main.gd scripts/hud.gd
git commit -m "feat(almas): material unico XP+moneda; cosecha; sin oro aleatorio por kill"
```

---

### Task 3: Level-up diferido al respiro

**Files:**
- Modify: `$JUEGO\scripts\main.gd`

- [ ] **Step 1: `_al_subir_nivel` solo acumula y anuncia**

Buscar:

```gdscript
func _al_subir_nivel(_nivel: int) -> void:
	_estado.registrar_maximo("nivel_max", _nivel)
	Efectos.sonido(self, "levelup")
	if is_instance_valid(jugador):
		Efectos.explosion(self, jugador.global_position, Color(0.3, 1.0, 0.5), 30)
	mejoras_pendientes += 1
	_mostrar_mejoras_si_toca()
```

Reemplazar por:

```gdscript
func _al_subir_nivel(_nivel: int) -> void:
	_estado.registrar_maximo("nivel_max", _nivel)
	Efectos.sonido(self, "levelup")
	if is_instance_valid(jugador):
		Efectos.explosion(self, jugador.global_position, Color(0.3, 1.0, 0.5), 30)
	mejoras_pendientes += 1
	hud.anunciar("¡NIVEL %d!" % _nivel, Color(0.4, 1.0, 0.6))
```

- [ ] **Step 2: el respiro abre las mejoras pendientes**

Buscar (en `_control_oleadas`, tras el edit de cosecha de Task 2):

```gdscript
		hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
		hud.actualizar_oleada(oleada)
```

Reemplazar por:

```gdscript
		hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
		hud.actualizar_oleada(oleada)
		_mostrar_mejoras_si_toca()
```

- [ ] **Step 3: Validar main.gd (EXIT 0) y correr el test — VERDE (9/9 PASS)**

```powershell
$g = 'C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe'
$p = 'C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego'
& $g --headless --path $p --check-only --script res://scripts/main.gd 2>$null | Out-Null; "main EXIT: $LASTEXITCODE"
$out = & $g --path $p res://tools/test_almas.tscn 2>&1 | ForEach-Object { "$_" }; $out | Where-Object { $_ -match 'PASS|FAIL|FIN' }
```

Expected:

```
PASS kill suelta alma
PASS kill NO da moneda directa
PASS alma da XP
PASS alma da moneda
PASS level-up no pausa
PASS level-up no abre menu
PASS mejoras acumuladas
PASS cosecha suma almas al avanzar oleada
PASS menu de mejoras aparece en el respiro
FIN TEST ALMAS
```

También re-correr `res://tools/test_stats.tscn` (capa 1 sigue verde, 9/9 PASS).

Si hay FAIL: parar y diagnosticar con superpowers:systematic-debugging — no parchear el test.

- [ ] **Step 4: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/main.gd
git commit -m "feat(almas): level-up acumulado sin pausa; mejoras en el respiro entre oleadas"
```

---

### Task 4: Verificación en vivo

**Files:** ninguno (verificación + notas).

- [ ] **Step 1: Partida real**

1. Lanzar por CLI en background: `& $g --path $p res://scenes/main.tscn` (NO `godot_run_scene`).
2. `runtime_eval`: `scene_root.menu_seleccion.visible = false; scene_root._iniciar_partida("guerrero", "bosque"); return "ok"`.
3. Jugar 20-30 s con `input_sequence` (mover + disparar). Confirmar con `runtime_screenshot`: HUD muestra "Almas: N" creciendo, anuncios "¡NIVEL X!" sin pausa, gemas violetas.
4. `runtime_eval`: `return {"almas": scene_root.oro_partida, "pendientes": scene_root.mejoras_pendientes, "pausado": tree.paused}` — pendientes ≥ 0 y pausado false durante oleada.
5. Esperar el respiro (o forzar matando: `tree.call_group("enemigos", "recibir_dano", 99999.0)`) → screenshot del menú de mejoras abierto en el respiro.
6. `runtime_get_performance` (sin regresión) y `runtime_quit`.

- [ ] **Step 2: Commit de cierre + notas**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git commit --allow-empty -m "test: capa 2 almas verificada en vivo"
```

Actualizar la nota Obsidian `Nightfall Survivors.md` (callout sesión 2026-06-11: capa 2 hecha) y la memoria `rework-brotato.md` (capa 2 ✅).

---

## Fuera de alcance

- Pantalla de elección de stats (1 de 4 por nivel) y tienda → capa 3 (sustituirá al menú viejo del respiro).
- Gasto de almas → capa 3 (tienda).
- Eliminar reliquias/corrupción → capa 5.
