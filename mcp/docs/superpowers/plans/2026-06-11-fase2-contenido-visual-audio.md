# Fase 2: Contenido visual/audio — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir 26 tools MCP (Partículas 5, Audio 6, AnimationTree 8, Theme/UI 7) portadas 1:1 desde godot-mcp-pro (fuente MIT), llevando el total de 74 a 100.

**Architecture:** Port adaptado: los comandos GDScript del fork MIT `blasdecrespo/godot-mcp-ck` se copian casi intactos como módulos del bridge (patrón Fase 1: `commands/*.gd` con `handles()`/`dispatch()`), sobre una base nueva `ported_base.gd` que replica los helpers del original y traduce su contrato de retorno (`{result}/{error}`) al del bridge (dict plano / `{"__error"}`). Lado Node: 4 módulos `server/tools/*.js` con `register*Tools(server, ctx)` como los de Fase 1. Todo son comandos de editor — sin tocar agente runtime ni relay.

**Tech Stack:** GDScript (Godot 4.6.3), Node.js + @modelcontextprotocol/sdk + zod.

**Spec:** `docs/superpowers/specs/2026-06-11-fase2-contenido-visual-audio-design.md`

---

## Estructura de archivos

| Acción | Archivo | Responsabilidad |
|---|---|---|
| Create | `docs/superpowers/reference/godot-mcp-ck/{LICENSE,base_command.gd,particle_commands.gd,audio_commands.gd,animation_tree_commands.gd,theme_commands.gd}` | Fuente MIT de referencia, vendorizada para reproducibilidad |
| Create | `addons/claude_bridge/commands/ported_base.gd` | Base de módulos portados: helpers del original + adaptador de contrato |
| Create | `addons/claude_bridge/commands/particles.gd` | 5 comandos de partículas |
| Create | `addons/claude_bridge/commands/audio.gd` | 6 comandos de audio |
| Create | `addons/claude_bridge/commands/animation_tree.gd` | 8 comandos de AnimationTree |
| Create | `addons/claude_bridge/commands/theme.gd` | 7 comandos de Theme/UI |
| Create | `server/tools/particles.js`, `server/tools/audio.js`, `server/tools/animation_tree.js`, `server/tools/theme.js` | Definición de las 26 tools MCP |
| Modify | `addons/claude_bridge/plugin.gd` | Registrar los 4 módulos nuevos |
| Modify | `server/index.js` | Importar y registrar los 4 módulos JS |
| Modify | `server/test-e2e.mjs` | `EXPECTED_MIN_TOOLS` 74→100 + tools nuevas requeridas |
| Modify | `README.md` | Conteo de tools + atribución MIT |

**Comandos de validación GDScript** (repo tiene `project.godot`; ejecutar desde la raíz del repo):

```powershell
& "C:\Users\braya\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --check-only --script <ruta .gd> --path .
```

Esperado siempre: exit 0, sin `SCRIPT ERROR`.

---

### Task 1: Vendorizar fuente de referencia MIT

**Files:**
- Create: `docs/superpowers/reference/godot-mcp-ck/LICENSE`
- Create: `docs/superpowers/reference/godot-mcp-ck/{base_command.gd,particle_commands.gd,audio_commands.gd,animation_tree_commands.gd,theme_commands.gd}`

- [ ] **Step 1: Descargar los 6 archivos desde GitHub**

```powershell
$dir = "docs/superpowers/reference/godot-mcp-ck"
New-Item -ItemType Directory -Force $dir
$repo = "repos/blasdecrespo/godot-mcp-ck/contents"
foreach ($f in @("LICENSE")) {
  gh api "$repo/$f" --jq '.content' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>process.stdout.write(Buffer.from(s,'base64')))" | Out-File -Encoding utf8 "$dir/$f"
}
foreach ($f in @("base_command.gd","particle_commands.gd","audio_commands.gd","animation_tree_commands.gd","theme_commands.gd")) {
  gh api "$repo/addons/godot_mcp/commands/$f" --jq '.content' | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>process.stdout.write(Buffer.from(s,'base64')))" | Out-File -Encoding utf8 "$dir/$f"
}
```

(Alternativa Bash: `gh api ... --jq '.content' | base64 -d > archivo`.)

