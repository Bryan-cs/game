# EQ2 — Inventario + equipar/desequipar + vender por oro + UI — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Guardar las piezas en un inventario persistente, equiparlas/desequiparlas (se aplican a `HojaStats` al iniciar la run), **vender** las no deseadas por oro, y una UI `menu_inventario` accesible desde el menú principal.

**Architecture:** `game_state.gd` (autoload `Estado`) gana `inventario: Array` (mochila) y `equipado: Dictionary` (slot→pieza), con helpers de equipar/desequipar/vender y persistencia JSON. El jugador aplica las piezas equipadas al arrancar la partida (`_aplicar_equipo_meta()` tras `_aplicar_talentos`, usando `HojaStats.aplicar_equipo` de EQ1). UI nueva `scripts/menu_inventario.gd` (CanvasLayer) con grid de mochila + 5 slots equipados + botones equipar/vender + stats; se abre desde `menu_principal`. EQ3 (gacha/monedas) y EQ4 (tienda de cofres) llenan el inventario; aquí se prueba con piezas inyectadas.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. Referenciar `class_name` nuevos vía `preload(...)` en `--check-only`.

---

### Task 1: Modelo de inventario en `game_state.gd`

**Files:** Modify `scripts/game_state.gd`

- [ ] **Step 1:** Preload + vars (junto a `nivel_max_desbloqueado`/`estrellas_nivel`):
```gdscript
const EquipamientoScript := preload("res://scripts/equipamiento.gd")

var inventario: Array = []        # piezas en la mochila (no equipadas)
var equipado: Dictionary = {}     # slot(String) -> pieza(Dictionary)
```

- [ ] **Step 2:** Persistencia. En `guardar()` añadir al dict:
```gdscript
		"inventario": inventario,
		"equipado": equipado,
```
En `cargar()`:
```gdscript
	var inv = datos.get("inventario", [])
	inventario = inv if inv is Array else []
	var eq = datos.get("equipado", {})
	equipado = eq if eq is Dictionary else {}
```

- [ ] **Step 3:** Helpers (añadir al final de `game_state.gd`):
```gdscript
func agregar_pieza(pieza: Dictionary) -> void:
	inventario.append(pieza)
	guardar()


func equipar(indice: int) -> void:
	if indice < 0 or indice >= inventario.size():
		return
	var pieza: Dictionary = inventario[indice]
	var slot: String = pieza.get("slot", "")
	if slot == "":
		return
	inventario.remove_at(indice)
	if equipado.has(slot):
		inventario.append(equipado[slot])  # la que estaba vuelve a la mochila
	equipado[slot] = pieza
	guardar()


func desequipar(slot: String) -> void:
	if equipado.has(slot):
		inventario.append(equipado[slot])
		equipado.erase(slot)
		guardar()


func vender_pieza(indice: int) -> int:
	if indice < 0 or indice >= inventario.size():
		return 0
	var pieza: Dictionary = inventario[indice]
	var valor: int = EquipamientoScript.valor_venta(pieza.get("rareza", "Común"))
	inventario.remove_at(indice)
	oro_total += valor
	guardar()
	return valor


func piezas_equipadas() -> Array:
	return equipado.values()
```

- [ ] **Step 4:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/game_state.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: El jugador aplica el equipo al iniciar la run

**Files:** Modify `scripts/jugador.gd`

- [ ] **Step 1:** En `_ready`, entre `_aplicar_talentos()` y `vida = vida_max`, añadir:
```gdscript
	_aplicar_equipo_meta()
```
quedando:
```gdscript
	_aplicar_talentos()
	_aplicar_equipo_meta()
	vida = vida_max
```

- [ ] **Step 2:** Añadir el método (junto a `_aplicar_talentos`):
```gdscript
func _aplicar_equipo_meta() -> void:
	if _estado and _estado.has_method("piezas_equipadas"):
		stats.aplicar_equipo(_estado.piezas_equipadas(), clase)
```

- [ ] **Step 3:** Syntax check de jugador.gd:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/jugador.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: UI `menu_inventario.gd`

**Files:** Create `scripts/menu_inventario.gd`

