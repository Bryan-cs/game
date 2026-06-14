# Fase 2: Contenido visual/audio — Diseño

**Fecha:** 2026-06-11
**Proyecto:** godot-claude-mcp — extensión hacia paridad con godot-mcp-pro (169 tools)
**Fase:** 2 de N (AnimationTree + Audio + Partículas + Theme/UI, 26 tools nuevas)
**Estado:** Aprobado por el usuario

## Contexto

El MCP tiene 74 tools (Fase 1 completada 2026-06-11). No hay forma de:

- Crear ni configurar sistemas de partículas (VFX de oleadas, muertes, impactos).
- Gestionar buses de audio, efectos ni players desde el MCP.
- Construir AnimationTree (state machines, blend trees) para animaciones de personajes.
- Crear/editar Themes de UI ni configurar anclajes de Controls.

Objetivo de la fase: cubrir esas cuatro categorías. Beneficiario directo: VFX, audio y UI de Nightfall Survivors (Godot 4.6.3).

Decisiones del usuario:

1. Alcance: las 4 categorías en una sola fase (26 tools).
2. Fidelidad: copia 1:1 de godot-mcp-pro — mismos parámetros y comportamiento.
3. Naming: prefijo `godot_` (convención interna), comportamiento idéntico al original.
4. Enfoque: **port adaptado** (opción A) — traducir la fuente MIT a nuestra arquitectura, no clean-room ni vendorizar.

### Fuente de referencia

Fork público `blasdecrespo/godot-mcp-ck` (GitHub), licencia MIT, copyright Youichi Uda (y1uda), autor original de godot-mcp-pro. Archivos de referencia:

- `addons/godot_mcp/commands/particle_commands.gd` (582 líneas)
- `addons/godot_mcp/commands/audio_commands.gd` (429 líneas)
- `addons/godot_mcp/commands/animation_tree_commands.gd` (563 líneas)
- `addons/godot_mcp/commands/theme_commands.gd` (331 líneas)

Atribución MIT: comentario de origen en la cabecera de cada módulo portado + nota en README.

## Arquitectura

Las 26 tools son comandos de **editor**: van por el bridge TCP 9080, sin relay al agente runtime (9081). Sin cambios en `runtime_agent.gd` ni `agent_link.gd`.

```
Claude <-MCP stdio-> Node server <-TCP 9080-> Bridge (plugin editor) -> commands/*.gd
```

### Módulos nuevos

| Lado | Archivos | Patrón |
|---|---|---|
| Addon | `addons/claude_bridge/commands/particles.gd`, `audio.gd`, `animation_tree.gd`, `theme.gd` | Mismo patrón que `editor_debug.gd`; `bridge_server.gd` los registra y delega |
| Server | `server/tools/particles.js`, `audio.js`, `animation_tree.js`, `theme.js` | Cada uno exporta `register(server, run)`; `index.js` los importa |

Los 74 comandos/tools existentes no se tocan.

## Tools

### Partículas (5 tools)

| Tool | Comando | Descripción |
|---|---|---|
| `godot_create_particles` | `create_particles` | Crea GPUParticles2D/3D bajo un nodo padre. Parámetros: `parent_path`, `name`, `type` (2d/3d), `amount`, `lifetime`, `explosiveness`, `randomness`, `one_shot`, `emitting`. |
| `godot_set_particle_material` | `set_particle_material` | Configura ParticleProcessMaterial: `direction`, `spread`, `initial_velocity_min/max`, `gravity`, `scale_min/max`, `color`, `emission_shape` (point/sphere/box/ring con sus dimensiones), `angular_velocity_min/max`, `orbit_velocity_min/max`, `damping_min/max`, `attractor_interaction_enabled`. |
| `godot_set_particle_color_gradient` | `set_particle_color_gradient` | Gradiente de color sobre vida de partícula. Parámetro: `stops` `[{offset, color}]`. |
| `godot_apply_particle_preset` | `apply_particle_preset` | Preset completo. Presets (portados del original): `explosion`, `fire`, `smoke`, `sparks`, `rain`, `snow`, `magic`, `dust`. |
| `godot_get_particle_info` | `get_particle_info` | Estado del sistema: propiedades del nodo + material + gradiente. |

### Audio (6 tools)

