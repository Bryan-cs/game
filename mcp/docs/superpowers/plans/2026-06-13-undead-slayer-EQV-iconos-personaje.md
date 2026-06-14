# EQV — Iconos 3D por ítem + preview del personaje con equipo — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development o executing-plans. Pasos con checkbox.

**Goal:** Que cada ítem tenga apariencia (icono 3D renderizado a textura, distinto por tipo, tintado por rareza) y que el inventario muestre un **preview 3D del personaje** con el arma equipada, pudiendo ciclar las 6 clases.

**Architecture:** Las armas rolean un `tipo_visual` (espada/arco/baston/daga/martillo/escudo). `equipo.gd` expone `malla_item(tipo) -> Node3D` (reusa sus mallas; primitivas simples para coraza/botas/anillo). `scripts/icono_render.gd` (Node helper) renderiza una malla en un `SubViewport` con `own_world_3d`, cámara y luz, y devuelve una `ImageTexture` cacheada por `tipo_visual` (≈10 tipos → 10 renders). `menu_inventario.gd` usa esos iconos en celdas y slots, y añade un `SubViewportContainer` con el modelo 3D de la clase + el arma equipada, con botones para ciclar clase.

**Repo del juego:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`. Rama: `undead-slayer-capa0`.

**Runner:** UNA instancia a la vez (`taskkill //F //IM Godot_v4.6.3-stable_win64_console.exe`), `timeout 45`. `class_name` nuevos vía `preload`. La verificación final es visual (relanzar el juego); el test automatiza lo frágil (que el icono no salga transparente).

---

### Task 1: `tipo_visual` en las piezas (`equipamiento.gd`)

**Files:** Modify `scripts/equipamiento.gd`

- [ ] **Step 1:** Añadir los subtipos de arma y el icono por slot (junto a las const):
```gdscript
const TIPOS_ARMA := ["espada", "arco", "baston", "daga", "martillo", "escudo"]
## Icono por slot no-arma (tipo_visual fijo).
const ICONO_SLOT := {"casco": "casco", "armadura": "coraza", "botas": "botas", "anillo": "anillo"}
```

- [ ] **Step 2:** En `generar(slot, rareza, afinidad, rng)`, calcular `tipo_visual` y meterlo en el dict devuelto. Cambiar el `return`:
```gdscript
	return {"slot": slot, "rareza": rareza, "afinidad": afinidad, "afijos": afijos}
```
por:
```gdscript
	var tipo_visual: String = ICONO_SLOT.get(slot, "")
	if slot == "arma":
		tipo_visual = TIPOS_ARMA[rng.randi_range(0, TIPOS_ARMA.size() - 1)]
	return {"slot": slot, "rareza": rareza, "afinidad": afinidad, "afijos": afijos, "tipo_visual": tipo_visual}
```

- [ ] **Step 3:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/equipamiento.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 2: Factory público de mallas en `equipo.gd`

**Files:** Modify `scripts/equipo.gd`

- [ ] **Step 1:** Añadir un método estático público (al inicio, tras `equipar`):
```gdscript
## Devuelve una malla 3D representativa de un tipo de ítem (para iconos y preview).
static func malla_item(tipo: String) -> Node3D:
	match tipo:
		"espada": return _espada()
		"arco": return _arco()
		"baston": return _baston(Color(0.5, 0.65, 1.0))
		"daga": return _daga()
		"martillo": return _martillo()
		"escudo": return _escudo()
		"casco": return _casco(Color(0.7, 0.7, 0.78))
		"coraza":
			var n := Node3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.5, 0.6, 0.28)
			m.material = _material(Color(0.55, 0.55, 0.62), true)
			n.add_child(_pieza(m, Vector3(0, -0.5, 0)))
			return n
		"botas":
			var n := Node3D.new()
			for lado in [-1.0, 1.0]:
				var m := BoxMesh.new()
				m.size = Vector3(0.18, 0.16, 0.34)
				m.material = _material(Color(0.4, 0.28, 0.18), true)
				n.add_child(_pieza(m, Vector3(0.13 * lado, -0.55, 0.05)))
			return n
		"anillo":
			var n := Node3D.new()
			var m := TorusMesh.new()
			m.inner_radius = 0.16
			m.outer_radius = 0.24
			m.material = _material(Color(0.95, 0.8, 0.3), true)
			n.add_child(_pieza(m, Vector3(0, -0.5, 0), Vector3(PI / 2.0, 0, 0)))
			return n
		_:
			var n := Node3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.3, 0.3, 0.3)
			m.material = _material(Color(0.6, 0.6, 0.6))
			n.add_child(_pieza(m, Vector3(0, -0.5, 0)))
			return n
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/equipo.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 3: Render de iconos a textura (`scripts/icono_render.gd`)

**Files:** Create `scripts/icono_render.gd`

- [ ] **Step 1:** Crear el helper (Node que se añade al árbol; cachea por tipo_visual):
```gdscript
class_name IconoRender
extends Node
## Renderiza una malla de ítem (de Equipo.malla_item) a una ImageTexture cacheada.