- [ ] **Step 1:** Crear el archivo:
```gdscript
extends CanvasLayer
## Inventario: equipar/desequipar piezas y vender las no deseadas por oro (EQ2).

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

var _estado: Node
var _lista: VBoxContainer
var _slots_caja: VBoxContainer
var _oro: Label
var _panel: Control


func _ready() -> void:
	layer = 26
	visible = false
	_estado = get_node(^"/root/Estado")
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.03, 0.06, 0.94)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.add_theme_constant_override("separation", 10)
	add_child(_panel)

	var titulo := Label.new()
	titulo.text = "INVENTARIO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 30)
	_panel.add_child(titulo)

	_oro = Label.new()
	_oro.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_oro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_oro)

	var sub_eq := Label.new()
	sub_eq.text = "Equipado"
	sub_eq.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	_panel.add_child(sub_eq)
	_slots_caja = VBoxContainer.new()
	_panel.add_child(_slots_caja)

	var sub_inv := Label.new()
	sub_inv.text = "Mochila (equipar / vender)"
	sub_inv.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	_panel.add_child(sub_inv)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 260)
	_panel.add_child(scroll)
	_lista = VBoxContainer.new()
	scroll.add_child(_lista)

	var cerrar := Button.new()
	cerrar.text = "CERRAR"
	cerrar.custom_minimum_size = Vector2(200, 44)
	cerrar.pressed.connect(func() -> void: visible = false)
	_panel.add_child(cerrar)


func abrir() -> void:
	visible = true
	_refrescar()


func _texto_pieza(pieza: Dictionary) -> String:
	var afijos := ""
	for stat in pieza.get("afijos", {}):
		afijos += " +%s %s" % [str(pieza.afijos[stat]), stat]
	var afin: String = pieza.get("afinidad", "ninguna")
	var afin_txt := "" if afin == "ninguna" else " [%s]" % afin
	return "%s · %s%s%s" % [pieza.get("slot", "?"), pieza.get("rareza", "?"), afin_txt, afijos]


func _refrescar() -> void:
	_oro.text = "Oro: %d" % _estado.oro_total
	# Slots equipados
	for hijo in _slots_caja.get_children():
		hijo.queue_free()
	for slot in EquipamientoScript.SLOTS:
		var fila := HBoxContainer.new()
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(520, 0)
		if _estado.equipado.has(slot):
			lbl.text = _texto_pieza(_estado.equipado[slot])
			var btn := Button.new()
			btn.text = "Quitar"
			btn.pressed.connect(func() -> void:
				_estado.desequipar(slot)
				_refrescar())
			fila.add_child(lbl)
			fila.add_child(btn)
		else:
			lbl.text = "%s · (vacío)" % slot
			fila.add_child(lbl)
		_slots_caja.add_child(fila)
	# Mochila
	for hijo in _lista.get_children():
		hijo.queue_free()
	for i in _estado.inventario.size():
		var pieza: Dictionary = _estado.inventario[i]
		var fila := HBoxContainer.new()
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(460, 0)
		lbl.text = _texto_pieza(pieza)
		fila.add_child(lbl)
		var idx := i
		var b_eq := Button.new()
		b_eq.text = "Equipar"
		b_eq.pressed.connect(func() -> void:
			_estado.equipar(idx)
			_refrescar())
		fila.add_child(b_eq)
		var b_vend := Button.new()
		b_vend.text = "Vender %d" % EquipamientoScript.valor_venta(pieza.get("rareza", "Común"))
		b_vend.pressed.connect(func() -> void:
			_estado.vender_pieza(idx)
			_refrescar())
		fila.add_child(b_vend)
		_lista.add_child(fila)
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_inventario.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 4: Botón "INVENTARIO" en el menú principal

**Files:** Modify `scripts/menu_principal.gd`

- [ ] **Step 1:** Preload (junto a los otros const):
```gdscript
const MenuInventarioScript := preload("res://scripts/menu_inventario.gd")
```

- [ ] **Step 2:** Var miembro (junto a `_tienda`):
```gdscript
var _inventario: CanvasLayer
```

- [ ] **Step 3:** Botón (tras la línea del botón "JUGAR"):
```gdscript
	_boton(caja, "INVENTARIO", func() -> void: _inventario.abrir())