- [ ] **Step 2: Verificar tamaños** — `wc -l` esperado aprox: base 124, particle 582, audio 429, animation_tree 563, theme 331. LICENSE empieza con "MIT License" y "Copyright (c) 2026 Youichi Uda".

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/reference/godot-mcp-ck
git commit -m "docs: vendoriza fuente MIT de godot-mcp-ck como referencia de Fase 2"
```

---

### Task 2: Base de módulos portados (`ported_base.gd`)

**Files:**
- Create: `addons/claude_bridge/commands/ported_base.gd`

Contrato del bridge (ver `addons/claude_bridge/commands/editor_debug.gd` y `bridge_server.gd:249-252`): cada módulo expone `handles(command) -> bool` y `dispatch(command, params)` que devuelve un Dictionary plano de resultado, o `{"__error": "mensaje"}`. El original de godot-mcp-pro devuelve `{"result": {...}}` o `{"error": {code, message, data}}`. `ported_base.gd` replica los helpers del original y traduce el contrato en `dispatch()`, de modo que los archivos portados casi no se tocan.

- [ ] **Step 1: Crear el archivo con este contenido exacto**

```gdscript
@tool
extends RefCounted
## Base para módulos portados de godot-mcp-pro.
## Fuente original: base_command.gd de github.com/blasdecrespo/godot-mcp-ck
## (licencia MIT, Copyright (c) 2026 Youichi Uda). Adaptaciones:
## - extends RefCounted (no Node) y sin dependencia de editor_plugin.
## - handles()/dispatch() para el patrón de módulos del bridge.
## - dispatch() traduce {result}/{error} del original a dict plano / {"__error"}.
## - get_editor() usa el singleton EditorInterface (Godot 4.2+).
## - Omitidos get_undo_redo() y get_game_user_dir() (no usados en Fase 2).


## Override en subclases: {"nombre_comando": Callable}
func get_commands() -> Dictionary:
	return {}


func handles(command: String) -> bool:
	return get_commands().has(command)


func dispatch(command: String, p: Dictionary):
	var commands := get_commands()
	if not commands.has(command):
		return {"__error": "Comando desconocido: %s" % command}
	var out = commands[command].call(p)
	if out is Dictionary and out.has("error"):
		var e: Dictionary = out["error"]
		var msg := str(e.get("message", "error"))
		var data: Dictionary = e.get("data", {})
		if data.has("suggestion"):
			msg += ". " + str(data["suggestion"])
		return {"__error": msg}
	if out is Dictionary and out.has("result"):
		return out["result"]
	return out


## --- Helpers idénticos en firma al base_command.gd original ---

func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene() -> Dictionary:
	return error(-32000, "No scene is currently open", {"suggestion": "Use open_scene to open a scene first"})


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if params.has(key):
		return int(params[key])
	return default


func get_editor():
	return EditorInterface


func get_edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	if root.has_node(node_path):
		return root.get_node(node_path)
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
```

- [ ] **Step 2: Validar sintaxis** (comando de validación de la cabecera del plan sobre `addons/claude_bridge/commands/ported_base.gd`). Esperado: exit 0.

- [ ] **Step 3: Commit**

```bash
git add addons/claude_bridge/commands/ported_base.gd
git commit -m "feat: base de modulos portados de godot-mcp-pro (contrato result/error -> bridge)"
```

---

## Receta de port (aplica a Tasks 3–6)

Cada módulo GDScript se crea así — **única transformación permitida** (el resto del archivo se copia byte a byte desde la referencia):

1. Abrir `docs/superpowers/reference/godot-mcp-ck/<categoria>_commands.gd`.
2. Sustituir las 2 primeras líneas (`@tool` + `extends "res://addons/godot_mcp/commands/base_command.gd"`) por:

```gdscript
@tool
extends "res://addons/claude_bridge/commands/ported_base.gd"
## Portado de <categoria>_commands.gd de godot-mcp-pro
## (github.com/blasdecrespo/godot-mcp-ck, MIT, Copyright (c) 2026 Youichi Uda).
## Único cambio respecto al original: este encabezado. Helpers en ported_base.gd.
```

3. Copiar el resto del archivo de referencia (desde `func get_commands()` hasta el final) sin cambios.
4. Validar sintaxis con el comando de la cabecera del plan. Si aparece un error por API inexistente en Godot 4.6.3, corregir SOLO esa línea y documentar la desviación en el commit.

Y cada módulo JS sigue el patrón de `server/tools/debug.js`: `import { z } from "zod"` + `export function registerXxxTools(server, { run })` + un `server.tool(nombre, descripción, schema, async (args) => run(comando, args))` por tool.

---

### Task 3: Partículas (5 tools)

**Files:**
- Create: `addons/claude_bridge/commands/particles.gd` (port de `particle_commands.gd`, receta arriba)
- Create: `server/tools/particles.js`
- Modify: `addons/claude_bridge/plugin.gd:8` (preload) y `:25` (append)
- Modify: `server/index.js:15` (import) y `:652` (register)

- [ ] **Step 1: Crear `particles.gd`** siguiendo la receta de port. Comandos esperados en `get_commands()`: `create_particles`, `set_particle_material`, `set_particle_color_gradient`, `apply_particle_preset`, `get_particle_info`.

- [ ] **Step 2: Validar sintaxis.** Esperado: exit 0.

- [ ] **Step 3: Crear `server/tools/particles.js` con este contenido exacto**

```javascript
import { z } from "zod";

