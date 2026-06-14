# Spec — Rework "Undead Slayer" de Nightfall Survivors

**Fecha:** 2026-06-13
**Estado:** Aprobado (diseño)
**Reemplaza:** rework Brotato (archivado) y la decisión de combate activo del 2026-06-09.

---

## 1. Resumen

Reorientar Nightfall Survivors al modelo del documento MVP "RPG Survival Action inspirado en
Undead Slayer": combate **100% automático** (el jugador solo controla el movimiento), progresión
intra-partida por niveles, jefes, equipamiento con stats y progresión permanente.

**Hallazgo clave:** el juego actual ya implementa casi todo el doc, e incluso de más. Esto NO es
construir un MVP desde cero. Son dos cambios núcleo más una alineación:

1. **Pivote de combate** — activo (disparo manual + Nova/Dash/skills por input) → 100% auto.
2. **Equipamiento con stats** (§8 del doc) — único sistema realmente ausente.
3. **Alineación menor** — pantalla de recompensas fin-partida, taxonomía de enemigos, conservar
   extras ya hechos.

El juego vive en `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`
(repo git propio). Los specs/planes viven en `godot-claude-mcp/docs/superpowers/`.

### Decisiones de diseño (2026-06-13)

- **Reemplazo total:** el doc Undead Slayer manda. Combate 100% auto. Brotato archivado.
- **Conservar 6 clases:** guerrero/paladin/arquero/asesino/mago/nigromante. Cada clase = loadout
  inicial distinto (arma + skills auto). El doc habla de "un personaje"; lo interpretamos como
  loadouts, no como borrar contenido.
- **Skills activas → auto-cast en cooldown:** Nova, Dash y skills de clase se lanzan solas. No
  hay input de combate, solo movimiento.
- **Equipamiento con stats: construir.** Es core del doc.
- **Conservar extras existentes** (pase de temporada, misiones diarias, skins). El doc es piso, no
  techo. No destruir trabajo funcional. *(Revisado 2026-06-13b: ver abajo — el sistema de oleadas,
  tienda y almas SÍ se quitan.)*

---

## 1c. Revisión 2026-06-13c — Equipamiento + inventario + gacha de cofres

Amplía el §8 (equipamiento) y adelanta monetización (antes en backlog §15) como **gacha con stub
de pago real**. Decisiones del usuario (2026-06-13c):

### Equipamiento (`scripts/equipamiento.gd`, `class_name Equipamiento`)
- **5 slots compartidos:** arma, casco, armadura, botas, anillo.
- **5 rarezas:** Común(1 afijo, x1.0) · Rara(2, x1.3) · Épica(3, x1.7) · Legendaria(4, x2.2) ·
  Mítica(5, x3.0). Reusa la escala de `_rareza_aleatoria` existente.
- **Pieza:** `{slot, rareza, afinidad_clase, afijos: {stat: valor}}`. Afijos suman a `HojaStats`
  (dano_pct, vida_max, critico_pct, vel_ataque_pct, armadura, velocidad_pct, robo_vida…).
- **Afinidad de clase:** cada pieza rolea afinidad (una de las 6 clases o "ninguna"). Equipada en la
  clase coincidente → **+25%** a sus afijos. Slots compartidos, sin bloqueo duro por clase.
- `HojaStats.aplicar_equipo(piezas: Array, clase: String)` recalcula al equipar/desequipar. Orden:
  base clase → talentos → equipo → mejoras de partida.

### Monedas
- `oro` (ganado jugando; ya existe en `game_state`).
- `gemas` (premium). `game_state`: añadir `gemas := 0` + persistencia.
- **Stub de pago real:** "comprar gemas" acredita gemas SIMULADAS (sin billing). Google Play Billing
  real = tarea de plataforma futura (no posible en build offline ahora).

