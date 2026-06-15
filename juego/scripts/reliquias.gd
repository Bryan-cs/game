class_name Reliquias
## Catálogo estático de Reliquias de Run (máx 3 activas por partida).

const CATALOGO: Dictionary = {
	"sangre_fria": {
		"nombre": "Sangre Fría",
		"desc": "Los críticos recuperan 3% de vida máxima",
		"tipo": "Ofensiva",
		"color": Color(0.95, 0.3, 0.3),
	},
	"rabia_acumulada": {
		"nombre": "Rabia Acumulada",
		"desc": "+2% daño por kill sin recibir golpe (máx +40%). Reset al recibir daño",
		"tipo": "Ofensiva",
		"color": Color(0.9, 0.45, 0.15),
	},
	"ojo_depredador": {
		"nombre": "Ojo Depredador",
		"desc": "Enemigos bajo 30% de vida reciben el doble de daño",
		"tipo": "Ofensiva",
		"color": Color(0.7, 0.25, 0.1),
	},
	"piel_de_piedra": {
		"nombre": "Piel de Piedra",
		"desc": "Cada 8 s ganas un escudo igual al 20% de tu vida máxima",
		"tipo": "Defensiva",
		"color": Color(0.6, 0.65, 0.7),
	},
	"ultimo_aliento": {
		"nombre": "Último Aliento",
		"desc": "Una vez por run, sobrevives a un golpe letal con 1 PV",
		"tipo": "Defensiva",
		"color": Color(0.9, 0.9, 0.4),
	},
	"codicia_infernal": {
		"nombre": "Codicia Infernal",
		"desc": "Oro ganado ×2, pero recibes 20% más daño",
		"tipo": "Riesgo",
		"color": Color(1.0, 0.75, 0.1),
	},
	"pacto_corrupto": {
		"nombre": "Pacto Corrupto",
		"desc": "+60% daño total. Cada kill suma +1 corrupción",
		"tipo": "Riesgo",
		"color": Color(0.7, 0.2, 0.95),
	},
	"corazon_vacio": {
		"nombre": "Corazón Vacío",
		"desc": "Al matar un jefe: recuperas 50% de vida y +30% velocidad por 15 s",
		"tipo": "Sinergia",
		"color": Color(0.3, 0.8, 0.55),
	},
	"agujon_venenoso": {
		"nombre": "Aguijón Venenoso",
		"desc": "30% de probabilidad de envenenar al atacar (5 daño/s durante 3 s)",
		"tipo": "Sinergia",
		"color": Color(0.4, 0.85, 0.2),
	},
	"sello_elite": {
		"nombre": "Sello Élite",
		"desc": "Al matar un élite, tu siguiente ataque es un crítico ×2 garantizado",
		"tipo": "Sinergia",
		"color": Color(0.6, 0.5, 1.0),
	},
}

static func ids_disponibles(excluir: Array) -> Array:
	var lista: Array = []
	for id in CATALOGO:
		if id not in excluir:
			lista.append(id)
	return lista
