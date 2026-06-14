# game

Monorepo con dos proyectos independientes:

| Carpeta | Qué es |
|---|---|
| [`juego/`](juego/) | El juego de Godot 4 (Nightfall Survivors / Undead Slayer). |
| [`mcp/`](mcp/) | El servidor MCP "Claude Bridge" que conecta Claude Code con el editor de Godot. |

## juego/

Proyecto de Godot 4. Ábrelo desde Godot con `juego/project.godot`.

## mcp/

Servidor MCP (Node.js) + plugin de editor de Godot que permite a Claude Code
controlar Godot. Instrucciones completas en [`mcp/README.md`](mcp/README.md).
