# Capa N5 — 60 niveles nombrados + selector — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Definir **60 niveles nombrados** (tema visual, jefe, escala de dificultad/monstruos y umbrales de estrellas por nivel) y un **menú de selección** con desbloqueo secuencial y estrellas. Reemplaza los valores provisionales globales de N2/N4 (jefe que cicla, umbral fijo de 60 s, umbrales de estrellas globales) por config por nivel.

**Architecture:** Nuevo `scripts/niveles.gd` (`class_name Niveles`) = fuente de datos: 60 nombres + helpers que derivan tema/jefe/escala/segundos-hasta-jefe/umbrales por índice. `menu_seleccion.gd` cambia la fila de 4 mapas por un **grid scrolleable de 60 niveles** (bloqueados más allá de `Estado.nivel_max_desbloqueado`, con estrellas), y emite el índice del nivel. `main.gd._iniciar_partida` recibe el índice, fija `mapa_actual` desde `Niveles`, y usa la config del nivel para jefe (`_invocar_jefe_nivel`), escala de dificultad (`_generar_enemigo`/`_spawn_continuo`), tiempo de aparición del jefe y umbrales de estrellas (`_estrellas_por_tiempo`).

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. Binario `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`. `--check-only --script` no resuelve `class_name` recién creados → usar `preload(...)` para referenciar `Niveles`.

---

### Task 1: `scripts/niveles.gd` — tabla de 60 niveles

**Files:** Create `scripts/niveles.gd`

- [ ] **Step 1:** Crear el archivo:
```gdscript
class_name Niveles
extends RefCounted
## Tabla data-driven de los 60 niveles (rework Undead Slayer, capa N5).
## Cada nivel: nombre propio, tema visual (clave de TEMAS_MAPA en main.gd), jefe,
## escala de dificultad/monstruos, segundos hasta el jefe y umbrales de estrellas.

const TOTAL := 60

## 60 nombres únicos, 15 por bioma (bosque, desierto, congelado, abismo).
const NOMBRES := [
	"Bosque Maldito", "Claro de los Ahorcados", "Sendero de Niebla", "Raíces Podridas",
	"Arboleda Susurrante", "Pantano Verde", "Espesura Sombría", "Tocón del Verdugo",
	"Valle de Musgo", "Cripta del Bosque", "Ciénaga Pálida", "Robledal Quebrado",
	"Hondonada Umbría", "Manantial Negro", "Corazón del Bosque",
	"Dunas de Ceniza", "Oasis Reseco", "Cañón Carmesí", "Mar de Arena",
	"Ruinas Enterradas", "Meseta Ardiente", "Tumba de Arena", "Vientos Abrasadores",
	"Espejismo Roto", "Garganta Polvorienta", "Templo Sepultado", "Llanura Calcinada",
	"Cementerio de Caravanas", "Cráter Solar", "Trono de Arena",
	"Reino Congelado", "Glaciar Quebrado", "Tundra Silente", "Cueva de Hielo",
	"Cumbre Helada", "Lago Petrificado", "Bosque Escarchado", "Paso Nevado",
	"Catedral de Hielo", "Abismo Blanco", "Fortaleza Helada", "Ventisca Eterna",
	"Grietas Azules", "Páramo Gélido", "Corona de Escarcha",
	"Abismo Eterno", "Falla del Vacío", "Pozo Sin Fondo", "Catacumbas Violetas",
	"Altar Profano", "Río de Almas", "Puente Quebrado", "Sima Carmesí",
	"Santuario Roto", "Vacío Aullante", "Trono del Vacío", "Umbral Final",
	"Caos Primigenio", "Corazón Tenebroso", "Fin de la Noche",
]

const TEMAS := ["bosque", "desierto", "congelado", "abismo"]
const JEFES := ["gigante_putrefacto", "senor_sombras", "rey_vacio"]


static func nombre(indice: int) -> String:
	if indice >= 0 and indice < NOMBRES.size():
		return NOMBRES[indice]
	return "Nivel %d" % (indice + 1)


static func tema(indice: int) -> String:
	return TEMAS[(indice / 15) % TEMAS.size()]  # 15 niveles por bioma


static func jefe(indice: int) -> String:
	# Progresión de jefe: 0-19 gigante, 20-39 señor de las sombras, 40-59 rey del vacío.
	return JEFES[mini(indice / 20, JEFES.size() - 1)]


static func escala(indice: int) -> float:
	# Dificultad/monstruos crecen de forma monótona con el nivel.
	return 1.0 + indice * 0.10


static func segundos_jefe(indice: int) -> float:
	# Niveles altos exigen sobrevivir un poco más antes del jefe.
	return 50.0 + indice * 2.0


static func umbral_3(indice: int) -> float:
	# 3★ si se completa por debajo de este tiempo (se relaja en niveles altos).
	return segundos_jefe(indice) + 20.0 + indice * 1.5


static func umbral_2(indice: int) -> float:
	return segundos_jefe(indice) + 45.0 + indice * 3.0


static func estrellas_por_tiempo(indice: int, t: float) -> int:
	if t <= umbral_3(indice):
		return 3
	if t <= umbral_2(indice):
		return 2
	return 1
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/niveles.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: Test unitario de la tabla `NIVELES`

**Files:** Create `tools/test_niveles.gd`, `tools/test_niveles.tscn`

- [ ] **Step 1:** `tools/test_niveles.gd`:
```gdscript
extends Node
## Smoke test Capa N5: la tabla de 60 niveles es coherente.