const nodePath = z.string().describe("Ruta del nodo GPUParticles2D/3D en la escena editada");
const vec3 = z
  .union([z.object({ x: z.number(), y: z.number(), z: z.number() }), z.string()])
  .describe("Vector3 como {x,y,z} o literal \"Vector3(0,-1,0)\"");

export function registerParticlesTools(server, { run }) {
  server.tool(
    "godot_create_particles",
    "Crea un GPUParticles2D o GPUParticles3D (con ParticleProcessMaterial vacío) bajo un nodo de la escena editada.",
    {
      parent_path: z.string().describe("Ruta del nodo padre ('.' = raíz)"),
      name: z.string().optional().describe("Nombre del nodo (por defecto Particles)"),
      is_3d: z.boolean().optional().describe("GPUParticles3D en vez de 2D (por defecto false)"),
      amount: z.number().optional().describe("Cantidad de partículas (por defecto 16)"),
      lifetime: z.number().optional().describe("Vida en segundos (por defecto 1.0)"),
      one_shot: z.boolean().optional().describe("Emitir una sola vez"),
      explosiveness: z.number().optional().describe("0..1 (por defecto 0)"),
      randomness: z.number().optional().describe("0..1 (por defecto 0)"),
      emitting: z.boolean().optional().describe("Emitiendo al crear (por defecto true)"),
    },
    async (args) => run("create_particles", args)
  );

  server.tool(
    "godot_set_particle_material",
    "Configura el ParticleProcessMaterial de un sistema de partículas: dirección, spread, velocidad, gravedad, escala, color, forma de emisión, velocidad angular/orbital, damping.",
    {
      node_path: nodePath,
      direction: vec3.optional(),
      spread: z.number().optional().describe("Ángulo de dispersión en grados"),
      initial_velocity_min: z.number().optional(),
      initial_velocity_max: z.number().optional(),
      gravity: vec3.optional(),
      scale_min: z.number().optional(),
      scale_max: z.number().optional(),
      color: z.string().optional().describe("Color '#rrggbb' o nombre"),
      emission_shape: z
        .enum(["point", "sphere", "sphere_surface", "box", "ring"])
        .optional()
        .describe("Forma de emisión"),
      emission_sphere_radius: z.number().optional(),
      emission_box_extents: vec3.optional(),
      emission_ring_radius: z.number().optional(),
      emission_ring_inner_radius: z.number().optional(),
      emission_ring_height: z.number().optional(),
      angular_velocity_min: z.number().optional(),
      angular_velocity_max: z.number().optional(),
      orbit_velocity_min: z.number().optional(),
      orbit_velocity_max: z.number().optional(),
      damping_min: z.number().optional(),
      damping_max: z.number().optional(),
      attractor_interaction_enabled: z.boolean().optional(),
    },
    async (args) => run("set_particle_material", args)
  );

  server.tool(
    "godot_set_particle_color_gradient",
    "Define el gradiente de color sobre la vida de las partículas (color_ramp del material).",
    {
      node_path: nodePath,
      stops: z
        .array(z.object({ offset: z.number().describe("0..1"), color: z.string().describe("'#rrggbb'") }))
        .describe("Paradas del gradiente en orden"),
    },
    async (args) => run("set_particle_color_gradient", args)
  );

  server.tool(
    "godot_apply_particle_preset",
    "Aplica un preset completo de material de partículas: explosion, fire, smoke, sparks, rain, snow, magic o dust.",
    {
      node_path: nodePath,
      preset: z.enum(["explosion", "fire", "smoke", "sparks", "rain", "snow", "magic", "dust"]),
    },
    async (args) => run("apply_particle_preset", args)
  );

  server.tool(
    "godot_get_particle_info",
    "Devuelve el estado de un sistema de partículas: propiedades del nodo, material y gradiente.",
    { node_path: nodePath },
    async (args) => run("get_particle_info", args)
  );
}
```

- [ ] **Step 4: Registrar en `plugin.gd`** — añadir tras la línea 8 (`const EditorDebug = ...`):

```gdscript
const ParticlesCmds = preload("res://addons/claude_bridge/commands/particles.gd")
```

y tras `server.modules.append(EditorDebug.new(editor_logger, agent_link))`:

```gdscript
server.modules.append(ParticlesCmds.new())
```

- [ ] **Step 5: Registrar en `server/index.js`** — junto a los imports existentes:

```javascript
import { registerParticlesTools } from "./tools/particles.js";
```

y junto a `registerDebugTools(server, ctx);`:

```javascript
registerParticlesTools(server, ctx);
```

- [ ] **Step 6: Verificar** — validar sintaxis de `plugin.gd` (exit 0) y `node --check server/tools/particles.js && node --check server/index.js` (sin salida = OK). Luego e2e rápido:

```powershell
cd server; $env:TEST_PORT='9181'; node test-e2e.mjs
```

Esperado: `TEST OK` y `tools registradas: 79`.

- [ ] **Step 7: Commit**

```bash
git add addons/claude_bridge/commands/particles.gd server/tools/particles.js addons/claude_bridge/plugin.gd server/index.js
git commit -m "feat: 5 tools de particulas portadas de godot-mcp-pro (MIT)"
```

---

### Task 4: Audio (6 tools)

**Files:**
- Create: `addons/claude_bridge/commands/audio.gd` (port de `audio_commands.gd`, receta arriba)
- Create: `server/tools/audio.js`
- Modify: `addons/claude_bridge/plugin.gd` (preload `AudioCmds` + append, igual que Task 3)
- Modify: `server/index.js` (import + register, igual que Task 3)

- [ ] **Step 1: Crear `audio.gd`** siguiendo la receta. Comandos: `get_audio_bus_layout`, `add_audio_bus`, `set_audio_bus`, `add_audio_bus_effect`, `add_audio_player`, `get_audio_info`.

- [ ] **Step 2: Validar sintaxis.** Esperado: exit 0.

- [ ] **Step 3: Crear `server/tools/audio.js` con este contenido exacto**

```javascript
import { z } from "zod";

