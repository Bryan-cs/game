extends CharacterBody3D
class_name Jugador
## Personaje jugable: combate 100% auto — el ataque primario apunta y dispara solo al más cercano.
## Seis clases con stats y arma inicial propias (GDD sección 6).

signal vida_cambiada(actual: float, maxima: float)
signal xp_cambiada(actual: float, necesaria: float, nivel: int)
signal subio_nivel(nivel: int)
signal murio
signal cooldowns_cambiados(nova: float, dash: float, hab1: float, hab2: float)
signal corrupcion_cambiada(valor: float)
signal invoco_aliados(cantidad: int)

const ProyectilScript     := preload("res://scripts/proyectil.gd")
const HojaStatsScript     := preload("res://scripts/stats.gd")
const ArbolTalentosScript := preload("res://scripts/arbol_talentos.gd")

const CLASES := {
	"guerrero":   {"nombre": "Guerrero",   "vida": 130.0, "velocidad": 5.0,  "mult_dano": 1.15, "critico": 0.05, "mult_critico": 1.8, "regen": 0.0, "arma": "espada", "color": Color(0.85, 0.3, 0.25), "desc": "Espadón: tajo cuerpo a cuerpo · +15% daño"},
	"arquero":    {"nombre": "Arquero",    "vida": 80.0,  "velocidad": 5.8,  "mult_dano": 1.1,  "critico": 0.08, "mult_critico": 1.8, "regen": 0.0, "arma": "arco",   "color": Color(0.3, 0.7, 0.35),  "desc": "Arco: flechas automáticas al más cercano · 8% crítico"},
	"mago":       {"nombre": "Mago",       "vida": 75.0,  "velocidad": 5.0,  "mult_dano": 1.35, "critico": 0.05, "mult_critico": 1.8, "regen": 0.0, "arma": "fuego",  "color": Color(0.35, 0.45, 0.95),"desc": "Bastón: orbes arcanos explosivos · +35% daño"},
	"nigromante": {"nombre": "Nigromante", "vida": 95.0,  "velocidad": 5.0,  "mult_dano": 1.05, "critico": 0.05, "mult_critico": 1.8, "regen": 2.0, "arma": "espada", "color": Color(0.5, 0.3, 0.6),  "desc": "Báculo de sombras · Invoca aliados · Regenera 2/s"},
	"asesino":    {"nombre": "Asesino",    "vida": 65.0,  "velocidad": 6.5,  "mult_dano": 1.0,  "critico": 0.35, "mult_critico": 2.5, "regen": 0.0, "arma": "arco",   "color": Color(0.4, 0.4, 0.45), "desc": "Dagas: lanzamiento rapidísimo · 35% crítico x2.5"},
	"paladin":    {"nombre": "Paladín",    "vida": 145.0, "velocidad": 4.6,  "mult_dano": 0.9,  "critico": 0.04, "mult_critico": 1.8, "regen": 3.5, "arma": "espada", "color": Color(0.9, 0.85, 0.5), "desc": "Martillo: golpe con empuje · Regenera 3.5 vida/s"},
}

## Modelos 3D riggeados (KayKit, CC0) por clase, con su animación de ataque.
const MODELOS := {
	"guerrero": {"ruta": "res://art/models/adventurers/Barbarian.glb", "ataque": "2H_Melee_Attack_Slice",
		"ocultar": ["Mug", "1H_Axe", "Barbarian_Round_Shield", "1H_Axe_Offhand"]},
	"paladin": {"ruta": "res://art/models/adventurers/Knight.glb", "ataque": "1H_Melee_Attack_Chop",
		"ocultar": ["2H_Sword", "Spike_Shield", "Rectangle_Shield", "Badge_Shield", "1H_Sword_Offhand"]},
	"mago": {"ruta": "res://art/models/adventurers/Mage.glb", "ataque": "Spellcast_Shoot",
		"ocultar": ["1H_Wand", "Spellbook_open", "Spellbook"]},
	"nigromante": {"ruta": "res://art/models/skeletons/Skeleton_Mage.glb", "ataque": "Spellcast_Shoot",
		"ocultar": []},
	"arquero": {"ruta": "res://art/models/adventurers/Rogue_Hooded.glb", "ataque": "1H_Ranged_Shoot",
		"ocultar": ["Throwable", "Knife", "2H_Crossbow", "Knife_Offhand"]},
	"asesino": {"ruta": "res://art/models/adventurers/Rogue.glb", "ataque": "Dualwield_Melee_Attack_Stab",
		"ocultar": ["Throwable", "2H_Crossbow", "1H_Crossbow"]},
}

