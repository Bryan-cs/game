# Capa 3: Loop de oleadas con timer + Tienda — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Oleadas con timer fijo (jefes sin timer), enemigos se disuelven al acabar, y flujo post-oleada Brotato: elección de stats (1 de 4 por nivel ganado) → tienda con almas (4 ofertas, comprar, reroll, candado) → botón "OLEADA N+1".

**Architecture:** `main.gd` gana `_timer_oleada` (cuenta atrás en `_process`; `-1` = oleada de jefe, sin timer), spawn por goteo (presupuesto repartido en ticks del `_spawner` existente), `_terminar_oleada()` (disuelve enemigos sin drops, atrae almas, paga cosecha) y `_flujo_post_oleada()` (stats → tienda). Dos pantallas nuevas siguiendo el patrón de `menu_mejoras.gd` (CanvasLayer + EstiloUI + pausa): `menu_stats.gd` (pool de 13 stats, 4 opciones, magnitud normal/grande) y `tienda_oleada.gd` (catálogo = el pool actual `_generar_opciones` con precios por rareza). El match gigante de `_al_elegir_mejora` se extrae a `_aplicar_opcion(opcion)` para que menú viejo (reliquias) y tienda lo compartan. El stat Suerte sesga `_rareza_aleatoria`.

**Desviaciones del spec (documentadas):** VENDER al 50% se pospone a capa 4 (requiere inventario de slots). El candado sobrevive al reroll pero no entre tiendas (persistencia entre tiendas → capa 4). Modificadores de oleada anunciados → capa 5.

**Tech Stack:** Godot 4.6.3. Validación/tests SOLO por CLI (`Godot_console.exe`) — NUNCA `godot_run_scene` (mata el juego, gotcha capa 1). Verificación en vivo: juego por CLI + tools runtime.

**Proyecto:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego` (`$JUEGO`). Binario: `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`.

**Spec:** `docs/superpowers/specs/2026-06-11-brotato-rework-design.md` (secciones 1-2 y capa 3 de la 6).

---

### Task 1: Test del loop (rojo)

**Files:**
- Create: `$JUEGO\tools\test_loop.gd`
- Create: `$JUEGO\tools\test_loop.tscn`

- [ ] **Step 1: Escribir el test**

`$JUEGO\tools\test_loop.gd`:

```gdscript
extends Node
## Smoke test Capa 3: timer de oleada, despawn, stats post-oleada, tienda.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg, true).timeout


func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)


func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque")
	await _esperar(2.5)
	var j = main.jugador
	# 1. Oleada 1 lanzada con timer activo y enemigos en goteo
	_check("oleada 1 con timer", main.oleada == 1 and main._timer_oleada > 0.0)
	_check("hay enemigos", get_tree().get_nodes_in_group("enemigos").size() > 0)
	# 2. Nivel ganado a mitad de oleada queda pendiente
	j.ganar_xp(30.0)
	_check("nivel pendiente sin pausa", main.mejoras_pendientes >= 1 and not get_tree().paused)
	# 3. Timer agotado: enemigos se disuelven y aparece la pantalla de stats
	main._timer_oleada = 0.05
	await _esperar(1.8)
	_check("oleada terminada", main._entre_oleadas)
	_check("enemigos disueltos", get_tree().get_nodes_in_group("enemigos").size() == 0)
	_check("pantalla de stats visible", main.menu_stats.visible)
	# 4. Elegir stat: aplica a la hoja y al consumir pendientes abre la tienda
	var dano0: float = j.stats.dano_pct
	var vida0: float = j.stats.vida_max
	var arm0: float = j.stats.armadura
	while main.menu_stats.visible:
		main.menu_stats._elegir(0)
		await _esperar(0.2)
	var cambio := j.stats.dano_pct != dano0 or j.stats.vida_max != vida0 or j.stats.armadura != arm0
	_check("stat aplicado o pendientes consumidos", main.mejoras_pendientes == 0)
	_check("tienda visible tras stats", main.tienda.visible)
	_check("pausado en tienda", get_tree().paused)
	# 5. Comprar oferta inyectada conocida
	main.oro_partida = 100
	main._ofertas_tienda[0] = {"id": "vida", "titulo": "Vitalidad", "desc": "+vida", "rareza": "Común", "mult": 1.0, "color": Color.WHITE, "precio": 10}
	var ok: bool = main.comprar_oferta(0)
	_check("compra valida descuenta almas", ok and main.oro_partida == 90)
	var ok2: bool = main.comprar_oferta(0)
	_check("oferta vendida no se recompra", not ok2 and main.oro_partida == 90)
	# 6. Reroll: descuenta y mantiene 4 ofertas
	var precio_rr: int = main.precio_reroll()
	var antes_rr: int = main.oro_partida
	var ok3: bool = main.reroll_tienda()
	_check("reroll descuenta", ok3 and main.oro_partida == antes_rr - precio_rr)
	_check("reroll mantiene 4 ofertas", main._ofertas_tienda.size() == 4)
	_check("reroll encarece", main.precio_reroll() > precio_rr)
	# 7. Siguiente oleada: cierra tienda, despausa y lanza la 2
	main.cerrar_tienda()
	_check("tienda cerrada y despausado", not main.tienda.visible and not get_tree().paused)
	await _esperar(2.2)
	_check("oleada 2 lanzada", main.oleada == 2 and not main._entre_oleadas)
	# 8. Oleada de jefe sin timer
	main._timer_oleada = 0.05
	await _esperar(1.8)
	while main.menu_stats.visible:
		main.menu_stats._elegir(0)
		await _esperar(0.2)
	main.oleada = 4
	main.cerrar_tienda()
	await _esperar(2.2)
	_check("oleada 5 es jefe sin timer", main.oleada == 5 and main._timer_oleada < 0.0)
	_check("jefe invocado", is_instance_valid(main.jefe))
	print("FIN TEST LOOP")
	get_tree().quit()
