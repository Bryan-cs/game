import { z } from "zod";

export function registerRuntimeTools(server, { run, godot, fail }) {
  server.tool(
    "runtime_get_scene_tree",
    "Árbol de nodos del JUEGO EN EJECUCIÓN (no del editor). Requiere el juego corriendo (godot_run_scene).",
    {},
    async () => run("runtime_get_scene_tree", {})
  );

  server.tool(
    "runtime_get_node_info",
    "Propiedades actuales de un nodo del juego en ejecución (estado en vivo).",
    { path: z.string().describe("Ruta relativa a la escena actual; '.' = raíz") },
    async (args) => run("runtime_get_node_info", args)
  );

  server.tool(
    "runtime_set_property",
    "Cambia una propiedad de un nodo del juego EN VIVO, sin reiniciar. Ideal para tuning (velocidad, vida, daño…). Acepta literales como 'Vector2(10, 20)'.",
    {
      path: z.string().describe("Ruta del nodo en el juego"),
      property: z.string().describe("Propiedad, admite 'position:x'"),
      value: z.any().describe("Nuevo valor"),
    },
    async (args) => run("runtime_set_property", args)
  );

  server.tool(
    "runtime_call_method",
    "Llama un método de un nodo del juego en ejecución con argumentos opcionales.",
    {
      path: z.string().describe("Ruta del nodo en el juego"),
      method: z.string().describe("Nombre del método"),
      args: z.array(z.any()).optional().describe("Argumentos; las cadenas con literales de Godot se convierten"),
    },
    async (args) => run("runtime_call_method", args)
  );

  server.tool(
    "runtime_eval",
    "Ejecuta GDScript arbitrario DENTRO del juego en ejecución. El código recibe 'scene_root' (escena actual) y 'tree' (SceneTree). Usa 'return' para devolver un valor.",
    { code: z.string().describe("Cuerpo de una función GDScript") },
    async (args) => run("runtime_eval", args)
  );

  server.tool(
    "runtime_screenshot",
    "Captura el viewport del JUEGO en ejecución y devuelve la imagen. Para VER el juego tal y como lo ve el jugador.",
    {},
    async () => {
      try {
        const r = await godot("runtime_screenshot", {});
        return {
          content: [
            { type: "image", data: r.image_base64, mimeType: "image/png" },
            { type: "text", text: `Captura del juego (${r.width}x${r.height})` },
          ],
        };
      } catch (err) {
        return fail(err);
      }
    }
  );

  server.tool(
    "runtime_find_nodes",
    "Busca nodos en el juego en ejecución por clase, grupo y/o nombre (máx. 200).",
    {
      type: z.string().optional().describe("Clase de Godot (incluye subclases)"),
      group: z.string().optional().describe("Nombre de grupo"),
      name_contains: z.string().optional().describe("Fragmento del nombre"),
    },
    async (args) => run("runtime_find_nodes", args)
  );

  server.tool("runtime_pause", "Pausa el juego en ejecución (get_tree().paused = true).", {}, async () =>
    run("runtime_pause", {})
  );

  server.tool("runtime_resume", "Reanuda el juego pausado.", {}, async () => run("runtime_resume", {}));

  server.tool(
    "runtime_time_scale",
    "Cambia Engine.time_scale del juego (cámara lenta o avance rápido). 1.0 = normal.",
    { scale: z.number().describe("Factor de tiempo, 0.01 a 20") },
    async (args) => run("runtime_time_scale", args)
  );

  server.tool(
    "runtime_wait",
    "Espera N segundos de juego y devuelve un snapshot opcional de los nodos vigilados (tipo y posición). Útil para observar evolución: '¿dónde está el enemigo tras 3s?'.",
    {
      seconds: z.number().describe("Segundos a esperar (máx. 110)"),
      watch: z.array(z.string()).optional().describe("Rutas de nodos a fotografiar al terminar"),
    },
    async (args) => run("runtime_wait", args, Math.min((args.seconds || 1) * 1000 + 10000, 120000))
  );

  server.tool(
    "runtime_monitor_signal",
    "Monitoriza emisiones de una señal del juego. action='start' (devuelve monitor_id), 'read' (emisiones acumuladas), 'stop' (desconecta y devuelve todo).",
    {
      action: z.enum(["start", "read", "stop"]),
      path: z.string().optional().describe("Nodo (solo para start)"),
      signal: z.string().optional().describe("Señal (solo para start)"),
      monitor_id: z.string().optional().describe("Id devuelto por start (para read/stop)"),
    },
    async (args) => run("runtime_monitor_signal", args)
  );

  server.tool(
    "runtime_get_performance",
    "Métricas de rendimiento del juego en vivo: FPS, tiempos de process/física, memoria, draw calls, nodos, nodos huérfanos.",
    {},
    async () => run("runtime_get_performance", {})
  );

  server.tool(
    "runtime_get_groups",
    "Lista los grupos activos del juego con el número de miembros de cada uno (p. ej. cuántos 'enemigos' vivos hay).",
    {},
    async () => run("runtime_get_groups", {})
  );

  server.tool("runtime_quit", "Cierra el juego en ejecución limpiamente desde dentro.", {}, async () =>
    run("runtime_quit", {})
  );
}
