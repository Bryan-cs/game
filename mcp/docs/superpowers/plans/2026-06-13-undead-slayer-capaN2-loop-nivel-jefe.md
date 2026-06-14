# Capa N2 — Loop de nivel + jefe (completar = matar jefe) — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development o superpowers:executing-plans. Pasos con checkbox (`- [ ]`).

**Goal:** Convertir la partida de "supervivencia infinita" a un **nivel con final**: tras un periodo de spawn continuo aparece el **jefe del nivel**; al matarlo el nivel se **completa**, se **desbloquea el siguiente** y se muestra una pantalla de completado.

**Architecture:** `scripts/main.gd` gana `nivel_actual` (índice del nivel en juego). El `_process` dispara el jefe una vez cuando `tiempo` supera el umbral del nivel (`_jefe_disparado` evita repetir). La muerte del jefe ya está centralizada en `_al_morir_enemigo`; cuando no queda ningún jefe vivo, en vez de solo ocultar el HUD se llama a `_completar_nivel()`, que persiste el desbloqueo en `game_state` (`nivel_max_desbloqueado`) y muestra la pantalla de completado (reutiliza la capa `_capa_game_over` con título "NIVEL COMPLETADO"). La selección de los 60 niveles y la config por nivel son Capa N5; las estrellas son Capa N4 — aquí NO se añaden. El jefe del nivel se elige de forma provisional ciclando `EnemigoScript.JEFES`.

**Tech Stack:** Godot 4.6.3, GDScript. Tests headless por CLI.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0` (continuar ahí).

**Gotchas de runner:** UNA instancia Godot a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe` entre corridas; ventana azul ~6 MB = colgada). Prefijar `timeout 45`. Binario: `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`.

---

### Estado actual relevante (`scripts/main.gd`, tras N1)

- `_iniciar_partida(clave, mapa := "bosque")` (~490): crea entorno/jugador/arma; `partida_activa = true`. Sin oleadas.
- `_process(delta)` (~90): suma `tiempo`, `hud.actualizar_tiempo`, actualiza barra de jefe si vivo.
- `_invocar_jefe(tipo)` (~800): crea el jefe (`jefe = _generar_enemigo(tipo)`), conecta esbirros, HUD + música de jefe.
- `_al_morir_enemigo(enemigo)` (~816): al morir un jefe suelta cofre y, si no queda otro jefe vivo, `hud.ocultar_jefe()` + música normal. **Aquí se engancha la compleción.**
- `_victoria()` (~1011) y `_capa_game_over`/`_go_titulo`/`_go_seguir`/`_refrescar_game_over()` (pantalla reutilizable).
- `EnemigoScript.JEFES == ["gigante_putrefacto", "senor_sombras", "rey_vacio"]`; `NOMBRES_JEFES` mapea nombres.
- Autoload `Estado` = `scripts/game_state.gd` con `guardar()`/`cargar()`.

---

### Task 1: Persistencia del nivel desbloqueado en `game_state`

**Files:** Modify `scripts/game_state.gd`

- [ ] **Step 1:** Añadir la variable (junto a las otras de progreso, p. ej. tras `var oro_total := 0`):
```gdscript
var nivel_max_desbloqueado := 0  # índice del nivel más alto desbloqueado (0 = primero)
```

- [ ] **Step 2:** En `guardar()`, añadir la clave al diccionario `datos`:
```gdscript
		"nivel_max_desbloqueado": nivel_max_desbloqueado,
```

- [ ] **Step 3:** En `cargar()`, leerla (con default):
```gdscript
	nivel_max_desbloqueado = int(datos.get("nivel_max_desbloqueado", 0))
```

- [ ] **Step 4:** Añadir un helper para desbloquear avanzando:
```gdscript
func desbloquear_nivel(indice: int) -> void:
	if indice > nivel_max_desbloqueado:
		nivel_max_desbloqueado = indice
		guardar()
```