```

`$JUEGO\tools\test_loop.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/test_loop.gd" id="1"]

[node name="TestLoop" type="Node"]
script = ExtResource("1")
```

Nota: los `create_timer(seg, true)` usan `process_always=true` porque parte del test corre con el árbol pausado (tienda abierta).

- [ ] **Step 2: Validar sintaxis y correr — ROJO**

```powershell
$g = 'C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe'
$p = 'C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego'
& $g --headless --path $p --check-only --script res://tools/test_loop.gd 2>$null | Out-Null; "EXIT: $LASTEXITCODE"
$out = & $g --path $p res://tools/test_loop.tscn 2>&1 | ForEach-Object { "$_" }; $out | Where-Object { $_ -match 'PASS|FAIL|FIN|ERROR' }
```

Expected: SCRIPT ERROR al acceder `main._timer_oleada` / `main.menu_stats` (no existen) — el proceso queda VIVO (el error aborta `_ready` antes del quit). Matar SOLO los 2 procesos Godot más nuevos: `Get-Process Godot* | Sort-Object StartTime | Select-Object -Last 2 | Stop-Process -Force` (los 2 más viejos = editor del usuario).

- [ ] **Step 3: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add tools/test_loop.gd tools/test_loop.tscn
git commit -m "test(loop): smoke test capa 3 (rojo)"
```

---

### Task 2: Timer de oleada, goteo, disolución y fin por jefe (`main.gd` + `hud.gd`)

**Files:**
- Modify: `$JUEGO\scripts\main.gd`
- Modify: `$JUEGO\scripts\hud.gd`

- [ ] **Step 1: Vars nuevas**

Buscar:

```gdscript
var mejoras_pendientes := 0
```

Reemplazar por:

```gdscript
var mejoras_pendientes := 0
var menu_stats: CanvasLayer
var tienda: CanvasLayer
var _timer_oleada := 0.0
var _presupuesto_spawn := 0
var _lote_spawn := 1
var _ofertas_tienda: Array = []
var _rerolls := 0
```

- [ ] **Step 2: `_process` — countdown del timer**

Buscar:

```gdscript
	tiempo += delta
	hud.actualizar_tiempo(tiempo)
	if oleada > 0 and not _entre_oleadas:
		hud.actualizar_oleada(oleada, get_tree().get_nodes_in_group("enemigos").size(), _enemigos_oleada)
```

