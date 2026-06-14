# Capa N3 — Level-up pausa + 3 cards — Plan / Nota

> **Resultado:** YA SATISFECHA por la Capa N1, sin código de producción nuevo. Esta capa se cierra
> con un test de verificación.

**Goal:** Al subir de nivel de personaje, el juego se PAUSA y aparecen 3 cards de mejora aleatorias
(clásico survivors / Undead Slayer); elegir una reanuda.

## Hallazgo

El comportamiento ya está implementado tras N1:
- `scripts/menu_mejoras.gd`: `mostrar()` hace `get_tree().paused = true` y el menú usa
  `process_mode = PROCESS_MODE_ALWAYS` (funciona en pausa).
- `scripts/main.gd`: `jugador.subio_nivel.connect(_al_subir_nivel)`; `_al_subir_nivel()` llama
  `_mostrar_mejoras_si_toca()` → `menu.mostrar(_opciones_actuales)` con 3 opciones de `_generar_opciones()`.
- `_al_elegir_mejora()` aplica la opción y, sin más pendientes, `get_tree().paused = false`.

No se requiere cambio de producción. Solo se añade verificación.

## Implementación

- **Test:** `tools/test_levelup.gd` + `.tscn`. Inicia partida, fuerza level-up con
  `jugador.ganar_xp(xp_necesaria + 5)`, y verifica: (1) tree pausado, (2) `menu.visible`,
  (3) `_opciones_actuales.size() == 3`, (4) elegir card reanuda (`not paused`).
- **Resultado:** 4/4 PASS. Commit `8a55403` en rama `undead-slayer-capa0`.

## Pendiente para capas futuras
- N4: añadir estrellas por tiempo a la pantalla de completado.
- N5: tabla `NIVELES` (60, nombres/tema/jefe/escala/umbrales) + menú de selección.
