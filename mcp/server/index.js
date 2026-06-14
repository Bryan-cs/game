#!/usr/bin/env node
/**
 * godot-claude-mcp
 * Servidor MCP (stdio) que conecta Claude Code con el editor de Godot.
 * Se comunica con el plugin "Claude Bridge" mediante TCP (JSON por líneas).
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import net from "node:net";

import { registerDebugTools } from "./tools/debug.js";
import { registerRuntimeTools } from "./tools/runtime.js";
import { registerInputTools } from "./tools/input.js";
import { registerParticlesTools } from "./tools/particles.js";
import { registerAudioTools } from "./tools/audio.js";
import { registerAnimationTreeTools } from "./tools/animation_tree.js";
import { registerThemeTools } from "./tools/theme.js";

const GODOT_HOST = process.env.GODOT_HOST || "127.0.0.1";
const GODOT_PORT = parseInt(process.env.GODOT_PORT || "9080", 10);
const TIMEOUT_MS = 15000;

// ---------------------------------------------------------------------------
// Conexión TCP con Godot (reconexión automática)
// ---------------------------------------------------------------------------

let socket = null;
let buffer = "";
let nextId = 1;
const pending = new Map(); // id -> { resolve, reject, timer }

function connect() {
  return new Promise((resolve, reject) => {
    if (socket && !socket.destroyed) return resolve(socket);

    const s = net.createConnection({ host: GODOT_HOST, port: GODOT_PORT });
    s.setEncoding("utf8");

    s.once("connect", () => {
      socket = s;
      resolve(s);
    });

    s.once("error", (err) => {
      if (socket === s) socket = null;
      reject(
        new Error(
          `No se pudo conectar con Godot en ${GODOT_HOST}:${GODOT_PORT}. ` +
            `Verifica que: 1) Godot esté abierto, 2) el plugin "Claude Bridge" esté activado ` +
            `(Proyecto → Ajustes del proyecto → Plugins), 3) el servidor esté iniciado en el panel ` +
            `Claude Bridge. Detalle: ${err.message}`
        )
      );
    });

    s.on("data", (chunk) => {
      buffer += chunk;
      let idx;
      while ((idx = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, idx);
        buffer = buffer.slice(idx + 1);
        if (!line.trim()) continue;
        try {
          const msg = JSON.parse(line);
          const entry = pending.get(msg.id);
          if (entry) {
            clearTimeout(entry.timer);
            pending.delete(msg.id);
            if (msg.ok) entry.resolve(msg.result);
            else entry.reject(new Error(msg.error || "Error desconocido en Godot"));
          }
        } catch {
          /* línea malformada: ignorar */
        }
      }
    });

    s.on("close", () => {
      if (socket === s) socket = null;
      for (const [, entry] of pending) {
        clearTimeout(entry.timer);
        entry.reject(new Error("Se perdió la conexión con Godot"));
      }
      pending.clear();
    });
  });
}

