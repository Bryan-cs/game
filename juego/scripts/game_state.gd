extends Node
## Estado persistente: oro, talentos, ajustes, mapas, skins, pase de temporada,
## misiones diarias y logros (GDD secciones 13, 14, 15, 18 y 19).

signal logro_completado(nombre: String)
signal mision_completada(nombre: String)

const RUTA_GUARDADO := "user://nightfall_save.json"
const EquipamientoScript := preload("res://scripts/equipamiento.gd")

var oro_total := 0
var gemas := 0
var nivel_max_desbloqueado := 0  # índice del nivel más alto desbloqueado (0 = primero)
var estrellas_nivel := {}  # { indice_nivel(int como String en JSON): mejor_estrellas 0-3 }
var inventario: Array = []        # piezas en la mochila (no equipadas)
var equipado: Dictionary = {}     # slot(String) -> pieza(Dictionary)
var ultima_clase := "guerrero"    # última clase jugada (para el preview del inventario)
var talentos := {
	"dano": 0,
	"velocidad": 0,
	"critico": 0,
	"vida": 0,
	"xp": 0,
}
var ajustes := {
	"vol_musica": 1.0,
	"vol_sfx": 1.0,
	"pantalla_completa": false,
	"glow": true,
	"sombras": true,
	"numeros_dano": true,
}

const NOMBRES_TALENTOS := {
	"dano": "Daño",
	"velocidad": "Velocidad",
	"critico": "Prob. Crítica",
	"vida": "Vida Máxima",
	"xp": "Imán de XP",
}

## Cofres de gacha (EQ3). Las odds suman 100; el cofre premium sesga a rarezas altas.
const COFRES := {
	"comun":   {"nombre": "Cofre Común",  "moneda": "oro",   "precio": 150,
		"odds": {"Común": 60.0, "Rara": 28.0, "Épica": 9.0, "Legendaria": 2.5, "Mítica": 0.5}},
	"premium": {"nombre": "Cofre Premium", "moneda": "gemas", "precio": 20,
		"odds": {"Común": 25.0, "Rara": 35.0, "Épica": 25.0, "Legendaria": 12.0, "Mítica": 3.0}},
}

# --- Mapas (sec. 13) ---------------------------------------------------------
const MAPAS := {
	"bosque": {"nombre": "Bosque Maldito", "precio": 0},
	"desierto": {"nombre": "Desierto Carmesí", "precio": 400},
	"congelado": {"nombre": "Reino Congelado", "precio": 900},
	"abismo": {"nombre": "Abismo Eterno", "precio": 1600},
}
var mapas_desbloqueados: Array = ["bosque"]

# --- Skins cosméticas (sec. 18): auras visibles en partida --------------------
const SKINS := {
	"ninguna": {"nombre": "Sin aura", "precio": 0, "color": Color(0, 0, 0)},
	"llama": {"nombre": "Aura de Llama", "precio": 300, "color": Color(1.0, 0.5, 0.15)},
	"espectro": {"nombre": "Aura Espectral", "precio": 300, "color": Color(0.3, 0.95, 1.0)},
	"sangre": {"nombre": "Aura de Sangre", "precio": 600, "color": Color(0.9, 0.15, 0.2)},
	"vacio": {"nombre": "Aura del Vacío", "precio": -1, "color": Color(0.6, 0.3, 1.0)},
	"oro": {"nombre": "Aura Dorada", "precio": -1, "color": Color(1.0, 0.85, 0.3)},
}
var skins_desbloqueadas: Array = ["ninguna"]
var skin_activa := "ninguna"

# --- Pase de temporada (sec. 18): XP del pase = oro ganado en partidas --------
const PASE_NIVELES := [
	{"xp": 100, "tipo": "oro", "valor": 100, "nombre": "100 oro"},
	{"xp": 250, "tipo": "oro", "valor": 150, "nombre": "150 oro"},
	{"xp": 450, "tipo": "oro", "valor": 200, "nombre": "200 oro"},
	{"xp": 700, "tipo": "oro", "valor": 250, "nombre": "250 oro"},
	{"xp": 1000, "tipo": "skin", "valor": "vacio", "nombre": "Aura del Vacío"},
	{"xp": 1400, "tipo": "oro", "valor": 350, "nombre": "350 oro"},
	{"xp": 1900, "tipo": "oro", "valor": 450, "nombre": "450 oro"},
	{"xp": 2500, "tipo": "oro", "valor": 550, "nombre": "550 oro"},
	{"xp": 3200, "tipo": "oro", "valor": 700, "nombre": "700 oro"},
	{"xp": 4000, "tipo": "skin", "valor": "oro", "nombre": "Aura Dorada"},
]
var pase_xp := 0
var pase_reclamados: Array = []

