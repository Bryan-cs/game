# Claude Bridge · Godot ↔ Claude Code — Guía de instalación y uso

> Conecta tu editor de Godot 4 con Claude Code mediante MCP. **100 herramientas** para que Claude cree escenas, personajes, partículas, audio, animaciones y UI; ejecute tu juego, lo juegue con input simulado, lo depure en vivo y vea lo que pasa en pantalla. Un panel visual dentro de Godot muestra en tiempo real cada comando.

```
Claude Code ──(MCP stdio)──► servidor Node.js ──(TCP 127.0.0.1:9080)──► Plugin Godot (editor)
                                                        └──(relay :9081)──► ClaudeRuntime (juego en ejecución)
```

---

## ¿Qué contiene el paquete?

```
godot-claude-mcp/
├── instalacion.md              ← esta guía
├── addons/
│   └── claude_bridge/          ← Plugin de Godot (copiar a tu proyecto)
│       ├── plugin.cfg
│       ├── plugin.gd           ← registro del plugin y lifecycle
│       ├── bridge_server.gd    ← servidor TCP + comandos del editor
│       ├── dock.gd             ← panel visual del editor
│       ├── capture_logger.gd   ← captura logs (sobrevive a crashes del juego)
│       ├── runtime_agent.gd    ← autoload ClaudeRuntime: comandos dentro del juego
│       ├── agent_link.gd       ← relay editor ↔ juego (puerto 9081)
│       └── commands/           ← módulos: partículas, audio, AnimationTree, theme, debug
└── server/
    ├── index.js                ← servidor MCP (Node.js)
    ├── tools/                  ← definiciones de herramientas por categoría
    └── package.json
```

---

## ¿Qué es capaz de crear y hacer? (100 herramientas)

| Categoría | Tools | Qué hace Claude con ellas |
|---|---|---|
| Escenas y proyecto | 10 | Crear/abrir/guardar/instanciar escenas, leer el árbol de nodos, input actions, ajustes del proyecto, ejecutar y detener el juego |
| Nodos y archivos | 10 | Crear/borrar/inspeccionar nodos, propiedades, recursos, scripts, leer/escribir archivos, ejecutar GDScript en el editor |
| 3D | 4 | Entorno completo (cielo+sol+suelo) en un paso, mallas primitivas, colisiones, materiales PBR |
| Personajes y animación | 5 | Personaje jugable completo en un paso (platformer, topdown, fps, third_person), animaciones por keyframes y spritesheet |
| Lógica y verificación | 5 | Señales, grupos, TileMap, **screenshot del viewport (Claude VE la escena)** |
| Debug del editor | 10 | Errores del editor, salida del juego (incluso tras crash), validar/buscar/recargar scripts, mover/renombrar nodos, selección |
| Runtime (juego en vivo) | 15 | Árbol del juego EN VIVO, tuning sin reiniciar, llamar métodos, screenshot del jugador, pausa/cámara lenta, monitor de señales, FPS/memoria/draw calls |
| Input simulado | 7 | Teclas, ratón, acciones y secuencias temporizadas: **Claude juega tu juego y reporta lo que pasa** |
| Partículas | 5 | GPUParticles 2D/3D, materiales, gradientes, presets (explosion, fire, smoke, sparks, rain, snow, magic, dust) |
| Audio | 6 | Buses con efectos (reverb, delay, compressor…), reproductores 2D/3D, layout persistente |
| AnimationTree | 8 | State machines completas: estados, transiciones con crossfade y condiciones, blend trees, parámetros |
| Theme / UI | 7 | Themes .tres, StyleBoxFlat, colores/constantes/fuentes, anclajes y presets de Controls |
| Otros (shaders, tileset, export, navegación, física) | 8 | Shaders, TileSets, import de assets, export del proyecto, búsqueda de nodos, capas de física, regiones de navegación |

Ejemplos reales de lo que puedes pedirle a Claude:

> *"Crea una escena 3D con entorno, suelo y un personaje en tercera persona; ejecútala"*
> *"Crea un platformer 2D con plataformas y un enemigo patrullando, y pruébalo tú mismo con input simulado"*
> *"El jugador se siente lento: sube su velocidad en vivo hasta que se sienta bien y dime el valor"*
> *"Añade partículas de chispas cuando muera un enemigo, con preset sparks en naranja"*
> *"Monta la state machine idle/run/jump del personaje con crossfade de 0.2s"*
> *"Toma una captura del viewport y dime si el nivel se ve bien"*
> *"El juego crasheó: lee la salida y dime la causa"*

La lista completa de las 100 herramientas con descripción está en `README.md`.

---

## Requisitos

| Herramienta | Versión mínima | Cómo verificar |
|---|---|---|
| Godot | 4.2 | `Ayuda → Acerca de Godot` |
| Node.js | 18 | `node --version` |
| npm | 9 | `npm --version` |
| Claude Code | cualquiera | `claude --version` |

Si no tienes Claude Code: `npm install -g @anthropic-ai/claude-code`

Funciona en **Windows, macOS y Linux** — el plugin es GDScript puro y el servidor es Node.js sin dependencias nativas.

