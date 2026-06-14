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