export function registerAudioTools(server, { run }) {
  server.tool(
    "godot_get_audio_bus_layout",
    "Devuelve los buses de audio del proyecto: nombre, volumen, solo/mute/bypass, send y efectos de cada bus.",
    {},
    async () => run("get_audio_bus_layout", {})
  );

  server.tool(
    "godot_add_audio_bus",
    "Crea un bus de audio nuevo en el AudioServer y lo persiste en default_bus_layout.tres.",
    {
      name: z.string().describe("Nombre del bus (único)"),
      at_position: z.number().optional().describe("Índice donde insertarlo (por defecto al final)"),
      volume_db: z.number().optional().describe("Volumen en dB"),
      send: z.string().optional().describe("Bus de destino (por defecto Master)"),
      solo: z.boolean().optional(),
      mute: z.boolean().optional(),
    },
    async (args) => run("add_audio_bus", args)
  );

  server.tool(
    "godot_set_audio_bus",
    "Modifica un bus de audio existente: volumen, solo, mute, bypass de efectos, renombrado y send.",
    {
      name: z.string().describe("Nombre del bus a modificar"),
      volume_db: z.number().optional(),
      solo: z.boolean().optional(),
      mute: z.boolean().optional(),
      bypass_effects: z.boolean().optional(),
      rename: z.string().optional().describe("Nuevo nombre"),
      send: z.string().optional().describe("Nuevo bus de destino"),
    },
    async (args) => run("set_audio_bus", args)
  );

  server.tool(
    "godot_add_audio_bus_effect",
    "Añade un efecto a un bus de audio. Tipos: reverb, chorus, delay, compressor, limiter, phaser, distortion, amplify, eq. Parámetros específicos del efecto en 'params' (p. ej. reverb: room_size, damping, wet, dry, spread).",
    {
      bus: z.string().describe("Nombre del bus"),
      effect_type: z.enum([
        "reverb", "chorus", "delay", "compressor", "limiter",
        "phaser", "distortion", "amplify", "eq",
      ]),
      at_position: z.number().optional().describe("Posición en la cadena de efectos"),
      params: z.record(z.any()).optional().describe("Parámetros del efecto según su tipo"),
    },
    async (args) => run("add_audio_bus_effect", args)
  );

  server.tool(
    "godot_add_audio_player",
    "Crea un AudioStreamPlayer, AudioStreamPlayer2D o AudioStreamPlayer3D bajo un nodo, opcionalmente con stream cargado y bus asignado.",
    {
      node_path: z.string().describe("Ruta del nodo padre ('.' = raíz)"),
      name: z.string().describe("Nombre del player"),
      type: z
        .enum(["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"])
        .optional()
        .describe("Tipo (por defecto AudioStreamPlayer)"),
      stream: z.string().optional().describe("Ruta res:// del AudioStream"),
      volume_db: z.number().optional(),
      bus: z.string().optional().describe("Bus de salida"),
      autoplay: z.boolean().optional(),
      max_distance: z.number().optional().describe("Solo 2D/3D"),
      attenuation: z.number().optional().describe("Solo 2D"),
      attenuation_model: z.number().optional().describe("Solo 3D (enum AttenuationModel)"),
      unit_size: z.number().optional().describe("Solo 3D"),
    },
    async (args) => run("add_audio_player", args)
  );

  server.tool(
    "godot_get_audio_info",
    "Devuelve información de un nodo de audio: tipo, stream, bus, volumen y propiedades específicas.",
    { node_path: z.string().describe("Ruta del nodo de audio") },
    async (args) => run("get_audio_info", args)
  );
}
```

- [ ] **Step 4: Registrar** — `plugin.gd`: `const AudioCmds = preload("res://addons/claude_bridge/commands/audio.gd")` + `server.modules.append(AudioCmds.new())`. `index.js`: `import { registerAudioTools } from "./tools/audio.js";` + `registerAudioTools(server, ctx);`.

- [ ] **Step 5: Verificar** — validar `audio.gd` y `plugin.gd` (exit 0), `node --check` de los dos JS, e2e con `TEST_PORT=9181`. Esperado: `TEST OK`, `tools registradas: 85`.

- [ ] **Step 6: Commit**

```bash
git add addons/claude_bridge/commands/audio.gd server/tools/audio.js addons/claude_bridge/plugin.gd server/index.js
git commit -m "feat: 6 tools de audio portadas de godot-mcp-pro (MIT)"
```

---

### Task 5: AnimationTree (8 tools)

**Files:**
- Create: `addons/claude_bridge/commands/animation_tree.gd` (port de `animation_tree_commands.gd`, receta arriba)
- Create: `server/tools/animation_tree.js`
- Modify: `addons/claude_bridge/plugin.gd` (preload `AnimationTreeCmds` + append)
- Modify: `server/index.js` (import + register)

- [ ] **Step 1: Crear `animation_tree.gd`** siguiendo la receta. Comandos: `create_animation_tree`, `get_animation_tree_structure`, `add_state_machine_state`, `remove_state_machine_state`, `add_state_machine_transition`, `remove_state_machine_transition`, `set_blend_tree_node`, `set_tree_parameter`.

- [ ] **Step 2: Validar sintaxis.** Esperado: exit 0.

- [ ] **Step 3: Crear `server/tools/animation_tree.js` con este contenido exacto**

```javascript
import { z } from "zod";

