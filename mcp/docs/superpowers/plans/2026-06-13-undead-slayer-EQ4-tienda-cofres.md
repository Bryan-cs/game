# EQ4 — Tienda de cofres + apertura + stub comprar gemas — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** UI de tienda de cofres: abrir Cofre Común (oro) y Premium (gemas), mostrar la pieza obtenida, y paquetes de "comprar gemas" (stub de pago real). Conecta la lógica de EQ3 a botones.

**Architecture:** Nuevo `scripts/menu_cofres.gd` (CanvasLayer) que muestra oro+gemas, dos botones de cofre (precio + odds resumidas), el resultado de la última apertura (rareza + pieza, coloreada por rareza), y botones de paquetes de gemas que llaman a `Estado.comprar_gemas` (stub). Todo apoyado en `Estado.abrir_cofre` / `Estado.COFRES` (EQ3). Accesible desde `menu_principal` (botón "COFRES"). Sin animación elaborada (un texto de resultado); el pulido visual es trabajo de arte futuro.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. `class_name` nuevos vía `preload`.

---

### Task 1: UI `menu_cofres.gd`

**Files:** Create `scripts/menu_cofres.gd`

- [ ] **Step 1:** Crear el archivo:
```gdscript
extends CanvasLayer
## Tienda de cofres (gacha): abrir cofres y comprar gemas (stub de pago real). EQ4.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

## Paquetes de gemas (stub: acreditan sin billing real).
const PAQUETES_GEMAS := [
	{"gemas": 50, "etiqueta": "50 gemas · $0.99"},
	{"gemas": 120, "etiqueta": "120 gemas · $1.99"},
	{"gemas": 300, "etiqueta": "300 gemas · $4.99"},
]

var _estado: Node
var _monedas: Label
var _resultado: Label


func _ready() -> void:
	layer = 27
	visible = false
	_estado = get_node(^"/root/Estado")
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.06, 0.94)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.add_theme_constant_override("separation", 10)
	add_child(caja)

	var titulo := Label.new()
	titulo.text = "COFRES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 30)
	caja.add_child(titulo)

	_monedas = Label.new()
	_monedas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monedas.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(_monedas)

	# Botones de cofre
	for tipo in _estado.COFRES:
		var cofre: Dictionary = _estado.COFRES[tipo]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(480, 52)
		btn.text = "%s — %d %s" % [cofre.nombre, cofre.precio, cofre.moneda]
		var t := String(tipo)
		btn.pressed.connect(func() -> void: _abrir(t))
		caja.add_child(btn)

	_resultado = Label.new()
	_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resultado.custom_minimum_size = Vector2(480, 60)
	_resultado.add_theme_font_size_override("font_size", 16)
	caja.add_child(_resultado)

	var sub := Label.new()
	sub.text = "Comprar gemas"
	sub.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(sub)
	for paq in PAQUETES_GEMAS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(480, 40)
		b.text = paq.etiqueta
		var n: int = paq.gemas
		b.pressed.connect(func() -> void:
			_estado.comprar_gemas(n)
			_refrescar()
			_resultado.text = "+%d gemas (compra simulada)" % n
			_resultado.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0)))
		caja.add_child(b)

	var cerrar := Button.new()
	cerrar.text = "CERRAR"
	cerrar.custom_minimum_size = Vector2(200, 44)
	cerrar.pressed.connect(func() -> void: visible = false)
	caja.add_child(cerrar)


func abrir() -> void:
	visible = true
	_resultado.text = ""
	_refrescar()


func _refrescar() -> void:
	_monedas.text = "Oro: %d     Gemas: %d" % [_estado.oro_total, _estado.gemas]


func _abrir(tipo: String) -> void:
	var pieza: Dictionary = _estado.abrir_cofre(tipo)
	_refrescar()
	if pieza.is_empty():
		_resultado.text = "Moneda insuficiente"
		_resultado.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return
	var rareza: String = pieza.get("rareza", "Común")
	var color: Color = EquipamientoScript.RAREZAS.get(rareza, {}).get("color", Color.WHITE)
	var afijos := ""
	for stat in pieza.get("afijos", {}):
		afijos += " +%s %s" % [str(pieza.afijos[stat]), stat]
	_resultado.text = "¡%s! %s%s" % [rareza, pieza.get("slot", "?"), afijos]
	_resultado.add_theme_color_override("font_color", color)
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_cofres.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: Botón "COFRES" en el menú principal

**Files:** Modify `scripts/menu_principal.gd`

- [ ] **Step 1:** Preload (junto a los otros const):
```gdscript
const MenuCofresScript := preload("res://scripts/menu_cofres.gd")
```

- [ ] **Step 2:** Var miembro (junto a `_inventario`):
```gdscript
var _cofres: CanvasLayer
```

- [ ] **Step 3:** Botón (tras el de "INVENTARIO"):
```gdscript
	_boton(caja, "COFRES", func() -> void: _cofres.abrir())