Reemplazar por:

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
```

- [ ] **Step 3: `_control_oleadas` → goteo de spawn + fin de oleada de jefe**

Buscar (función completa):

```gdscript
func _control_oleadas() -> void:
	if not partida_activa or get_tree().paused or _entre_oleadas:
		return
	var vivos := get_tree().get_nodes_in_group("enemigos").size()
	if oleada == 0 or vivos <= maxi(2, _enemigos_oleada / 5):
		_entre_oleadas = true
		oleada += 1
		_estado.registrar_maximo("oleada_max", oleada)
		if is_instance_valid(jugador) and jugador.stats.cosecha > 0.0:
			sumar_almas(int(jugador.stats.cosecha))
		hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
		hud.actualizar_oleada(oleada)
		_mostrar_mejoras_si_toca()
		Efectos.sonido(self, "cofre", -4.0)
		_temporizar(3.0, _lanzar_oleada)
```

Reemplazar por:

```gdscript
func _control_oleadas() -> void:
	if not partida_activa or get_tree().paused or _entre_oleadas:
		return
	if oleada == 0:
		return
	# Goteo: reparte el presupuesto de la oleada en lotes por tick
	if _presupuesto_spawn > 0:
		var vivos := get_tree().get_nodes_in_group("enemigos").size()
		var lote := mini(_lote_spawn, mini(_presupuesto_spawn, MAX_ENEMIGOS - vivos))
		for i in maxi(lote, 0):
			_generar_enemigo(_tipo_aleatorio())
		_presupuesto_spawn -= maxi(lote, 0)
	# Oleada de jefe (sin timer): termina cuando no queda ningún jefe vivo
	if _timer_oleada < 0.0 and not is_instance_valid(jefe) and _presupuesto_spawn <= 0:
		_terminar_oleada()


func _siguiente_oleada() -> void:
	if not partida_activa:
		return
	oleada += 1
	_estado.registrar_maximo("oleada_max", oleada)
	hud.anunciar("OLEADA %d" % oleada, Color(1.0, 0.85, 0.4))
	hud.actualizar_oleada(oleada)
	Efectos.sonido(self, "cofre", -4.0)
	_temporizar(1.5, _lanzar_oleada)


func _terminar_oleada() -> void:
	if _entre_oleadas or not partida_activa:
		return
	_entre_oleadas = true
	_timer_oleada = 0.0
	_presupuesto_spawn = 0
	hud.actualizar_timer_oleada(-1.0)
	# Disolución: los supervivientes se desvanecen SIN soltar nada
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		Efectos.explosion(self, enemigo.global_position, Color(0.45, 0.3, 0.65), 12, 0.8)
		enemigo.queue_free()
	# Las almas del suelo vuelan al jugador
	get_tree().call_group("gemas", "atraer")
	if is_instance_valid(jugador) and jugador.stats.cosecha > 0.0:
		sumar_almas(int(jugador.stats.cosecha))
	Efectos.sonido(self, "levelup", -4.0)
	_temporizar(1.1, _flujo_post_oleada)


func _flujo_post_oleada() -> void:
	if not partida_activa:
		return
	if mejoras_pendientes > 0:
		menu_stats.mostrar(mejoras_pendientes)
	else:
		_abrir_tienda()
```

- [ ] **Step 4: `_lanzar_oleada` — timer por oleada y presupuesto de goteo**

Buscar (función completa):

```gdscript
func _lanzar_oleada() -> void:
	_entre_oleadas = false
	if not partida_activa:
		return
	var extra_corrupcion := int(jugador.corrupcion / 25.0) * 2 if is_instance_valid(jugador) else 0
	var cantidad := mini(int((6 + oleada * 4 + extra_corrupcion) * _mult_oleada), MAX_ENEMIGOS)
	_enemigos_oleada = cantidad
	for i in cantidad:
		_generar_enemigo(_tipo_aleatorio())
	if oleada % 5 == 0:
		if JEFES_OLEADA.has(oleada):
			_invocar_jefe(JEFES_OLEADA[oleada])
		else:
			# Oleadas 20+: dos jefes aleatorios simultáneos
			for k in 2:
				_invocar_jefe(EnemigoScript.JEFES.pick_random())