- [ ] **Step 5:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/game_state.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: `main.gd` — `nivel_actual`, umbral de jefe, disparo único

**Files:** Modify `scripts/main.gd`

- [ ] **Step 1:** Añadir vars de nivel (junto a `var jefe`):
```gdscript
var nivel_actual := 0
var _jefe_disparado := false
```

- [ ] **Step 2:** Añadir constante de duración antes del jefe (junto a `MAX_ENEMIGOS`):
```gdscript
const SEGUNDOS_HASTA_JEFE := 60.0  # tras este tiempo de combate aparece el jefe del nivel
```

- [ ] **Step 3:** Aceptar el nivel en `_iniciar_partida` y resetear el flag. Cambiar la firma y el cuerpo inicial:
```gdscript
func _iniciar_partida(clave: String, mapa := "bosque") -> void:
	clase_jugador = clave
	mapa_actual = mapa if TEMAS_MAPA.has(mapa) else "bosque"
```
por:
```gdscript
func _iniciar_partida(clave: String, mapa := "bosque", indice_nivel := 0) -> void:
	clase_jugador = clave
	mapa_actual = mapa if TEMAS_MAPA.has(mapa) else "bosque"
	nivel_actual = indice_nivel
	_jefe_disparado = false
```

- [ ] **Step 4:** En `_process`, disparar el jefe una sola vez al superar el umbral. Reemplazar el cuerpo actual:
```gdscript
	tiempo += delta
	hud.actualizar_tiempo(tiempo)
	if is_instance_valid(jefe):
		hud.actualizar_jefe(jefe.vida / jefe.vida_max)
```
por:
```gdscript
	tiempo += delta
	hud.actualizar_tiempo(tiempo)
	if not _jefe_disparado and tiempo >= SEGUNDOS_HASTA_JEFE:
		_jefe_disparado = true
		_invocar_jefe_nivel()
	if is_instance_valid(jefe):
		hud.actualizar_jefe(jefe.vida / jefe.vida_max)
```

- [ ] **Step 5:** Añadir el selector de jefe del nivel (provisional: cicla los 3 jefes; config por nivel = N5). Colócalo junto a `_invocar_jefe`:
```gdscript
func _invocar_jefe_nivel() -> void:
	var tipo: String = EnemigoScript.JEFES[nivel_actual % EnemigoScript.JEFES.size()]
	_invocar_jefe(tipo)
	hud.anunciar("¡EL JEFE HA APARECIDO!", Color(1.0, 0.3, 0.25))
```

---

### Task 3: Completar el nivel al morir el jefe

**Files:** Modify `scripts/main.gd` (`_al_morir_enemigo`, nuevo `_completar_nivel`)

- [ ] **Step 1:** En `_al_morir_enemigo`, en la rama de muerte de jefe, sustituir la parte donde, al no quedar otro jefe, solo se oculta el HUD:
```gdscript
			else:
				hud.ocultar_jefe()
				sonido_mgr.tocar_musica("res://audio/musica.wav")
```
por:
```gdscript
			else:
				hud.ocultar_jefe()
				_completar_nivel()
```

- [ ] **Step 2:** Añadir `_completar_nivel()` (reutiliza la capa de game over como pantalla de completado). Colócalo junto a `_victoria`:
```gdscript
func _completar_nivel() -> void:
	if not partida_activa:
		return
	partida_activa = false
	sonido_mgr.detener_musica()
	# Banca el oro de la run al meta (igual que _victoria) con bonus de compleción.
	oro_partida = int(oro_partida * 1.5)
	_estado.oro_total += oro_partida
	_estado.pase_xp += oro_partida
	_estado.evento("oro_ganado", oro_partida)
	_estado.evento("victorias")
	# Desbloquea el siguiente nivel.
	_estado.desbloquear_nivel(nivel_actual + 1)
	_estado.guardar()
	oro_partida = 0
	get_tree().paused = true
	_go_titulo.text = "NIVEL %d COMPLETADO" % (nivel_actual + 1)
	EstiloUI.titulo_epico(_go_titulo, 38, Color(1.0, 0.85, 0.3))
	Efectos.sonido(self, "levelup", 2.0)
	_refrescar_game_over()
	_go_seguir.visible = false
	_capa_game_over.visible = true
```