```

- [ ] **Step 4:** Instanciar (junto a la creación de `_tienda`):
```gdscript
	_inventario = CanvasLayer.new()
	_inventario.set_script(MenuInventarioScript)
	add_child(_inventario)
```

- [ ] **Step 5:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_principal.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 5: Smoke test de inventario (lógica)

**Files:** Create `tools/test_inventario.gd`, `tools/test_inventario.tscn`

- [ ] **Step 1:** `tools/test_inventario.gd`:
```gdscript
extends Node
## Smoke test EQ2: equipar/desequipar/vender y aplicación al iniciar partida.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.inventario = []
	estado.equipado = {}
	estado.oro_total = 0

	# Inyectar dos piezas deterministas
	var arma := {"slot": "arma", "rareza": "Épica", "afinidad": "guerrero", "afijos": {"dano_pct": 20.0}}
	var casco := {"slot": "casco", "rareza": "Común", "afinidad": "ninguna", "afijos": {"vida_max": 15.0}}
	estado.agregar_pieza(arma)
	estado.agregar_pieza(casco)
	_check("mochila tiene 2 piezas", estado.inventario.size() == 2)

	# Equipar el arma (índice 0)
	estado.equipar(0)
	_check("equipar mueve a slot", estado.equipado.has("arma") and estado.inventario.size() == 1)

	# Vender la pieza restante (casco, Común=10 oro)
	var ganado: int = estado.vender_pieza(0)
	_check("vender da oro por rareza", ganado == 10 and estado.oro_total == 10 and estado.inventario.is_empty())

	# Iniciar partida: el arma equipada (Épica afinidad guerrero) sube dano_pct del guerrero
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _esperar(0.6)
	main.menu_seleccion.visible = false
	main._iniciar_partida("guerrero", "bosque", 0)
	await _esperar(0.3)
	# dano_pct base del guerrero = 0; +20 * 1.25 (afinidad) = 25
	_check("equipo aplicado al iniciar (afinidad)", absf(main.jugador.stats.dano_pct - 25.0) < 0.01)

	get_tree().paused = false
	print("FIN TEST INVENTARIO")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_inventario.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_inventario.gd" id="1_inv"]

[node name="TestInventario" type="Node"]
script = ExtResource("1_inv")
```

- [ ] **Step 3:** Correr (4/4 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_inventario.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected: 4 PASS + `FIN TEST INVENTARIO`.

---

### Task 6: No-regresión + commit

- [ ] **Step 1:** No-regresión (mata godot entre corridas):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_equipo.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_stats.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```
Expected: ambos all-PASS.

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/game_state.gd scripts/jugador.gd scripts/menu_inventario.gd scripts/menu_principal.gd tools/test_inventario.gd tools/test_inventario.tscn
git commit -m "feat(equipo): inventario + equipar/desequipar + vender por oro + UI (EQ2)"
```

---

## Self-review

- **Cobertura del spec (Revisión 1c, EQ2):** inventario persistente (Task 1), equipar/desequipar
  (Task 1,3), vender por oro según rareza (Task 1,3), equipo aplicado al iniciar la run (Task 2),
  UI accesible desde el menú principal (Tasks 3,4). Monedas/gacha (EQ3) y cofres (EQ4) no se tocan.
- **Sin placeholders:** código y comandos exactos.
- **Consistencia:** `Estado.agregar_pieza/equipar(int)/desequipar(String)/vender_pieza(int)->int/
  piezas_equipadas()->Array`; `jugador._aplicar_equipo_meta()` usa `stats.aplicar_equipo` (EQ1);
  `Equipamiento.valor_venta`/`SLOTS` (EQ1). UI lee/escribe `Estado`.
- **Verificación UI:** la UI se prueba indirectamente (el test no abre el menú, prueba la lógica de
  `Estado`); el menú se valida por `--check-only` (parse) y, al jugar, por inspección visual. No hay
  test automatizado de clics (gotcha conocido: clicks no llegan a menús pausados).
- **Decisión:** vender solo aplica a piezas de la MOCHILA (no equipadas); para vender una equipada,
  primero "Quitar". Simplifica y evita vender por accidente lo puesto.