### Gacha de cofres (2 tipos)
- **Cofre Común** (precio en **oro**) — odds: Común 60 / Rara 28 / Épica 9 / Legendaria 2.5 / Mítica 0.5.
- **Cofre Premium** (precio en **gemas**) — odds: Común 25 / Rara 35 / Épica 25 / Legendaria 12 / Mítica 3.
- Abrir → gasta moneda → rolea rareza (odds del cofre) → genera pieza (slot + afijos escalados por
  rareza + afinidad) → al inventario → muestra resultado.

### Inventario (`scripts/menu_inventario.gd`)
- Guarda TODAS las piezas (equipadas + en mochila). Persistido en `game_state`
  (`inventario: Array`, `equipado: Dictionary` slot→pieza).
- Equipar/desequipar (recalcula `HojaStats`), con comparativa de stats.
- **Vender** pieza no deseada → **oro** por rareza: Común 10 / Rara 30 / Épica 80 / Legendaria 200 /
  Mítica 500.

### Capas
- **EQ1** — modelo `equipamiento.gd` + `HojaStats.aplicar_equipo` + afinidad (testeable headless).
- **EQ2** — inventario + equipar/desequipar + **vender por oro** + UI `menu_inventario`.
- **EQ3** — monedas (`gemas`) + tabla de odds de gacha + generación de pieza por cofre.
- **EQ4** — tienda de cofres (Común=oro / Premium=gemas) + apertura + stub "comprar gemas".

*(Supersede la nota de §10/§15 que dejaba la monetización fuera: el gacha entra ahora con stub de
pago; el billing real sigue siendo trabajo de plataforma futuro.)*

---

## 1b. Revisión 2026-06-13b — Estructura de niveles (SUPERSEDE el sistema de oleadas)

Decisión del usuario: abandonar el loop de oleadas (heredado de Brotato) y adoptar la estructura
de **niveles/stages estilo Undead Slayer**.

### Estructura de partida
- **60 niveles** con progresión secuencial. Cada nivel se define en una tabla data-driven `NIVELES`:
  `{nombre, tema, mezcla_enemigos, jefe, escala_dificultad, umbrales_estrellas}`. Reusa
  `TEMAS_MAPA` + `_crear_entorno()` para variar paleta/entorno (no son 60 escenas hand-crafted; son
  60 configs distintas sobre el generador procedural, ampliables con arte bespoke luego).
- **Cada nivel tiene NOMBRE** (ej. por acto/bioma: "Bosque Maldito", "Cripta de Ceniza", …).
- **Selección de nivel** (reemplaza el selector de mapa de `menu_seleccion`): grid de 60 niveles con
  desbloqueo secuencial — completar el nivel N desbloquea N+1. Muestra estrellas obtenidas por nivel.
- **Dentro del nivel:** spawn **continuo** de enemigos (SIN timer de oleada, SIN tienda, SIN respiro
  entre oleadas). Tras un periodo de combate aparece el **jefe del nivel**. **Matar al jefe =
  nivel completado** → pantalla de recompensa → desbloquea el siguiente.
- **XP/mejoras:** los orbes dan SOLO XP. Al llenar la barra → **PAUSA + 3 cards aleatorias**
  (`menu_mejoras`, ya existe). Sin moneda de almas.

### Calificación por estrellas (1-3) según tiempo
- Al completar un nivel (matar al jefe), se otorgan **1, 2 o 3 estrellas según el tiempo total**
  de la partida: más rápido = más estrellas. Cada nivel define `umbrales_estrellas` (p. ej.
  `{3: 120s, 2: 180s}`; por debajo de 120 s = 3★, por debajo de 180 s = 2★, resto = 1★). Los
  umbrales se relajan en niveles más difíciles.
- Se persiste la **mejor calificación por nivel** en `game_state` (`estrellas_nivel: {indice: 0-3}`).
  La UI de selección muestra las estrellas. Suma de estrellas = métrica de maestría (futuro: premios).

### Escalado de dificultad y monstruos por nivel
- La dificultad **crece con el número de nivel**: `escala_dificultad` aumenta de forma monótona
  (p. ej. `1.0 + indice * k`). Escala vida y daño de enemigos (el daño a la mitad del ritmo que la
  vida, igual que `enemigo.configurar(tipo, escala)` ya hace), ritmo/cantidad de spawn, y la
  vida/daño del jefe del nivel.