```

Reemplazar por:

```gdscript
func _lanzar_oleada() -> void:
	_entre_oleadas = false
	if not partida_activa:
		return
	var es_jefe := oleada % 5 == 0
	var extra_corrupcion := int(jugador.corrupcion / 25.0) * 2 if is_instance_valid(jugador) else 0
	var cantidad := int((6 + oleada * 4 + extra_corrupcion) * _mult_oleada)
	_enemigos_oleada = cantidad
	_timer_oleada = -1.0 if es_jefe else minf(60.0, 20.0 + 2.5 * oleada)
	if es_jefe:
		hud.actualizar_timer_oleada(-1.0)
	# Lote inicial (un tercio) + goteo del resto durante la oleada
	var inicial := mini(maxi(cantidad / 3, 4), MAX_ENEMIGOS)
	for i in inicial:
		_generar_enemigo(_tipo_aleatorio())
	_presupuesto_spawn = maxi(cantidad - inicial, 0)
	var duracion := _timer_oleada if _timer_oleada > 0.0 else 45.0
	_lote_spawn = maxi(1, int(ceil(_presupuesto_spawn / maxf(duracion * 0.7, 1.0))))
	if es_jefe:
		if JEFES_OLEADA.has(oleada):
			_invocar_jefe(JEFES_OLEADA[oleada])
		else:
			# Oleadas 20+: dos jefes aleatorios simultáneos
			for k in 2:
				_invocar_jefe(EnemigoScript.JEFES.pick_random())
```

- [ ] **Step 5: Arranque de partida usa el flujo nuevo**

Buscar:

```gdscript
	partida_activa = true
	sonido_mgr.tocar_musica("res://audio/musica.wav")
```

Reemplazar por:

```gdscript
	partida_activa = true
	sonido_mgr.tocar_musica("res://audio/musica.wav")
	_temporizar(1.0, _siguiente_oleada)
```

(El arranque de la oleada 1 lo hace SOLO este temporizador; la rama `oleada == 0` de `_control_oleadas` retorna sin hacer nada — evita doble arranque.)

- [ ] **Step 6: Fin de oleada cuando muere el último jefe**

Buscar (en `_al_morir_enemigo`):

```gdscript
		else:
			hud.ocultar_jefe()
			if oleada == OLEADA_FINAL and enemigo.tipo == "rey_vacio":
				_victoria()
			else:
				sonido_mgr.tocar_musica("res://audio/musica.wav")
```

Reemplazar por:

```gdscript
		else:
			hud.ocultar_jefe()
			if oleada == OLEADA_FINAL and enemigo.tipo == "rey_vacio":
				_victoria()
			else:
				sonido_mgr.tocar_musica("res://audio/musica.wav")
				_temporizar(1.0, _terminar_oleada)
```

- [ ] **Step 7: Modo infinito tras victoria entra al flujo**

Buscar:

```gdscript
	hud.anunciar("MODO INFINITO", Color(0.85, 0.4, 1.0))
```

Reemplazar por:

```gdscript
	hud.anunciar("MODO INFINITO", Color(0.85, 0.4, 1.0))
	_temporizar(1.0, _terminar_oleada)
```

- [ ] **Step 8: `hud.gd` — countdown de oleada**

Buscar:

```gdscript
func actualizar_oro(oro: int) -> void:
```

Reemplazar por:

```gdscript
func actualizar_timer_oleada(segundos: float) -> void:
	if segundos < 0.0:
		etiqueta_tiempo.text = "☠ JEFE"
		return
	etiqueta_tiempo.text = "%d" % int(ceil(segundos))


func actualizar_oro(oro: int) -> void:
```

(Nota: si la etiqueta del reloj central no se llama `etiqueta_tiempo`, localizar el nombre real con `grep "func actualizar_tiempo" scripts/hud.gd -A 3` y usar esa variable.)

- [ ] **Step 9: Validar (`main` y `hud` EXIT 0) y commit**

El test sigue rojo (faltan `menu_stats` y `tienda` — Tasks 3-4).

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/main.gd scripts/hud.gd
git commit -m "feat(loop): timer de oleada, spawn por goteo, disolucion y fin por jefe"
```

---

### Task 3: Pantalla de stats post-oleada

**Files:**
- Create: `$JUEGO\scripts\menu_stats.gd`
- Modify: `$JUEGO\scripts\main.gd`

- [ ] **Step 1: Crear `scripts/menu_stats.gd`**