const treePath = z.string().describe("Ruta del nodo AnimationTree");
const smPath = z
  .string()
  .optional()
  .describe("Ruta de state machine anidada (vacío = raíz del árbol)");

export function registerAnimationTreeTools(server, { run }) {
  server.tool(
    "godot_create_animation_tree",
    "Crea un AnimationTree (raíz AnimationNodeStateMachine) bajo un nodo, ligado a un AnimationPlayer.",
    {
      node_path: z.string().describe("Ruta del nodo padre ('.' = raíz)"),
      anim_player: z.string().optional().describe("Ruta del AnimationPlayer a usar"),
      name: z.string().optional().describe("Nombre del nodo (por defecto AnimationTree)"),
    },
    async (args) => run("create_animation_tree", args)
  );

  server.tool(
    "godot_get_animation_tree_structure",
    "Devuelve la estructura del AnimationTree: estados, transiciones, nodos de blend tree y parámetros actuales.",
    { node_path: treePath },
    async (args) => run("get_animation_tree_structure", args)
  );

  server.tool(
    "godot_add_state_machine_state",
    "Añade un estado a la state machine del AnimationTree (animación o sub-árbol).",
    {
      node_path: treePath,
      state_name: z.string().describe("Nombre del estado"),
      state_machine_path: smPath,
      state_type: z.string().optional().describe("Tipo de estado (por defecto 'animation'; también 'blend_tree', etc.)"),
      animation: z.string().optional().describe("Animación a reproducir (para state_type animation)"),
      position_x: z.number().optional().describe("Posición X en el grafo del editor"),
      position_y: z.number().optional().describe("Posición Y en el grafo del editor"),
    },
    async (args) => run("add_state_machine_state", args)
  );

  server.tool(
    "godot_remove_state_machine_state",
    "Elimina un estado de la state machine.",
    { node_path: treePath, state_name: z.string(), state_machine_path: smPath },
    async (args) => run("remove_state_machine_state", args)
  );

  server.tool(
    "godot_add_state_machine_transition",
    "Crea una transición entre dos estados de la state machine, con crossfade y modo de avance.",
    {
      node_path: treePath,
      from_state: z.string(),
      to_state: z.string(),
      state_machine_path: smPath,
      switch_mode: z.enum(["immediate", "sync", "at_end"]).optional().describe("Por defecto immediate"),
      advance_mode: z.enum(["disabled", "enabled", "auto"]).optional().describe("Por defecto enabled"),
      advance_expression: z.string().optional().describe("Expresión de condición de avance"),
      xfade_time: z.number().optional().describe("Crossfade en segundos"),
    },
    async (args) => run("add_state_machine_transition", args)
  );

  server.tool(
    "godot_remove_state_machine_transition",
    "Elimina la transición entre dos estados.",
    { node_path: treePath, from_state: z.string(), to_state: z.string(), state_machine_path: smPath },
    async (args) => run("remove_state_machine_transition", args)
  );

  server.tool(
    "godot_set_blend_tree_node",
    "Añade o configura un nodo dentro de un estado de tipo blend tree (Animation, Blend2, OneShot, TimeScale, etc.) y opcionalmente lo conecta a otro nodo.",
    {
      node_path: treePath,
      blend_tree_state: z.string().describe("Nombre del estado blend tree dentro de la state machine"),
      bt_node_name: z.string().describe("Nombre del nodo a crear/configurar en el blend tree"),
      bt_node_type: z.string().describe("Tipo: Animation, Blend2, Blend3, OneShot, TimeScale, Add2, ..."),
      state_machine_path: smPath,
      animation: z.string().optional().describe("Animación (para tipo Animation)"),
      position_x: z.number().optional(),
      position_y: z.number().optional(),
      connect_to: z.string().optional().describe("Nodo destino de la conexión"),
      connect_port: z.number().optional().describe("Puerto de entrada del destino (por defecto 0)"),
    },
    async (args) => run("set_blend_tree_node", args)
  );

  server.tool(
    "godot_set_tree_parameter",
    "Establece un parámetro del AnimationTree (ruta 'parameters/...'): blend amounts, condiciones, travel de la state machine, etc.",
    {
      node_path: treePath,
      parameter: z.string().describe("Ruta del parámetro, p. ej. 'parameters/playback' o 'parameters/Blend2/blend_amount'"),
      value: z.any().describe("Valor a asignar"),
    },
    async (args) => run("set_tree_parameter", args)
  );
}
```

- [ ] **Step 4: Registrar** — `plugin.gd`: `const AnimationTreeCmds = preload("res://addons/claude_bridge/commands/animation_tree.gd")` + `server.modules.append(AnimationTreeCmds.new())`. `index.js`: `import { registerAnimationTreeTools } from "./tools/animation_tree.js";` + `registerAnimationTreeTools(server, ctx);`.

- [ ] **Step 5: Verificar** — validaciones + e2e como en Task 4. Esperado: `TEST OK`, `tools registradas: 93`.

- [ ] **Step 6: Commit**

```bash
git add addons/claude_bridge/commands/animation_tree.gd server/tools/animation_tree.js addons/claude_bridge/plugin.gd server/index.js
git commit -m "feat: 8 tools de AnimationTree portadas de godot-mcp-pro (MIT)"
```

---

### Task 6: Theme/UI (7 tools)

**Files:**
- Create: `addons/claude_bridge/commands/theme.gd` (port de `theme_commands.gd`, receta arriba)
- Create: `server/tools/theme.js`
- Modify: `addons/claude_bridge/plugin.gd` (preload `ThemeCmds` + append)
- Modify: `server/index.js` (import + register)

- [ ] **Step 1: Crear `theme.gd`** siguiendo la receta. Comandos: `create_theme`, `set_theme_color`, `set_theme_constant`, `set_theme_font_size`, `set_theme_stylebox`, `setup_control`, `get_theme_info`.

- [ ] **Step 2: Validar sintaxis.** Esperado: exit 0.

- [ ] **Step 3: Crear `server/tools/theme.js` con este contenido exacto**

```javascript
import { z } from "zod";