- La **mezcla de enemigos** se endurece por nivel: niveles tempranos = tipos básicos; niveles
  avanzados introducen tipos rápidos/tanque/élite y jefes más duros. Cada nivel define qué tipos
  aparecen y en qué proporción.

### Qué se QUITA (supersede secciones que asumían oleadas)
- Sistema de oleadas en `main.gd`: `oleada`, `_timer_oleada`, `_entre_oleadas`, `_mult_oleada`,
  `_enemigos_oleada`, `_control_oleadas`, `_siguiente_oleada`, `_terminar_oleada`,
  `_flujo_post_oleada`, `_lanzar_oleada`, `JEFES_OLEADA`/ciclo de jefe-cada-5.
- Tienda de oleada: `scripts/tienda_oleada.gd`, `scripts/menu_tienda.gd`, `scripts/menu_stats.gd`
  (selección Brotato 1-de-4 post-oleada).
- Almas como moneda dentro de la run: `gema_xp.gd` vuelve a ser orbe de **XP puro** (sin
  `sumar_almas`/moneda de run). El **oro meta** (entre partidas, árbol de talentos) se conserva.
- Fases de noche: `FASES`, `fase_noche`, `_activar_fase`.
- Reliquias estilo Brotato por jefe, si interfieren con el flujo de niveles.

### Qué se CONSERVA
- Oro meta + árbol de talentos permanente (entre niveles), 6 clases, combate auto (Capa 0),
  equipamiento (capa futura), los jefes existentes (mapeados como jefes de nivel), pase/misiones/skins.

### Orden de implementación (revisado)
- **Capa N1 — Limpieza:** quitar oleadas/tienda/almas/fases de `main.gd`; borrar scripts Brotato;
  `gema_xp` → XP puro; spawn continuo simple (un solo flujo, sin oleadas). El juego debe seguir
  jugándose (spawn continuo + level-up cards) tras esta capa.
- **Capa N2 — Loop de nivel:** spawn continuo → aparición del jefe tras periodo → matar jefe =
  nivel completado → pantalla de recompensa → desbloqueo del siguiente.
- **Capa N3 — Level-up pausa + 3 cards:** garantizar que `menu_mejoras` pausa y aparece al subir
  nivel (clásico survivors).
- **Capa N4 — Estrellas por tiempo:** calificación 1-3★ al completar, umbrales por nivel,
  persistencia `estrellas_nivel`, mostrar en UI.
- **Capa N5 — 60 niveles + selección:** tabla `NIVELES` (nombres, temas, mezcla, jefe, escalado,
  umbrales), menú de selección de 60 niveles con desbloqueo y estrellas.

Estas capas N1-N5 reemplazan el rol que tenían las "capas 3/loop+tienda" del rework Brotato.

---

## 2. Estado actual mapeado al doc

| Doc § | Sistema | Estado | Acción |
|---|---|---|---|
| 3 Stats | `scripts/stats.gd` (`HojaStats`, 13 stats) | ✓ excede doc | conservar; añadir `aplicar_equipo()` |
| 4 Enemigos | `scripts/enemigo.gd` (8 tipos + 3 jefes + elites) | ✓ excede doc | documentar taxonomía doc (mapeo) |
| 5 XP/level-up | `scripts/gema_xp.gd` + `scripts/menu_mejoras.gd` | ✓ | conservar |
| 6 Habilidades | 6 clases (`arma_*`) + Nova + skills + veneno/congelar/quemar | ✓ excede doc | volver auto-cast |
| 7 Cartas mejora | `scripts/menu_mejoras.gd` | ✓ | conservar |
| **8 Equipamiento** | `scripts/equipo.gd` = **solo cosmético** | ❌ **ausente** | **construir sistema con stats** |
| 9 Recompensas | `game_state.gd` stats + oro | ◑ parcial | añadir pantalla fin-partida |
| 10 Árbol permanente | `game_state.gd` talentos (5, costo exponencial) | ✓ | conservar |
| 11 Mapas | `game_state.gd` MAPAS (bosque + 3) | ✓ excede doc | conservar |
| 12 Jefe | 3 jefes (golpe/área/invocación ya implementados) | ✓ excede doc | conservar |
| 13 UI | menús principal/seleccion/mejoras/pausa/stats/tienda/ajustes/misiones | ✓ | añadir inventario |
| 14 Guardado JSON | `game_state.gd` (`user://nightfall_save.json`) | ✓ | extender con equipo |
| 15 Monetización | — | backlog | no implementar |
| 16 Métricas | `game_state.gd` stats (kills/jefes/partidas/...) | ◑ | instrumentación ya base |

