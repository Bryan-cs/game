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