# --- Estadísticas, logros y misiones (sec. 19) --------------------------------
var stats := {"kills": 0, "jefes": 0, "jefes_rey_vacio": 0, "partidas": 0, "oleada_max": 0, "nivel_max": 0, "oro_ganado": 0, "muertes": 0, "victorias": 0}
var stats_dia := {}

const LOGROS := {
	"primera_sangre": {"nombre": "Primera Sangre", "desc": "Mata 1 enemigo", "stat": "kills", "meta": 1, "oro": 25},
	"cazador": {"nombre": "Cazador", "desc": "100 bajas totales", "stat": "kills", "meta": 100, "oro": 100},
	"exterminador": {"nombre": "Exterminador", "desc": "1000 bajas totales", "stat": "kills", "meta": 1000, "oro": 500},
	"matajefes": {"nombre": "Matajefes", "desc": "Derrota un jefe", "stat": "jefes", "meta": 1, "oro": 200},
	"veterano": {"nombre": "Veterano", "desc": "10 partidas jugadas", "stat": "partidas", "meta": 10, "oro": 150},
	"marea": {"nombre": "Contra la Marea", "desc": "Alcanza el nivel 10 en una partida", "stat": "nivel_max", "meta": 10, "oro": 250},
	"ascendido": {"nombre": "Ascendido", "desc": "Nivel 15 en una partida", "stat": "nivel_max", "meta": 15, "oro": 200},
	"incansable": {"nombre": "Incansable", "desc": "Cae 10 veces", "stat": "muertes", "meta": 10, "oro": 100},
	"ricachon": {"nombre": "Ricachón", "desc": "Acumula 2000 oro ganado", "stat": "oro_ganado", "meta": 2000, "oro": 300},
	"conquistador": {"nombre": "Conquistador de la Noche", "desc": "Derrota al Rey del Vacío (victoria)", "stat": "jefes_rey_vacio", "meta": 1, "oro": 500},
}
var logros_completados: Array = []

const PLANTILLAS_MISIONES := [
	{"id": "m_kills80", "nombre": "Exterminio", "desc": "Mata 80 enemigos hoy", "stat": "kills", "meta": 80, "oro": 60},
	{"id": "m_kills150", "nombre": "Masacre", "desc": "Mata 150 enemigos hoy", "stat": "kills", "meta": 150, "oro": 110},
	{"id": "m_jefe", "nombre": "Caza Mayor", "desc": "Derrota 1 jefe hoy", "stat": "jefes", "meta": 1, "oro": 150},
	{"id": "m_oleada6", "nombre": "Resistencia", "desc": "Alcanza el nivel 6 en una partida hoy", "stat": "nivel_max", "meta": 6, "oro": 80},
	{"id": "m_nivel8", "nombre": "Crecimiento", "desc": "Llega a nivel 8 en una partida", "stat": "nivel_max", "meta": 8, "oro": 70},
	{"id": "m_oro100", "nombre": "Botín", "desc": "Gana 100 de oro hoy", "stat": "oro_ganado", "meta": 100, "oro": 80},
	{"id": "m_partidas2", "nombre": "Doble Turno", "desc": "Juega 2 partidas hoy", "stat": "partidas", "meta": 2, "oro": 50},
]
var misiones_fecha := ""
var misiones: Array = []


func _ready() -> void:
	cargar()
	_generar_misiones_diarias()
	aplicar_pantalla()


func aplicar_pantalla() -> void:
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if ajustes.pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)


# --- Talentos ------------------------------------------------------------------

const TALENTO_MAX := 5
const _COSTOS_TALENTO := [40, 65, 100, 150, 200]


func costo_talento(clave: String) -> int:
	var nv := int(talentos.get(clave, 0))
	if nv >= TALENTO_MAX:
		return 0
	return _COSTOS_TALENTO[nv]


func comprar_talento(clave: String) -> bool:
	if int(talentos.get(clave, 0)) >= TALENTO_MAX:
		return false
	var costo := costo_talento(clave)
	if oro_total < costo:
		return false
	oro_total -= costo
	talentos[clave] = int(talentos.get(clave, 0)) + 1
	guardar()
	return true


# --- Mapas y skins ---------------------------------------------------------------