`equipo.gd` confirmado puramente visual: cuelga armas/cascos procedurales del brazo según clase
(`equipar()`, `adornar_enemigo()`). No toca stats. El equipamiento del doc es nuevo.

---

## 3. Cambio A — Pivote de combate a 100% auto

### Estado actual (`scripts/jugador.gd`, 1094 líneas)

- Cabecera declara: "juego activo — disparo manual (clic), Nova (Q) y Dash (Espacio)".
- 6 clases en `ATAQUES`: cada una con `tipo`, `cadencia`, `dano`, `por_nivel`, parámetros de arma.
- `_physics_process` (~línea 388): `quiere_atacar = Input.is_mouse_button_pressed(LEFT) or modo_tactil`;
  dispara si `_cd_disparo <= 0`. Nova en `habilidad_nova`, Dash en `habilidad_dash` (just_pressed).
- Apuntado (~línea 437, ~753): dirección hacia `get_viewport().get_mouse_position()`.
- Cooldowns expuestos a HUD vía señal `cooldowns_cambiados(nova, dash, hab1, hab2)`.

### Cambios

1. **Auto-apuntado.** Nuevo helper `_objetivo_auto() -> Node3D`: barre `get_tree().get_nodes_in_group("enemigos")`,
   elige el de menor distancia al jugador. Si no hay enemigos, devuelve `null`.
2. **Disparo automático.** Sustituir el gatillo por input. En cada frame, si `_cd_disparo <= 0` y
   `_objetivo_auto()` existe, atacar hacia el objetivo. La dirección de `_atacar()`/`_disparar()`
   pasa de "hacia ratón" a "hacia objetivo". Si no hay objetivo, no dispara (ahorra proyectiles).
3. **Nova → auto-cast.** Al cumplir `_cd_nova`, lanzar sola. Heurística de objetivo: centroide del
   cúmulo de enemigos más denso a rango, o el más cercano si hay pocos.
4. **Dash → auto-cast defensivo.** Lanzar al cumplir `_cd_dash` **solo** si hay amenaza: enemigo
   dentro de un radio corto (p. ej. `radio_golpe + margen`) o vida < umbral. Dirección: alejándose
   del enemigo más cercano (o hueco más seguro). No malgastar en CD si no hay peligro.
5. **Skills activas de clase → auto-cast.** Las skills `"tipo": "activa"` (p. ej. `tormenta_dagas`)
   se lanzan al cumplir su CD apuntando al más cercano/área.
6. **Limpieza de input.** Quitar lectura de `MOUSE_BUTTON_LEFT`, `habilidad_nova`, `habilidad_dash`
   como gatillos de combate. Conservar solo movimiento (`mover_*` + joystick táctil). Mantener pausa.
7. **HUD.** Cooldowns siguen mostrándose (informativos), pero quitar prompts de "mantén clic para
   atacar" / indicador de apuntado manual si existen. La señal `cooldowns_cambiados` se conserva.

### Riesgos / gotchas

- `jugador.gd` es grande (1094 líneas). El pivote toca `_physics_process`, `_atacar`, `_disparar`,
  Nova, Dash. Cambios localizados; no reescribir el archivo.