## Habilidades únicas por clase: aparecen como opciones al subir de nivel.
## Las activas se auto-lanzan por cooldown cuando hay enemigos cerca.
const HABILIDADES := {
	"guerrero": [
		{"id": "torbellino", "nombre": "Torbellino", "desc": "Giro devastador que arrasa todo alrededor", "tipo": "activa", "cd": 7.0, "anim": "2H_Melee_Attack_Spinning"},
		{"id": "embestida", "nombre": "Embestida", "desc": "Carga 7 m arrollando todo a tu paso", "tipo": "activa", "cd": 6.0, "anim": "2H_Melee_Attack_Stab"},
		{"id": "piel_hierro", "nombre": "Piel de Hierro", "desc": "-12% daño recibido por nivel", "tipo": "pasiva"},
		{"id": "furia", "nombre": "Furia", "desc": "+15% daño por nivel con vida bajo 40%", "tipo": "pasiva"},
		{"id": "hoja_gigante", "nombre": "Hoja Gigante", "desc": "Ondas de corte más grandes y perforantes", "tipo": "pasiva", "requiere": "activa_rama", "req_nv": 2},
		{"id": "corazon_hierro", "nombre": "Corazón de Hierro", "desc": "Escudo automático al caer bajo 30% de vida", "tipo": "pasiva", "requiere": "piel_hierro", "req_nv": 2},
		{"id": "sed_batalla", "nombre": "Sed de Batalla", "desc": "Cada baja acelera tu ataque y movimiento 4 s", "tipo": "pasiva", "requiere": "furia", "req_nv": 2},
		{"id": "rey_masacre", "nombre": "👑 REY DE LA MASACRE", "desc": "Rodeado de 12+: furia infinita (+80% daño, robo de vida)", "tipo": "pasiva", "requiere": "activa_rama", "req_nv": 3, "req_nivel": 10},
	],
	"arquero": [
		{"id": "lluvia_flechas", "nombre": "Lluvia de Flechas", "desc": "Flechas explosivas caen sobre la horda", "tipo": "activa", "cd": 8.0, "anim": "2H_Ranged_Shoot"},
		{"id": "flecha_multiple", "nombre": "Flecha Múltiple", "desc": "Abanico de flechas perforantes", "tipo": "activa", "cd": 5.0, "anim": "2H_Ranged_Shooting"},
		{"id": "perforante", "nombre": "Flecha Perforante", "desc": "Tus flechas atraviesan +1 enemigo por nivel", "tipo": "pasiva"},
		{"id": "ojo_halcon", "nombre": "Ojo de Halcón", "desc": "+8% probabilidad de crítico por nivel", "tipo": "pasiva"},
	],
	"mago": [
		{"id": "meteoro", "nombre": "Meteoro", "desc": "Roca ardiente con explosión masiva", "tipo": "activa", "cd": 9.0, "anim": "Spellcast_Long"},
		{"id": "anillo_hielo", "nombre": "Anillo de Hielo", "desc": "Congela y daña todo alrededor", "tipo": "activa", "cd": 8.0, "anim": "Spellcast_Shoot"},
		{"id": "eco", "nombre": "Eco Arcano", "desc": "20% por nivel de disparar un orbe extra", "tipo": "pasiva"},
		{"id": "sabiduria", "nombre": "Sabiduría", "desc": "+10% de experiencia por nivel", "tipo": "pasiva"},
	],
	"nigromante": [
		{"id": "legion", "nombre": "Legión", "desc": "Alza aliados y desata una onda de sombras", "tipo": "activa", "cd": 12.0, "anim": "Spellcast_Raise"},
		{"id": "drenar", "nombre": "Drenar Vida", "desc": "Daña en área y te cura la mitad", "tipo": "activa", "cd": 9.0, "anim": "Spellcast_Long"},
		{"id": "pacto_almas", "nombre": "Pacto de Almas", "desc": "Aliados +50% daño y +4s por nivel", "tipo": "pasiva"},
		{"id": "huesos_frios", "nombre": "Huesos Fríos", "desc": "Tus aliados explotan al expirar", "tipo": "pasiva"},
	],
	"asesino": [
		{"id": "tormenta_dagas", "nombre": "Tormenta de Dagas", "desc": "Nova masiva de dagas perforantes", "tipo": "activa", "cd": 6.0, "anim": "Dualwield_Melee_Attack_Slice"},
		{"id": "golpe_sombra", "nombre": "Golpe de Sombra", "desc": "Teletransporte al enemigo y golpe triple", "tipo": "activa", "cd": 7.0, "anim": "Dualwield_Melee_Attack_Stab"},
		{"id": "sed_sangre", "nombre": "Sed de Sangre", "desc": "Los críticos te curan 2 por nivel", "tipo": "pasiva"},
		{"id": "venenos", "nombre": "Venenos", "desc": "Tus dagas envenenan (daño por segundo)", "tipo": "pasiva"},
	],
	"paladin": [
		{"id": "juicio", "nombre": "Juicio", "desc": "Martillazo sagrado que arrasa y empuja", "tipo": "activa", "cd": 9.0, "anim": "2H_Melee_Attack_Chop"},
		{"id": "escudo_sagrado", "nombre": "Escudo Sagrado", "desc": "Barrera que absorbe daño 6 s", "tipo": "activa", "cd": 10.0, "anim": "Block_Attack"},
		{"id": "bendicion", "nombre": "Bendición", "desc": "+1 regeneración por nivel", "tipo": "pasiva"},
		{"id": "consagracion", "nombre": "Consagración", "desc": "El suelo bajo tus pies quema enemigos", "tipo": "pasiva"},
	],
}

## Ataque primario por clase (automático: apunta al enemigo más cercano).
const ATAQUES := {
	"guerrero":   {"tipo": "melee",  "cadencia": 0.45, "dano": 26.0, "por_nivel": 8.0, "radio": 2.8},
	"paladin":    {"tipo": "melee",  "cadencia": 0.8,  "dano": 32.0, "por_nivel": 8.0, "radio": 2.5, "empuje": 9.0},
	"arquero":    {"tipo": "flecha", "cadencia": 0.25, "dano": 15.0, "por_nivel": 5.0, "vel": 28.0},
	"asesino":    {"tipo": "daga",   "cadencia": 0.18, "dano": 8.0,  "por_nivel": 4.0, "vel": 26.0},
	"mago":       {"tipo": "orbe",   "cadencia": 0.5,  "dano": 20.0, "por_nivel": 6.0, "vel": 16.0, "aoe": 1.2},
	"nigromante": {"tipo": "sombra", "cadencia": 0.4,  "dano": 16.0, "por_nivel": 6.0, "vel": 18.0},
}

var clase := "guerrero"
var stats := HojaStatsScript.new()
var vida := 120.0
var radio_iman := 3.5
var mult_xp := 1.0
var vel_proyectil_mult := 1.0
var mult_critico := 1.8

# Propiedades legacy sobre la hoja: main.gd y las armas siguen funcionando.
var vida_max: float:
	get: return stats.vida_max
	set(v): stats.vida_max = v
var velocidad: float:
	get: return stats.velocidad_movimiento()
	set(v): stats.velocidad_pct = (v / stats.velocidad_base - 1.0) * 100.0
var mult_dano: float:
	get: return stats.mult_dano("global")
	set(v): stats.dano_pct = (v - 1.0) * 100.0
var prob_critico: float:
	get: return stats.prob_critico()
	set(v): stats.critico_pct = v * 100.0
var regen: float:
	get: return stats.regen
	set(v): stats.regen = v
var nivel := 1
var xp := 0.0
var xp_necesaria := 20.0
var limite_mapa := 70.0

# Disparo automático: apunta al enemigo más cercano cada vez que el cooldown está listo
var nivel_disparo := 1
var cadencia_disparo := 0.35

# Nova de Choque (Q): daño en área + empuje
var nivel_nova := 1
var cd_nova := 8.0

# Dash (Espacio): esquiva con invulnerabilidad breve
var cd_dash := 4.0

# Corrupción (0-100): más daño y rareza, menos curación, más enemigos
var corrupcion := 0.0

# Habilidades de clase aprendidas: id -> nivel
var habilidades := {}
var _cd_habs := {}
var _cd_habs_max := {}
var _reembolso_cd := false
var escudo := 0.0
var _escudo_t := 0.0
var _consagracion_t := 0.0
var _corazon_cd := 0.0
# Reliquias de Run
var reliquias: Array[String] = []
var mult_curacion := 1.0  # escalar de curación; modificado por nodos del árbol
var _rabia_stacks: int = 0
var _ultimo_aliento_usado: bool = false
var _sello_elite_activo: bool = false
var _piel_piedra_timer: float = 8.0
var _corazon_vacio_activo: bool = false
var _corazon_vacio_timer: float = 0.0
var _frenesi_t := 0.0
var _rey_t := 0.0
var _rey_cd := 0.0
var _rey_chequeo := 0.0
var _overlay_rojo: ColorRect

# Controles táctiles (Android)
var modo_tactil := false
var controles: Node = null

var _cd_disparo := 0.0
var _cd_nova := 0.0
var _cd_dash := 0.0
var _dash_restante := 0.0
var _dash_dir := Vector3.ZERO
var _invulnerable := 0.0
var _ultima_entrada := Vector3.ZERO
var _fase_paso := 0.0
var _anim_ataque := 0.0
var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _material: StandardMaterial3D
var _partes: Dictionary
var _modelo: Node3D
var _anim: AnimationPlayer
@onready var _estado: Node = get_node(^"/root/Estado")