func comprar_mapa(id: String) -> bool:
	if id in mapas_desbloqueados:
		return true
	var precio: int = MAPAS[id].precio
	if oro_total < precio:
		return false
	oro_total -= precio
	mapas_desbloqueados.append(id)
	guardar()
	return true


func comprar_skin(id: String) -> bool:
	if id in skins_desbloqueadas:
		return true
	var precio: int = SKINS[id].precio
	if precio < 0 or oro_total < precio:
		return false
	oro_total -= precio
	skins_desbloqueadas.append(id)
	guardar()
	return true


func equipar_skin(id: String) -> void:
	if id in skins_desbloqueadas:
		skin_activa = id
		guardar()


# --- Pase de temporada ------------------------------------------------------------

func pase_nivel_actual() -> int:
	var nivel := 0
	for datos in PASE_NIVELES:
		if pase_xp >= int(datos.xp):
			nivel += 1
	return nivel


func pase_reclamar(indice: int) -> bool:
	if indice in pase_reclamados or indice >= PASE_NIVELES.size():
		return false
	var datos: Dictionary = PASE_NIVELES[indice]
	if pase_xp < int(datos.xp):
		return false
	pase_reclamados.append(indice)
	if datos.tipo == "oro":
		oro_total += int(datos.valor)
	elif datos.tipo == "skin":
		if not (datos.valor in skins_desbloqueadas):
			skins_desbloqueadas.append(datos.valor)
	guardar()
	return true


# --- Eventos, logros y misiones -----------------------------------------------------

func evento(stat: String, n := 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + n
	stats_dia[stat] = int(stats_dia.get(stat, 0)) + n
	_chequear_logros()
	_chequear_misiones()


func registrar_maximo(stat: String, valor: int) -> void:
	stats[stat] = maxi(int(stats.get(stat, 0)), valor)
	stats_dia[stat] = maxi(int(stats_dia.get(stat, 0)), valor)
	_chequear_logros()
	_chequear_misiones()


func _chequear_logros() -> void:
	for id in LOGROS:
		if id in logros_completados:
			continue
		var datos: Dictionary = LOGROS[id]
		if int(stats.get(datos.stat, 0)) >= int(datos.meta):
			logros_completados.append(id)
			oro_total += int(datos.oro)
			logro_completado.emit(datos.nombre)
			guardar()


func _chequear_misiones() -> void:
	for mision in misiones:
		if mision.completada:
			continue
		if int(stats_dia.get(mision.stat, 0)) >= int(mision.meta):
			mision.completada = true
			oro_total += int(mision.oro)
			mision_completada.emit(mision.nombre)
			guardar()


func progreso_mision(mision: Dictionary) -> int:
	return mini(int(stats_dia.get(mision.stat, 0)), int(mision.meta))


func _generar_misiones_diarias() -> void:
	var fecha := Time.get_date_string_from_system()
	if misiones_fecha == fecha and not misiones.is_empty():
		return
	misiones_fecha = fecha
	stats_dia = {}
	misiones = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fecha)
	var indices := []
	while indices.size() < 3:
		var i := rng.randi_range(0, PLANTILLAS_MISIONES.size() - 1)
		if not (i in indices):
			indices.append(i)
	for i in indices:
		var plantilla: Dictionary = PLANTILLAS_MISIONES[i]
		misiones.append({
			"id": plantilla.id, "nombre": plantilla.nombre, "desc": plantilla.desc,
			"stat": plantilla.stat, "meta": plantilla.meta, "oro": plantilla.oro,
			"completada": false,
		})
	guardar()


# --- Guardado -----------------------------------------------------------------------

func guardar() -> void:
	var datos := {
		"oro_total": oro_total, "gemas": gemas, "talentos": talentos, "ajustes": ajustes,
		"mapas": mapas_desbloqueados, "skins": skins_desbloqueadas, "skin_activa": skin_activa,
		"pase_xp": pase_xp, "pase_reclamados": pase_reclamados,
		"stats": stats, "stats_dia": stats_dia, "logros": logros_completados,
		"misiones_fecha": misiones_fecha, "misiones": misiones,
		"nivel_max_desbloqueado": nivel_max_desbloqueado,
		"estrellas_nivel": estrellas_nivel,
		"inventario": inventario,
		"equipado": equipado,
		"ultima_clase": ultima_clase,
	}
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo:
		archivo.store_string(JSON.stringify(datos))


