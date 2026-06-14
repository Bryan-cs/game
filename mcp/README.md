# Godot ↔ Claude Code MCP (Claude Bridge)

Conecta **Claude Code** con el **editor de Godot 4** mediante un servidor MCP, con un **panel visual** dentro de Godot para controlar y ver todo lo que pasa en tiempo real.

```
Claude Code  ←(MCP/stdio)→  servidor Node.js  ←(TCP local)→  Plugin en Godot (panel visual)
```

## ¿Qué puede hacer Claude una vez conectado?

**Escenas y proyecto**

| Herramienta | Descripción |
|---|---|
| `godot_status` | Verifica la conexión, versión de Godot y nombre del proyecto |
| `godot_create_scene` | Crea una escena nueva (.tscn) y la abre en el editor |
| `godot_open_scene` / `godot_save_scene` | Abre y guarda escenas |
| `godot_instance_scene` | Instancia escenas guardadas dentro de otra (composición de niveles) |
| `godot_get_scene_tree` | Lee el árbol de nodos de la escena abierta |
| `godot_add_input_action` | Crea acciones de entrada (teclas y botones de mando) |
| `godot_set_project_setting` | Cambia ajustes del proyecto (escena principal, física, ventana…) |
| `godot_run_scene` / `godot_stop_scene` | Ejecuta o detiene el juego |

**Nodos y recursos**

| Herramienta | Descripción |
|---|---|
| `godot_create_node` / `godot_delete_node` | Crea y elimina nodos (2D, 3D y UI) |
| `godot_set_property` / `godot_get_node_info` | Modifica e inspecciona propiedades |
| `godot_assign_resource` | Asigna texturas, mallas, audio… a propiedades de nodos |
| `godot_list_files` / `godot_read_file` / `godot_write_file` | Explora, lee y escribe archivos |
| `godot_attach_script` | Adjunta un script a un nodo |

**3D**

| Herramienta | Descripción |
|---|---|
| `godot_setup_environment_3d` | Cielo + sol con sombras + suelo con colisión en un paso |
| `godot_create_primitive_mesh` | Mallas primitivas (box, sphere, capsule…) con color |
| `godot_create_collision_shape` | Formas de colisión 2D y 3D |
| `godot_create_material` | Materiales PBR (color, metallic, roughness, emisión) |

**Personajes y animaciones**

| Herramienta | Descripción |
|---|---|
| `godot_create_character` | Personaje jugable completo en un paso: cuerpo, colisión, cámara, script de movimiento e input (estilos: platformer, topdown, fps, third_person) |
| `godot_create_animation` | Animaciones por keyframes en AnimationPlayer |
| `godot_create_sprite_animation` | Animaciones de spritesheet en AnimatedSprite2D |
| `godot_list_animations` / `godot_play_animation` | Lista y previsualiza animaciones |

**Lógica de juego y verificación**

| Herramienta | Descripción |
|---|---|
| `godot_connect_signal` / `godot_list_signals` | Conecta señales entre nodos (persistente) |
| `godot_add_to_group` | Grupos de nodos (enemigos, recolectables…) |
| `godot_paint_tiles` | Pinta celdas en TileMap/TileMapLayer |
| `godot_screenshot` | Captura el viewport 2D/3D: **Claude puede ver la escena** |
| `godot_execute_code` | Ejecuta GDScript arbitrario en el editor (para todo lo demás) |

**Debug y editor (Fase 1)**

| Herramienta | Descripción |
|---|---|
| `godot_get_errors` | Errores y warnings recientes del editor (buffer de 500) |
| `godot_get_game_output` | Salida del juego (print + errores), disponible incluso tras un crash |
| `godot_validate_script` | Compila un .gd y devuelve los errores de compilación |
| `godot_search_scripts` | Busca texto o regex en los scripts del proyecto |
| `godot_reload_scripts` | Fuerza re-escaneo del sistema de archivos y scripts |
| `godot_move_node` / `godot_rename_node` | Reparent (conservando transform), reordenar y renombrar nodos |
| `godot_get_selection` / `godot_set_selection` | Lee o cambia la selección del editor |
| `godot_open_script` | Abre un script en el editor en la línea indicada |