| Tool | Comando | Descripción |
|---|---|---|
| `godot_get_audio_bus_layout` | `get_audio_bus_layout` | Buses actuales: nombre, volumen, solo/mute/bypass, sends, efectos. |
| `godot_add_audio_bus` | `add_audio_bus` | Crea bus. Parámetros: `name`, `volume_db`, `send`, `solo`, `mute`. |
| `godot_set_audio_bus` | `set_audio_bus` | Modifica bus: `volume_db`, `solo`, `mute`, `bypass_effects`, `rename`, `send`. |
| `godot_add_audio_bus_effect` | `add_audio_bus_effect` | Añade efecto a un bus: reverb, chorus, delay, compressor, distortion, EQ, limiter, etc., con parámetros específicos por tipo (`params` dict). |
| `godot_add_audio_player` | `add_audio_player` | Crea AudioStreamPlayer/2D/3D bajo un nodo: `parent_path`, `name`, `type`, `stream` (ruta res://), `bus`, `volume_db`, `autoplay`. |
| `godot_get_audio_info` | `get_audio_info` | Info de nodos de audio de la escena. |

Los cambios de bus layout se persisten en `default_bus_layout.tres` (comportamiento del original).

### AnimationTree (8 tools)

| Tool | Comando | Descripción |
|---|---|---|
| `godot_create_animation_tree` | `create_animation_tree` | Crea AnimationTree ligado a un AnimationPlayer: `parent_path`, `anim_player_path`, `root_type` (state_machine/blend_tree). |
| `godot_get_animation_tree_structure` | `get_animation_tree_structure` | Estructura completa: estados, transiciones, nodos blend, parámetros. |
| `godot_add_state_machine_state` | `add_state_machine_state` | Añade estado (animación) a la state machine: `tree_path`, `state_name`, `animation`, `position`. |
| `godot_remove_state_machine_state` | `remove_state_machine_state` | Elimina estado. |
| `godot_add_state_machine_transition` | `add_state_machine_transition` | Transición entre estados: `from`, `to`, `xfade_time`, `switch_mode`, `advance_mode`, `advance_condition`. |
| `godot_remove_state_machine_transition` | `remove_state_machine_transition` | Elimina transición. |
| `godot_set_blend_tree_node` | `set_blend_tree_node` | Añade/configura nodo en blend tree (Animation, Blend2, OneShot, TimeScale, etc.) y conexiones. |
| `godot_set_tree_parameter` | `set_tree_parameter` | Setea parámetro del árbol (`parameters/...`): blend amounts, condiciones, travel. |

### Theme/UI (7 tools)

| Tool | Comando | Descripción |
|---|---|---|
| `godot_create_theme` | `create_theme` | Crea recurso Theme (.tres) y opcionalmente lo asigna a un Control. |
| `godot_set_theme_color` | `set_theme_color` | Color de theme/override: `theme_path` o `node_path`, `color_name`, `theme_type`, `color`. |
| `godot_set_theme_constant` | `set_theme_constant` | Constante (separation, margin, etc.). |
| `godot_set_theme_font_size` | `set_theme_font_size` | Tamaño de fuente por tipo. |
| `godot_set_theme_stylebox` | `set_theme_stylebox` | StyleBoxFlat: bg_color, bordes (color/ancho), corner_radius, sombra, content margins. |
| `godot_setup_control` | `setup_control` | Configura Control: anchors/preset (full_rect, center, etc.), offsets, size flags. |
| `godot_get_theme_info` | `get_theme_info` | Theme y overrides de un Control o recurso. |

Total fase: **26 tools** (5 partículas + 6 audio + 8 AnimationTree + 7 theme). Total acumulado: **100 tools**.

## Manejo de errores

- Timeout por defecto 15s (existente); ninguna tool de esta fase necesita timeout extendido.
- Errores accionables: nodo no existe, nodo de clase incorrecta (p. ej. `set_particle_material` sobre un nodo que no es GPUParticles), recurso no encontrado, AnimationPlayer sin animación referenciada, bus inexistente. Validaciones portadas del original (`_get_particles_node`, parsing de colores `_parse_color`, etc.).
- Mutaciones de escena marcan la escena como modificada (mismo mecanismo que las tools existentes) para que `godot_save_scene` persista.
- Parser de literales existente (`Vector2(…)`, `#ff0000`) reutilizado para colores y vectores.

## Testing

1. **e2e (`server/test-e2e.mjs`):** verifica registro de las 26 tools nuevas (total 100) y rutas de error sin editor abierto. Puerto alternativo `TEST_PORT=9181` si el editor está abierto.
2. **Semiautomático con editor abierto:** escena de prueba donde se ejecuta cada categoría: crear partículas + aplicar preset + leer info; crear bus + efecto + player + leer layout; crear AnimationTree + estado + transición + leer estructura; crear theme + stylebox + setup_control + leer info. Verificación con los `get_*_info` de cada categoría.
3. **Smoke real en Nightfall Survivors:** `.\sync-addon.ps1` + reiniciar editor; crear un VFX real (p. ej. preset sparks en muerte de enemigo) y verificar visualmente con screenshot.
4. Criterio de aceptación: las 26 tools responden sin timeout mudo con editor abierto y devuelven error accionable con editor cerrado.

## Fuera de alcance (fases futuras)

- Resto del backlog (~59 tools): Batch/Refactor, Análisis, Testing/QA declarativo, Física, Navegación extra, Resource avanzado, TileMap, Shader, Animation tracks, Export extra, Editor extra.
- Migración de los 42 comandos originales de `bridge_server.gd` a módulos.
- UndoRedo en mutaciones de editor.