const EquipoScript := preload("res://scripts/equipo.gd")

static var _cache: Dictionary = {}


## Devuelve la textura del icono para 'tipo'. Asíncrono la 1ª vez (renderiza); cacheado luego.
## 'host' = un Node ya en el árbol (para añadir el SubViewport temporal).
func generar(tipo: String, host: Node) -> Texture2D:
	if _cache.has(tipo):
		return _cache[tipo]
	var malla := EquipoScript.malla_item(tipo)
	if malla == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, 35, 0)
	luz.light_energy = 1.4
	vp.add_child(luz)
	var amb := DirectionalLight3D.new()
	amb.rotation_degrees = Vector3(40, -120, 0)
	amb.light_energy = 0.5
	vp.add_child(amb)
	var pivote := Node3D.new()
	vp.add_child(pivote)
	pivote.add_child(malla)
	var cam := Camera3D.new()
	cam.position = Vector3(0, -0.5, 2.0)
	cam.fov = 40.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, -0.5, 0), Vector3.UP)
	# Esperar dos frames para que el render quede listo, luego leer la imagen.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	_cache[tipo] = tex
	vp.queue_free()
	return tex
```

- [ ] **Step 2:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/icono_render.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 4: Iconos en el inventario + preview del personaje

**Files:** Modify `scripts/menu_inventario.gd`

- [ ] **Step 1:** Preloads y vars nuevas (junto a las existentes):
```gdscript
const IconoRenderScript := preload("res://scripts/icono_render.gd")

var _iconos: IconoRender
var _texs: Dictionary = {}          # tipo_visual -> Texture2D
var _vp_personaje: SubViewport
var _pivote_pj: Node3D
var _clase_preview := "guerrero"
const CLASES_PREVIEW := ["guerrero", "arquero", "mago", "nigromante", "asesino", "paladin"]
```

- [ ] **Step 2:** En `_ready`, crear el helper de iconos y el preview del personaje. Añadir al final de `_ready` (antes no hay; se añade tras construir el resto de UI). Crear el helper:
```gdscript
	_iconos = IconoRenderScript.new()
	add_child(_iconos)
```
Y dentro del `cuerpo` (HBoxContainer), ANTES de la columna de mochila, añadir una columna de preview del personaje:
```gdscript
	var col_pj := VBoxContainer.new()
	col_pj.add_theme_constant_override("separation", 8)
	cuerpo.add_child(col_pj)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(280, 420)
	col_pj.add_child(cont)
	_vp_personaje = SubViewport.new()
	_vp_personaje.own_world_3d = true
	_vp_personaje.transparent_bg = true
	_vp_personaje.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_vp_personaje)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, 40, 0)
	luz.light_energy = 1.3
	_vp_personaje.add_child(luz)
	_pivote_pj = Node3D.new()
	_vp_personaje.add_child(_pivote_pj)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.0)
	cam.fov = 38.0
	_vp_personaje.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	var fila_clase := HBoxContainer.new()
	fila_clase.alignment = BoxContainer.ALIGNMENT_CENTER
	col_pj.add_child(fila_clase)
	var b_prev := Button.new()
	b_prev.text = "◀"
	b_prev.pressed.connect(func() -> void: _ciclar_clase(-1))
	fila_clase.add_child(b_prev)
	var lbl_clase := Label.new()
	lbl_clase.name = "LblClase"
	lbl_clase.custom_minimum_size = Vector2(160, 0)
	lbl_clase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila_clase.add_child(lbl_clase)
	var b_next := Button.new()
	b_next.text = "▶"
	b_next.pressed.connect(func() -> void: _ciclar_clase(1))
	fila_clase.add_child(b_next)