**Runtime — el juego en ejecución** (requiere `godot_run_scene`; usan el autoload `ClaudeRuntime`)

| Herramienta | Descripción |
|---|---|
| `runtime_get_scene_tree` | Árbol de nodos del juego EN VIVO |
| `runtime_get_node_info` / `runtime_find_nodes` | Inspecciona nodos y busca por clase/grupo/nombre |
| `runtime_set_property` | Tuning en vivo sin reiniciar (velocidad, vida, daño…) |
| `runtime_call_method` / `runtime_eval` | Llama métodos o ejecuta GDScript dentro del juego |
| `runtime_screenshot` | Captura lo que ve el jugador |
| `runtime_pause` / `runtime_resume` / `runtime_time_scale` | Pausa y cámara lenta/rápida |
| `runtime_wait` | Espera N segundos y devuelve snapshot de nodos vigilados |
| `runtime_monitor_signal` | Registra emisiones de una señal (start/read/stop) |
| `runtime_get_performance` | FPS, memoria, draw calls, nodos huérfanos |
| `runtime_get_groups` | Grupos activos con conteo de miembros (enemigos vivos…) |
| `runtime_quit` | Cierra el juego limpiamente |

**Simulación de input — playtest automático**

| Herramienta | Descripción |
|---|---|
| `input_action_press` / `input_action_release` | Mantiene/suelta acciones del Input Map |
| `input_key` | Tecla simulada (tap, press o release) |
| `input_mouse_move` / `input_mouse_click` | Ratón: mover y click (UI y apuntado) |
| `input_text` | Escribe texto |
| `input_sequence` | Secuencia temporizada de inputs: playtest scripteado completo |

**Partículas (Fase 2)**

| Herramienta | Descripción |
|---|---|
| `godot_create_particles` | Crea GPUParticles2D/3D con material listo para configurar |
| `godot_set_particle_material` | Dirección, spread, velocidad, gravedad, escala, forma de emisión… |
| `godot_set_particle_color_gradient` | Gradiente de color sobre la vida de la partícula |
| `godot_apply_particle_preset` | Presets: explosion, fire, smoke, sparks, rain, snow, magic, dust |
| `godot_get_particle_info` | Estado completo del sistema de partículas |

**Audio (Fase 2)**

| Herramienta | Descripción |
|---|---|
| `godot_get_audio_bus_layout` | Buses con volumen, mute/solo, sends y efectos |
| `godot_add_audio_bus` / `godot_set_audio_bus` | Crea y modifica buses (persiste en default_bus_layout.tres) |
| `godot_add_audio_bus_effect` | Reverb, chorus, delay, compressor, limiter, phaser, distortion, amplify, eq |
| `godot_add_audio_player` | AudioStreamPlayer/2D/3D con stream y bus |
| `godot_get_audio_info` | Información de un nodo de audio |

**AnimationTree (Fase 2)**

| Herramienta | Descripción |
|---|---|
| `godot_create_animation_tree` | AnimationTree con state machine ligado a un AnimationPlayer |
| `godot_get_animation_tree_structure` | Estados, transiciones, blend trees y parámetros |
| `godot_add_state_machine_state` / `godot_remove_state_machine_state` | Estados de la state machine |
| `godot_add_state_machine_transition` / `godot_remove_state_machine_transition` | Transiciones con crossfade y condiciones |
| `godot_set_blend_tree_node` | Nodos de blend tree (Blend2, OneShot, TimeScale…) y conexiones |
| `godot_set_tree_parameter` | Parámetros del árbol: blends, condiciones, travel |

**Theme/UI (Fase 2)**

