import { z } from "zod";

const treePath = z.string().describe("Ruta del nodo AnimationTree");
const smPath = z
  .string()
  .optional()
  .describe("Ruta de state machine anidada (vacío = raíz del árbol)");

export function registerAnimationTreeTools(server, { run }) {
  server.tool(
    "godot_create_animation_tree",
    "Crea un AnimationTree (raíz AnimationNodeStateMachine) bajo un nodo, ligado a un AnimationPlayer.",
    {
      node_path: z.string().describe("Ruta del nodo padre ('.' = raíz)"),
      anim_player: z.string().optional().describe("Ruta del AnimationPlayer a usar"),
      name: z.string().optional().describe("Nombre del nodo (por defecto AnimationTree)"),
    },
    async (args) => run("create_animation_tree", args)
  );

  server.tool(
    "godot_get_animation_tree_structure",
    "Devuelve la estructura del AnimationTree: estados, transiciones, nodos de blend tree y parámetros actuales.",
    { node_path: treePath },
    async (args) => run("get_animation_tree_structure", args)
  );

  server.tool(
    "godot_add_state_machine_state",
    "Añade un estado a la state machine del AnimationTree (animación o sub-árbol).",
    {
      node_path: treePath,
      state_name: z.string().describe("Nombre del estado"),
      state_machine_path: smPath,
      state_type: z.string().optional().describe("Tipo de estado (por defecto 'animation'; también 'blend_tree', etc.)"),
      animation: z.string().optional().describe("Animación a reproducir (para state_type animation)"),
      position_x: z.number().optional().describe("Posición X en el grafo del editor"),
      position_y: z.number().optional().describe("Posición Y en el grafo del editor"),
    },
    async (args) => run("add_state_machine_state", args)
  );

  server.tool(
    "godot_remove_state_machine_state",
    "Elimina un estado de la state machine.",
    { node_path: treePath, state_name: z.string(), state_machine_path: smPath },
    async (args) => run("remove_state_machine_state", args)
  );

  server.tool(
    "godot_add_state_machine_transition",
    "Crea una transición entre dos estados de la state machine, con crossfade y modo de avance.",
    {
      node_path: treePath,
      from_state: z.string(),
      to_state: z.string(),
      state_machine_path: smPath,
      switch_mode: z.enum(["immediate", "sync", "at_end"]).optional().describe("Por defecto immediate"),
      advance_mode: z.enum(["disabled", "enabled", "auto"]).optional().describe("Por defecto enabled"),
      advance_expression: z.string().optional().describe("Expresión de condición de avance"),
      xfade_time: z.number().optional().describe("Crossfade en segundos"),
    },
    async (args) => run("add_state_machine_transition", args)
  );

  server.tool(
    "godot_remove_state_machine_transition",
    "Elimina la transición entre dos estados.",
    { node_path: treePath, from_state: z.string(), to_state: z.string(), state_machine_path: smPath },
    async (args) => run("remove_state_machine_transition", args)
  );

  server.tool(
    "godot_set_blend_tree_node",
    "Añade o configura un nodo dentro de un estado de tipo blend tree (Animation, Blend2, OneShot, TimeScale, etc.) y opcionalmente lo conecta a otro nodo.",
    {
      node_path: treePath,
      blend_tree_state: z.string().describe("Nombre del estado blend tree dentro de la state machine"),
      bt_node_name: z.string().describe("Nombre del nodo a crear/configurar en el blend tree"),
      bt_node_type: z.string().describe("Tipo: Animation, Blend2, Blend3, OneShot, TimeScale, Add2, ..."),
      state_machine_path: smPath,
      animation: z.string().optional().describe("Animación (para tipo Animation)"),
      position_x: z.number().optional(),
      position_y: z.number().optional(),
      connect_to: z.string().optional().describe("Nodo destino de la conexión"),
      connect_port: z.number().optional().describe("Puerto de entrada del destino (por defecto 0)"),
    },
    async (args) => run("set_blend_tree_node", args)
  );

  server.tool(
    "godot_set_tree_parameter",
    "Establece un parámetro del AnimationTree (ruta 'parameters/...'): blend amounts, condiciones, travel de la state machine, etc.",
    {
      node_path: treePath,
      parameter: z.string().describe("Ruta del parámetro, p. ej. 'parameters/playback' o 'parameters/Blend2/blend_amount'"),
      value: z.any().describe("Valor a asignar"),
    },
    async (args) => run("set_tree_parameter", args)
  );
}