- [ ] **Step 3:** Syntax check de main.gd hasta limpio:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/main.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 4: Smoke test del loop de nivel

**Files:** Create `tools/test_nivel.gd`, `tools/test_nivel.tscn`

- [ ] **Step 1:** `tools/test_nivel.gd`:
```gdscript
extends Node
## Smoke test Capa N2: aparece jefe, matarlo completa el nivel y desbloquea el siguiente.

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.nivel_max_desbloqueado = 0
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)

	# Forzar la aparición del jefe sin esperar 60 s reales.
	main.tiempo = main.SEGUNDOS_HASTA_JEFE + 0.1
	await _esperar(0.4)
	var jefe_vivo := is_instance_valid(main.jefe) and main.jefe.es_jefe
	_check("aparece el jefe del nivel", jefe_vivo)

	# Matar al jefe (daño masivo) y comprobar compleción.
	if jefe_vivo:
		main.jefe.recibir_dano(999999.0)
	await _esperar(0.5)
	_check("nivel completado pausa la partida", not main.partida_activa and get_tree().paused)
	_check("desbloquea el siguiente nivel", estado.nivel_max_desbloqueado >= 1)

	get_tree().paused = false
	print("FIN TEST NIVEL")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_nivel.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_nivel.gd" id="1_nvl"]

[node name="TestNivel" type="Node"]
script = ExtResource("1_nvl")
```

- [ ] **Step 3:** Correr (3/3 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_nivel.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected:
```
PASS aparece el jefe del nivel
PASS nivel completado pausa la partida
PASS desbloquea el siguiente nivel
FIN TEST NIVEL
```

---

### Task 5: No-regresión + commit

- [ ] **Step 1:** No-regresión (cada uno tras matar godot previo):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_spawn_continuo.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_combate_auto.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected: ambos all-PASS.

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/main.gd scripts/game_state.gd tools/test_nivel.gd tools/test_nivel.tscn
git commit -m "feat(niveles): loop de nivel con jefe; matar jefe completa y desbloquea (capa N2)"
```
(Incluye `tools/test_nivel.gd.uid` si Godot lo generó.)

---

## Self-review

- **Cobertura del spec (Revisión 1b, Capa N2):** tras periodo aparece el jefe (Task 2), matar al jefe
  completa el nivel (Task 3), desbloquea el siguiente con persistencia (Tasks 1,3), pantalla de
  completado (Task 3). Estrellas (N4) y selección de 60 niveles + config por nivel (N5) NO se tocan.
- **Sin placeholders:** cada paso muestra el bloque exacto y comandos con salida esperada.
- **Consistencia de tipos/nombres:** `nivel_actual: int`, `_jefe_disparado: bool`,
  `SEGUNDOS_HASTA_JEFE: float`, `Estado.desbloquear_nivel(int)`, `Estado.nivel_max_desbloqueado: int`.
  `_invocar_jefe_nivel()` usa `EnemigoScript.JEFES` (existe). `_completar_nivel()` reutiliza
  `_go_titulo`/`_refrescar_game_over`/`_capa_game_over`/`_go_seguir` (existen).
- **Riesgo:** el jefe del nivel es provisional (cicla 3 jefes); N5 lo hará data-driven por nivel.
  El umbral fijo de 60 s se parametrizará por nivel en N5. La pantalla de completado reusa la de game
  over; N4 le añadirá las estrellas.
- **Manual:** `_iniciar_partida` ahora acepta `indice_nivel`; el menú de selección (N5) lo pasará. Por
  ahora el flujo existente que llama `_iniciar_partida(clave, mapa)` sigue válido (default 0).