func _ready() -> void:
	add_to_group("jugador")
	collision_layer = 2
	collision_mask = 1 | 4
	_aplicar_clase()
	_crear_cuerpo()
	_aplicar_talentos()
	_aplicar_arbol_talentos()
	_aplicar_equipo_meta()
	vida = vida_max
	vida_cambiada.emit(vida, vida_max)
	xp_cambiada.emit(xp, xp_necesaria, nivel)
	# Overlay carmesí del Rey de la Masacre
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_overlay_rojo = ColorRect.new()
	_overlay_rojo.color = Color(0.7, 0.05, 0.08, 0.0)
	_overlay_rojo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_overlay_rojo)


func _aplicar_clase() -> void:
	var datos: Dictionary = CLASES[clase]
	stats.vida_max = datos.vida
	stats.velocidad_base = datos.velocidad
	stats.dano_pct = (datos.mult_dano - 1.0) * 100.0
	stats.critico_pct = datos.critico * 100.0
	stats.regen = datos.regen
	mult_critico = datos.get("mult_critico", 1.8)
	cadencia_disparo = ATAQUES[clase].cadencia
	if clase == "arquero":
		vel_proyectil_mult = 1.3


func _crear_cuerpo() -> void:
	var datos: Dictionary = CLASES[clase]
	var info: Dictionary = MODELOS.get(clase, {})
	if not info.is_empty() and ResourceLoader.exists(info.ruta):
		_modelo = (load(info.ruta) as PackedScene).instantiate()
		_modelo.scale = Vector3.ONE * 0.7
		_modelo.position.y = -0.9
		add_child(_modelo)
		var ocultar: Array = info.get("ocultar", [])
		var pila: Array = [_modelo]
		while not pila.is_empty():
			var nodo: Node = pila.pop_back()
			if nodo is MeshInstance3D and String(nodo.name) in ocultar:
				nodo.visible = false
			for hijo in nodo.get_children():
				pila.append(hijo)
		_anim = _modelo.find_child("AnimationPlayer", true, false)
		if _anim:
			for nombre in ["Idle", "Walking_A", "Running_A"]:
				if _anim.has_animation(nombre):
					_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
			_anim.play("Idle")
	else:
		_partes = Cuerpos.humanoide(datos.color, 1.0)
		_material = _partes.material
		Equipo.equipar(_partes, clase)
		add_child(_partes.raiz)
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var colision := CollisionShape3D.new()
	colision.shape = forma
	add_child(colision)
	_crear_aura()
	_montar_arma_equipada()


func _montar_arma_equipada() -> void:
	# Muestra el arma equipada (tipo_visual) en la mano del personaje durante la partida.
	if _estado == null or not _estado.equipado.has("arma"):
		return
	var tipo: String = _estado.equipado["arma"].get("tipo_visual", "")
	if tipo == "":
		return
	var malla := Equipo.malla_item(tipo)
	if malla == null:
		return
	if _modelo:
		var esq: Skeleton3D = _modelo.find_child("Skeleton3D", true, false)
		var idx := -1
		if esq:
			# Preferir el slot de arma dedicado (handslot.r) sobre el hueso de la mano.
			for objetivo in ["handslot.r", "hand.r"]:
				for b in esq.get_bone_count():
					if esq.get_bone_name(b).to_lower() == objetivo:
						idx = b
						break
				if idx >= 0:
					break
		if esq and idx >= 0:
			var att := BoneAttachment3D.new()
			att.bone_idx = idx
			esq.add_child(att)
			malla.scale = Vector3.ONE * 0.5
			malla.position = Vector3(0, 0.05, 0)
			att.add_child(malla)
		else:
			malla.scale = Vector3.ONE * 0.6
			malla.position = Vector3(0.35, 1.1, 0.1)
			_modelo.add_child(malla)
	elif not _partes.is_empty():
		malla.scale = Vector3.ONE * 0.5
		_partes.brazo_d.add_child(malla)


func _crear_aura() -> void:
	# Skin cosmética equipada (tienda): anillo + chispas del color del aura
	var skin_id: String = _estado.skin_activa
	if skin_id == "ninguna" or not _estado.SKINS.has(skin_id):
		return
	var color: Color = _estado.SKINS[skin_id].color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var malla := TorusMesh.new()
	malla.inner_radius = 0.5
	malla.outer_radius = 0.62
	malla.material = mat
	var anillo := MeshInstance3D.new()
	anillo.mesh = malla
	anillo.position.y = -0.82
	add_child(anillo)
	var chispas := GPUParticles3D.new()
	chispas.amount = 12
	chispas.lifetime = 1.4
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.55
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 12.0
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.1
	pmat.color = color
	chispas.process_material = pmat
	var pm := SphereMesh.new()
	pm.radius = 0.04
	pm.height = 0.08
	var pmm := StandardMaterial3D.new()
	pmm.albedo_color = color
	pmm.emission_enabled = true
	pmm.emission = color
	pmm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmm.vertex_color_use_as_albedo = true
	pm.material = pmm
	chispas.draw_pass_1 = pm
	chispas.position.y = -0.7
	add_child(chispas)


func _aplicar_talentos() -> void:
	var t: Dictionary = _estado.talentos
	stats.vida_max *= 1.0 + 0.10 * int(t.get("vida", 0))
	stats.velocidad_pct += 5.0 * int(t.get("velocidad", 0))
	stats.dano_pct += 8.0 * int(t.get("dano", 0))
	stats.critico_pct += 3.0 * int(t.get("critico", 0))
	radio_iman *= 1.0 + 0.15 * int(t.get("xp", 0))


func _aplicar_arbol_talentos() -> void:
	if not _estado or not ("arbol_nodos" in _estado):
		return
	var arbol: Dictionary = _estado.arbol_nodos
	if arbol.is_empty():
		return
	_aplicar_lista_nodos_arbol(ArbolTalentosScript.NODOS_GLOBAL, arbol)
	_aplicar_lista_nodos_arbol(ArbolTalentosScript.NODOS_CLASE.get(clase, []), arbol)


func _aplicar_lista_nodos_arbol(lista: Array, arbol: Dictionary) -> void:
	for nodo in lista:
		var nivel: int = int(arbol.get(nodo.id, 0))
		if nivel <= 0:
			continue
		var stat: String = nodo.stat
		var valor: float = float(nodo.get("valor_por_nivel", 0.0)) * float(nivel)
		match stat:
			"vida_max_pct":
				stats.vida_max *= 1.0 + valor / 100.0
			"suerte":
				stats.suerte += valor
			"curacion_pct":
				mult_curacion *= 1.0 + valor / 100.0
			"xp_pct":
				mult_xp *= 1.0 + valor / 100.0
			"radio_iman_pct":
				radio_iman *= 1.0 + valor / 100.0
			"melee_pct":
				stats.melee_pct += valor
			"armadura":
				stats.armadura += valor
			"vel_ataque_pct":
				stats.vel_ataque_pct += valor
			"critico_pct":
				stats.critico_pct += valor
			"distancia_pct":
				stats.distancia_pct += valor
			"esquiva_pct":
				stats.esquiva_pct += valor
			"regen":
				stats.regen += valor
			"dano_pct":
				stats.dano_pct += valor
			# "oro_pct" se aplica en main.gd via _estado.mult_oro_arbol()


