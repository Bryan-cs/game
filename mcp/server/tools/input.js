import { z } from "zod";

export function registerInputTools(server, { run }) {
  server.tool(
    "input_action_press",
    "Mantiene pulsada una acción del Input Map del juego (p. ej. 'move_up'). Queda pulsada hasta input_action_release.",
    {
      action: z.string().describe("Nombre de la acción del Input Map"),
      strength: z.number().optional().describe("Fuerza 0-1 (por defecto 1)"),
    },
    async (args) => run("input_action_press", args)
  );

  server.tool(
    "input_action_release",
    "Suelta una acción mantenida con input_action_press.",
    { action: z.string().describe("Nombre de la acción") },
    async (args) => run("input_action_release", args)
  );

  server.tool(
    "input_key",
    "Simula una tecla en el juego. mode: 'tap' (pulsar y soltar), 'press' (mantener), 'release' (soltar).",
    {
      key: z.string().describe("Nombre de la tecla: 'A', 'Space', 'Escape', 'Shift'…"),
      mode: z.enum(["tap", "press", "release"]).optional().describe("Por defecto tap"),
    },
    async (args) => run("input_key", args)
  );

  server.tool(
    "input_mouse_move",
    "Mueve el ratón del juego a coordenadas de viewport.",
    { x: z.number(), y: z.number() },
    async (args) => run("input_mouse_move", args)
  );

  server.tool(
    "input_mouse_click",
    "Click del ratón en coordenadas del viewport del juego (sirve para UI y para apuntar).",
    {
      x: z.number(),
      y: z.number(),
      button: z.enum(["left", "right", "middle"]).optional().describe("Por defecto left"),
    },
    async (args) => run("input_mouse_click", args)
  );

  server.tool(
    "input_text",
    "Escribe texto en el juego (p. ej. en un LineEdit con foco).",
    { text: z.string().describe("Texto a escribir") },
    async (args) => run("input_text", args)
  );

  server.tool(
    "input_sequence",
    "Ejecuta una secuencia temporizada de inputs — playtest scripteado. Cada paso: {type, ...params, wait_after}. Tipos: action_press, action_release, key, mouse_move, mouse_click, text, wait. Ejemplo: mantener 'move_up' 2s, click en (640,360), esperar 1s.",
    {
      steps: z
        .array(
          z.object({
            type: z.enum(["action_press", "action_release", "key", "mouse_move", "mouse_click", "text", "wait"]),
            action: z.string().optional(),
            strength: z.number().optional(),
            key: z.string().optional(),
            mode: z.string().optional(),
            x: z.number().optional(),
            y: z.number().optional(),
            button: z.string().optional(),
            text: z.string().optional(),
            seconds: z.number().optional().describe("Solo para type=wait"),
            wait_after: z.number().optional().describe("Segundos de espera tras el paso (máx. 30)"),
          })
        )
        .describe("Pasos de la secuencia"),
    },
    async (args) => {
      const totalWait = (args.steps || []).reduce(
        (acc, s) => acc + (s.wait_after || 0) + (s.type === "wait" ? s.seconds || 1 : 0),
        0
      );
      return run("input_sequence", args, Math.min(totalWait * 1000 + 15000, 120000));
    }
  );
}