const NivelesScript := preload("res://scripts/niveles.gd")

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	_check("hay 60 niveles", NivelesScript.TOTAL == 60 and NivelesScript.NOMBRES.size() == 60)
	# Nombres únicos
	var vistos := {}
	var unicos := true
	for n in NivelesScript.NOMBRES:
		if vistos.has(n):
			unicos = false
		vistos[n] = true
	_check("nombres únicos", unicos)
	# Dificultad monótona creciente
	var monotona := true
	for i in range(1, 60):
		if NivelesScript.escala(i) <= NivelesScript.escala(i - 1):
			monotona = false
	_check("dificultad crece por nivel", monotona)
	# Temas y jefes válidos en todo el rango
	var validos := true
	for i in 60:
		if not (NivelesScript.tema(i) in NivelesScript.TEMAS):
			validos = false
		if not (NivelesScript.jefe(i) in NivelesScript.JEFES):
			validos = false
	_check("tema y jefe válidos en los 60", validos)
	# Estrellas: completar rápido = 3, lento = 1
	_check("estrellas por tiempo", NivelesScript.estrellas_por_tiempo(0, 1.0) == 3 and NivelesScript.estrellas_por_tiempo(0, 99999.0) == 1)
	print("FIN TEST NIVELES")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_niveles.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_niveles.gd" id="1_nvls"]

[node name="TestNiveles" type="Node"]
script = ExtResource("1_nvls")
```

- [ ] **Step 3:** Correr (5/5 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_niveles.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```

---

### Task 3: `main.gd` usa la config por nivel

**Files:** Modify `scripts/main.gd`

- [ ] **Step 1:** Añadir el preload junto a los otros const (p. ej. tras `const EnemigoScript`):
```gdscript
const NivelesScript := preload("res://scripts/niveles.gd")
```

- [ ] **Step 2:** En `_iniciar_partida(clave, mapa := "bosque", indice_nivel := 0)`, derivar el tema del nivel (ignorando el `mapa` recibido cuando hay índice válido). Reemplazar:
```gdscript
	clase_jugador = clave
	mapa_actual = mapa if TEMAS_MAPA.has(mapa) else "bosque"
	nivel_actual = indice_nivel
	_jefe_disparado = false
```
por:
```gdscript
	clase_jugador = clave
	nivel_actual = indice_nivel
	var tema_nivel := NivelesScript.tema(indice_nivel)
	mapa_actual = tema_nivel if TEMAS_MAPA.has(tema_nivel) else "bosque"
	_jefe_disparado = false
```

- [ ] **Step 3:** Jefe por nivel. En `_invocar_jefe_nivel`, reemplazar el selector provisional:
```gdscript
	var tipo: String = EnemigoScript.JEFES[nivel_actual % EnemigoScript.JEFES.size()]
	_invocar_jefe(tipo)
	hud.anunciar("¡EL JEFE HA APARECIDO!", Color(1.0, 0.3, 0.25))
```
por:
```gdscript
	var tipo: String = NivelesScript.jefe(nivel_actual)
	_invocar_jefe(tipo)
	hud.anunciar("¡EL JEFE HA APARECIDO!", Color(1.0, 0.3, 0.25))
```

- [ ] **Step 4:** Tiempo de aparición del jefe por nivel. En `_process`, reemplazar:
```gdscript
	if not _jefe_disparado and tiempo >= SEGUNDOS_HASTA_JEFE:
```
por:
```gdscript
	if not _jefe_disparado and tiempo >= NivelesScript.segundos_jefe(nivel_actual):
```
(La constante `SEGUNDOS_HASTA_JEFE` puede quedarse como fallback o borrarse si no se usa en otro sitio — comprobar con grep y, si queda sin uso, eliminarla.)