func _aplicar_equipo_meta() -> void:
	if _estado and _estado.has_method("piezas_equipadas"):
		stats.aplicar_equipo(_estado.piezas_equipadas(), clase)


func _physics_process(delta: float) -> void:
	_cd_disparo = maxf(0.0, _cd_disparo - delta)
	_cd_nova = maxf(0.0, _cd_nova - delta)
	_cd_dash = maxf(0.0, _cd_dash - delta)
	for id_h in _cd_habs.keys():
		_cd_habs[id_h] = maxf(0.0, _cd_habs[id_h] - delta)
	_corazon_cd = maxf(0.0, _corazon_cd - delta)
	_frenesi_t = maxf(0.0, _frenesi_t - delta)
	_rey_cd = maxf(0.0, _rey_cd - delta)
	if _rey_t > 0.0:
		_rey_t -= delta
		_overlay_rojo.color.a = 0.16 + 0.05 * sin(Time.get_ticks_msec() * 0.01)
		if _rey_t <= 0.0:
			_overlay_rojo.color.a = 0.0
	if nivel_habilidad("rey_masacre") > 0 and _rey_t <= 0.0 and _rey_cd <= 0.0:
		_rey_chequeo -= delta
		if _rey_chequeo <= 0.0:
			_rey_chequeo = 0.5
			var cercanos := 0
			for enemigo in get_tree().get_nodes_in_group("enemigos"):
				if enemigo.global_position.distance_to(global_position) <= 8.0:
					cercanos += 1
					if cercanos >= 12:
						break
			if cercanos >= 12:
				_rey_t = 6.0
				_rey_cd = 25.0
				Efectos.onda(get_tree().current_scene, global_position, 8.0, Color(0.85, 0.1, 0.12))
				Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP, Color(0.9, 0.15, 0.15))
				Efectos.sonido(self, "nova", 2.0)
				_sacudir(0.45)
				var escena := get_tree().current_scene
				if escena and "hud" in escena and escena.hud:
					escena.hud.anunciar("¡REY DE LA MASACRE!", Color(0.95, 0.12, 0.15))
	if _escudo_t > 0.0:
		_escudo_t -= delta
		if _escudo_t <= 0.0:
			escudo = 0.0
	if nivel_habilidad("consagracion") > 0 and vida > 0.0:
		_consagracion_t -= delta
		if _consagracion_t <= 0.0:
			_consagracion_t = 0.5
			var dano_aura := (2.0 + 2.0 * nivel_habilidad("consagracion")) * mult_dano
			for enemigo in get_tree().get_nodes_in_group("enemigos"):
				if enemigo.global_position.distance_to(global_position) <= 2.6:
					enemigo.recibir_dano(dano_aura)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if _material:
		_material.emission_enabled = _invulnerable > 0.3
		_material.emission = Color(1, 1, 1)
	elif _modelo:
		_modelo.visible = _invulnerable <= 0.3 or fmod(_invulnerable * 12.0, 2.0) < 1.0
	if regen > 0.0 and vida > 0.0 and vida < vida_max:
		curar(regen * delta)
	# Piel de Piedra: escudo periódico cada 8 s
	if "piel_de_piedra" in reliquias and vida > 0.0:
		_piel_piedra_timer -= delta
		if _piel_piedra_timer <= 0.0:
			_piel_piedra_timer = 8.0
			escudo = maxf(escudo, vida_max * 0.20)
			_escudo_t = maxf(_escudo_t, 4.0)
	# Corazón Vacío: velocidad temporal tras matar jefe
	if _corazon_vacio_activo:
		_corazon_vacio_timer = maxf(0.0, _corazon_vacio_timer - delta)
		if _corazon_vacio_timer <= 0.0:
			_corazon_vacio_activo = false
	if not is_on_floor():
		velocity.y -= _gravedad * delta
	var entrada := Vector3(
		Input.get_axis("mover_izquierda", "mover_derecha"),
		0.0,
		Input.get_axis("mover_arriba", "mover_abajo")
	)
	if controles != null and controles.vector.length() > 0.05:
		entrada = controles.vector
	if entrada.length() > 0.0:
		entrada = entrada.normalized()
	_ultima_entrada = entrada
	if _dash_restante > 0.0:
		_dash_restante -= delta
		velocity.x = _dash_dir.x * 18.0
		velocity.z = _dash_dir.z * 18.0
	else:
		var vel_efectiva := velocidad
		if _frenesi_t > 0.0:
			vel_efectiva *= 1.0 + 0.08 * nivel_habilidad("sed_batalla")
		if _rey_t > 0.0:
			vel_efectiva *= 1.3
		if _corazon_vacio_activo:
			vel_efectiva *= 1.30
		velocity.x = entrada.x * vel_efectiva
		velocity.z = entrada.z * vel_efectiva
	move_and_slide()
	# Arena circular: límite radial
	var plano := Vector2(global_position.x, global_position.z)
	if plano.length() > limite_mapa:
		plano = plano.normalized() * limite_mapa
		global_position.x = plano.x
		global_position.z = plano.y
	var objetivo := _enemigo_cercano()
	_animar(entrada, delta, objetivo)
	if vida > 0.0:
		# Combate 100% auto: dispara solo cuando hay objetivo y el cooldown está listo.
		if _cd_disparo <= 0.0 and objetivo != null:
			_atacar(objetivo)
		if Input.is_action_just_pressed("habilidad_nova"):
			intentar_nova()
		if Input.is_action_just_pressed("habilidad_dash"):
			intentar_dash()
		if Input.is_action_just_pressed("habilidad_1"):
			intentar_habilidad(0)
		if Input.is_action_just_pressed("habilidad_2"):
			intentar_habilidad(1)
	cooldowns_cambiados.emit(
		1.0 - _cd_nova / cd_nova,
		1.0 - _cd_dash / cd_dash,
		fraccion_habilidad(0),
		fraccion_habilidad(1)
	)


func activas() -> Array:
	var lista: Array = []
	for hab in HABILIDADES[clase]:
		if hab.tipo == "activa":
			lista.append(hab)
	return lista


func fraccion_habilidad(slot: int) -> float:
	var lista := activas()
	if slot >= lista.size():
		return -1.0
	var hab: Dictionary = lista[slot]
	if nivel_habilidad(hab.id) <= 0:
		return -1.0
	var cd_max: float = _cd_habs_max.get(hab.id, 1.0)
	return 1.0 - _cd_habs.get(hab.id, 0.0) / maxf(cd_max, 0.01)


func _raiz_visual() -> Node3D:
	if _modelo:
		return _modelo
	if not _partes.is_empty():
		return _partes.raiz
	return null