```gdscript
extends CanvasLayer
## Post-oleada: elige 1 subida de stat por nivel ganado (estilo Brotato).

signal terminado

const PICKS := [
	{"clave": "vida_max", "nombre": "Vida Máxima", "normal": 10.0, "grande": 25.0, "sufijo": ""},
	{"clave": "regen", "nombre": "Regeneración", "normal": 0.5, "grande": 1.5, "sufijo": "/s"},
	{"clave": "robo_vida", "nombre": "Robo de Vida", "normal": 2.0, "grande": 5.0, "sufijo": "%"},
	{"clave": "dano_pct", "nombre": "Daño", "normal": 5.0, "grande": 12.0, "sufijo": "%"},
	{"clave": "melee_pct", "nombre": "Daño Melee", "normal": 8.0, "grande": 18.0, "sufijo": "%"},
	{"clave": "distancia_pct", "nombre": "Daño a Distancia", "normal": 8.0, "grande": 18.0, "sufijo": "%"},
	{"clave": "vel_ataque_pct", "nombre": "Vel. de Ataque", "normal": 5.0, "grande": 12.0, "sufijo": "%"},
	{"clave": "critico_pct", "nombre": "Crítico", "normal": 3.0, "grande": 7.0, "sufijo": "%"},
	{"clave": "armadura", "nombre": "Armadura", "normal": 2.0, "grande": 5.0, "sufijo": ""},
	{"clave": "esquiva_pct", "nombre": "Esquiva", "normal": 3.0, "grande": 6.0, "sufijo": "%"},
	{"clave": "velocidad_pct", "nombre": "Velocidad", "normal": 4.0, "grande": 9.0, "sufijo": "%"},
	{"clave": "suerte", "nombre": "Suerte", "normal": 5.0, "grande": 12.0, "sufijo": ""},
	{"clave": "cosecha", "nombre": "Cosecha", "normal": 2.0, "grande": 6.0, "sufijo": " almas"},
]

var jugador: Jugador
var _restantes := 0
var _opciones: Array = []
var _botones: VBoxContainer
var _titulo: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(_titulo, 24)
	caja.add_child(_titulo)
	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 10)
	caja.add_child(_botones)


func mostrar(niveles: int) -> void:
	_restantes = niveles
	_refrescar()
	visible = true
	get_tree().paused = true


func _fmt(v: float) -> String:
	return ("%.1f" % v) if absf(v - roundf(v)) > 0.01 else ("%d" % int(v))


func _refrescar() -> void:
	_titulo.text = "NIVEL GANADO — Elige un stat (%d)" % _restantes
	for hijo in _botones.get_children():
		hijo.queue_free()
	var pool := PICKS.duplicate()
	pool.shuffle()
	_opciones = []
	for i in 4:
		var pick: Dictionary = pool[i].duplicate()
		pick["es_grande"] = randf() < 0.25
		pick["monto"] = float(pick["grande"]) if pick["es_grande"] else float(pick["normal"])
		_opciones.append(pick)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(420, 50)
		var estrella: String = "★ " if pick["es_grande"] else ""
		boton.text = "%s%s  +%s%s" % [estrella, pick["nombre"], _fmt(pick["monto"]), pick["sufijo"]]
		boton.add_theme_font_size_override("font_size", 17)
		if pick["es_grande"]:
			boton.add_theme_color_override("font_color", Color(0.75, 0.4, 1.0))
		boton.pressed.connect(_elegir.bind(i))
		_botones.add_child(boton)


func _elegir(indice: int) -> void:
	var pick: Dictionary = _opciones[indice]
	jugador.stats.set(pick["clave"], float(jugador.stats.get(pick["clave"])) + float(pick["monto"]))
	if pick["clave"] == "vida_max":
		jugador.vida_cambiada.emit(jugador.vida, jugador.vida_max)
	_restantes -= 1
	if _restantes > 0:
		_refrescar()
	else:
		visible = false
		terminado.emit()
```

- [ ] **Step 2: `main.gd` — preload, creación y conexión**

Buscar:

```gdscript
const MenuScript := preload("res://scripts/menu_mejoras.gd")
```

Reemplazar por:

```gdscript
const MenuScript := preload("res://scripts/menu_mejoras.gd")
const MenuStatsScript := preload("res://scripts/menu_stats.gd")
const TiendaOleadaScript := preload("res://scripts/tienda_oleada.gd")
```

Buscar:

```gdscript
	menu = CanvasLayer.new()
	menu.set_script(MenuScript)
	add_child(menu)
	menu.mejora_elegida.connect(_al_elegir_mejora)
```

Reemplazar por:

