# Rework Brotato — Nightfall Survivors

**Fecha:** 2026-06-11
**Estado:** aprobado por el usuario (diseño validado sección por sección)
**Proyecto Godot:** `C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego`

## Objetivo

Que la experiencia de run (progresión, jugabilidad, supervivencia) se sienta como Brotato, conservando el toque propio: clases únicas con combate ACTIVO (arma manual + dash + habilidades E/R) y jefes con mecánicas.

## Decisiones tomadas (con el usuario)

| Decisión | Elección |
|---|---|
| Estructura de oleadas | Brotato puro: timer fijo, tienda entre oleadas |
| Economía de run | Material único (almas) = XP + dinero de tienda |
| Sistema de stats | Hoja completa de 13 stats |
| Combate | Activo conservado: arma manual de clase + dash + E/R; 6 slots de armas automáticas de tienda |
| Sistemas conservados | Solo eventos dinámicos (como modificadores de oleada anunciados) |
| Sistemas eliminados | Fases de noche, corrupción, reliquias (recicladas como ítems), Nova Q, menú de mejoras mid-run, evoluciones por nivel |
| Habilidades de clase | Ítems exclusivos en tienda (comprar de nuevo = subir nivel, máx 5) |
| Estrategia | Rework incremental por capas (juego jugable tras cada capa) |

## 1. Loop de run

- Run = **15 oleadas** + victoria. Jefes en 5/10/15. Modo infinito tras ganar (jefes dobles cada 5 oleadas desde la 20) se conserva.
- Oleada normal: timer `20 + 2.5·N` s (tope 60 s). Timer grande arriba-centro.
- Spawn continuo: presupuesto de enemigos por oleada repartido en el tiempo (spawner actual adaptado). Élites: % creciente desde oleada 6.
- Fin de oleada: enemigos vivos se disuelven (efecto), almas del suelo vuelan al jugador, se abre flujo post-oleada: **stats por nivel ganado → tienda → botón "OLEADA N+1"**. Sin presión de tiempo en tienda.
- **Oleadas de jefe sin timer**: terminan al matar al jefe. Mecánicas de jefes intactas (slam telegrafiado, teleport+esbirros, orbes de vacío, ataque a distancia).
- **Modificadores de oleada** (eventos reciclados): ~1 de cada 3 oleadas; se anuncian AL SALIR de la tienda, antes de empezar la oleada. Lluvia de Sangre, Invasión Élite, Eclipse, Altar Maldito (rebalanceado: ítem gratis a cambio de 30% de la vida actual).
- Muerte = fin de run, sin revivir. Almas restantes → oro meta 1:1 (igual que en victoria).
- **Arena: radio 38** (antes 76) en todos los mapas. Densidad alta: esquivar > viajar.
- Ritmo objetivo: run de 18–25 min.
- Escalado de dificultad: solo por Nº de oleada (vida +12%, daño +6% por oleada, ya existente). Se elimina el reloj global `1 + tiempo/150`.

## 2. Economía y tienda

### Almas (material único)
- Cada enemigo suelta almas (sustituye gemas XP + oro de run). Recogerla = +XP y +1 alma a la vez. Imán igual que hoy. Tope de drops en suelo y fusión (sistema actual de gemas se hereda).
- Subir de nivel NO pausa la oleada. Niveles acumulados se resuelven al final de la oleada: **1 elección de stat (de 4 opciones) por nivel ganado**.
- Curva XP: se parte de la actual (`14 + 10·(nivel−1)`), se rebalancea en pruebas.

### Tienda (entre oleadas)
- 4 ofertas: armas + ítems + habilidades de clase (exclusivas, borde dorado, garantizadas en primeras tiendas).
- Rarezas común/rara/épica/legendaria; pesos mejoran con Nº de oleada y stat Suerte.
- **Reroll** (precio base sube con la oleada y por cada uso en la misma tienda) + **candado** (reserva una oferta para la siguiente tienda) + **vender** al 50%.
- UI con `EstiloUI` gótico existente. Funciona táctil sin trabajo extra.

### Armas: 6 slots y fusión de tiers
- Comprar arma = ocupa 1 de 6 slots. Armas de slot son automáticas (espada orbital, arco, bola de fuego, cadena eléctrica, dagas fantasma, martillo sísmico — las 6 existentes).
- **Dos armas iguales del mismo tier = fusión a tier+1** (tiers 1–4). Sustituye la evolución por nivel 5: la evolución actual de cada arma es su forma tier 4 (Tormenta de Cuchillas = Espada tier 4, etc.).
- Sinergias actuales (Hojas Ígneas, Flechas Explosivas, Tormenta de Plasma, Eco de Forja) se conservan como bonus por combinación de armas equipadas.
- El arma manual de clase NO ocupa slot y no se compra: es fija.