func _animar(entrada: Vector3, delta: float, objetivo: Node3D) -> void:
	var vel_h := Vector2(velocity.x, velocity.z).length()
	var mirada := entrada
	if objetivo != null:
		mirada = objetivo.global_position - global_position
		mirada.y = 0.0
	var raiz := _raiz_visual()
	if raiz and mirada.length() > 0.1:
		raiz.rotation.y = atan2(mirada.x, mirada.z)
	_anim_ataque = maxf(0.0, _anim_ataque - delta)
	if _anim:
		# Modelo riggeado: máquina de estados simple sobre AnimationPlayer.
		if _anim_ataque > 0.0:
			return
		var anim_objetivo := "Idle"
		if _dash_restante > 0.0 and _anim.has_animation("Dodge_Forward"):
			anim_objetivo = "Dodge_Forward"
		elif vel_h > 0.5:
			anim_objetivo = "Running_A"
		if _anim.current_animation != anim_objetivo:
			_anim.play(anim_objetivo, 0.15)
		return
	# Fallback procedural
	if _partes.is_empty():
		return
	if vel_h > 0.3:
		_fase_paso += delta * vel_h * 2.2
	Cuerpos.animar_paso(_partes, _fase_paso, clampf(vel_h / velocidad, 0.0, 1.0))
	if _anim_ataque > 0.0:
		var progreso := clampf((0.3 - _anim_ataque) / 0.3, 0.0, 1.0)
		_partes.brazo_d.rotation.x = lerpf(-2.4, 0.9, minf(progreso * 1.5, 1.0))


# --- Habilidades de clase ----------------------------------------------------

func aprender_habilidad(id: String, niveles := 1) -> void:
	habilidades[id] = int(habilidades.get(id, 0)) + niveles
	match id:
		"bendicion":
			regen += 1.0 * niveles
		"ojo_halcon":
			prob_critico += 0.08 * niveles
		"sabiduria":
			mult_xp += 0.10 * niveles


func nivel_habilidad(id: String) -> int:
	return int(habilidades.get(id, 0))


func al_matar(es_elite := false, es_jefe := false) -> void:
	if nivel_habilidad("sed_batalla") > 0:
		_frenesi_t = 4.0
	if _rey_t > 0.0:
		curar(5.0)
	if "rabia_acumulada" in reliquias:
		_rabia_stacks = mini(_rabia_stacks + 1, 20)
	if "pacto_corrupto" in reliquias:
		anadir_corrupcion(1.0)
	if es_elite and "sello_elite" in reliquias:
		_sello_elite_activo = true
		Efectos.onda(get_tree().current_scene, global_position, 1.5, Color(0.6, 0.5, 1.0))
	if es_jefe and "corazon_vacio" in reliquias:
		curar(vida_max * 0.50)
		_corazon_vacio_activo = true
		_corazon_vacio_timer = 15.0
		Efectos.onda(get_tree().current_scene, global_position, 3.0, Color(0.3, 0.8, 0.55))
		Efectos.sonido(self, "levelup", 0.0)


func intentar_habilidad(slot := 0) -> void:
	var lista := activas()
	if slot >= lista.size():
		return
	var hab: Dictionary = lista[slot]
	var nv := nivel_habilidad(hab.id)
	if nv <= 0 or _cd_habs.get(hab.id, 0.0) > 0.0 or vida <= 0.0:
		return
	_cd_habs_max[hab.id] = hab.cd * pow(0.95, nv - 1)
	_cd_habs[hab.id] = _cd_habs_max[hab.id]
	_reembolso_cd = false
	# Animación característica del personaje
	if _anim and _anim.has_animation(hab.anim):
		_anim.play(hab.anim, 0.05, 1.3)
		_anim_ataque = 0.5
	else:
		_anim_ataque = 0.4
	match hab.id:
		"torbellino":
			_hab_torbellino(nv)
		"embestida":
			_hab_embestida(nv)
		"lluvia_flechas":
			_hab_lluvia_flechas(nv)
		"flecha_multiple":
			_hab_flecha_multiple(nv)
		"meteoro":
			_hab_meteoro(nv)
		"anillo_hielo":
			_hab_anillo_hielo(nv)
		"legion":
			_hab_legion(nv)
		"drenar":
			_hab_drenar(nv)
		"tormenta_dagas":
			_hab_tormenta_dagas(nv)
		"golpe_sombra":
			_hab_golpe_sombra(nv)
		"juicio":
			_hab_juicio(nv)
		"escudo_sagrado":
			_hab_escudo_sagrado(nv)
	if _reembolso_cd:
		_cd_habs[hab.id] = 0.5


func _hab_torbellino(nv: int) -> void:
	var radio := 4.5 + 0.4 * nv
	var dano := calcular_dano(35.0 + 14.0 * nv)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - global_position
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		if enemigo.has_method("aplicar_empuje") and hacia.length() > 0.1:
			enemigo.aplicar_empuje(hacia.normalized() * 10.0)
		enemigo.recibir_dano(dano)
	# 6 ondas de corte radiales: el torbellino se proyecta a distancia
	var dano_onda := calcular_dano((20.0 + 7.0 * nv) * 1.0)
	for i in 6:
		var angulo := TAU * i / 6.0
		_lanzar_onda_corte(Vector3(cos(angulo), 0, sin(angulo)), dano_onda, 1.2)
	Efectos.onda(get_tree().current_scene, global_position, radio, Color(0.95, 0.95, 1.0))
	Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP * 0.5, Color(0.8, 0.85, 1.0))
	Efectos.sonido(self, "nova", 0.0)
	_sacudir(0.35)


func _hab_lluvia_flechas(nv: int) -> void:
	var objetivos: Array = []
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.global_position.distance_to(global_position) <= 14.0:
			objetivos.append(enemigo)
			if objetivos.size() >= 10 + nv * 3:
				break
	if objetivos.is_empty():
		objetivos.append(self)
	for objetivo in objetivos:
		var proyectil := _proyectil_flecha()
		proyectil.global_position = objetivo.global_position + Vector3(randf_range(-0.7, 0.7), 9.0, randf_range(-0.7, 0.7))
		proyectil.direccion = Vector3.DOWN
		proyectil.velocidad = 18.0
		proyectil.dano = calcular_dano(20.0 + 8.0 * nv)
		proyectil.radio_explosion = 1.3
		proyectil.look_at(proyectil.global_position + Vector3.DOWN, Vector3.FORWARD)
	Efectos.onda(get_tree().current_scene, global_position, 3.0, Color(0.6, 0.9, 0.4))
	Efectos.sonido(self, "disparo", 0.0)


func _hab_meteoro(nv: int) -> void:
	var objetivo := _enemigo_cercano()
	var destino: Vector3 = objetivo.global_position if objetivo else global_position + Vector3.FORWARD
	var proyectil := _crear_proyectil(Color(1.0, 0.5, 0.12), 0.6)
	proyectil.global_position = destino + Vector3(randf_range(-1, 1), 12.0, randf_range(-1, 1))
	proyectil.direccion = Vector3.DOWN
	proyectil.velocidad = 15.0
	proyectil.dano = calcular_dano(55.0 + 20.0 * nv)
	proyectil.radio_explosion = 4.0 + 0.5 * nv
	Efectos.onda(get_tree().current_scene, global_position, 2.5, Color(1.0, 0.5, 0.12))
	Efectos.sonido(self, "nova", 0.0)