```gdscript
	menu = CanvasLayer.new()
	menu.set_script(MenuScript)
	add_child(menu)
	menu.mejora_elegida.connect(_al_elegir_mejora)
	menu_stats = CanvasLayer.new()
	menu_stats.set_script(MenuStatsScript)
	add_child(menu_stats)
	menu_stats.terminado.connect(_al_terminar_stats)
	tienda = CanvasLayer.new()
	tienda.set_script(TiendaOleadaScript)
	add_child(tienda)
```

Y en `_crear_jugador` (o donde se asigna `controles.jugador = jugador` en `_iniciar_partida`) hay que pasar el jugador a la pantalla. Más simple y robusto: en `_flujo_post_oleada`, antes de `menu_stats.mostrar(...)`, añadir `menu_stats.jugador = jugador`. Versión final de `_flujo_post_oleada` (sustituye a la de Task 2):

```gdscript
func _flujo_post_oleada() -> void:
	if not partida_activa:
		return
	if mejoras_pendientes > 0:
		menu_stats.jugador = jugador
		menu_stats.mostrar(mejoras_pendientes)
	else:
		_abrir_tienda()


func _al_terminar_stats() -> void:
	mejoras_pendientes = 0
	_abrir_tienda()
```

(Task 2 deja `_flujo_post_oleada` llamando a `menu_stats.mostrar` sin asignar jugador — si Task 2 y 3 se implementan en commits separados, el juego compila igual porque `menu_stats` es `CanvasLayer` y la rama solo corre con `mejoras_pendientes > 0`; el test sigue rojo hasta Task 4 de todos modos.)

- [ ] **Step 3: Validar ambos scripts (EXIT 0) y commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/menu_stats.gd scripts/main.gd
git commit -m "feat(loop): pantalla de eleccion de stats post-oleada"
```

---

### Task 4: Tienda de oleada

**Files:**
- Create: `$JUEGO\scripts\tienda_oleada.gd`
- Modify: `$JUEGO\scripts\main.gd`

- [ ] **Step 1: Crear `scripts/tienda_oleada.gd`**

```gdscript
extends CanvasLayer
## Tienda entre oleadas: 4 ofertas con precio en almas, reroll y candado.

var main: Node
var _titulo: Label
var _almas_lbl: Label
var _filas: VBoxContainer
var _reroll_btn: Button
var _siguiente_btn: Button


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(_titulo, 24)
	caja.add_child(_titulo)
	_almas_lbl = Label.new()
	_almas_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_almas_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	_almas_lbl.add_theme_font_size_override("font_size", 19)
	caja.add_child(_almas_lbl)
	_filas = VBoxContainer.new()
	_filas.add_theme_constant_override("separation", 8)
	caja.add_child(_filas)
	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 12)
	abajo.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(abajo)
	_reroll_btn = Button.new()
	_reroll_btn.custom_minimum_size = Vector2(200, 46)
	_reroll_btn.pressed.connect(func() -> void: main.reroll_tienda())
	abajo.add_child(_reroll_btn)
	_siguiente_btn = Button.new()
	_siguiente_btn.custom_minimum_size = Vector2(240, 46)
	_siguiente_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_siguiente_btn.pressed.connect(func() -> void: main.cerrar_tienda())
	abajo.add_child(_siguiente_btn)


func abrir(oleada: int) -> void:
	_titulo.text = "TIENDA — Tras la oleada %d" % oleada
	_siguiente_btn.text = "OLEADA %d  →" % (oleada + 1)
	refrescar()
	visible = true
	get_tree().paused = true


func refrescar() -> void:
	_almas_lbl.text = "Almas: %d" % main.oro_partida
	_reroll_btn.text = "REROLL (%d almas)" % main.precio_reroll()
	_reroll_btn.disabled = main.oro_partida < main.precio_reroll()
	for hijo in _filas.get_children():
		hijo.queue_free()
	for i in main._ofertas_tienda.size():
		var oferta: Dictionary = main._ofertas_tienda[i]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_filas.add_child(fila)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(480, 50)
		if oferta.get("vendida", false):
			boton.text = "— VENDIDO —"
			boton.disabled = true
		else:
			boton.text = "[%s]  %s — %s   · %d almas" % [oferta.rareza, oferta.titulo, oferta.desc, int(oferta.precio)]
			boton.add_theme_color_override("font_color", oferta.color)
			boton.disabled = main.oro_partida < int(oferta.precio)
		boton.add_theme_font_size_override("font_size", 16)
		boton.pressed.connect(func() -> void:
			main.comprar_oferta(i)
			refrescar())
		fila.add_child(boton)
		var candado := Button.new()
		candado.custom_minimum_size = Vector2(52, 50)
		candado.toggle_mode = true
		candado.button_pressed = oferta.get("bloqueada", false)
		candado.text = "🔒"
		candado.toggled.connect(func(activo: bool) -> void: oferta["bloqueada"] = activo)
		fila.add_child(candado)
