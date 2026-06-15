class_name ArbolTalentos
## Catálogo estático del Árbol de Habilidades Híbrido.
## Rama global (aplica a todas las runs) + rama por clase (solo a su clase).
## stat: nombre del campo en HojaStats o del jugador que se afecta.
## costo: libros de talento por nivel (acumulativo, no total).

const NODOS_GLOBAL := [
	{
		"id": "vida_global",
		"nombre": "Vitalidad Profunda",
		"desc": "+8% vida máxima por nivel",
		"max": 3, "costos": [1, 2, 3],
		"stat": "vida_max_pct", "valor_por_nivel": 8.0,
	},
	{
		"id": "oro_global",
		"nombre": "Codicia Templada",
		"desc": "+10% oro ganado por nivel",
		"max": 3, "costos": [1, 2, 2],
		"stat": "oro_pct", "valor_por_nivel": 10.0,
	},
	{
		"id": "suerte_global",
		"nombre": "Toque de Suerte",
		"desc": "+15 suerte (mejores rarezas de cofre)",
		"max": 2, "costos": [2, 3],
		"stat": "suerte", "valor_por_nivel": 15.0,
	},
	{
		"id": "curacion_global",
		"nombre": "Resiliencia",
		"desc": "+20% curación recibida por nivel",
		"max": 2, "costos": [2, 3],
		"stat": "curacion_pct", "valor_por_nivel": 20.0,
	},
	{
		"id": "xp_global",
		"nombre": "Mente Ávida",
		"desc": "+10% experiencia ganada por nivel",
		"max": 2, "costos": [1, 2],
		"stat": "xp_pct", "valor_por_nivel": 10.0,
	},
	{
		"id": "radio_global",
		"nombre": "Campo Imantado",
		"desc": "+20% radio de recolección por nivel",
		"max": 2, "costos": [1, 2],
		"stat": "radio_iman_pct", "valor_por_nivel": 20.0,
	},
]

const NODOS_CLASE := {
	"guerrero": [
		{
			"id": "gue_aguante", "nombre": "Aguante Brutal",
			"desc": "+12% vida máxima", "max": 3, "costos": [1, 2, 3],
			"stat": "vida_max_pct", "valor_por_nivel": 12.0,
		},
		{
			"id": "gue_furia", "nombre": "Furia Melee",
			"desc": "+12% daño cuerpo a cuerpo", "max": 3, "costos": [1, 2, 3],
			"stat": "melee_pct", "valor_por_nivel": 12.0,
		},
		{
			"id": "gue_armadura", "nombre": "Piel de Acero",
			"desc": "+8 armadura por nivel", "max": 2, "costos": [2, 3],
			"stat": "armadura", "valor_por_nivel": 8.0,
		},
	],
	"arquero": [
		{
			"id": "arq_cadencia", "nombre": "Dedos Veloces",
			"desc": "+12% velocidad de ataque", "max": 3, "costos": [1, 2, 3],
			"stat": "vel_ataque_pct", "valor_por_nivel": 12.0,
		},
		{
			"id": "arq_critico", "nombre": "Ojo de Halcón",
			"desc": "+5% probabilidad de crítico", "max": 3, "costos": [1, 2, 3],
			"stat": "critico_pct", "valor_por_nivel": 5.0,
		},
		{
			"id": "arq_penetracion", "nombre": "Flecha Penetrante",
			"desc": "+12% daño a distancia", "max": 2, "costos": [2, 3],
			"stat": "distancia_pct", "valor_por_nivel": 12.0,
		},
	],
	"mago": [
		{
			"id": "mag_potencia", "nombre": "Potencia Arcana",
			"desc": "+15% daño global", "max": 3, "costos": [1, 2, 3],
			"stat": "dano_pct", "valor_por_nivel": 15.0,
		},
		{
			"id": "mag_sabiduria", "nombre": "Sabiduría Antigua",
			"desc": "+12% experiencia ganada", "max": 2, "costos": [1, 2],
			"stat": "xp_pct", "valor_por_nivel": 12.0,
		},
		{
			"id": "mag_critico", "nombre": "Resonancia Mágica",
			"desc": "+6% probabilidad de crítico", "max": 2, "costos": [2, 3],
			"stat": "critico_pct", "valor_por_nivel": 6.0,
		},
	],
	"nigromante": [
		{
			"id": "nec_regen", "nombre": "Lazos Eternos",
			"desc": "+0.8 regeneración de vida por segundo", "max": 3, "costos": [1, 2, 3],
			"stat": "regen", "valor_por_nivel": 0.8,
		},
		{
			"id": "nec_fuerza", "nombre": "Huestes de Sombra",
			"desc": "+10% daño global", "max": 3, "costos": [1, 2, 3],
			"stat": "dano_pct", "valor_por_nivel": 10.0,
		},
		{
			"id": "nec_cosecha", "nombre": "Cosecha Oscura",
			"desc": "+10% radio de recolección", "max": 2, "costos": [1, 2],
			"stat": "radio_iman_pct", "valor_por_nivel": 10.0,
		},
	],
	"asesino": [
		{
			"id": "ase_critico", "nombre": "Instinto Asesino",
			"desc": "+7% probabilidad de crítico", "max": 3, "costos": [1, 2, 3],
			"stat": "critico_pct", "valor_por_nivel": 7.0,
		},
		{
			"id": "ase_distancia", "nombre": "Golpe Mortal",
			"desc": "+15% daño a distancia", "max": 3, "costos": [1, 2, 3],
			"stat": "distancia_pct", "valor_por_nivel": 15.0,
		},
		{
			"id": "ase_esquiva", "nombre": "Sombra Evasiva",
			"desc": "+8% probabilidad de esquiva", "max": 2, "costos": [2, 3],
			"stat": "esquiva_pct", "valor_por_nivel": 8.0,
		},
	],
	"paladin": [
		{
			"id": "pal_armadura", "nombre": "Fortaleza Sagrada",
			"desc": "+10 armadura por nivel", "max": 3, "costos": [1, 2, 3],
			"stat": "armadura", "valor_por_nivel": 10.0,
		},
		{
			"id": "pal_regen", "nombre": "Gracia Divina",
			"desc": "+1.2 regeneración de vida por segundo", "max": 3, "costos": [1, 2, 3],
			"stat": "regen", "valor_por_nivel": 1.2,
		},
		{
			"id": "pal_vida", "nombre": "Escudo de Fe",
			"desc": "+8% vida máxima", "max": 2, "costos": [2, 3],
			"stat": "vida_max_pct", "valor_por_nivel": 8.0,
		},
	],
}


static func nodo_por_id(id: String) -> Dictionary:
	for n in NODOS_GLOBAL:
		if n.id == id:
			return n
	for clase in NODOS_CLASE:
		for n in NODOS_CLASE[clase]:
			if n.id == id:
				return n
	return {}