func _hab_legion(nv: int) -> void:
	invoco_aliados.emit(2 + nv)
	var radio := 4.5 + 0.3 * nv
	var dano := calcular_dano(20.0 + 8.0 * nv)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - global_position
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		enemigo.recibir_dano(dano)
	Efectos.onda(get_tree().current_scene, global_position, radio, Color(0.5, 0.25, 0.7))
	Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP * 0.5, Color(0.45, 0.9, 0.5))
	Efectos.sonido(self, "muerte", 0.0)


func _hab_tormenta_dagas(nv: int) -> void:
	var cantidad := 12 + nv * 2
	for i in cantidad:
		var angulo := TAU * i / cantidad
		var proyectil := _proyectil_daga()
		proyectil.direccion = Vector3(cos(angulo), 0, sin(angulo))
		proyectil.velocidad = 20.0
		proyectil.dano = calcular_dano(16.0 + 6.0 * nv)
		proyectil.perforaciones_restantes = 2
		proyectil.look_at(proyectil.global_position + proyectil.direccion, Vector3.UP)
	Efectos.onda(get_tree().current_scene, global_position, 3.5, Color(0.8, 0.85, 0.95))
	Efectos.sonido(self, "dash", 0.0)


func _hab_embestida(nv: int) -> void:
	var _obj_emb := _enemigo_cercano()
	var dir := (_obj_emb.global_position - global_position) if _obj_emb != null else Vector3.FORWARD
	dir.y = 0.0
	if dir.length() < 0.2:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var origen := global_position
	_dash_dir = dir
	_dash_restante = 0.4
	_invulnerable = maxf(_invulnerable, 0.55)
	# Daña a todo lo que quede cerca de la línea de carga
	var dano := calcular_dano(30.0 + 12.0 * nv)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - origen
		hacia.y = 0.0
		var avance := hacia.dot(dir)
		if avance < 0.0 or avance > 8.0:
			continue
		if (hacia - dir * avance).length() > 1.8:
			continue
		if enemigo.has_method("aplicar_empuje"):
			enemigo.aplicar_empuje(dir * 12.0)
		enemigo.recibir_dano(dano)
	_lanzar_onda_corte(dir, calcular_dano(20.0 + 8.0 * nv), 1.1)
	Efectos.sonido(self, "dash", 0.0)
	_sacudir(0.25)


func _hab_flecha_multiple(nv: int) -> void:
	var _obj_flechas := _enemigo_cercano()
	var dir := (_obj_flechas.global_position - global_position) if _obj_flechas != null else Vector3.FORWARD
	dir.y = 0.0
	if dir.length() < 0.2:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var cantidad := 7 + nv * 2
	for i in cantidad:
		var angulo := deg_to_rad(-35.0 + 70.0 * i / maxf(cantidad - 1, 1))
		var proyectil := _proyectil_flecha()
		proyectil.direccion = dir.rotated(Vector3.UP, angulo)
		proyectil.velocidad = 24.0
		proyectil.dano = calcular_dano(14.0 + 6.0 * nv)
		proyectil.perforaciones_restantes = 2 + nivel_habilidad("perforante")
		proyectil.look_at(proyectil.global_position + proyectil.direccion, Vector3.UP)
	Efectos.sonido(self, "disparo", 0.0)


func _hab_anillo_hielo(nv: int) -> void:
	var radio := 5.0 + 0.4 * nv
	var dano := calcular_dano(18.0 + 8.0 * nv)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.global_position.distance_to(global_position) > radio:
			continue
		if enemigo.has_method("congelar"):
			enemigo.congelar(2.5)
		enemigo.recibir_dano(dano)
	Efectos.onda(get_tree().current_scene, global_position, radio, Color(0.55, 0.85, 1.0))
	Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP * 0.5, Color(0.6, 0.9, 1.0))
	Efectos.sonido(self, "nova", 0.0)


func _hab_drenar(nv: int) -> void:
	var radio := 5.0 + 0.3 * nv
	var dano := calcular_dano(15.0 + 6.0 * nv)
	var total := 0.0
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.global_position.distance_to(global_position) > radio:
			continue
		enemigo.recibir_dano(dano)
		total += dano
	if total > 0.0:
		curar(total * 0.5)
	Efectos.onda(get_tree().current_scene, global_position, radio, Color(0.6, 0.15, 0.3))
	Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP * 0.5, Color(0.4, 0.9, 0.4))
	Efectos.sonido(self, "muerte", 0.0)


func _hab_golpe_sombra(nv: int) -> void:
	var objetivo := _enemigo_cercano()
	if objetivo == null or objetivo.global_position.distance_to(global_position) > 12.0:
		_reembolso_cd = true  # sin objetivo: casi sin cooldown
		return
	Efectos.explosion(get_tree().current_scene, global_position + Vector3.UP * 0.6, Color(0.3, 0.2, 0.45), 18)
	var dir := (objetivo.global_position - global_position)
	dir.y = 0.0
	global_position = objetivo.global_position - dir.normalized() * 1.1
	_invulnerable = maxf(_invulnerable, 0.45)
	objetivo.recibir_dano(calcular_dano(25.0 + 10.0 * nv) * 3.0)
	Efectos.explosion_grande(get_tree().current_scene, objetivo.global_position + Vector3.UP * 0.6, Color(0.5, 0.3, 0.7))
	Efectos.sonido(self, "golpe", 0.0)
	_sacudir(0.2)


func _hab_escudo_sagrado(nv: int) -> void:
	escudo = 40.0 + 20.0 * nv
	_escudo_t = 6.0
	Efectos.onda(get_tree().current_scene, global_position, 2.0, Color(1.0, 0.9, 0.5))
	Efectos.sonido(self, "cofre", 0.0)


func _hab_juicio(nv: int) -> void:
	var radio := 5.0 + 0.4 * nv
	var dano := calcular_dano(40.0 + 15.0 * nv)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - global_position
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		if enemigo.has_method("aplicar_empuje") and hacia.length() > 0.1:
			enemigo.aplicar_empuje(hacia.normalized() * 16.0)
		enemigo.recibir_dano(dano)
	Efectos.onda(get_tree().current_scene, global_position, radio, Color(1.0, 0.9, 0.4))
	Efectos.explosion_grande(get_tree().current_scene, global_position + Vector3.UP * 0.5, Color(1.0, 0.85, 0.35))
	Efectos.sonido(self, "golpe", 0.0)


# --- Acciones del jugador ---------------------------------------------------

func intentar_nova() -> void:
	if _cd_nova <= 0.0 and vida > 0.0:
		_lanzar_nova()


func intentar_dash() -> void:
	if _cd_dash <= 0.0 and vida > 0.0:
		_iniciar_dash(_ultima_entrada)



func _enemigo_cercano() -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := INF
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var d: float = enemigo.global_position.distance_to(global_position)
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = enemigo
	return mejor