```

- [ ] **Step 2: `main.gd` — abrir tienda, comprar, reroll, cerrar, precios**

Añadir después de `func _al_terminar_stats()` (Task 3):

```gdscript
func _abrir_tienda() -> void:
	_rerolls = 0
	_ofertas_tienda = _generar_opciones(4)
	for oferta in _ofertas_tienda:
		oferta["precio"] = _precio_opcion(oferta)
	tienda.main = self
	tienda.abrir(oleada)


func _precio_opcion(opcion: Dictionary) -> int:
	var base := 15
	match String(opcion.rareza):
		"Rara":
			base = 25
		"Épica":
			base = 45
		"Legendaria":
			base = 70
		"Mítica":
			base = 100
	return int(base * (1.0 + 0.05 * oleada))


func precio_reroll() -> int:
	return 5 + 2 * oleada + 4 * _rerolls


func comprar_oferta(indice: int) -> bool:
	if indice >= _ofertas_tienda.size():
		return false
	var opcion: Dictionary = _ofertas_tienda[indice]
	var precio := int(opcion.precio)
	if opcion.get("vendida", false) or oro_partida < precio:
		return false
	oro_partida -= precio
	hud.actualizar_oro(oro_partida)
	opcion["vendida"] = true
	_aplicar_opcion(opcion)
	Efectos.sonido(self, "cofre", -4.0)
	return true


func reroll_tienda() -> bool:
	var precio := precio_reroll()
	if oro_partida < precio:
		return false
	oro_partida -= precio
	hud.actualizar_oro(oro_partida)
	_rerolls += 1
	var nuevas := _generar_opciones(4)
	for i in nuevas.size():
		nuevas[i]["precio"] = _precio_opcion(nuevas[i])
		if i < _ofertas_tienda.size() and _ofertas_tienda[i].get("bloqueada", false) and not _ofertas_tienda[i].get("vendida", false):
			nuevas[i] = _ofertas_tienda[i]
	_ofertas_tienda = nuevas
	tienda.refrescar()
	return true


func cerrar_tienda() -> void:
	tienda.visible = false
	get_tree().paused = false
	_siguiente_oleada()
```

- [ ] **Step 3: `_generar_opciones` con cantidad parametrizable**

Buscar:

```gdscript
func _generar_opciones() -> Array:
```

Reemplazar por:

```gdscript
func _generar_opciones(cantidad := 3) -> Array:
```

Buscar:

```gdscript
	pool.shuffle()
	var opciones: Array = []
	for i in mini(3, pool.size()):
```

Reemplazar por:

```gdscript
	pool.shuffle()
	var opciones: Array = []
	for i in mini(cantidad, pool.size()):
```

- [ ] **Step 4: Extraer `_aplicar_opcion` del match de `_al_elegir_mejora`**

Buscar:

```gdscript
func _al_elegir_mejora(indice: int) -> void:
	var opcion: Dictionary = _opciones_actuales[indice]
	if _eligiendo_reliquia:
		_eligiendo_reliquia = false
		_aplicar_reliquia(opcion)
		if mejoras_pendientes > 0:
			_mostrar_mejoras_si_toca()
		else:
			get_tree().paused = false
		return
	var mult: float = opcion.mult
	var extra := 1 if mult >= 1.7 else 0
```

Reemplazar por:

```gdscript
func _al_elegir_mejora(indice: int) -> void:
	var opcion: Dictionary = _opciones_actuales[indice]
	if _eligiendo_reliquia:
		_eligiendo_reliquia = false
		_aplicar_reliquia(opcion)
		if mejoras_pendientes > 0:
			_mostrar_mejoras_si_toca()
		else:
			get_tree().paused = false
		return
	_aplicar_opcion(opcion)
	mejoras_pendientes -= 1
	if mejoras_pendientes > 0:
		_mostrar_mejoras_si_toca()
	else:
		get_tree().paused = false


