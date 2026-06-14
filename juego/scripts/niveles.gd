class_name Niveles
extends RefCounted
## Tabla data-driven de los 60 niveles (rework Undead Slayer, capa N5).
## Cada nivel: nombre propio, tema visual (clave de TEMAS_MAPA en main.gd), jefe,
## escala de dificultad/monstruos, segundos hasta el jefe y umbrales de estrellas.

const TOTAL := 60

## 60 nombres únicos, 15 por bioma (bosque, desierto, congelado, abismo).
const NOMBRES := [
	"Bosque Maldito", "Claro de los Ahorcados", "Sendero de Niebla", "Raíces Podridas",
	"Arboleda Susurrante", "Pantano Verde", "Espesura Sombría", "Tocón del Verdugo",
	"Valle de Musgo", "Cripta del Bosque", "Ciénaga Pálida", "Robledal Quebrado",
	"Hondonada Umbría", "Manantial Negro", "Corazón del Bosque",
	"Dunas de Ceniza", "Oasis Reseco", "Cañón Carmesí", "Mar de Arena",
	"Ruinas Enterradas", "Meseta Ardiente", "Tumba de Arena", "Vientos Abrasadores",
	"Espejismo Roto", "Garganta Polvorienta", "Templo Sepultado", "Llanura Calcinada",
	"Cementerio de Caravanas", "Cráter Solar", "Trono de Arena",
	"Reino Congelado", "Glaciar Quebrado", "Tundra Silente", "Cueva de Hielo",
	"Cumbre Helada", "Lago Petrificado", "Bosque Escarchado", "Paso Nevado",
	"Catedral de Hielo", "Abismo Blanco", "Fortaleza Helada", "Ventisca Eterna",
	"Grietas Azules", "Páramo Gélido", "Corona de Escarcha",
	"Abismo Eterno", "Falla del Vacío", "Pozo Sin Fondo", "Catacumbas Violetas",
	"Altar Profano", "Río de Almas", "Puente Quebrado", "Sima Carmesí",
	"Santuario Roto", "Vacío Aullante", "Trono del Vacío", "Umbral Final",
	"Caos Primigenio", "Corazón Tenebroso", "Fin de la Noche",
]

const TEMAS := ["bosque", "desierto", "congelado", "abismo"]
const JEFES := ["gigante_putrefacto", "senor_sombras", "rey_vacio"]


static func nombre(indice: int) -> String:
	if indice >= 0 and indice < NOMBRES.size():
		return NOMBRES[indice]
	return "Nivel %d" % (indice + 1)


static func tema(indice: int) -> String:
	return TEMAS[(indice / 15) % TEMAS.size()]  # 15 niveles por bioma


static func jefe(indice: int) -> String:
	# Progresión de jefe: 0-19 gigante, 20-39 señor de las sombras, 40-59 rey del vacío.
	return JEFES[mini(indice / 20, JEFES.size() - 1)]


static func escala(indice: int) -> float:
	# Dificultad/monstruos crecen de forma monótona con el nivel.
	return 1.0 + indice * 0.10


static func segundos_jefe(indice: int) -> float:
	# Niveles altos exigen sobrevivir un poco más antes del jefe.
	return 50.0 + indice * 2.0


static func umbral_3(indice: int) -> float:
	# 3★ si se completa por debajo de este tiempo (se relaja en niveles altos).
	return segundos_jefe(indice) + 20.0 + indice * 1.5


static func umbral_2(indice: int) -> float:
	return segundos_jefe(indice) + 45.0 + indice * 3.0


static func estrellas_por_tiempo(indice: int, t: float) -> int:
	if t <= umbral_3(indice):
		return 3
	if t <= umbral_2(indice):
		return 2
	return 1