- `modo_tactil` ya existía como gatillo alterno — al volver auto, el joystick táctil queda solo para
  mover. Verificar que `controles_tactiles.gd` no asuma botón de ataque.
- Equilibrio: sin input el jugador no puede "guardar" Nova/Dash para el momento clave. Las
  heurísticas (Dash solo bajo amenaza, Nova al cúmulo) compensan. Ajustar umbrales en playtest.

---

## 4. Cambio B — Equipamiento con stats (§8)

### Modelo de datos

Nuevo `scripts/equipamiento.gd` (`class_name Equipamiento`, extends `RefCounted`):

- **Slots:** `arma`, `casco`, `armadura`, `botas`, `anillo`.
- **Rarezas:** `comun`, `poco_comun`, `raro`, `epico`, `legendario` — cada una define cuántos
  afijos de stat lleva la pieza y su magnitud (multiplicador de rolls). Reusar la curva/sesgo de
  rareza ya presente en `scripts/tienda_oleada.gd`.
- **Pieza** (Dictionary o sub-recurso): `{slot, rareza, nombre, stats: {clave: valor}}` donde
  `clave` mapea a campos de `HojaStats` (`dano_pct`, `vida_max`, `critico_pct`, `vel_ataque_pct`,
  `armadura`, `velocidad_pct`, …). El doc pide stats: Daño, Vida, Crítico, Velocidad — superconjunto
  permitido.

### Integración con stats

- Nuevo método `HojaStats.aplicar_equipo(piezas: Array) -> void`: parte de los valores base de la
  clase y **suma** los afijos de todas las piezas equipadas. Se recalcula al equipar/desequipar.
- La hoja sigue siendo fuente única de verdad. El equipo es una capa aditiva sobre la base de clase
  + talentos + mejoras de partida. Orden de aplicación: **base clase → talentos (meta) → equipo
  (meta) → mejoras de partida (cartas)**.

### Drops

- Enemigos **elite** y **jefes** sueltan una pieza al morir (señal/hook en `enemigo.gd` `murio` o en
  el orquestador `main.gd` que ya escucha muertes). Rareza sesgada por `HojaStats.suerte`
  (reusa lógica de sesgo de cofres/tienda).
- Enemigos básicos: no sueltan equipo (solo orbes XP) para no inundar. Posible drop raro de baja
  rareza con probabilidad baja (ajustable).

### Persistencia

- `game_state.gd`: añadir `inventario: Array` (piezas no equipadas) y `equipado: Dictionary`
  (slot → pieza). Incluir en `guardar()`/`cargar()` del JSON existente. Migración: ausencia de las
  claves → inventario vacío y todos los slots vacíos.

### UI

- Nuevo `scripts/menu_inventario.gd` (+ entrada en pantalla principal §13, "Inventario"): grid de 5
  slots equipados + lista de inventario. Al seleccionar pieza: comparativa de stats (delta vs.
  equipada actual). Equipar/desequipar recalcula `HojaStats.aplicar_equipo`.
- Reusar `scripts/ui_estilo.gd` para coherencia visual.

---

## 5. Cambio C — Alineación menor

### Pantalla de recompensas fin-partida (§9)

- Al terminar partida (muerte o victoria), mostrar pantalla de recompensas: oro ganado, equipo
  dropeado conservado, XP de cuenta. Cálculo por **tiempo sobrevivido + jefes derrotados + nivel
  alcanzado** (datos ya en `game_state.stats`). Ampliar el menú de muerte/fin existente, no crear
  flujo nuevo.
- **Materiales:** el doc §9 los menciona como recompensa. Fuera de alcance del MVP — no hay sistema
  de crafteo que los consuma. Si más adelante se añade crafteo, los materiales entran ahí. Por ahora
  las recompensas son oro + equipo + XP de cuenta.

### Taxonomía de enemigos (§4)

- El doc nombra básico/rápido/tanque/elite/jefe. Los 8 tipos actuales ya cubren esos roles
  (zombie/esqueleto=básico, arana_gigante=rápido, caballero_oscuro/demonio_menor=tanque, sistema
  elite ya existe, 3 jefes). **Documentar el mapeo** (comentario/tabla), no renombrar ni borrar.