```

- [ ] **Step 3:** `abrir()` ahora pre-genera iconos (async) y arma el preview. Reemplazar `abrir`:
```gdscript
func abrir() -> void:
	visible = true
	_sel = -1
	if _estado.has_method("get") and "ultima_clase" in _estado:
		_clase_preview = _estado.ultima_clase
	await _pregenerar_iconos()
	_construir_personaje()
	_refrescar()
```
Y añadir:
```gdscript
func _pregenerar_iconos() -> void:
	var tipos := EquipamientoScript.TIPOS_ARMA + EquipamientoScript.ICONO_SLOT.values()
	for t in tipos:
		if not _texs.has(t):
			_texs[t] = await _iconos.generar(t, self)


func _tex_pieza(pieza: Dictionary) -> Texture2D:
	var t: String = pieza.get("tipo_visual", "")
	return _texs.get(t, null)


func _ciclar_clase(dir: int) -> void:
	var i: int = CLASES_PREVIEW.find(_clase_preview)
	i = (i + dir + CLASES_PREVIEW.size()) % CLASES_PREVIEW.size()
	_clase_preview = CLASES_PREVIEW[i]
	_construir_personaje()


func _construir_personaje() -> void:
	for h in _pivote_pj.get_children():
		h.queue_free()
	var lbl := find_child("LblClase", true, false)
	if lbl:
		lbl.text = _clase_preview.capitalize()
	var info: Dictionary = JugadorScriptInfo()
	if info.has("ruta") and ResourceLoader.exists(info.ruta):
		var modelo := (load(info.ruta) as PackedScene).instantiate()
		modelo.scale = Vector3.ONE * 1.1
		modelo.position.y = -0.05
		_pivote_pj.add_child(modelo)
	# Arma equipada visible junto al personaje
	if _estado.equipado.has("arma"):
		var tipo: String = _estado.equipado["arma"].get("tipo_visual", "espada")
		var malla := EquipoScript_malla(tipo)
		if malla:
			malla.position = Vector3(0.45, 1.0, 0.2)
			malla.scale = Vector3.ONE * 0.9
			_pivote_pj.add_child(malla)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(_pivote_pj):
		_pivote_pj.rotate_y(_delta * 0.6)
```
Helpers de acceso (añadir; evitan depender de `class_name` no resueltos):
```gdscript
func JugadorScriptInfo() -> Dictionary:
	var modelos = load("res://scripts/jugador.gd").MODELOS
	return modelos.get(_clase_preview, {})


func EquipoScript_malla(tipo: String) -> Node3D:
	return load("res://scripts/equipo.gd").malla_item(tipo)
```

- [ ] **Step 4:** Usar el icono en las celdas. En `_refrescar_mochila`, para cada celda, asignar el icono como `icon` del Button (además del texto reducido). Tras crear `celda` y antes de `_grid.add_child(celda)`:
```gdscript
		var tex := _tex_pieza(pieza)
		if tex:
			celda.icon = tex
			celda.expand_icon = true
			celda.add_theme_constant_override("icon_max_width", 84)
			celda.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
```
Y reducir el texto de la celda a solo estrellas + afinidad (el icono manda):
```gdscript
		celda.text = "\n\n%s %s" % ["★".repeat(_tier(rareza)), marca]
```
(Reemplaza la línea `celda.text = ...` previa.)

- [ ] **Step 5:** Usar el icono también en los slots equipados. En `_refrescar_equipo`, cuando el slot tiene pieza, tras fijar el stylebox:
```gdscript
			var tex_eq := _tex_pieza(pieza)
			if tex_eq:
				celda.icon = tex_eq
				celda.expand_icon = true
				celda.add_theme_constant_override("icon_max_width", 56)
```

- [ ] **Step 6:** Syntax check:
```bash
timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/menu_inventario.gd 2>&1 | grep -iE "error" || echo OK
```

---

### Task 5: Guardar la última clase jugada (para el preview)

**Files:** Modify `scripts/game_state.gd`, `scripts/main.gd`

- [ ] **Step 1:** En `game_state.gd`: `var ultima_clase := "guerrero"`, persistir en `guardar()` (`"ultima_clase": ultima_clase,`) y `cargar()` (`ultima_clase = datos.get("ultima_clase", "guerrero")`).

- [ ] **Step 2:** En `main.gd._iniciar_partida`, al inicio (tras `clase_jugador = clave`):
```gdscript
	_estado.ultima_clase = clave