- [ ] **Step 5:** Estrellas por nivel. Reemplazar el cuerpo de `_estrellas_por_tiempo`:
```gdscript
func _estrellas_por_tiempo(t: float) -> int:
	if t <= SEGUNDOS_HASTA_JEFE + 20.0:
		return 3
	if t <= SEGUNDOS_HASTA_JEFE + 45.0:
		return 2
	return 1
```
por (delega en la tabla por nivel):
```gdscript
func _estrellas_por_tiempo(t: float) -> int:
	return NivelesScript.estrellas_por_tiempo(nivel_actual, t)
```

- [ ] **Step 6:** Escala de dificultad por nivel en el spawn. En `_generar_enemigo`, donde calcula la escala por tiempo:
```gdscript
	var minutos := tiempo / 60.0
	var enemigo := CharacterBody3D.new()
	enemigo.set_script(EnemigoScript)
	enemigo.configurar(tipo, 1.0 + minutos * 0.25)
```
cambiar la línea de `configurar` para multiplicar por la escala del nivel:
```gdscript
	enemigo.configurar(tipo, (1.0 + minutos * 0.25) * NivelesScript.escala(nivel_actual))
```

- [ ] **Step 7:** Syntax check de main.gd hasta limpio:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/main.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 4: Selector de 60 niveles en `menu_seleccion.gd`

**Files:** Modify `scripts/menu_seleccion.gd`

- [ ] **Step 1:** Cambiar la señal y el estado. Reemplazar la cabecera:
```gdscript
signal clase_elegida(clave: String, mapa: String)

var _mapa_sel := "bosque"
var _botones_mapa := {}
var _estado: Node
var _oro: Label
```
por:
```gdscript
signal clase_elegida(clave: String, mapa: String, indice_nivel: int)

const NivelesScript := preload("res://scripts/niveles.gd")

var _nivel_sel := 0
var _botones_nivel := {}
var _estado: Node
var _oro: Label
```

- [ ] **Step 2:** Reemplazar el bloque que construye la fila de mapas (desde `var sub_mapa := Label.new()` hasta `_refrescar_mapas()` inclusive) por un grid scrolleable de niveles:
```gdscript
	var sub_nivel := Label.new()
	sub_nivel.text = "Elige el nivel"
	sub_nivel.add_theme_font_size_override("font_size", 15)
	sub_nivel.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	caja.add_child(sub_nivel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 220)
	caja.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	_nivel_sel = mini(_estado.nivel_max_desbloqueado, NivelesScript.TOTAL - 1)
	for i in NivelesScript.TOTAL:
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(96, 50)
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_al_pulsar_nivel.bind(i))
		grid.add_child(boton)
		_botones_nivel[i] = boton
	_refrescar_niveles()
```

- [ ] **Step 3:** Reemplazar `_refrescar_mapas`, `_al_pulsar_mapa` por las versiones de nivel:
```gdscript
func _refrescar_niveles() -> void:
	_oro.text = "Oro total: %d" % _estado.oro_total
	for i in _botones_nivel:
		var boton: Button = _botones_nivel[i]
		var desbloqueado: bool = i <= _estado.nivel_max_desbloqueado
		if desbloqueado:
			var estrellas: int = _estado.estrellas_de(i)
			var glifos := "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
			boton.disabled = false
			boton.text = "%d\n%s%s" % [i + 1, ("✦ " if i == _nivel_sel else ""), glifos]
		else:
			boton.disabled = true
			boton.text = "🔒\n%d" % (i + 1)


func _al_pulsar_nivel(i: int) -> void:
	if i <= _estado.nivel_max_desbloqueado:
		_nivel_sel = i
		_refrescar_niveles()
```

- [ ] **Step 4:** Mostrar el nombre del nivel seleccionado. En `_refrescar_niveles`, tras actualizar el oro, añadir (requiere un Label `_nombre_nivel`; créalo en `_ready` tras `sub_nivel` y guárdalo como var miembro `var _nombre_nivel: Label`):
   - Declarar miembro: `var _nombre_nivel: Label`
   - En `_ready`, tras añadir `sub_nivel`:
```gdscript
	_nombre_nivel = Label.new()
	_nombre_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre_nivel.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	caja.add_child(_nombre_nivel)
```
   - En `_refrescar_niveles`, al final:
```gdscript
	if _nombre_nivel:
		_nombre_nivel.text = "%d. %s" % [_nivel_sel + 1, NivelesScript.nombre(_nivel_sel)]
```

- [ ] **Step 5:** Emitir el índice del nivel al elegir clase. Reemplazar:
```gdscript
func _al_elegir(clave: String) -> void:
	visible = false
	clase_elegida.emit(clave, _mapa_sel)
```
por:
```gdscript
func _al_elegir(clave: String) -> void:
	visible = false
	clase_elegida.emit(clave, NivelesScript.tema(_nivel_sel), _nivel_sel)
```