### Ítems
- Pool inicial ~25: las 8 reliquias recicladas (Sangre Hirviente, Corazón del Gigante, etc.) + nuevos basados en la hoja de stats, con maluses (suben unos stats, bajan otros).
- Exclusivos de clase: árbol Warlord simplificado — Rey de la Masacre = ítem legendario exclusivo del Guerrero (tienda oleada 10+, caro, overlay carmesí intacto); Hoja Gigante / Corazón de Hierro / Sed de Batalla = ítems épicos exclusivos del Guerrero. Patrón replicable a otras clases en el futuro.

### Jefes y cofres
- Jefe muerto suelta cofre: en la siguiente tienda, **1 ítem gratis a elegir de 3** (rareza alta, sesgo por Suerte).

## 3. Stats y clases

### Hoja de 13 stats
| Stat | Efecto |
|---|---|
| Vida Máx | — |
| Regeneración | HP/s |
| Robo de vida % | del daño infligido |
| Daño % | global; también escala habilidades E/R |
| Daño Melee % | armas/ataques melee |
| Daño a Distancia % | armas/ataques a distancia |
| Velocidad de ataque % | cadencia de arma manual + slots |
| Crítico % | x2 daño |
| Armadura | reducción `arm/(arm+15)` |
| Esquiva % | ignora el golpe; tope 60% |
| Velocidad % | movimiento |
| Suerte | rarezas de tienda, drops de cofre |
| Cosecha | +almas pasivas al final de cada oleada |

- Cada arma declara si escala con Melee% o Distancia%.
- Level-up: 4 opciones aleatorias de subida de stat, con magnitudes por rareza (ej. +3% crit común, +8% crit épica).
- Talentos meta actuales (5) se mapean a stats iniciales (+daño%, +velocidad%, +crit%, +vida, +imán→Cosecha).

### Clases (stats iniciales + tradeoff + arma manual fija)
| Clase | Tradeoff | Arma manual |
|---|---|---|
| Guerrero | +20% melee, +15 vida / −20% distancia | Tajo + onda de corte |
| Paladín | +6 armadura, +2 regen / −15% vel. ataque | Martillo con empuje |
| Arquero | +25% distancia, proyectiles +30% vel / −30% melee, −20 vida | Flecha |
| Asesino | +30% crit, +15% velocidad / −40% vida máx | Dagas |
| Mago | +25% daño, E/R −15% CD / −15 vida, 0 armadura | Orbe AoE |
| Nigromante | Caídos se alzan como aliados / −20% daño propio | Proyectil sombra |

- Cada clase conserva 2 activas (E/R) + 2 pasivas, ahora vía tienda.
- Modelos KayKit, animaciones y onda de corte del Guerrero: sin cambios.

## 4. HUD

Timer de oleada central grande · "OLEADA N" · contador de almas · barra XP + nivel · vida · cooldowns E/R + dash · cartel de modificador al iniciar oleada · barra de vida del jefe (en oleadas de jefe, sustituye al timer). Desaparecen: barra de corrupción, contador vivos/total (el fin de oleada ya no depende de matar), reloj global.

## 5. Qué se conserva sin tocar

4 mapas comprables (tema visual; todos arena r=38), misiones diarias, logros, pase de temporada, skins/auras, talentos meta (remapeados a stats), ayudas con respawn durante la oleada (poción/imán/bomba), controles táctiles, audio, pool de efectos/rendimiento, modelos y animaciones.

## 6. Capas de implementación (orden)

1. **Stats**: `scripts/stats.gd` — hoja del jugador; daño/vida/velocidad/crit leen de ahí. Sin cambio visible.
2. **Almas**: drop único reemplaza gemas+oro de run; level-up acumulado sin pausa; conversión a oro meta al final.
3. **Loop**: timer de oleada, despawn al acabar, pantalla post-oleada (stats → tienda), reroll/lock/vender, botón siguiente oleada; jefes sin timer.
4. **Slots y clase**: 6 slots, fusión de tiers, habilidades de clase como ofertas exclusivas, tradeoffs y stats iniciales por clase.
5. **Limpieza**: borrar corrupción/fases de noche/Nova/menú mid-run/reloj global; eventos → modificadores anunciados; cofre de jefe; arena r=38; HUD final.

Verificación por capa: `godot_validate_script` / `--check-only`, prueba en vivo con tools runtime (tuning, screenshot, input simulado), benchmark FPS al cerrar (referencia: 304 FPS prom / 191 mín con 90 enemigos).

## Riesgos

- **Balance desde cero**: precios de tienda, curva de almas, magnitudes de stats — reservar sesión de tuning en vivo (runtime_set_property) tras la capa 4.
- **Misiones/logros** que referencien sistemas borrados (corrupción, oleadas por matar): auditar en capa 5.
- **Arena pequeña + 90 enemigos**: densidad puede saturar móvil; re-benchmark en capa 5.