async function godot(command, params = {}, timeoutMs = TIMEOUT_MS) {
  const s = await connect();
  const id = nextId++;
  const payload = JSON.stringify({ id, command, params }) + "\n";

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Godot no respondió al comando '${command}' en ${timeoutMs / 1000}s`));
    }, timeoutMs);
    pending.set(id, { resolve, reject, timer });
    s.write(payload);
  });
}

function ok(result) {
  return {
    content: [{ type: "text", text: typeof result === "string" ? result : JSON.stringify(result, null, 2) }],
  };
}

function fail(err) {
  return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
}

async function run(command, params, timeoutMs) {
  try {
    return ok(await godot(command, params, timeoutMs));
  } catch (err) {
    return fail(err);
  }
}

// ---------------------------------------------------------------------------
// Definición del servidor MCP y sus herramientas
// ---------------------------------------------------------------------------

const server = new McpServer({ name: "godot", version: "1.0.0" });

server.tool(
  "godot_status",
  "Comprueba la conexión con el editor de Godot y devuelve la versión y el nombre del proyecto.",
  {},
  async () => run("ping", {})
);

server.tool(
  "godot_get_scene_tree",
  "Devuelve el árbol completo de nodos de la escena abierta actualmente en el editor (nombres, tipos, rutas y scripts).",
  {},
  async () => run("get_scene_tree", {})
);

server.tool(
  "godot_open_scene",
  "Abre una escena en el editor de Godot.",
  { path: z.string().describe("Ruta de la escena, p. ej. res://scenes/main.tscn") },
  async ({ path }) => run("open_scene", { path })
);

server.tool(
  "godot_create_node",
  "Crea un nodo nuevo en la escena abierta. Acepta propiedades iniciales opcionales.",
  {
    type: z.string().describe("Clase de Godot, p. ej. Sprite2D, CharacterBody2D, Label"),
    name: z.string().optional().describe("Nombre del nodo (por defecto, el tipo)"),
    parent: z.string().optional().describe("Ruta del nodo padre relativa a la raíz; '.' es la raíz"),
    properties: z
      .record(z.any())
      .optional()
      .describe('Propiedades iniciales, p. ej. {"position": "Vector2(100, 200)", "text": "Hola"}'),
  },
  async (args) => run("create_node", args)
);

server.tool(
  "godot_delete_node",
  "Elimina un nodo de la escena abierta.",
  { path: z.string().describe("Ruta del nodo relativa a la raíz, p. ej. Player/Sprite2D") },
  async ({ path }) => run("delete_node", { path })
);

server.tool(
  "godot_set_property",
  "Cambia una propiedad de un nodo. Acepta literales de Godot como 'Vector2(10, 20)' o 'Color(1, 0, 0)'.",
  {
    path: z.string().describe("Ruta del nodo relativa a la raíz"),
    property: z.string().describe("Nombre de la propiedad, admite subpropiedades como 'position:x'"),
    value: z.any().describe("Nuevo valor (número, texto, booleano o literal de Godot como cadena)"),
  },
  async (args) => run("set_property", args)
);

server.tool(
  "godot_get_node_info",
  "Devuelve el tipo y todas las propiedades visibles de un nodo.",
  { path: z.string().describe("Ruta del nodo relativa a la raíz; '.' es la raíz") },
  async ({ path }) => run("get_node_info", { path })
);

server.tool(
  "godot_save_scene",
  "Guarda la escena abierta actualmente en el editor.",
  {},
  async () => run("save_scene", {})
);

server.tool(
  "godot_run_scene",
  "Ejecuta una escena en Godot. Sin argumentos ejecuta la escena abierta; con 'path' ejecuta esa escena.",
  { path: z.string().optional().describe("Ruta de la escena a ejecutar (opcional)") },
  async ({ path }) => run("run_scene", path ? { path } : {})
);

server.tool(
  "godot_stop_scene",
  "Detiene la escena que se está ejecutando.",
  {},
  async () => run("stop_scene", {})
);

server.tool(
  "godot_list_files",
  "Lista los archivos del proyecto de Godot (excluye addons).",
  {
    path: z.string().optional().describe("Carpeta inicial, por defecto res://"),
    recursive: z.boolean().optional().describe("Buscar en subcarpetas (por defecto true)"),
  },
  async (args) => run("list_files", args)
);

server.tool(
  "godot_read_file",
  "Lee el contenido de un archivo del proyecto (scripts, escenas, recursos de texto).",
  { path: z.string().describe("Ruta res:// del archivo") },
  async ({ path }) => run("read_file", { path })
);

server.tool(
  "godot_write_file",
  "Crea o sobrescribe un archivo en el proyecto (p. ej. un script .gd). Godot reescanea el sistema de archivos automáticamente.",
  {
    path: z.string().describe("Ruta res:// del archivo"),
    content: z.string().describe("Contenido completo del archivo"),
  },
  async (args) => run("write_file", args)
);

server.tool(
  "godot_attach_script",
  "Adjunta un script existente a un nodo de la escena abierta.",
  {
    node: z.string().describe("Ruta del nodo relativa a la raíz"),
    script: z.string().describe("Ruta res:// del script .gd"),
  },
  async (args) => run("attach_script", args)
);

server.tool(
  "godot_execute_code",
  "Ejecuta código GDScript arbitrario dentro del editor. El código recibe la variable 'scene_root' (raíz de la escena abierta) y puede usar EditorInterface. Útil para operaciones avanzadas no cubiertas por otras herramientas.",
  { code: z.string().describe("Cuerpo de una función GDScript; usa 'return' para devolver un valor") },
  async ({ code }) => run("execute_code", { code })
);

// ---------------------------------------------------------------------------
// Escenas y proyecto
// ---------------------------------------------------------------------------

server.tool(
  "godot_create_scene",
  "Crea una escena nueva (.tscn) con el tipo de nodo raíz indicado, la guarda y la abre en el editor.",
  {
    path: z.string().describe("Ruta de la nueva escena, p. ej. res://scenes/nivel_1.tscn"),
    root_type: z.string().optional().describe("Clase del nodo raíz: Node2D, Node3D, Control… (por defecto Node2D)"),
    root_name: z.string().optional().describe("Nombre del nodo raíz"),
  },
  async (args) => run("create_scene", args)
);

server.tool(
  "godot_instance_scene",
  "Instancia una escena guardada (.tscn) como hijo dentro de la escena abierta. Clave para componer niveles con personajes, enemigos, props, etc.",
  {
    scene: z.string().describe("Ruta res:// de la escena a instanciar"),
    parent: z.string().optional().describe("Ruta del nodo padre ('.' = raíz)"),
    name: z.string().optional().describe("Nombre de la instancia"),
    properties: z.record(z.any()).optional().describe('Propiedades iniciales, p. ej. {"position": "Vector2(300, 100)"}'),
  },
  async (args) => run("instance_scene", args)
);

server.tool(
  "godot_add_input_action",
  "Crea o reemplaza una acción de entrada del proyecto (Input Map) con teclas y/o botones de mando.",
  {
    name: z.string().describe("Nombre de la acción, p. ej. 'attack' o 'dash'"),
    keys: z.array(z.string()).optional().describe('Teclas, p. ej. ["E"], ["Shift"], ["Space"]'),
    joy_buttons: z.array(z.number()).optional().describe("Índices de botones de mando (0 = A/Cruz)"),
  },
  async (args) => run("add_input_action", args)
);

server.tool(
  "godot_set_project_setting",
  "Cambia un ajuste del proyecto, p. ej. 'application/run/main_scene' para definir la escena principal, o ajustes de física y ventana.",
  {
    setting: z.string().describe("Ruta del ajuste, p. ej. application/run/main_scene"),
    value: z.any().describe("Nuevo valor"),
  },
  async (args) => run("set_project_setting", args)
);

// ---------------------------------------------------------------------------
// Recursos, mallas, colisiones y materiales (3D)
// ---------------------------------------------------------------------------

server.tool(
  "godot_assign_resource",
  "Carga un recurso del proyecto (textura, malla, material, audio…) y lo asigna a una propiedad de un nodo. P. ej. asignar res://sprites/heroe.png a la propiedad 'texture' de un Sprite2D.",
  {
    node: z.string().describe("Ruta del nodo relativa a la raíz"),
    property: z.string().describe("Propiedad destino: texture, mesh, material_override, stream…"),
    resource: z.string().describe("Ruta res:// del recurso"),
  },
  async (args) => run("assign_resource", args)
);

server.tool(
  "godot_create_primitive_mesh",
  "Asigna una malla primitiva (box, sphere, capsule, cylinder, plane, torus) a un MeshInstance3D, con tamaño y color opcionales. Ideal para prototipar niveles 3D.",
  {
    node: z.string().describe("Ruta del MeshInstance3D"),
    shape: z.enum(["box", "sphere", "capsule", "cylinder", "plane", "torus"]),
    x: z.number().optional().describe("Ancho (box/plane)"),
    y: z.number().optional().describe("Alto (box)"),
    z: z.number().optional().describe("Profundidad (box/plane)"),
    radius: z.number().optional(),
    height: z.number().optional(),
    color: z.string().optional().describe("Color en hex, p. ej. '#e5484d'"),
  },
  async (args) => run("create_primitive_mesh", args)
);

server.tool(
  "godot_create_collision_shape",
  "Crea y asigna la forma de colisión a un CollisionShape2D (rectangle, circle, capsule) o CollisionShape3D (box, sphere, capsule, cylinder).",
  {
    node: z.string().describe("Ruta del CollisionShape2D o CollisionShape3D"),
    shape: z.string().describe("2D: rectangle, circle, capsule · 3D: box, sphere, capsule, cylinder"),
    x: z.number().optional(),
    y: z.number().optional(),
    z: z.number().optional(),
    radius: z.number().optional(),
    height: z.number().optional(),
  },
  async (args) => run("create_collision_shape", args)
);

server.tool(
  "godot_create_material",
  "Crea un StandardMaterial3D (color, metallic, roughness, emisión opcional) y lo aplica como material_override de un nodo 3D.",
  {
    node: z.string().describe("Ruta del nodo 3D (MeshInstance3D, CSGBox3D…)"),
    color: z.string().optional().describe("Color albedo en hex"),
    metallic: z.number().optional().describe("0 a 1"),
    roughness: z.number().optional().describe("0 a 1"),
    emission: z.string().optional().describe("Color de emisión en hex (lo hace brillar)"),
    emission_energy: z.number().optional(),
  },
  async (args) => run("create_material", args)
);

server.tool(
  "godot_setup_environment_3d",
  "Prepara una escena 3D en un solo paso: cielo procedural (WorldEnvironment), sol con sombras (DirectionalLight3D) y, opcionalmente, un suelo con colisión. El punto de partida perfecto para cualquier juego 3D.",
  {
    sun: z.boolean().optional().describe("Añadir luz direccional (por defecto true)"),
    floor: z.boolean().optional().describe("Añadir suelo de 40x40 con colisión"),
    sky_color: z.string().optional().describe("Color del cielo en hex"),
    floor_color: z.string().optional(),
    glow: z.boolean().optional().describe("Activar efecto glow"),
  },
  async (args) => run("setup_environment_3d", args)
);

// ---------------------------------------------------------------------------
// Personajes y animaciones
// ---------------------------------------------------------------------------

server.tool(
  "godot_create_character",
  "Crea un personaje jugable COMPLETO en un solo paso: cuerpo con visual y colisión, cámara, script de movimiento listo para usar y acciones de entrada (WASD + flechas + espacio) registradas automáticamente. Estilos: 'platformer' (2D con gravedad y salto), 'topdown' (2D vista cenital), 'fps' (3D primera persona con ratón) y 'third_person' (3D tercera persona con SpringArm).",
  {
    name: z.string().optional().describe("Nombre del personaje (por defecto Player)"),
    style: z.enum(["platformer", "topdown", "fps", "third_person"]),
    color: z.string().optional().describe("Color del cuerpo placeholder en hex"),
    parent: z.string().optional().describe("Nodo padre ('.' = raíz)"),
    with_camera: z.boolean().optional().describe("Incluir cámara que sigue al personaje (2D, por defecto true)"),
    script_path: z.string().optional().describe("Dónde guardar el script (por defecto res://scripts/<nombre>.gd)"),
  },
  async (args) => run("create_character", args)
);

server.tool(
  "godot_create_animation",
  "Crea una animación por keyframes en un AnimationPlayer (lo crea si no existe). Cada track anima una propiedad de un nodo: position, rotation, scale, modulate, etc. Las rutas de nodos son relativas al padre del AnimationPlayer.",
  {
    name: z.string().describe("Nombre de la animación, p. ej. 'idle', 'abrir_puerta'"),
    length: z.number().optional().describe("Duración en segundos (por defecto 1)"),
    loop: z.boolean().optional(),
    player: z.string().optional().describe("Ruta del AnimationPlayer (si se omite, se busca o crea en la raíz)"),
    tracks: z
      .array(
        z.object({
          node: z.string().describe("Ruta del nodo a animar"),
          property: z.string().describe("Propiedad, p. ej. 'position' o 'modulate'"),
          keyframes: z.array(
            z.object({
              time: z.number(),
              value: z.any().describe("Valor; admite literales como 'Vector2(0, -20)'"),
            })
          ),
        })
      )
      .describe("Pistas de animación"),
  },
  async (args) => run("create_animation", args)
);

server.tool(
  "godot_list_animations",
  "Lista las animaciones de un AnimationPlayer.",
  { player: z.string().optional().describe("Ruta del AnimationPlayer") },
  async (args) => run("list_animations", args)
);

server.tool(
  "godot_play_animation",
  "Reproduce una animación en el editor como vista previa.",
  {
    name: z.string().describe("Nombre de la animación"),
    player: z.string().optional(),
  },
  async (args) => run("play_animation", args)
);

server.tool(
  "godot_create_sprite_animation",
  "Configura animaciones de spritesheet en un AnimatedSprite2D: divide la textura en una cuadrícula (hframes x vframes) y crea cada animación con los índices de frame indicados (orden de lectura: izquierda a derecha, arriba a abajo, empezando en 0).",
  {
    node: z.string().describe("Ruta del AnimatedSprite2D"),
    texture: z.string().describe("Ruta res:// del spritesheet"),
    hframes: z.number().describe("Columnas de la cuadrícula"),
    vframes: z.number().describe("Filas de la cuadrícula"),
    animations: z.array(
      z.object({
        name: z.string(),
        frames: z.array(z.number()).describe("Índices de frame, p. ej. [0,1,2,3]"),
        fps: z.number().optional(),
        loop: z.boolean().optional(),
      })
    ),
  },
  async (args) => run("create_sprite_animation", args)
);

// ---------------------------------------------------------------------------
// Señales, grupos, captura y tiles
// ---------------------------------------------------------------------------

server.tool(
  "godot_connect_signal",
  "Conecta una señal de un nodo a un método de otro de forma persistente (se guarda con la escena). P. ej. conectar 'body_entered' de un Area2D al método '_on_moneda_recogida' del nivel.",
  {
    from: z.string().describe("Nodo emisor"),
    signal: z.string().describe("Nombre de la señal"),
    to: z.string().describe("Nodo receptor"),
    method: z.string().describe("Método a llamar (debe existir en el script del receptor)"),
  },
  async (args) => run("connect_signal", args)
);

server.tool(
  "godot_list_signals",
  "Lista todas las señales disponibles de un nodo con sus argumentos.",
  { path: z.string().describe("Ruta del nodo") },
  async (args) => run("list_signals", args)
);

server.tool(
  "godot_add_to_group",
  "Añade un nodo a un grupo de forma persistente (útil para 'enemigos', 'recolectables', etc.).",
  {
    path: z.string().describe("Ruta del nodo"),
    group: z.string().describe("Nombre del grupo"),
  },
  async (args) => run("add_to_group", args)
);

server.tool(
  "godot_screenshot",
  "Captura el viewport del editor (2D o 3D) y devuelve la imagen para que Claude pueda VER el estado actual de la escena. Úsala para verificar visualmente el resultado de los cambios.",
  { viewport: z.enum(["2d", "3d"]).optional().describe("Viewport a capturar (por defecto 3d)") },
  async ({ viewport }) => {
    try {
      const r = await godot("screenshot", { viewport: viewport || "3d" });
      return {
        content: [
          { type: "image", data: r.image_base64, mimeType: "image/png" },
          { type: "text", text: `Captura del viewport ${viewport || "3d"} (${r.width}x${r.height})` },
        ],
      };
    } catch (err) {
      return fail(err);
    }
  }
);

server.tool(
  "godot_paint_tiles",
  "Pinta celdas en un TileMapLayer o TileMap que ya tenga un TileSet asignado.",
  {
    path: z.string().describe("Ruta del TileMapLayer o TileMap"),
    source_id: z.number().optional().describe("ID de la fuente del TileSet (por defecto 0)"),
    layer: z.number().optional().describe("Capa (solo TileMap clásico)"),
    cells: z.array(
      z.object({
        x: z.number(),
        y: z.number(),
        atlas_x: z.number().optional(),
        atlas_y: z.number().optional(),
      })
    ).describe("Celdas a pintar con sus coordenadas de atlas"),
  },
  async (args) => run("paint_tiles", args)
);

// ---------------------------------------------------------------------------
// Assets externos, TileSets, exportación y utilidades avanzadas
// ---------------------------------------------------------------------------

server.tool(
  "godot_import_asset",
  "Copia un archivo externo (modelo .glb/.gltf, textura, audio…) desde cualquier ruta del disco al proyecto de Godot y dispara el reimport automático. Resuelve la importación de assets sin tocar el editor.",
  {
    source: z.string().describe("Ruta absoluta del archivo en disco, p. ej. C:/Descargas/robot.glb"),
    dest: z
      .string()
      .optional()
      .describe("Ruta destino res:// (por defecto res://assets/<nombre>). Si termina en '/', conserva el nombre original"),
  },
  async (args) => run("import_asset", args)
);

server.tool(
  "godot_create_tileset",
  "Crea un TileSet (.tres) desde una textura de atlas: divide la imagen en una cuadrícula de tiles y, opcionalmente, añade colisión rectangular a todos los tiles o a una lista concreta. Puede asignarlo directamente a un TileMapLayer.",
  {
    texture: z.string().describe("Ruta res:// de la textura del atlas"),
    tile_width: z.number().describe("Ancho de cada tile en píxeles"),
    tile_height: z.number().describe("Alto de cada tile en píxeles"),
    path: z.string().optional().describe("Dónde guardar el .tres (por defecto res://tilesets/tileset.tres)"),
    collision_all: z.boolean().optional().describe("Añadir colisión rectangular a TODOS los tiles"),
    collision_tiles: z
      .array(z.object({ x: z.number(), y: z.number() }))
      .optional()
      .describe("Coordenadas de atlas de los tiles que llevan colisión"),
    assign_to: z.string().optional().describe("Ruta de un TileMapLayer/TileMap al que asignar el TileSet"),
  },
  async (args) => run("create_tileset", args)
);

server.tool(
  "godot_export_project",
  "Exporta el proyecto a un ejecutable usando un preset de export_presets.cfg. Sin 'preset' devuelve la lista de presets disponibles. Requiere plantillas de exportación instaladas. La exportación puede tardar varios minutos.",
  {
    preset: z.string().optional().describe("Nombre del preset (omitir para listar los disponibles)"),
    output: z.string().optional().describe("Ruta del ejecutable a generar, p. ej. res://build/juego.exe"),
    debug: z.boolean().optional().describe("Exportar en modo debug (por defecto release)"),
  },
  async (args) => run("export_project", args, 300000)
);

server.tool(
  "godot_create_shader",
  "Crea un archivo .gdshader con el código indicado y, opcionalmente, lo aplica a un nodo mediante un ShaderMaterial (material_override en 3D, material en 2D). Acepta parámetros uniform iniciales.",
  {
    path: z.string().describe("Ruta res:// del shader, p. ej. res://shaders/disolver.gdshader"),
    code: z.string().describe("Código completo del shader (debe incluir shader_type spatial; o canvas_item;)"),
    node: z.string().optional().describe("Nodo al que aplicar el shader"),
    parameters: z
      .record(z.any())
      .optional()
      .describe('Uniforms iniciales, p. ej. {"intensidad": 0.5, "tinte": "Color(1, 0, 0)"}'),
  },
  async (args) => run("create_shader", args)
);

server.tool(
  "godot_duplicate_node",
  "Duplica un nodo (con todos sus hijos y script) una o varias veces, con desplazamiento incremental opcional. Ideal para poblar niveles con copias de props, plataformas o enemigos.",
  {
    path: z.string().describe("Ruta del nodo a duplicar"),
    count: z.number().optional().describe("Número de copias (por defecto 1, máximo 200)"),
    offset: z
      .string()
      .optional()
      .describe("Desplazamiento incremental por copia, p. ej. 'Vector3(2, 0, 0)' o 'Vector2(64, 0)'"),
    parent: z.string().optional().describe("Padre de las copias (por defecto, el mismo del original)"),
    name: z.string().optional().describe("Nombre base de las copias (Godot añade sufijos únicos)"),
  },
  async (args) => run("duplicate_node", args)
);

server.tool(
  "godot_find_nodes",
  "Busca nodos en la escena abierta filtrando por clase (incluye herencia), grupo y/o fragmento del nombre. Devuelve rutas, tipos y nombres.",
  {
    type: z.string().optional().describe("Clase de Godot, p. ej. 'CharacterBody3D' (incluye subclases)"),
    group: z.string().optional().describe("Nombre de grupo, p. ej. 'enemigos'"),
    name_contains: z.string().optional().describe("Texto que debe contener el nombre (sin distinguir mayúsculas)"),
  },
  async (args) => run("find_nodes", args)
);

server.tool(
  "godot_set_physics_layers",
  "Nombra las capas de física del proyecto y/o configura collision_layer y collision_mask de un nodo usando números de capa (1-32) en lugar de máscaras de bits.",
  {
    dimension: z.enum(["2d", "3d"]).optional().describe("Espacio de física (por defecto 3d)"),
    names: z
      .record(z.string())
      .optional()
      .describe('Nombres de capas del proyecto, p. ej. {"1": "suelo", "2": "jugador", "3": "enemigos"}'),
    node: z.string().optional().describe("Nodo con colisión a configurar"),
    layer: z.array(z.number()).optional().describe("Capas en las que ESTÁ el nodo, p. ej. [2]"),
    mask: z.array(z.number()).optional().describe("Capas que el nodo DETECTA, p. ej. [1, 3]"),
  },
  async (args) => run("set_physics_layers", args)
);

server.tool(
  "godot_create_nav_region",
  "Crea un NavigationRegion3D con su NavigationMesh y lo hornea a partir de la geometría de los nodos indicados (los añade a un grupo fuente). Base para IA con NavigationAgent3D.",
  {
    name: z.string().optional().describe("Nombre del nodo (por defecto NavRegion)"),
    parent: z.string().optional().describe("Nodo padre ('.' = raíz)"),
    nodes: z
      .array(z.string())
      .optional()
      .describe("Nodos cuya geometría forma el área navegable, p. ej. ['Suelo']"),
    source_group: z.string().optional().describe("Grupo fuente de geometría (por defecto 'nav_source')"),
    agent_radius: z.number().optional().describe("Radio del agente (por defecto 0.5)"),
    agent_height: z.number().optional().describe("Altura del agente (por defecto 1.8)"),
    cell_size: z.number().optional().describe("Resolución del horneado (por defecto 0.25)"),
    bake: z.boolean().optional().describe("Hornear inmediatamente (por defecto true)"),
  },
  async (args) => run("create_nav_region", args, 60000)
);

// ---------------------------------------------------------------------------

const ctx = { run, godot, ok, fail };
registerDebugTools(server, ctx);
registerRuntimeTools(server, ctx);
registerInputTools(server, ctx);
registerParticlesTools(server, ctx);
registerAudioTools(server, ctx);
registerAnimationTreeTools(server, ctx);
registerThemeTools(server, ctx);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[godot-claude-mcp] Listo. Esperando a Godot en ${GODOT_HOST}:${GODOT_PORT}`);