```

- [ ] **Step 3:** Syntax check de ambos:
```bash
for f in game_state main; do timeout 30 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" --check-only --script res://scripts/$f.gd 2>&1 | grep -iE "error" || echo "$f OK"; done
```

---

### Task 6: Smoke test del render de iconos

**Files:** Create `tools/test_iconos.gd`, `tools/test_iconos.tscn`

- [ ] **Step 1:** `tools/test_iconos.gd` (verifica que el icono NO sale transparente — la parte frágil):
```gdscript
extends Node
const IconoRenderScript := preload("res://scripts/icono_render.gd")
const EquipamientoScript := preload("res://scripts/equipamiento.gd")

func _check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)

func _ready() -> void:
	var ir := IconoRenderScript.new()
	add_child(ir)
	var tex: Texture2D = await ir.generar("espada", self)
	_check("genera textura de espada", tex != null)
	var no_vacia := false
	if tex:
		var img := tex.get_image()
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				if img.get_pixel(x, y).a > 0.05:
					no_vacia = true
					break
			if no_vacia:
				break
	_check("el icono no está vacío (renderizó algo)", no_vacia)
	# tipo_visual presente al generar pieza de arma
	var rng := RandomNumberGenerator.new()
	var pieza := EquipamientoScript.generar("arma", "Rara", "ninguna", rng)
	_check("arma tiene tipo_visual", pieza.get("tipo_visual", "") in EquipamientoScript.TIPOS_ARMA)
	print("FIN TEST ICONOS")
	get_tree().quit()
```

- [ ] **Step 2:** `tools/test_iconos.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/test_iconos.gd" id="1_ic"]

[node name="TestIconos" type="Node"]
script = ExtResource("1_ic")
```

- [ ] **Step 3:** Correr (3/3 PASS). NOTA: requiere render real — NO usar `--headless` para este test (el render-a-textura necesita el servidor de render):
```bash
timeout 45 "C:/Users/braya/Downloads/Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego" res://tools/test_iconos.tscn 2>&1 | grep -E "PASS|FAIL|FIN|SCRIPT ERROR"
```
Si "el icono no está vacío" falla, aumentar a 3-4 `await RenderingServer.frame_post_draw` en `icono_render.gd`.

---

### Task 7: No-regresión + commit

- [ ] **Step 1:** `test_inventario` 4/4, `test_equipo` 6/6, `test_gacha` 7/7 (mata godot entre cada uno).

- [ ] **Step 2:** Commit:
```bash
cd "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego"
git add scripts/equipamiento.gd scripts/equipo.gd scripts/icono_render.gd scripts/menu_inventario.gd scripts/game_state.gd scripts/main.gd tools/test_iconos.gd tools/test_iconos.tscn
git commit -m "feat(equipo): iconos 3D por item + preview del personaje con arma equipada (EQV)"
```

---

## Self-review

- **Cobertura del pedido:** apariencia por ítem (icono 3D por `tipo_visual`, Task 1-4), armas con 6
  subtipos visuales (Task 1-2), personaje mostrado con el arma equipada y ciclado de clases (Task 4),
  iconos en celdas y slots (Task 4).
- **Sin placeholders:** código y comandos exactos.
- **Riesgo (3D en UI):** el render-a-textura puede salir vacío si el timing de frames es corto; el
  test #6 lo verifica automáticamente (pixeles no transparentes) y el plan indica subir los `await`
  si falla. El preview del personaje usa `UPDATE_ALWAYS` (vivo) y rota en `_process`. El test de
  iconos NO usa `--headless` (necesita render real).
- **Acceso a scripts:** se usa `load(...)` en vez de `class_name` para `jugador.gd`/`equipo.gd` y
  evitar problemas de resolución de clase global en `--check-only`.
- **Honestidad:** el arma equipada se coloca junto al personaje en posición aproximada (no anclada a
  hueso de la mano del rig KayKit, que es frágil por modelo); suficiente para un preview. Anclaje a
  hueso = pulido futuro.
- **Verificación final:** visual — relanzar el juego y abrir INVENTARIO.