const controlPath = z.string().describe("Ruta del nodo Control en la escena editada");

export function registerThemeTools(server, { run }) {
  server.tool(
    "godot_create_theme",
    "Crea un recurso Theme y lo guarda como .tres.",
    {
      path: z.string().describe("Ruta res:// del .tres a crear"),
      default_font_size: z.number().optional().describe("Tamaño de fuente por defecto del theme"),
    },
    async (args) => run("create_theme", args)
  );

  server.tool(
    "godot_set_theme_color",
    "Añade un override de color de theme a un Control (add_theme_color_override).",
    {
      node_path: controlPath,
      name: z.string().describe("Nombre del color (p. ej. font_color)"),
      color: z.string().describe("Color '#rrggbb' o nombre"),
      theme_type: z.string().optional().describe("Tipo de theme (por defecto la clase del Control)"),
    },
    async (args) => run("set_theme_color", args)
  );

  server.tool(
    "godot_set_theme_constant",
    "Añade un override de constante de theme a un Control (separation, margin, etc.).",
    {
      node_path: controlPath,
      name: z.string().describe("Nombre de la constante (p. ej. separation)"),
      value: z.number().optional().describe("Valor entero (por defecto 0)"),
    },
    async (args) => run("set_theme_constant", args)
  );

  server.tool(
    "godot_set_theme_font_size",
    "Añade un override de tamaño de fuente a un Control.",
    {
      node_path: controlPath,
      name: z.string().describe("Nombre del font size (p. ej. font_size)"),
      size: z.number().optional().describe("Tamaño en píxeles (por defecto 16)"),
    },
    async (args) => run("set_theme_font_size", args)
  );

  server.tool(
    "godot_set_theme_stylebox",
    "Crea un StyleBoxFlat y lo aplica como override a un Control: fondo, borde, esquinas redondeadas y padding.",
    {
      node_path: controlPath,
      name: z.string().describe("Nombre del stylebox (p. ej. panel, normal, pressed)"),
      bg_color: z.string().optional().describe("Color de fondo '#rrggbb'"),
      border_color: z.string().optional(),
      border_width: z.number().optional().describe("Ancho de borde en px (los 4 lados)"),
      corner_radius: z.number().optional().describe("Radio de esquinas en px (las 4)"),
      padding: z.number().optional().describe("Content margin en px (los 4 lados)"),
    },
    async (args) => run("set_theme_stylebox", args)
  );

  server.tool(
    "godot_setup_control",
    "Configura el layout de un Control: preset de anclajes, tamaño mínimo, size flags, márgenes, separación y dirección de crecimiento.",
    {
      node_path: controlPath,
      anchor_preset: z
        .string()
        .optional()
        .describe("Preset: full_rect, center, top_left, top_right, bottom_left, bottom_right, center_top, center_bottom, center_left, center_right, top_wide, bottom_wide, left_wide, right_wide, vcenter_wide, hcenter_wide"),
      min_size: z.string().optional().describe("Tamaño mínimo 'Vector2(x, y)'"),
      size_flags_h: z.string().optional().describe("fill, expand, expand_fill, shrink_center, shrink_end"),
      size_flags_v: z.string().optional().describe("fill, expand, expand_fill, shrink_center, shrink_end"),
      margins: z
        .object({ left: z.number().optional(), top: z.number().optional(), right: z.number().optional(), bottom: z.number().optional() })
        .optional()
        .describe("Offsets en px respecto a los anclajes"),
      separation: z.number().optional().describe("Separación (solo BoxContainer)"),
      grow_h: z.string().optional().describe("begin, end, both"),
      grow_v: z.string().optional().describe("begin, end, both"),
    },
    async (args) => run("setup_control", args)
  );

  server.tool(
    "godot_get_theme_info",
    "Devuelve el theme y los overrides de theme de un Control.",
    { node_path: controlPath },
    async (args) => run("get_theme_info", args)
  );
}
```

- [ ] **Step 4: Registrar** — `plugin.gd`: `const ThemeCmds = preload("res://addons/claude_bridge/commands/theme.gd")` + `server.modules.append(ThemeCmds.new())`. `index.js`: `import { registerThemeTools } from "./tools/theme.js";` + `registerThemeTools(server, ctx);`.

- [ ] **Step 5: Verificar** — validaciones + e2e. Esperado: `TEST OK`, `tools registradas: 100`.

- [ ] **Step 6: Commit**

```bash
git add addons/claude_bridge/commands/theme.gd server/tools/theme.js addons/claude_bridge/plugin.gd server/index.js
git commit -m "feat: 7 tools de Theme/UI portadas de godot-mcp-pro (MIT)"
```

---

### Task 7: Actualizar test e2e

**Files:**
- Modify: `server/test-e2e.mjs:31` y `:63`

- [ ] **Step 1: Subir el mínimo de tools** — en la línea 31:

```javascript
const EXPECTED_MIN_TOOLS = 100; // 42 originales + 32 Fase 1 + 26 Fase 2
```

- [ ] **Step 2: Añadir una tool requerida por categoría nueva** — en la línea 63, ampliar la lista:

```javascript
for (const required of [
  "godot_get_errors", "runtime_get_scene_tree", "input_sequence", "runtime_screenshot",
  "godot_create_particles", "godot_add_audio_bus", "godot_create_animation_tree", "godot_set_theme_stylebox",
]) {
```

- [ ] **Step 3: Ejecutar**

```powershell
cd server; $env:TEST_PORT='9181'; node test-e2e.mjs
```

Esperado: `tools registradas: 100`, `TEST OK`, exit 0.

- [ ] **Step 4: Commit**

```bash
git add server/test-e2e.mjs
git commit -m "test: e2e verifica 100 tools incluidas las 26 de Fase 2"
```

---

### Task 8: README y atribución

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Actualizar el conteo de tools** (74 → 100) donde el README lo mencione, y añadir las 4 categorías nuevas a la lista de capacidades si existe tal lista.

- [ ] **Step 2: Añadir sección de atribución** al final del README:

```markdown
## Atribución

Los módulos `commands/particles.gd`, `commands/audio.gd`, `commands/animation_tree.gd`,
`commands/theme.gd` y `commands/ported_base.gd` están portados de
[godot-mcp-ck](https://github.com/blasdecrespo/godot-mcp-ck)
(godot-mcp-pro), licencia MIT, Copyright (c) 2026 Youichi Uda (y1uda).
Copia de referencia y licencia en `docs/superpowers/reference/godot-mcp-ck/`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: conteo 100 tools y atribucion MIT de los modulos portados"
```

---

### Task 9: Sync y smoke test en Nightfall Survivors

El addon del juego es una COPIA: hay que sincronizar y reiniciar el editor. Las tools MCP nuevas no aparecen en la sesión de Claude Code hasta reiniciarla; mientras tanto se usa `tcp-cmd.mjs`, que habla directo con el bridge.

- [ ] **Step 1: Sincronizar addon al proyecto del juego**

```powershell
.\sync-addon.ps1
```

- [ ] **Step 2: Pedir al usuario reiniciar el editor de Godot de Nightfall Survivors** (necesario para recargar el plugin). Esperar confirmación.

- [ ] **Step 3: Smoke por categoría vía tcp-cmd** (desde la raíz del repo, editor abierto con una escena):

```powershell
node tcp-cmd.mjs create_particles '{"parent_path": ".", "name": "SmokeTest", "amount": 32}'
node tcp-cmd.mjs apply_particle_preset '{"node_path": "SmokeTest", "preset": "sparks"}'
node tcp-cmd.mjs get_particle_info '{"node_path": "SmokeTest"}'
node tcp-cmd.mjs add_audio_bus '{"name": "SFXTest", "volume_db": -6}'
node tcp-cmd.mjs add_audio_bus_effect '{"bus": "SFXTest", "effect_type": "reverb", "params": {"room_size": 0.8}}'
node tcp-cmd.mjs get_audio_bus_layout '{}'
node tcp-cmd.mjs get_theme_info '{"node_path": "."}'
```

Esperado: cada comando devuelve `ok: true` con datos (get_theme_info puede devolver error accionable si la raíz no es Control — eso también es un pase: error claro, no timeout).

Para AnimationTree, sobre una escena con AnimationPlayer (p. ej. un personaje KayKit):

```powershell
node tcp-cmd.mjs create_animation_tree '{"node_path": ".", "anim_player": "AnimationPlayer"}'
node tcp-cmd.mjs get_animation_tree_structure '{"node_path": "AnimationTree"}'
```

- [ ] **Step 4: Limpiar artefactos del smoke** — eliminar el nodo `SmokeTest`, el `AnimationTree` de prueba y el bus `SFXTest` (vía `delete_node` y, para el bus, el panel Audio del editor o `set_audio_bus`), y NO guardar la escena de prueba si no se desea persistir.

- [ ] **Step 5: VFX real de validación (criterio jugabilidad):** crear en la escena del enemigo (o donde el usuario indique) un GPUParticles3D con preset `sparks` para la muerte de enemigos, guardar escena, lanzar el juego con `run_scene` y verificar visualmente con `runtime_screenshot` que las partículas se ven al morir un enemigo.

- [ ] **Step 6: Commit final si hubo ajustes** y actualizar la memoria del proyecto (`mcp-fase1-runtime-debug.md`: 74→100 tools, Fase 2 completada, pendiente recalculado).

---

## Self-review (hecho al escribir el plan)

- **Cobertura del spec:** 26 tools ↔ Tasks 3–6; arquitectura módulos ↔ Tasks 2–6; errores accionables ↔ ported_base.dispatch + e2e; testing ↔ Tasks 7 y 9; atribución MIT ↔ Tasks 1 y 8. Sin huecos.
- **Placeholders:** ninguno — el código GDScript vive vendorizado en Task 1 con receta de transformación cerrada (solo encabezado); JS completo inline.
- **Consistencia de tipos:** nombres de comandos en `get_commands()` de la referencia = strings que envían los JS (`run("create_particles", ...)` etc.); verificado contra la fuente descargada.
- **Riesgo conocido:** APIs del original que no existan en 4.6.3 — la receta lo contempla (corregir línea + documentar en commit).