func cargar() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return
	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if not (datos is Dictionary):
		return
	oro_total = int(datos.get("oro_total", 0))
	gemas = int(datos.get("gemas", 0))
	var t = datos.get("talentos", {})
	if t is Dictionary:
		for clave in talentos.keys():
			talentos[clave] = int(t.get(clave, 0))
	var a = datos.get("ajustes", {})
	if a is Dictionary:
		for clave in ajustes.keys():
			if a.has(clave):
				ajustes[clave] = a[clave]
	mapas_desbloqueados = datos.get("mapas", ["bosque"])
	skins_desbloqueadas = datos.get("skins", ["ninguna"])
	skin_activa = datos.get("skin_activa", "ninguna")
	pase_xp = int(datos.get("pase_xp", 0))
	pase_reclamados = datos.get("pase_reclamados", [])
	var s = datos.get("stats", {})
	if s is Dictionary:
		for clave in stats.keys():
			stats[clave] = int(s.get(clave, 0))
	stats_dia = datos.get("stats_dia", {})
	logros_completados = datos.get("logros", [])
	misiones_fecha = datos.get("misiones_fecha", "")
	misiones = datos.get("misiones", [])
	nivel_max_desbloqueado = int(datos.get("nivel_max_desbloqueado", 0))
	var en = datos.get("estrellas_nivel", {})
	estrellas_nivel = en if en is Dictionary else {}
	var inv = datos.get("inventario", [])
	inventario = inv if inv is Array else []
	var eq = datos.get("equipado", {})
	equipado = eq if eq is Dictionary else {}
	ultima_clase = datos.get("ultima_clase", "guerrero")


func desbloquear_nivel(indice: int) -> void:
	if indice > nivel_max_desbloqueado:
		nivel_max_desbloqueado = indice
		guardar()


func registrar_estrellas(indice: int, estrellas: int) -> void:
	var clave := str(indice)
	if estrellas > int(estrellas_nivel.get(clave, 0)):
		estrellas_nivel[clave] = estrellas
		guardar()


func estrellas_de(indice: int) -> int:
	return int(estrellas_nivel.get(str(indice), 0))


func agregar_pieza(pieza: Dictionary) -> void:
	inventario.append(pieza)
	guardar()


func equipar(indice: int) -> void:
	if indice < 0 or indice >= inventario.size():
		return
	var pieza: Dictionary = inventario[indice]
	var slot: String = pieza.get("slot", "")
	if slot == "":
		return
	inventario.remove_at(indice)
	if equipado.has(slot):
		inventario.append(equipado[slot])  # la que estaba vuelve a la mochila
	equipado[slot] = pieza
	guardar()


func desequipar(slot: String) -> void:
	if equipado.has(slot):
		inventario.append(equipado[slot])
		equipado.erase(slot)
		guardar()


func vender_pieza(indice: int) -> int:
	if indice < 0 or indice >= inventario.size():
		return 0
	var pieza: Dictionary = inventario[indice]
	var valor: int = EquipamientoScript.valor_venta(pieza.get("rareza", "Común"))
	inventario.remove_at(indice)
	oro_total += valor
	guardar()
	return valor


func piezas_equipadas() -> Array:
	return equipado.values()


func _rolear_rareza(odds: Dictionary) -> String:
	var total := 0.0
	for r in odds:
		total += float(odds[r])
	var x := randf() * total
	var acum := 0.0
	for r in EquipamientoScript.ORDEN_RAREZA:
		if odds.has(r):
			acum += float(odds[r])
			if x <= acum:
				return r
	return "Común"


## Abre un cofre: gasta la moneda, genera una pieza por las odds y la mete al inventario.
## Devuelve la pieza generada, o {} si no hay moneda suficiente o el tipo no existe.
func abrir_cofre(tipo: String) -> Dictionary:
	if not COFRES.has(tipo):
		return {}
	var cofre: Dictionary = COFRES[tipo]
	var precio: int = cofre.precio
	if cofre.moneda == "oro":
		if oro_total < precio:
			return {}
		oro_total -= precio
	else:
		if gemas < precio:
			return {}
		gemas -= precio
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rareza := _rolear_rareza(cofre.odds)
	var pieza: Dictionary = EquipamientoScript.generar_aleatoria(rareza, rng)
	agregar_pieza(pieza)  # ya hace guardar()
	return pieza


## Stub de pago real: acredita gemas como si se hubiera comprado un paquete.
## (El billing real de Google Play es trabajo de plataforma futuro.)
func comprar_gemas(cantidad: int) -> void:
	gemas += cantidad
	guardar()