### Extras conservados

- Pase de temporada, misiones diarias, skins, mapas extra: **no tocar**. Funcionan y son contenido
  extra sobre el MVP. El doc los lista en backlog Fase 2 como objetivos; aquí ya existen.

---

## 6. Arquitectura / límites

- `HojaStats` (`stats.gd`): fuente única de stats efectivos. Nuevo input: equipo.
- `jugador.gd`: consume `HojaStats`, ahora con combate auto. Sin input de combate.
- `equipamiento.gd`: modelo puro de datos (sin nodos). Genera/rolea piezas, calcula afijos.
- `game_state.gd` (autoload `Estado`): persistencia meta (oro, talentos, **inventario+equipado**,
  pase, misiones, skins, mapas, stats).
- `menu_inventario.gd`: vista; lee/escribe `Estado` y recalcula `HojaStats`.
- `enemigo.gd` / `main.gd`: drops de equipo en muerte de elite/jefe.

Cada unidad: propósito único, comunicada por interfaces claras (señales / métodos de `HojaStats` y
`Estado`). `equipamiento.gd` testeable aislado (datos puros).

---

## 7. Orden de implementación (capas → planes)

1. **Capa 0 — Pivote combate auto** (Cambio A, sin Nova/Dash/skills). Disparo auto al más cercano.
   Núcleo; todo lo demás asume combate auto.
2. **Capa 1 — Auto-cast** de Nova, Dash y skills de clase (Cambio A 3-5).
3. **Capa 2 — Equipamiento: modelo + stats** (`equipamiento.gd`, `HojaStats.aplicar_equipo`,
   persistencia). Sin UI todavía; testeable headless.
4. **Capa 3 — Drops + UI inventario** (drops en elite/jefe, `menu_inventario.gd`, entrada en
   pantalla principal).
5. **Capa 4 — Recompensas fin-partida + alineación** (Cambio C).

Cada capa: su propio plan vía writing-plans, implementación, test, commit.

---

## 8. Testing

- Patrón existente: escenas headless `tools/test_*.tscn` (ya hay test_stats, test_almas, test_loop,
  test_enemigos, test_jefes, test_habilidades, …).
- **Nuevos:**
  - `tools/test_combate_auto.tscn`: spawnea enemigos, verifica que el jugador (sin input) auto-apunta
    y los mata; verifica que Dash solo se dispara bajo amenaza y Nova al cúmulo.
  - `tools/test_equipo.tscn`: equipar/desequipar piezas suma/resta correctamente en `HojaStats`;
    persistencia round-trip (guardar→cargar) conserva inventario+equipado; rareza sesgada por suerte.
- **Gotchas de testeo** (de la memoria de proyecto, verificar siguen vigentes):
  - Lanzar el juego por **CLI** (`Godot_console.exe --path <proy> <escena>`), no por
    `godot_run_scene` (muere silencioso ~2s tras iniciar partida).
  - `input_sequence` con clicks no alcanza botones de menús pausados → usar `runtime_eval` o despausar.
  - `--check-only --script` no resuelve `class_name` recién creados → usar `const X := preload(...)`.
  - Binario: `C:\Users\braya\Downloads\Godot_v4.6.3-stable_win64_console.exe`.

---

## 9. Métricas de éxito (§16 del doc)

- Sesión promedio > 10 min · Retención D1 > 30% · D7 > 10% · 80% completan una partida.
- Instrumentación base ya en `game_state.stats`. Validación de retención queda fuera del alcance de
  código (requiere telemetría/usuarios); el MVP debe dejar el ciclo divertido y medible.

---

## 10. Fuera de alcance (backlog Fase 2)

Multijugador, PvP, clanes, mascotas, gremios, eventos temporales, gacha avanzado, pase de batalla
(el pase de temporada actual es simple y se conserva), rankings globales, monetización.