---

## Instalación (4 pasos, ~5 minutos)

### Paso 1 — Plugin de Godot

Copia la carpeta `addons/claude_bridge` dentro de la carpeta raíz de tu proyecto de Godot (al mismo nivel que `project.godot`):

```
mi-juego/
├── project.godot
└── addons/
    └── claude_bridge/      ← pega esta carpeta aquí (completa, con commands/)
```

Luego en Godot:

**Proyecto → Ajustes del proyecto → Plugins → Claude Bridge → activar el toggle**

El panel **Claude Bridge** aparecerá en el lateral del editor con un punto 🟢 verde: el servidor ya está activo en el puerto `9080`.

> Si el panel no aparece, cierra y vuelve a abrir Godot con el proyecto.

El plugin registra además el autoload `ClaudeRuntime`, que habilita las herramientas `runtime_*` e `input_*` dentro del juego. Solo está activo en builds de debug: **no se incluye en tus exports de release**.

### Paso 2 — Servidor MCP (Node.js)

Abre una terminal en la carpeta `server` del paquete:

```bash
cd godot-claude-mcp/server
npm install
```

Solo necesitas hacerlo una vez (instala `@modelcontextprotocol/sdk` y `zod`).

### Paso 3 — Registrar el MCP en Claude Code

Reemplaza la ruta con la ubicación real de la carpeta `server` en tu PC:

**macOS / Linux**
```bash
claude mcp add godot -- node /ruta/a/godot-claude-mcp/server/index.js
```

**Windows (PowerShell)**
```powershell
claude mcp add godot -- node C:\ruta\a\godot-claude-mcp\server\index.js
```

> El panel de Godot tiene un botón **"Copiar comando de instalación"** que genera esta línea lista para pegar.

Verifica:
```bash
claude mcp list
```
Debes ver `godot` con estado **connected**.

### Paso 4 — Probar

Con Godot abierto y el panel en verde, abre Claude Code en la carpeta de tu juego:

```bash
cd mi-juego
claude
```

Pídele: *"Verifica la conexión con Godot"*. Claude responderá con la versión de Godot y el nombre de tu proyecto, y verás el comando en el registro del panel.

---

## El panel visual

```
┌─────────────────────────────────┐
│ Claude Bridge          🟢 Activo │
├─────────────────────────────────┤
│ Puerto  [9080]                  │
│ [ Detener servidor ]            │
│ ● 1 cliente    42 comandos      │
├─────────────────────────────────┤
│ ACTIVIDAD                       │
│ 14:03:21  → get_scene_tree      │
│ 14:03:21  ✓ get_scene_tree      │
│ 14:03:25  → create_character    │
│ 14:03:25  ✓ create_character    │
├─────────────────────────────────┤
│ [ Copiar comando de instalación]│
│ [ Limpiar registro ]            │
└─────────────────────────────────┘
```

---

## Configuración de puerto

Si el `9080` está ocupado, cámbialo en el panel y vuelve a registrar el MCP:

```bash
claude mcp remove godot
claude mcp add godot -e GODOT_PORT=9090 -- node /ruta/a/server/index.js
```

---

## Solución de problemas

**"No se pudo conectar con Godot"**
1. Godot abierto con el proyecto.
2. Plugin activado en **Proyecto → Ajustes del proyecto → Plugins**.
3. Panel con punto 🟢 verde; si está 🔴, pulsa **Iniciar servidor**.

**El plugin no aparece en la lista de plugins**
→ Verifica que `addons/claude_bridge/plugin.cfg` existe junto a tu `project.godot`.

**Error de GDScript al activar el plugin**
→ Copia el error de la consola de Godot (pestaña inferior): indica la línea exacta. Asegúrate de haber copiado la carpeta `commands/` completa.

**`claude mcp list` no muestra `godot`**
→ Repite el Paso 3 con la ruta absoluta completa al `index.js`.

**Las herramientas `runtime_*` / `input_*` fallan**
→ El juego debe estar en ejecución (`godot_run_scene` primero). Solo funcionan en builds de debug.

**Instalé una versión nueva del plugin y no se reflejan los cambios**
→ Reinicia el editor de Godot y la sesión de Claude Code (las tools nuevas requieren reiniciar la sesión).

---

## Seguridad

- El servidor TCP escucha **únicamente en `127.0.0.1`** (tu máquina). Nada queda expuesto a tu red ni a internet.
- `godot_execute_code` y `runtime_eval` ejecutan GDScript directamente: úsalas solo con código de confianza.
- El autoload `ClaudeRuntime` solo corre en builds de debug; tus exports de release no lo incluyen.

---

## Licencia y atribución

Los módulos `commands/particles.gd`, `commands/audio.gd`, `commands/animation_tree.gd`, `commands/theme.gd` y `commands/ported_base.gd` derivan de [godot-mcp-ck](https://github.com/blasdecrespo/godot-mcp-ck), licencia MIT, Copyright (c) 2026 Youichi Uda (y1uda). El archivo `LICENSE-godot-mcp-ck.txt` incluido en este paquete debe conservarse.
