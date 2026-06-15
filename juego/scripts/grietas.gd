class_name Grietas
## Sistema de Grietas: progresión macro del juego (10 Grietas × 10 niveles).
## Para añadir Grieta II en adelante, agrega una entrada más al CATALOGO.

const NIVELES_POR_GRIETA := 10

const CATALOGO := [
	{
		"id"         : "grieta_i",
		"nombre"     : "Grieta I",
		"subtitulo"  : "El Umbral Maldito",
		"lore"       : "El primer desgarro en el velo entre mundos.",
		"rasgo"      : "Las sombras más jóvenes  ·  Horda sin piedad",
		"tema"       : "bosque",
		"boss"       : "gigante_putrefacto",
		"boss_nombre": "Gigante Putrefacto",
		"color"      : Color(0.42, 0.88, 0.48),
		"niveles"    : [
			"El Primer Velo",
			"Raíces del Olvido",
			"Claro de los Caídos",
			"Niebla Perpetua",
			"Sendero Sin Retorno",
			"Pantano de Almas",
			"La Arboleda Susurrante",
			"Cripta Superficial",
			"El Umbral Se Abre",
			"Corazón Maldito",
		],
	},
	# Grieta II – X: añadir entradas aquí.
]


## Datos de la Grieta a la que pertenece el nivel, o {} si no está definida.
static func de_nivel(indice_nivel: int) -> Dictionary:
	if indice_nivel < 0:
		return {}
	var idx: int = indice_nivel / NIVELES_POR_GRIETA
	return CATALOGO[idx] if idx < CATALOGO.size() else {}


## Nombre propio del nivel dentro de su Grieta, o "" si no está definido.
static func nombre_nivel(indice_nivel: int) -> String:
	var g: Dictionary = de_nivel(indice_nivel)
	if g.is_empty():
		return ""
	var local: int = indice_nivel % NIVELES_POR_GRIETA
	var lista: Array = g.niveles
	return lista[local] if local < lista.size() else ""


## True si el nivel es el último de su Grieta (combate de jefe de cierre).
static func es_nivel_boss(indice_nivel: int) -> bool:
	if de_nivel(indice_nivel).is_empty():
		return false
	return (indice_nivel % NIVELES_POR_GRIETA) == (NIVELES_POR_GRIETA - 1)


## Total de niveles con contenido de Grieta definido.
static func total_niveles_definidos() -> int:
	return CATALOGO.size() * NIVELES_POR_GRIETA


## Número romano del índice de Grieta (0-indexed → "I", "II", …).
static func romano(idx_grieta: int) -> String:
	const R := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return R[clampi(idx_grieta, 0, R.size() - 1)]