- [ ] **Step 6:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_seleccion.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 5: Conexión de la señal en `main.gd`

**Files:** Modify `scripts/main.gd`

- [ ] **Step 1:** La señal ahora lleva 3 args y conecta directo a `_iniciar_partida(clave, mapa, indice_nivel)`. Verificar la línea de conexión (`menu_seleccion.clase_elegida.connect(_iniciar_partida)`): como `_iniciar_partida(clave, mapa, indice_nivel := 0)` acepta 3 args, la conexión sigue siendo válida con los 3 emitidos. No requiere cambio salvo que la firma no acepte el 3º (ya lo acepta tras N2). Confirmar con grep que la conexión existe y `_iniciar_partida` acepta 3 parámetros.

---

### Task 6: Test de integración nivel-config

**Files:** Create `tools/test_nivel_config.gd`, `tools/test_nivel_config.tscn`

- [ ] **Step 1:** `tools/test_nivel_config.gd`:
```gdscript
extends Node
## Smoke test Capa N5: iniciar un nivel aplica su tema y su jefe.

const NivelesScript := preload("res://scripts/niveles.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.nivel_max_desbloqueado = 40  # desbloquear hasta un nivel del bioma abismo
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	# Nivel 40 (índice) → bioma abismo, jefe rey_vacio
	main._iniciar_partida("guerrero", NivelesScript.tema(40), 40)
	await _esperar(0.3)
	_check("tema del nivel aplicado", main.mapa_actual == NivelesScript.tema(40))
	# Forzar jefe del nivel
	main.tiempo = NivelesScript.segundos_jefe(40) + 0.1
	await _esperar(0.4)
	var jefe_ok := is_instance_valid(main.jefe) and main.jefe.tipo == NivelesScript.jefe(40)
	_check("jefe del nivel correcto", jefe_ok)
	get_tree().paused = false
	print("FIN TEST NIVEL CONFIG")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_nivel_config.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_nivel_config.gd" id="1_nvcfg"]

[node name="TestNivelConfig" type="Node"]
script = ExtResource("1_nvcfg")
```

- [ ] **Step 3:** Correr (2/2 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_nivel_config.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```

---

### Task 7: No-regresión + commit

- [ ] **Step 1:** Correr todos los tests previos (mata godot entre cada uno):
  `test_niveles` (5/5), `test_nivel_config` (2/2), `test_nivel` (3/3), `test_estrellas` (2/2),
  `test_spawn_continuo` (4/4), `test_combate_auto` (3/3), `test_levelup` (4/4), `test_stats` (9/9).
```bash
for t in test_niveles test_nivel_config test_nivel test_estrellas test_spawn_continuo test_combate_auto test_levelup test_stats; do echo "=== $t ==="; taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe 2>/dev/null; sleep 2; timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/$t.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"; done
```
Expected: todos all-PASS.

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/niveles.gd scripts/main.gd scripts/menu_seleccion.gd tools/test_niveles.gd tools/test_niveles.tscn tools/test_nivel_config.gd tools/test_nivel_config.tscn
git commit -m "feat(niveles): 60 niveles nombrados + selector con desbloqueo y estrellas (capa N5)"
```
(Incluye `.uid` generados.)

---

## Self-review

- **Cobertura del spec (Revisión 1b, Capa N5):** tabla `NIVELES` de 60 con nombre/tema/jefe/escala/
  umbrales (Task 1), escalado de dificultad+monstruos por nivel (Task 3 Step 6), jefe por nivel
  (Task 3 Step 3), umbrales de estrellas por nivel (Task 3 Step 5), menú de selección de 60 con
  desbloqueo secuencial + estrellas + nombre (Task 4), cableado del índice (Tasks 4-5).
- **Reemplaza provisionales:** N2 (jefe que cicla, umbral 60 s) y N4 (umbrales de estrellas globales)
  pasan a config por nivel vía `Niveles`.
- **Sin placeholders:** 60 nombres listados; helpers con fórmulas concretas; código y comandos exactos.
- **Consistencia:** `Niveles.tema/jefe/escala/segundos_jefe/estrellas_por_tiempo(int[,float])`;
  `clase_elegida(String, String, int)`; `_iniciar_partida(String, String, int)`. `Estado.estrellas_de`
  y `nivel_max_desbloqueado` (de N2/N4) usados por el selector.
- **Riesgo UI:** el grid de 60 botones es funcional pero sobrio; pulido visual (iconos, scroll suave)
  queda para una capa de arte. Los 60 "mapas" comparten 4 temas visuales (15 c/u) — distintos por
  nombre/escala/jefe; arte bespoke por nivel es trabajo futuro, como se acordó.