| Herramienta | Descripción |
|---|---|
| `godot_create_theme` | Crea un recurso Theme (.tres) |
| `godot_set_theme_color` / `godot_set_theme_constant` / `godot_set_theme_font_size` | Overrides de theme en Controls |
| `godot_set_theme_stylebox` | StyleBoxFlat: fondo, bordes, esquinas, padding |
| `godot_setup_control` | Anclajes (presets), size flags, márgenes, grow |
| `godot_get_theme_info` | Theme y overrides de un Control |

En total: **100 herramientas**.

## Requisitos

- Godot **4.2 o superior**
- Node.js **18 o superior**
- Claude Code instalado (`npm install -g @anthropic-ai/claude-code`)

## Instalación (3 pasos)

### 1. Instala el plugin en tu proyecto de Godot

Copia la carpeta `addons/claude_bridge` dentro de la carpeta de tu proyecto:

```
mi-juego/
└── addons/
    └── claude_bridge/
```

En Godot: **Proyecto → Ajustes del proyecto → Plugins → Claude Bridge → Activar**.

Verás aparecer el panel **Claude Bridge** en el lateral derecho del editor, con el punto verde indicando que el servidor está activo en el puerto `9080`.

### 2. Instala las dependencias del servidor MCP

```bash
cd godot-claude-mcp/server
npm install
```

### 3. Registra el MCP en Claude Code

Desde la carpeta de tu proyecto de juego:

```bash
claude mcp add godot -- node /ruta/completa/a/godot-claude-mcp/server/index.js
```

(En el panel de Godot hay un botón **"Copiar comando de instalación"** que te da esta línea lista para editar.)

¡Listo! Abre Claude Code y pídele cosas como:

> "Crea una escena 3D con entorno, suelo y un personaje en tercera persona; ejecútala"
> "Crea un personaje platformer azul, añade un suelo y unas plataformas, y prueba el nivel"
> "Configura las animaciones idle y run de mi spritesheet de 8x4 frames"
> "Haz que la puerta se abra con una animación cuando el jugador entre al Area3D"
> "Toma una captura del viewport y dime si el nivel se ve bien"

## El panel visual

El dock **Claude Bridge** dentro de Godot te muestra:

- 🟢/🔴 **Estado** del servidor y puerto en uso
- **Clientes conectados** (Claude Code aparece aquí al conectarse)
- **Registro de actividad** en vivo: cada comando que Claude ejecuta, con hora y resultado (✓/✗)
- **Iniciar/Detener** el servidor y cambiar el puerto
- Botón para **copiar el comando de instalación** de Claude Code

## Configuración opcional

Si cambias el puerto en el panel de Godot, indícaselo al servidor MCP con una variable de entorno:

```bash
claude mcp add godot -e GODOT_PORT=9090 -- node /ruta/a/server/index.js
```

## Solución de problemas

- **"No se pudo conectar con Godot"** → Asegúrate de que Godot esté abierto, el plugin activado y el punto del panel en verde.
- **El puerto está ocupado** → Cambia el puerto en el panel y reinicia el servidor con el botón; recuerda actualizar `GODOT_PORT`.
- **Claude no ve las herramientas** → Ejecuta `claude mcp list` para verificar que `godot` aparezca como conectado.

## Seguridad

El servidor TCP solo escucha en `127.0.0.1` (tu propia máquina); nada queda expuesto a la red. Ten en cuenta que `godot_execute_code` permite ejecutar código en el editor: es la herramienta más potente y la que hace posible casi cualquier automatización.

## Atribución

Los módulos `commands/particles.gd`, `commands/audio.gd`, `commands/animation_tree.gd`,
`commands/theme.gd` y `commands/ported_base.gd` están portados de
[godot-mcp-ck](https://github.com/blasdecrespo/godot-mcp-ck)
(godot-mcp-pro), licencia MIT, Copyright (c) 2026 Youichi Uda (y1uda).
Copia de referencia y licencia en `docs/superpowers/reference/godot-mcp-ck/`.