func _atacar(objetivo: Node3D) -> void:
	if objetivo == null:
		return
	var datos: Dictionary = ATAQUES[clase]
	var direccion: Vector3 = objetivo.global_position - global_position
	direccion.y = 0.0
	if direccion.length() < 0.2:
		return
	direccion = direccion.normalized()
	var factor := 1.0
	if _frenesi_t > 0.0:
		factor *= 0.85
	if _rey_t > 0.0:
		factor *= 0.6
	_cd_disparo = cadencia_disparo * factor / stats.mult_cadencia()
	_anim_ataque = 0.3
	var raiz := _raiz_visual()
	if raiz:
		raiz.rotation.y = atan2(direccion.x, direccion.z)
	if _anim and MODELOS.has(clase):
		var nombre_ataque: String = MODELOS[clase].ataque
		if _anim.has_animation(nombre_ataque):
			var largo := _anim.get_animation(nombre_ataque).length
			_anim.play(nombre_ataque, 0.05, largo / maxf(cadencia_disparo, 0.25))
			_anim_ataque = maxf(cadencia_disparo * 0.9, 0.25)
	if datos.tipo == "melee":
		_ataque_melee(direccion, datos)
	else:
		_ataque_proyectil(direccion, datos)


func _sacudir(fuerza: float) -> void:
	var escena := get_tree().current_scene
	if escena and escena.has_method("sacudir_camara"):
		escena.sacudir_camara(fuerza)


func _lanzar_onda_corte(direccion: Vector3, dano_onda: float, escala := 1.0) -> void:
	# Media luna de acero que viaja cortando lo que atraviesa
	var nv_hoja := nivel_habilidad("hoja_gigante")
	escala *= 1.0 + 0.3 * nv_hoja
	var onda := _proyectil_base(0.9 * escala)
	for i in 5:
		var seg := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(0.55 * escala, 0.08, 0.16)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.9, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.75, 1.0)
		mat.emission_energy_multiplier = 1.6
		malla.material = mat
		seg.mesh = malla
		seg.position = Vector3((i - 2) * 0.48 * escala, 0, -(0.3 - absf(i - 2.0) * 0.13) * escala)
		seg.rotation.y = (i - 2) * 0.28
		onda.add_child(seg)
	onda.direccion = direccion
	onda.velocidad = 16.0
	onda.dano = dano_onda
	onda.perforaciones_restantes = 5 + 2 * nv_hoja
	onda.vida_util = 0.45 * escala
	onda.look_at(onda.global_position + direccion, Vector3.UP)


func _ataque_melee(direccion: Vector3, datos: Dictionary) -> void:
	var dano := calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "melee")
	var golpeo := false
	var golpes := 0
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var hacia: Vector3 = enemigo.global_position - global_position
		hacia.y = 0.0
		if hacia.length() > datos.radio:
			continue
		if hacia.normalized().dot(direccion) < 0.25:
			continue
		if datos.has("empuje") and enemigo.has_method("aplicar_empuje"):
			enemigo.aplicar_empuje(direccion * datos.empuje)
		var dano_melee := dano
		if "ojo_depredador" in reliquias and "vida" in enemigo and "vida_max" in enemigo:
			if enemigo.vida / maxf(enemigo.vida_max, 1.0) < 0.30:
				dano_melee *= 2.0
		enemigo.recibir_dano(dano_melee)
		if "agujon_venenoso" in reliquias and randf() < 0.30 and enemigo.has_method("envenenar"):
			enemigo.envenenar(5.0, 3.0)
		golpeo = true
		golpes += 1
	if golpes > 0 and stats.robo_vida > 0.0:
		curar(dano * golpes * stats.robo_vida / 100.0)
	Efectos.sonido(self, "golpe" if golpeo else "dash", -4.0)
	Efectos.explosion(get_tree().current_scene, global_position + direccion * 1.5 + Vector3.UP * 0.6, Color(1.0, 0.95, 0.8), 10, 0.7)
	if golpeo:
		_sacudir(0.1)
	if clase == "guerrero":
		# El tajo del Guerrero proyecta una onda de corte a distancia
		var base_onda: float = (datos.dano + datos.por_nivel * (nivel_disparo - 1)) * 0.6
		_lanzar_onda_corte(direccion, calcular_dano(base_onda, "melee"))


func _ataque_proyectil(direccion: Vector3, datos: Dictionary) -> void:
	var proyectil: Area3D
	match datos.tipo:
		"flecha":
			proyectil = _proyectil_flecha()
		"daga":
			proyectil = _proyectil_daga()
			proyectil.veneno_dps = 5.0 * nivel_habilidad("venenos")
		"orbe":
			proyectil = _crear_proyectil(Color(0.6, 0.4, 1.0), 0.22)
			proyectil.radio_explosion = datos.aoe
		"sombra":
			proyectil = _crear_proyectil(Color(0.25, 0.9, 0.45), 0.18)
		_:
			proyectil = _crear_proyectil(Color(0.3, 0.95, 1.0), 0.16)
	proyectil.direccion = direccion
	proyectil.velocidad = datos.vel * vel_proyectil_mult
	proyectil.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "distancia")
	proyectil.robo_vida = stats.robo_vida
	if "ojo_depredador" in reliquias:
		proyectil.double_bajo_vida = true
	if "agujon_venenoso" in reliquias and randf() < 0.30:
		proyectil.veneno_dps = maxf(proyectil.veneno_dps, 5.0)
	proyectil.look_at(proyectil.global_position + direccion, Vector3.UP)
	if datos.tipo == "flecha":
		proyectil.perforaciones_restantes += nivel_habilidad("perforante")
	if datos.tipo == "orbe" and randf() < 0.2 * nivel_habilidad("eco"):
		var extra := _crear_proyectil(Color(0.6, 0.4, 1.0), 0.22)
		extra.radio_explosion = datos.aoe
		extra.direccion = direccion.rotated(Vector3.UP, 0.3)
		extra.velocidad = datos.vel * vel_proyectil_mult
		extra.dano = calcular_dano(datos.dano + datos.por_nivel * (nivel_disparo - 1), "distancia")
		extra.robo_vida = stats.robo_vida
		extra.look_at(extra.global_position + extra.direccion, Vector3.UP)
	Efectos.sonido(self, "disparo", -6.0)


func _proyectil_base(radio_colision: float) -> Area3D:
	var proyectil := Area3D.new()
	proyectil.set_script(ProyectilScript)
	var forma := SphereShape3D.new()
	forma.radius = radio_colision
	var colision := CollisionShape3D.new()
	colision.shape = forma
	proyectil.add_child(colision)
	get_tree().current_scene.add_child(proyectil)
	proyectil.global_position = global_position + Vector3.UP * 0.5
	return proyectil


func _proyectil_flecha() -> Area3D:
	var proyectil := _proyectil_base(0.25)
	var asta := CylinderMesh.new()
	asta.top_radius = 0.025
	asta.bottom_radius = 0.025
	asta.height = 0.7
	var mat_asta := StandardMaterial3D.new()
	mat_asta.albedo_color = Color(0.55, 0.4, 0.2)
	asta.material = mat_asta
	var mesh_asta := MeshInstance3D.new()
	mesh_asta.mesh = asta
	mesh_asta.rotation.x = PI / 2.0
	proyectil.add_child(mesh_asta)
	var punta := CylinderMesh.new()
	punta.top_radius = 0.0
	punta.bottom_radius = 0.055
	punta.height = 0.16
	var mat_punta := StandardMaterial3D.new()
	mat_punta.albedo_color = Color(0.85, 0.9, 1.0)
	mat_punta.emission_enabled = true
	mat_punta.emission = Color(0.7, 0.8, 1.0)
	punta.material = mat_punta
	var mesh_punta := MeshInstance3D.new()
	mesh_punta.mesh = punta
	mesh_punta.rotation.x = -PI / 2.0
	mesh_punta.position.z = -0.42
	proyectil.add_child(mesh_punta)
	return proyectil


