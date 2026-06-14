import { z } from "zod";

const severity = z.enum(["all", "error", "warning"]).optional().describe("Filtro (por defecto all)");
const limit = z.number().optional().describe("Máximo de entradas (por defecto 100)");
const clear = z.boolean().optional().describe("Vaciar el buffer tras leer");

export function registerDebugTools(server, { run }) {
  server.tool(
    "godot_get_errors",
    "Devuelve los errores y warnings recientes del EDITOR de Godot (buffer circular de 500). Úsala tras operaciones que puedan fallar en silencio.",
    { severity, limit, clear },
    async (args) => run("get_errors", args)
  );

  server.tool(
    "godot_get_game_output",
    "Devuelve la salida del JUEGO (print, errores, warnings) acumulada por el editor. Funciona incluso después de que el juego haya terminado o crasheado.",
    { severity, limit, clear },
    async (args) => run("get_game_output", args)
  );

  server.tool(
    "godot_validate_script",
    "Compila un script .gd y devuelve si es válido junto con los errores de compilación capturados. Sustituye la validación por CLI headless.",
    { path: z.string().describe("Ruta res:// del script") },
    async (args) => run("validate_script", args)
  );

  server.tool(
    "godot_search_scripts",
    "Busca texto o regex en los scripts .gd del proyecto. Devuelve archivo, línea y texto de cada coincidencia (máx. 200).",
    {
      pattern: z.string().describe("Texto o regex a buscar"),
      regex: z.boolean().optional().describe("Interpretar pattern como regex"),
      path: z.string().optional().describe("Carpeta base (por defecto res://)"),
      include_addons: z.boolean().optional().describe("Incluir addons (por defecto false)"),
    },
    async (args) => run("search_scripts", args)
  );

  server.tool(
    "godot_reload_scripts",
    "Fuerza un re-escaneo del sistema de archivos y de los scripts en el editor.",
    {},
    async () => run("reload_scripts", {})
  );

  server.tool(
    "godot_move_node",
    "Mueve un nodo: cambia su padre (reparent conservando transform global por defecto) y/o su posición entre hermanos.",
    {
      path: z.string().describe("Ruta del nodo a mover"),
      new_parent: z.string().optional().describe("Ruta del nuevo padre ('.' = raíz)"),
      index: z.number().optional().describe("Posición entre hermanos (0 = primero)"),
      keep_transform: z.boolean().optional().describe("Conservar transform global (por defecto true)"),
    },
    async (args) => run("move_node", args)
  );

  server.tool(
    "godot_rename_node",
    "Renombra un nodo de la escena abierta.",
    {
      path: z.string().describe("Ruta del nodo"),
      name: z.string().describe("Nuevo nombre"),
    },
    async (args) => run("rename_node", args)
  );

  server.tool(
    "godot_get_selection",
    "Devuelve los nodos seleccionados actualmente en el editor.",
    {},
    async () => run("get_selection", {})
  );

  server.tool(
    "godot_set_selection",
    "Selecciona nodos en el editor (dirige la atención del usuario a esos nodos).",
    { paths: z.array(z.string()).describe("Rutas de los nodos a seleccionar") },
    async (args) => run("set_selection", args)
  );

  server.tool(
    "godot_open_script",
    "Abre un script en el editor de scripts de Godot, en la línea indicada.",
    {
      path: z.string().describe("Ruta res:// del script"),
      line: z.number().optional().describe("Línea (por defecto 1)"),
    },
    async (args) => run("open_script", args)
  );
}