```

- [ ] **Step 4:** Instanciar (junto a `_inventario`):
```gdscript
	_cofres = CanvasLayer.new()
	_cofres.set_script(MenuCofresScript)
	add_child(_cofres)
```

- [ ] **Step 5:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_principal.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: Smoke test de la tienda de cofres

**Files:** Create `tools/test_tienda_cofres.gd`, `tools/test_tienda_cofres.tscn`

- [ ] **Step 1:** `tools/test_tienda_cofres.gd` (instancia el menú y ejercita sus handlers sin clics):
```gdscript
extends Node
## Smoke test EQ4: la tienda de cofres instancia y abre cofres vía su lógica.

const MenuCofresScript := preload("res://scripts/menu_cofres.gd")

func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout

func _check(nombre: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + nombre)

func _ready() -> void:
	var estado = get_node("/root/Estado")
	estado.inventario = []
	estado.oro_total = 1000
	estado.gemas = 0

	var menu := CanvasLayer.new()
	menu.set_script(MenuCofresScript)
	add_child(menu)
	await _esperar(0.2)
	_check("la tienda instancia sin crash", is_instance_valid(menu))

	menu.abrir()
	await _esperar(0.1)
	_check("abrir muestra la tienda", menu.visible)

	# Abrir un cofre común vía el handler interno
	menu._abrir("comun")
	await _esperar(0.1)
	_check("abrir cofre añade pieza", estado.inventario.size() == 1)
	_check("gastó oro", estado.oro_total < 1000)

	print("FIN TEST TIENDA COFRES")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_tienda_cofres.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_tienda_cofres.gd" id="1_tc"]

[node name="TestTiendaCofres" type="Node"]
script = ExtResource("1_tc")
```

- [ ] **Step 3:** Correr (4/4 PASS):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_tienda_cofres.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Expected: 4 PASS + `FIN TEST TIENDA COFRES`.

---

### Task 4: No-regresión + commit

- [ ] **Step 1:** `test_gacha` 7/7 y `test_inventario` 4/4:
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_gacha.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_inventario.tscn 2>&1 | grep -E "PASS|FAIL|FIN"
```

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/menu_cofres.gd scripts/menu_principal.gd tools/test_tienda_cofres.gd tools/test_tienda_cofres.tscn
git commit -m "feat(equipo): tienda de cofres + apertura + stub comprar gemas (EQ4)"
```

---

## Self-review

- **Cobertura del spec (Revisión 1c, EQ4):** tienda con Cofre Común (oro) y Premium (gemas) (Task 1),
  muestra la pieza obtenida coloreada por rareza (Task 1), paquetes de gemas vía stub `comprar_gemas`
  (Task 1), accesible desde el menú principal (Task 2). Cierra el sistema equipamiento+gacha.
- **Sin placeholders:** código y comandos exactos.
- **Consistencia:** usa `Estado.abrir_cofre`/`COFRES`/`comprar_gemas`/`oro_total`/`gemas` (EQ3) y
  `Equipamiento.RAREZAS` (EQ1). El test ejercita `menu._abrir("comun")` directamente (gotcha: los
  clics no llegan a menús; se prueba el handler, no el botón).
- **Honestidad:** los precios "$0.99/$1.99/$4.99" son etiquetas; `comprar_gemas` es un STUB que acredita
  gemas sin cobrar — el billing real (Google Play) es trabajo de plataforma futuro.
- **Riesgo:** UI sobria (texto de resultado, sin animación de apertura); el pulido visual es arte futuro.