func _proyectil_daga() -> Area3D:
	var proyectil := _proyectil_base(0.22)
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.06, 0.02, 0.34)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.85, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.65, 0.75)
	hoja.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = hoja
	proyectil.add_child(mesh)
	return proyectil


func _lanzar_nova() -> void:
	_cd_nova = cd_nova
	var radio := 4.0 + 0.5 * (nivel_nova - 1)
	var dano := calcular_dano(30.0 + 12.0 * (nivel_nova - 1))
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var distancia: float = enemigo.global_position.distance_to(global_position)
		if distancia <= radio:
			if enemigo.has_method("aplicar_empuje"):
				var dir: Vector3 = enemigo.global_position - global_position
				dir.y = 0.0
				if dir.length() > 0.1:
					enemigo.aplicar_empuje(dir.normalized() * 12.0)
			enemigo.recibir_dano(dano)
	_efecto_anillo(radio)
	Efectos.sonido(self, "nova")


func _iniciar_dash(entrada: Vector3) -> void:
	var dir := entrada
	if dir.length() < 0.1:
		var _obj_dash := _enemigo_cercano()
		dir = (_obj_dash.global_position - global_position) if _obj_dash != null else Vector3.FORWARD
		dir.y = 0.0
	if dir.length() < 0.1:
		return
	_cd_dash = cd_dash
	_dash_dir = dir.normalized()
	_dash_restante = 0.18
	_invulnerable = maxf(_invulnerable, 0.4)
	Efectos.sonido(self, "dash", -4.0)


func _crear_proyectil(color: Color, tamano: float) -> Area3D:
	var proyectil := _proyectil_base(maxf(tamano, 0.25))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	var malla := SphereMesh.new()
	malla.radius = tamano
	malla.height = tamano * 2.0
	malla.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	proyectil.add_child(mesh)
	return proyectil


func _efecto_anillo(radio: float, color := Color(0.3, 0.9, 1.0)) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var malla := TorusMesh.new()
	malla.inner_radius = 0.85
	malla.outer_radius = 1.0
	malla.material = mat
	var anillo := MeshInstance3D.new()
	anillo.mesh = malla
	get_tree().current_scene.add_child(anillo)
	anillo.global_position = global_position
	anillo.scale = Vector3.ONE * 0.3
	var tween := anillo.create_tween()
	tween.tween_property(anillo, "scale", Vector3.ONE * radio, 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(anillo.queue_free)


# --- Daño, vida y experiencia -----------------------------------------------

func recibir_dano(cantidad: float) -> void:
	if _invulnerable > 0.0 or vida <= 0.0:
		return
	if randf() < stats.prob_esquiva():
		Efectos.sonido(self, "dash", -8.0)
		return
	cantidad *= 1.0 - stats.reduccion_armadura()
	cantidad *= maxf(0.4, 1.0 - 0.12 * nivel_habilidad("piel_hierro"))
	if "codicia_infernal" in reliquias:
		cantidad *= 1.20
	if "rabia_acumulada" in reliquias and cantidad > 0.0:
		_rabia_stacks = 0
	if escudo > 0.0:
		var absorbido := minf(escudo, cantidad)
		escudo -= absorbido
		cantidad -= absorbido
		if cantidad <= 0.0:
			return
	# Último Aliento: una vez por run sobrevive a golpe letal
	if "ultimo_aliento" in reliquias and not _ultimo_aliento_usado and vida - cantidad <= 0.0 and vida > 1.0:
		vida = 1.0
		_ultimo_aliento_usado = true
		Efectos.onda(get_tree().current_scene, global_position, 3.0, Color(1.0, 1.0, 0.3))
		Efectos.sonido(self, "cofre", 2.0)
		vida_cambiada.emit(vida, vida_max)
		_invulnerable = 2.0
		return
	vida -= cantidad
	if bool(_estado.ajustes.get("numeros_dano", true)):
		Efectos.numero_dano(get_tree().current_scene, global_position + Vector3.UP * 1.5, cantidad, Color(1.0, 0.28, 0.28))
	# Corazón de Hierro: escudo de emergencia bajo 30% de vida
	var nv_corazon := nivel_habilidad("corazon_hierro")
	if nv_corazon > 0 and vida > 0.0 and vida < vida_max * 0.3 and _corazon_cd <= 0.0:
		_corazon_cd = 20.0
		escudo = 40.0 + 30.0 * nv_corazon
		_escudo_t = 5.0
		Efectos.onda(get_tree().current_scene, global_position, 2.2, Color(1.0, 0.9, 0.5))
		Efectos.sonido(self, "cofre", -2.0)
	_invulnerable = 0.6
	vida_cambiada.emit(vida, vida_max)
	Efectos.sonido(self, "dano_jugador")
	if vida <= 0.0:
		murio.emit()


func curar(cantidad: float) -> void:
	vida = minf(vida + cantidad * mult_curacion * (1.0 - corrupcion * 0.0075), vida_max)
	vida_cambiada.emit(vida, vida_max)


func anadir_corrupcion(cantidad: float) -> void:
	corrupcion = clampf(corrupcion + cantidad, 0.0, 100.0)
	corrupcion_cambiada.emit(corrupcion)


func ganar_xp(cantidad: float) -> void:
	xp += cantidad * mult_xp
	while xp >= xp_necesaria:
		xp -= xp_necesaria
		nivel += 1
		xp_necesaria = 5.0 + 15.0 * nivel
		subio_nivel.emit(nivel)
	xp_cambiada.emit(xp, xp_necesaria, nivel)


func calcular_dano(base: float, tipo := "global") -> float:
	var dano := base * stats.mult_dano(tipo) * (1.0 + corrupcion * 0.005)
	if "rabia_acumulada" in reliquias:
		dano *= 1.0 + minf(_rabia_stacks * 0.02, 0.40)
	if "pacto_corrupto" in reliquias:
		dano *= 1.60
	if nivel_habilidad("furia") > 0 and vida < vida_max * 0.4:
		dano *= 1.0 + 0.15 * nivel_habilidad("furia")
	if _rey_t > 0.0:
		dano *= 1.8
	var es_critico := randf() < prob_critico or _sello_elite_activo
	if es_critico:
		var mult_crit := mult_critico
		if _sello_elite_activo:
			mult_crit = maxf(mult_crit, 2.0)
			_sello_elite_activo = false
		dano *= mult_crit
		if nivel_habilidad("sed_sangre") > 0 and vida > 0.0:
			curar(2.0 * nivel_habilidad("sed_sangre"))
		if "sangre_fria" in reliquias and vida > 0.0:
			curar(vida_max * 0.03)
	return dano
