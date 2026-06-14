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