func _aplicar_opcion(opcion: Dictionary) -> void:
	var mult: float = opcion.mult
	var extra := 1 if mult >= 1.7 else 0
```

Y buscar el final del match:

```gdscript
				var clave: String = opcion.id.trim_prefix("mejorar_")
				if armas.has(clave):
					armas[clave].mejorar(1 + extra)
	mejoras_pendientes -= 1
	if mejoras_pendientes > 0:
		_mostrar_mejoras_si_toca()
	else:
		get_tree().paused = false
```

Reemplazar por:

```gdscript
				var clave: String = opcion.id.trim_prefix("mejorar_")
				if armas.has(clave):
					armas[clave].mejorar(1 + extra)
```

- [ ] **Step 5: Suerte sesga la rareza**

Buscar:

```gdscript
	var r := randf() - (jugador.corrupcion * 0.002 if is_instance_valid(jugador) else 0.0)
```

Reemplazar por:

```gdscript
	var sesgo := 0.0
	if is_instance_valid(jugador):
		sesgo = jugador.corrupcion * 0.002 + jugador.stats.suerte * 0.003
	var r := randf() - sesgo
```

- [ ] **Step 6: Validar (`main`, `tienda_oleada`, `menu_stats` EXIT 0), test VERDE y regresión**

```powershell
$g = 'C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe'
$p = 'C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego'
foreach ($s in 'main','tienda_oleada','menu_stats') { & $g --headless --path $p --check-only --script "res://scripts/$s.gd" 2>$null | Out-Null; "$s EXIT: $LASTEXITCODE" }
foreach ($t in 'test_loop','test_almas','test_stats') {
  "== $t =="
  $out = & $g --path $p "res://tools/$t.tscn" 2>&1 | ForEach-Object { "$_" }; $out | Where-Object { $_ -match 'PASS|FAIL|FIN' }
}
```

Expected: test_loop 18/18 PASS; test_stats 9/9. **test_almas:** los checks de level-up/cosecha/respiro cambiaron de mecánica (el menú viejo ya no abre en el respiro; ahora abre `menu_stats`): si `menu de mejoras aparece en el respiro` falla, ACTUALIZAR ese check del test a `main.menu_stats.visible or main.tienda.visible` y el de cosecha sigue igual (se paga en `_terminar_oleada`). Documentar el cambio en el commit.

- [ ] **Step 7: Commit**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/tienda_oleada.gd scripts/menu_stats.gd scripts/main.gd tools/test_almas.gd
git commit -m "feat(tienda): tienda de oleada con almas, reroll y candado; stats post-oleada"
```

---

### Task 5: Verificación en vivo

- [ ] **Step 1: Partida real por CLI + runtime** (patrón capas 1-2; clicks NO llegan a menús pausados → usar `runtime_eval` para comprar/cerrar)

1. Lanzar `res://scenes/main.tscn` por CLI en background; `runtime_eval` inicia partida.
2. Jugar la oleada 1 con `input_sequence` (~25 s); screenshot: countdown del timer visible en el centro.
3. Dejar agotar el timer → screenshot: disolución + pantalla stats (si hubo nivel) o tienda.
4. `runtime_eval`: elegir stats (`scene_root.menu_stats._elegir(0)`), comprar oferta asequible (`scene_root.comprar_oferta(i)`), reroll, screenshot de la tienda.
5. `cerrar_tienda()` → oleada 2 arranca; verificar goteo (enemigos aparecen progresivamente).
6. Saltar a jefe: `scene_root.oleada = 4; scene_root.cerrar_tienda()` desde la siguiente tienda → oleada 5: HUD "☠ JEFE", sin countdown; matar jefe (`recibir_dano`) → tienda aparece tras 1 s.
7. `runtime_get_performance` + `runtime_quit`.

- [ ] **Step 2: Commit cierre + notas**

```powershell
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add -A
git commit --allow-empty -m "test: capa 3 loop+tienda verificada en vivo"
```

Actualizar nota Obsidian (capa 3 hecha) y memoria `rework-brotato.md`.

---

## Fuera de alcance

- Vender ítems/armas al 50%, fusión de tiers, 6 slots, candado persistente entre tiendas, habilidades exclusivas con borde dorado → capa 4.
- Borrar menú viejo de mejoras (queda SOLO para reliquias), corrupción, fases, eventos→modificadores anunciados, arena r=38, HUD final → capa 5.
