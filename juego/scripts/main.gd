extends Node3D
## Nightfall Survivors — director de partida del MVP (GDD v1.0).
## Mapa: Bosque Maldito. Jefe: Gigante Putrefacto a los 5 minutos.

const JugadorScript := preload("res://scripts/jugador.gd")
const EnemigoScript := preload("res://scripts/enemigo.gd")
const NivelesScript := preload("res://scripts/niveles.gd")
const GemaScript := preload("res://scripts/gema_xp.gd")
const CofreScript := preload("res://scripts/cofre.gd")
const HudScript := preload("res://scripts/hud.gd")
const MenuScript := preload("res://scripts/menu_mejoras.gd")
const ArmaEspadaScript := preload("res://scripts/arma_espada.gd")
const ArmaFuegoScript := preload("res://scripts/arma_fuego.gd")
const ArmaArcoScript := preload("res://scripts/arma_arco.gd")
const ArmaRayoScript := preload("res://scripts/arma_rayo.gd")
const ArmaDagasScript := preload("res://scripts/arma_dagas.gd")
const ArmaMartilloScript := preload("res://scripts/arma_martillo.gd")
const AliadoScript := preload("res://scripts/aliado.gd")
const MenuSeleccionScript := preload("res://scripts/menu_seleccion.gd")
const SonidoScript := preload("res://scripts/sonido.gd")
const ControlesScript := preload("res://scripts/controles_tactiles.gd")
const AltarScript := preload("res://scripts/altar.gd")
const MenuPausaScript := preload("res://scripts/menu_pausa.gd")
const MenuAjustesScript := preload("res://scripts/menu_ajustes.gd")
const AyudaScript := preload("res://scripts/ayuda.gd")

## Nombres de jefes (se reusan al invocar jefes; jefe-por-nivel es Capa N2)
const NOMBRES_JEFES := {
	"gigante_putrefacto": "GIGANTE PUTREFACTO",
	"senor_sombras": "SEÑOR DE LAS SOMBRAS",
	"rey_vacio": "REY DEL VACÍO",
}

const MAX_ENEMIGOS := 90
const LIMITE_MAPA := 70.0
const SEGUNDOS_HASTA_JEFE := 60.0  # tras este tiempo de combate aparece el jefe del nivel

## Temas visuales de los mapas (GDD sec. 13)
const TEMAS_MAPA := {
	"bosque": {"suelo": Color(0.12, 0.2, 0.12), "fondo": Color(0.045, 0.035, 0.095), "ambiente": Color(0.25, 0.3, 0.45), "luz": Color(0.65, 0.7, 1.0), "niebla": Color(0.08, 0.1, 0.16), "luna": Color(0.75, 0.78, 1.0), "props": "bosque"},
	"desierto": {"suelo": Color(0.42, 0.24, 0.13), "fondo": Color(0.1, 0.035, 0.05), "ambiente": Color(0.5, 0.28, 0.18), "luz": Color(1.0, 0.6, 0.4), "niebla": Color(0.18, 0.07, 0.05), "luna": Color(1.0, 0.4, 0.3), "props": "desierto"},
	"congelado": {"suelo": Color(0.6, 0.68, 0.78), "fondo": Color(0.04, 0.06, 0.13), "ambiente": Color(0.4, 0.5, 0.7), "luz": Color(0.75, 0.88, 1.0), "niebla": Color(0.16, 0.22, 0.32), "luna": Color(0.85, 0.95, 1.0), "props": "congelado"},
	"abismo": {"suelo": Color(0.07, 0.045, 0.11), "fondo": Color(0.02, 0.01, 0.05), "ambiente": Color(0.3, 0.15, 0.45), "luz": Color(0.55, 0.35, 0.9), "niebla": Color(0.1, 0.04, 0.16), "luna": Color(0.7, 0.4, 1.0), "props": "abismo"},
}

var jugador: Jugador
var hud
var menu
var camara: Camera3D
var tiempo := 0.0
var kills := 0
var oro_partida := 0
var jefe: Node3D = null
var jefe_invocado := false
var nivel_actual := 0
var _jefe_disparado := false
var partida_activa := false
var clase_jugador := "guerrero"
var mapa_actual := "bosque"
var sonido_mgr: Node
var menu_seleccion: CanvasLayer
var menu_pausa: CanvasLayer
var menu_ajustes: CanvasLayer
var controles: CanvasLayer
var mejoras_pendientes := 0
var armas := {}
var _mult_vel_evento := 1.0
var _prob_oro := 0.25
var _sinergias_activas := {}
var _mult_vel_enemigos := 1.0
var _entorno: Environment
var _luz: DirectionalLight3D
var _spawner: Timer
var _luciernagas: GPUParticles3D
var _opciones_actuales: Array = []
var _capa_game_over: CanvasLayer
var _go_titulo: Label
var _go_stats: Label
var _go_oro_total: Label
var _go_botones_talentos := {}
var _go_seguir: Button
@onready var _estado: Node = get_node(^"/root/Estado")


func _ready() -> void:
	add_to_group("partida")
	randomize()
	_crear_interfaz()
	_crear_spawner()
	_estado.logro_completado.connect(func(nombre: String) -> void: hud.anunciar("LOGRO: " + nombre.to_upper(), Color(1.0, 0.85, 0.4)))
	_estado.mision_completada.connect(func(nombre: String) -> void: hud.anunciar("MISIÓN CUMPLIDA: " + nombre.to_upper(), Color(0.4, 1.0, 0.5)))


func _process(delta: float) -> void:
	if not partida_activa:
		return
	tiempo += delta
	hud.actualizar_tiempo(tiempo)
	if not _jefe_disparado and tiempo >= NivelesScript.segundos_jefe(nivel_actual):
		_jefe_disparado = true
		_invocar_jefe_nivel()
	if is_instance_valid(jefe):
		hud.actualizar_jefe(jefe.vida / jefe.vida_max)


var _shake := 0.0


func sacudir_camara(fuerza: float) -> void:
	_shake = maxf(_shake, fuerza)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(jugador):
		var destino := jugador.global_position + Vector3(0, 14, 9)
		camara.global_position = camara.global_position.lerp(destino, 0.12)
		camara.look_at(jugador.global_position, Vector3.UP)
		if _shake > 0.0:
			camara.h_offset = randf_range(-1.0, 1.0) * _shake
			camara.v_offset = randf_range(-1.0, 1.0) * _shake
			_shake = maxf(0.0, _shake - _delta * 1.4)
		else:
			camara.h_offset = 0.0
			camara.v_offset = 0.0
		if _luciernagas:
			_luciernagas.global_position = jugador.global_position + Vector3.UP * 1.5


# --- Construcción del mundo -------------------------------------------------

func _crear_entorno() -> void:
	var tema: Dictionary = TEMAS_MAPA[mapa_actual]
	# Arena CIRCULAR (adiós al cuadrado)
	var suelo := StaticBody3D.new()
	suelo.collision_layer = 1
	var malla_suelo := CylinderMesh.new()
	malla_suelo.top_radius = LIMITE_MAPA + 6.0
	malla_suelo.bottom_radius = LIMITE_MAPA + 6.0
	malla_suelo.height = 0.5
	var mat_suelo := StandardMaterial3D.new()
	mat_suelo.albedo_color = tema.suelo
	malla_suelo.material = mat_suelo
	var mesh_suelo := MeshInstance3D.new()
	mesh_suelo.mesh = malla_suelo
	suelo.add_child(mesh_suelo)
	var forma_suelo := CylinderShape3D.new()
	forma_suelo.radius = LIMITE_MAPA + 6.0
	forma_suelo.height = 0.5
	var col_suelo := CollisionShape3D.new()
	col_suelo.shape = forma_suelo
	suelo.add_child(col_suelo)
	suelo.position.y = -0.25
	add_child(suelo)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, 30, 0)
	luz.light_color = tema.luz
	luz.light_energy = 0.8
	luz.shadow_enabled = true
	add_child(luz)
	_luz = luz

	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = tema.fondo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = tema.ambiente
	entorno.ambient_light_energy = 0.6
	entorno.fog_enabled = true
	entorno.fog_light_color = tema.niebla
	entorno.fog_density = 0.012
	entorno.glow_enabled = true
	entorno.glow_intensity = 0.9
	entorno.glow_bloom = 0.15
	entorno.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)
	_entorno = entorno
	_aplicar_graficos()

	_decorar_mapa()

	camara = Camera3D.new()
	camara.position = Vector3(0, 14, 9)
	add_child(camara)
	camara.look_at(Vector3.ZERO, Vector3.UP)
	camara.current = true


const RUTA_PROPS := "res://art/models/halloween/"


func _decorar_mapa() -> void:
	var tema: Dictionary = TEMAS_MAPA[mapa_actual]
	# Luna en el horizonte (color según el mapa)
	var luna_malla := SphereMesh.new()
	luna_malla.radius = 5.0
	luna_malla.height = 10.0
	var mat_luna := StandardMaterial3D.new()
	mat_luna.albedo_color = Color(0.9, 0.9, 1.0)
	mat_luna.emission_enabled = true
	mat_luna.emission = tema.luna
	mat_luna.emission_energy_multiplier = 2.0
	mat_luna.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luna_malla.material = mat_luna
	var luna := MeshInstance3D.new()
	luna.mesh = luna_malla
	luna.position = Vector3(70, 45, -80)
	add_child(luna)

	# Luciérnagas: siguen al jugador
	_luciernagas = GPUParticles3D.new()
	_luciernagas.amount = 36
	_luciernagas.lifetime = 7.0
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(22, 2, 22)
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.2
	pmat.initial_velocity_max = 0.7
	pmat.spread = 180.0
	pmat.color = Color(0.7, 1.0, 0.5)
	_luciernagas.process_material = pmat
	var fmalla := SphereMesh.new()
	fmalla.radius = 0.05
	fmalla.height = 0.1
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.7, 1.0, 0.5)
	fmat.emission_enabled = true
	fmat.emission = Color(0.6, 1.0, 0.4)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fmalla.material = fmat
	_luciernagas.draw_pass_1 = fmalla
	_luciernagas.position.y = 1.5
	add_child(_luciernagas)

	# Decoración según el tema del mapa
	var arboles: Array = []
	var num_arboles := 0
	var num_cementerios := 1
	var num_faroles := 6
	var detalles: Array = ["skull", "bone_A", "bone_B", "ribcage", "gravemarker_A", "candle_triple", "post_skull"]
	var num_detalles := 24
	match tema.props:
		"bosque":
			arboles = ["tree_dead_large", "tree_dead_medium", "tree_dead_small",
				"tree_pine_orange_large", "tree_pine_orange_medium", "tree_dead_large_decorated"]
			num_arboles = 55
			num_cementerios = 2
			num_faroles = 8
			detalles.append_array(["pumpkin_orange", "pumpkin_orange_jackolantern"])
			num_detalles = 26
		"desierto":
			num_arboles = 0
			num_detalles = 40
			detalles = ["skull", "bone_A", "bone_B", "bone_C", "ribcage", "gravemarker_A", "gravemarker_B"]
			for i in 14:
				_prop("pillar", _pos_libre(10.0), randf() * TAU, randf_range(0.8, 1.6), 0.4)
		"congelado":
			arboles = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"]
			num_arboles = 45
			num_faroles = 10
		"abismo":
			num_arboles = 0
			num_faroles = 4
			num_detalles = 30
			detalles = ["skull", "candle_triple", "candle", "plaque_candles", "post_skull", "ribcage"]
			for i in 16:
				_prop("pillar", _pos_libre(10.0), randf() * TAU, randf_range(0.9, 1.8), 0.4)
			for i in 5:
				_prop(["shrine_candles", "crypt"].pick_random(), _pos_libre(20.0), randf() * TAU, 1.0, 1.2)
	for i in num_arboles:
		_prop(arboles.pick_random(), _pos_libre(12.0), randf() * TAU, randf_range(0.9, 1.5), 0.45)
	for i in num_cementerios:
		_cementerio(_pos_libre(30.0))
	for i in num_faroles:
		var farol := _prop("post_lantern", _pos_libre(14.0), randf() * TAU, 1.0, 0.2)
		if farol:
			var luz_farol := OmniLight3D.new()
			luz_farol.light_color = Color(1.0, 0.7, 0.35)
			luz_farol.light_energy = 1.6
			luz_farol.omni_range = 7.0
			luz_farol.position.y = 2.2
			farol.add_child(luz_farol)
	for i in num_detalles:
		_prop(detalles.pick_random(), _pos_libre(8.0), randf() * TAU, 1.0, 0.0)
	for i in 8:
		_prop("floor_dirt", _pos_libre(6.0), randf() * TAU, randf_range(1.0, 1.8), 0.0)
	for i in 10:
		_prop(["path_A", "path_B", "path_C", "path_D"].pick_random(), _pos_libre(5.0), randf() * TAU, 1.2, 0.0)
	# Perímetro de la arena: columnas, barriles y antorchas marcan el borde
	for i in 36:
		var angulo_borde := TAU * i / 36.0
		var pos_borde := Vector3(cos(angulo_borde), 0, sin(angulo_borde)) * (LIMITE_MAPA + 2.0)
		match i % 4:
			0:
				_prop_dungeon("column", pos_borde, angulo_borde + PI, 1.3, 0.6)
			1:
				_prop_dungeon("torch_lit", pos_borde, angulo_borde + PI, 1.4, 0.0)
			2:
				_prop_dungeon("barrier_column", pos_borde, angulo_borde + PI, 1.3, 0.6)
			3:
				_prop_dungeon("crates_stacked", pos_borde, randf() * TAU, 1.2, 0.5)


func _prop_dungeon(nombre: String, pos: Vector3, rot_y := 0.0, escala := 1.0, radio_colision := 0.0) -> Node3D:
	var ruta := "res://art/models/dungeon/" + nombre + ".glb"
	if not ResourceLoader.exists(ruta):
		return null
	var inst: Node3D = (load(ruta) as PackedScene).instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * escala
	if radio_colision > 0.0:
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1
		var forma := CylinderShape3D.new()
		forma.radius = radio_colision
		forma.height = 3.0
		var col := CollisionShape3D.new()
		col.shape = forma
		col.position.y = 1.5
		cuerpo.add_child(col)
		inst.add_child(cuerpo)
	add_child(inst)
	return inst


func _limitar_pos(pos: Vector3) -> Vector3:
	var plano := Vector2(pos.x, pos.z)
	if plano.length() > LIMITE_MAPA:
		plano = plano.normalized() * LIMITE_MAPA
	return Vector3(plano.x, pos.y, plano.y)


func _pos_libre(margen_centro: float) -> Vector3:
	for intento in 8:
		var angulo := randf() * TAU
		var radio := LIMITE_MAPA * sqrt(randf())
		if radio >= margen_centro:
			return Vector3(cos(angulo) * radio, 0, sin(angulo) * radio)
	return Vector3(margen_centro, 0, margen_centro)


func _prop(nombre: String, pos: Vector3, rot_y := 0.0, escala := 1.0, radio_colision := 0.0) -> Node3D:
	var ruta := RUTA_PROPS + nombre + ".gltf"
	if not ResourceLoader.exists(ruta):
		if nombre.begins_with("tree"):
			var arbol := _crear_arbol(pos)
			add_child(arbol)
			return arbol
		return null
	var inst: Node3D = (load(ruta) as PackedScene).instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * escala
	if radio_colision > 0.0:
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1
		var forma := CylinderShape3D.new()
		forma.radius = radio_colision
		forma.height = 2.0
		var col := CollisionShape3D.new()
		col.shape = forma
		col.position.y = 1.0
		cuerpo.add_child(col)
		inst.add_child(cuerpo)
	add_child(inst)
	return inst


func _cementerio(centro: Vector3) -> void:
	_prop(["crypt", "shrine_candles"].pick_random(), centro, randf() * TAU, 1.0, 1.4)
	var tumbas := ["grave_A", "grave_B", "gravestone", "grave_A_destroyed", "gravemarker_B", "coffin"]
	for i in 9:
		var angulo := TAU * i / 9.0 + randf() * 0.4
		var radio := randf_range(4.0, 9.0)
		var pos := _limitar_pos(centro + Vector3(cos(angulo) * radio, 0, sin(angulo) * radio))
		_prop(tumbas.pick_random(), pos, randf() * TAU, 1.0, 0.0)
	for i in 10:
		var angulo := TAU * i / 10.0
		var pos := _limitar_pos(centro + Vector3(cos(angulo), 0, sin(angulo)) * 11.0)
		_prop(["fence", "fence_broken"].pick_random(), pos, angulo + PI / 2.0, 1.0, 0.0)
	_prop("arch_gate", centro + Vector3(11.0, 0, 0), PI / 2.0, 1.0, 0.0)


func _crear_arbol(pos: Vector3) -> Node3D:
	var arbol := Node3D.new()
	var tronco_malla := CylinderMesh.new()
	tronco_malla.top_radius = 0.2
	tronco_malla.bottom_radius = 0.3
	tronco_malla.height = 1.6
	var mat_tronco := StandardMaterial3D.new()
	mat_tronco.albedo_color = Color(0.25, 0.17, 0.1)
	tronco_malla.material = mat_tronco
	var tronco := MeshInstance3D.new()
	tronco.mesh = tronco_malla
	tronco.position.y = 0.8
	arbol.add_child(tronco)
	var copa_malla := CylinderMesh.new()
	copa_malla.top_radius = 0.0
	copa_malla.bottom_radius = 1.1
	copa_malla.height = 2.4
	var mat_copa := StandardMaterial3D.new()
	mat_copa.albedo_color = Color(0.06, 0.14, 0.08)
	copa_malla.material = mat_copa
	var copa := MeshInstance3D.new()
	copa.mesh = copa_malla
	copa.position.y = 2.6
	arbol.add_child(copa)
	var cuerpo_arbol := StaticBody3D.new()
	cuerpo_arbol.collision_layer = 1
	var forma_arbol := CylinderShape3D.new()
	forma_arbol.radius = 0.35
	forma_arbol.height = 1.6
	var colision_arbol := CollisionShape3D.new()
	colision_arbol.shape = forma_arbol
	colision_arbol.position.y = 0.8
	cuerpo_arbol.add_child(colision_arbol)
	arbol.add_child(cuerpo_arbol)
	arbol.position = pos
	arbol.scale = Vector3.ONE * randf_range(0.8, 1.6)
	return arbol


func _crear_jugador() -> void:
	var cuerpo := CharacterBody3D.new()
	cuerpo.set_script(JugadorScript)
	jugador = cuerpo
	jugador.clase = clase_jugador
	jugador.limite_mapa = LIMITE_MAPA
	jugador.vida_cambiada.connect(hud.actualizar_vida)
	jugador.xp_cambiada.connect(hud.actualizar_xp)
	jugador.subio_nivel.connect(_al_subir_nivel)
	jugador.murio.connect(_game_over)
	jugador.cooldowns_cambiados.connect(hud.actualizar_cooldowns)
	jugador.corrupcion_cambiada.connect(hud.actualizar_corrupcion)
	jugador.invoco_aliados.connect(_al_invocar_aliados)
	add_child(jugador)
	jugador.global_position = Vector3(0, 1.2, 0)


func _crear_interfaz() -> void:
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	hud.pausa_conmutada.connect(_conmutar_pausa)
	menu = CanvasLayer.new()
	menu.set_script(MenuScript)
	add_child(menu)
	menu.mejora_elegida.connect(_al_elegir_mejora)
	sonido_mgr = Node.new()
	sonido_mgr.set_script(SonidoScript)
	add_child(sonido_mgr)
	var pool := Node.new()
	pool.set_script(preload("res://scripts/pool_fx.gd"))
	add_child(pool)
	menu_seleccion = CanvasLayer.new()
	menu_seleccion.set_script(MenuSeleccionScript)
	add_child(menu_seleccion)
	menu_seleccion.clase_elegida.connect(_iniciar_partida)
	menu_ajustes = CanvasLayer.new()
	menu_ajustes.set_script(MenuAjustesScript)
	add_child(menu_ajustes)
	menu_ajustes.ajustes_cambiados.connect(_aplicar_graficos)
	menu_pausa = CanvasLayer.new()
	menu_pausa.set_script(MenuPausaScript)
	add_child(menu_pausa)
	menu_pausa.reanudar.connect(_conmutar_pausa)
	menu_pausa.reiniciar.connect(_reiniciar)
	menu_pausa.abrir_ajustes.connect(menu_ajustes.abrir)
	menu_pausa.salir_al_menu.connect(_salir_al_menu)
	_crear_game_over()


func _crear_spawner() -> void:
	_spawner = Timer.new()
	_spawner.wait_time = 1.0
	_spawner.autostart = true
	_spawner.timeout.connect(_spawn_continuo)
	add_child(_spawner)
	var temporizador_eventos := Timer.new()
	temporizador_eventos.wait_time = 75.0
	temporizador_eventos.autostart = true
	temporizador_eventos.timeout.connect(_evento_aleatorio)
	add_child(temporizador_eventos)
	var temporizador_ayudas := Timer.new()
	temporizador_ayudas.wait_time = 25.0
	temporizador_ayudas.autostart = true
	temporizador_ayudas.timeout.connect(_generar_ayuda)
	add_child(temporizador_ayudas)


func _iniciar_partida(clave: String, mapa := "bosque", indice_nivel := 0) -> void:
	clase_jugador = clave
	_estado.ultima_clase = clave
	nivel_actual = indice_nivel
	var tema_nivel := NivelesScript.tema(indice_nivel)
	mapa_actual = tema_nivel if TEMAS_MAPA.has(tema_nivel) else "bosque"
	_jefe_disparado = false
	_crear_entorno()
	_estado.evento("partidas")
	_crear_jugador()
	_dar_arma(Jugador.CLASES[clave].arma)
	if DisplayServer.is_touchscreen_available():
		controles = CanvasLayer.new()
		controles.set_script(ControlesScript)
		add_child(controles)
		controles.jugador = jugador
		jugador.controles = controles
		jugador.modo_tactil = true
	partida_activa = true
	sonido_mgr.tocar_musica("res://audio/musica.wav")


# --- Armas y mejoras --------------------------------------------------------

func _dar_arma(clave: String) -> void:
	var guion: GDScript
	match clave:
		"espada":
			guion = ArmaEspadaScript
		"fuego":
			guion = ArmaFuegoScript
		"arco":
			guion = ArmaArcoScript
		"rayo":
			guion = ArmaRayoScript
		"dagas":
			guion = ArmaDagasScript
		"martillo":
			guion = ArmaMartilloScript
	var arma := Node3D.new()
	arma.set_script(guion)
	arma.jugador = jugador
	jugador.add_child(arma)
	armas[clave] = arma
	_comprobar_sinergias()


func _comprobar_sinergias() -> void:
	if armas.has("espada") and armas.has("fuego") and not _sinergias_activas.has("hojas_igneas"):
		_sinergias_activas["hojas_igneas"] = true
		armas["espada"].activar_sinergia_fuego()
		hud.anunciar("SINERGIA: HOJAS ÍGNEAS", Color(1.0, 0.45, 0.15))
	if armas.has("arco") and armas.has("fuego") and not _sinergias_activas.has("flechas_explosivas"):
		_sinergias_activas["flechas_explosivas"] = true
		armas["arco"].sinergia_explosiva = true
		hud.anunciar("SINERGIA: FLECHAS EXPLOSIVAS", Color(1.0, 0.6, 0.25))
	if armas.has("rayo") and armas.has("fuego") and not _sinergias_activas.has("plasma"):
		_sinergias_activas["plasma"] = true
		armas["fuego"].sinergia_plasma = true
		hud.anunciar("SINERGIA: TORMENTA DE PLASMA", Color(0.5, 0.8, 1.0))
	if armas.has("martillo") and armas.has("espada") and not _sinergias_activas.has("forja"):
		_sinergias_activas["forja"] = true
		armas["espada"].mult_forja = 1.25
		hud.anunciar("SINERGIA: ECO DE FORJA", Color(0.85, 0.7, 0.4))


func _rareza_aleatoria() -> Dictionary:
	# La corrupción sesga la suerte hacia rarezas superiores (hasta -0.2 con 100).
	var sesgo := 0.0
	if is_instance_valid(jugador):
		sesgo = jugador.corrupcion * 0.002 + jugador.stats.suerte * 0.003
	var r := randf() - sesgo
	if r < 0.60:
		return {"rareza": "Común", "mult": 1.0, "color": Color(0.85, 0.85, 0.85)}
	if r < 0.85:
		return {"rareza": "Rara", "mult": 1.3, "color": Color(0.4, 0.65, 1.0)}
	if r < 0.95:
		return {"rareza": "Épica", "mult": 1.7, "color": Color(0.75, 0.4, 1.0)}
	if r < 0.99:
		return {"rareza": "Legendaria", "mult": 2.2, "color": Color(1.0, 0.65, 0.2)}
	return {"rareza": "Mítica", "mult": 3.0, "color": Color(1.0, 0.25, 0.25)}


func _generar_opciones(cantidad := 3) -> Array:
	var pool: Array = []
	if not armas.has("fuego"):
		pool.append({"id": "arma_fuego", "titulo": "Bola de Fuego", "desc": "Nueva arma: proyectil explosivo"})
	if not armas.has("arco"):
		pool.append({"id": "arma_arco", "titulo": "Arco Automático", "desc": "Nueva arma: flechas perforantes"})
	if not armas.has("rayo"):
		pool.append({"id": "arma_rayo", "titulo": "Cadena Eléctrica", "desc": "Nueva arma: rayo que salta entre enemigos"})
	if not armas.has("dagas"):
		pool.append({"id": "arma_dagas", "titulo": "Dagas Fantasma", "desc": "Nueva arma: dagas espectrales aleatorias"})
	if not armas.has("martillo"):
		pool.append({"id": "arma_martillo", "titulo": "Martillo Sísmico", "desc": "Nueva arma: golpes de tierra en área"})
	for clave in armas:
		var arma = armas[clave]
		if arma.nivel < 8:
			pool.append({"id": "mejorar_" + clave, "titulo": arma.nombre(), "desc": "Subir a nivel %d" % (arma.nivel + 1)})
		if arma.nivel >= 5 and not arma.evolucionada:
			pool.append({"id": "evolucionar_" + clave, "titulo": arma.nombre_evolucion(), "desc": "EVOLUCIÓN de %s" % arma.nombre()})
	pool.append({"id": "disparo", "titulo": "Maestría de Arma", "desc": "Ataque a nivel %d: +daño y velocidad" % (jugador.nivel_disparo + 1)})
	pool.append({"id": "nova", "titulo": "Nova de Choque", "desc": "Subir a nivel %d: +daño, +radio, -enfriamiento" % (jugador.nivel_nova + 1)})
	pool.append({"id": "dash", "titulo": "Dash Veloz", "desc": "-enfriamiento del dash"})
	pool.append({"id": "vida", "titulo": "Vitalidad", "desc": "+vida máxima y cura"})
	pool.append({"id": "velocidad", "titulo": "Ligereza", "desc": "+velocidad de movimiento"})
	pool.append({"id": "dano", "titulo": "Furia", "desc": "+daño global"})
	pool.append({"id": "iman", "titulo": "Imán", "desc": "+radio de recolección"})
	pool.append({"id": "pacto", "titulo": "Pacto Oscuro", "desc": "+12% daño global… y +15 de corrupción"})
	# Cada habilidad tiene su propio slot (E/R): ambas activas se pueden aprender
	var max_nv_activas := 0
	for hab in Jugador.HABILIDADES[clase_jugador]:
		if hab.tipo == "activa":
			max_nv_activas = maxi(max_nv_activas, jugador.nivel_habilidad(hab.id))
	for hab in Jugador.HABILIDADES[clase_jugador]:
		var nv_hab: int = jugador.nivel_habilidad(hab.id)
		# Tiers: prerrequisitos de habilidad y de nivel del jugador
		if hab.has("requiere"):
			if hab.requiere == "activa_rama":
				if max_nv_activas < int(hab.get("req_nv", 1)):
					continue
			elif jugador.nivel_habilidad(hab.requiere) < int(hab.get("req_nv", 1)):
				continue
		if int(hab.get("req_nivel", 0)) > jugador.nivel:
			continue
		if nv_hab == 0:
			pool.append({"id": "hab_" + hab.id, "titulo": "★ " + hab.nombre, "desc": "NUEVA HABILIDAD: " + hab.desc})
		elif nv_hab < 5:
			pool.append({"id": "hab_" + hab.id, "titulo": hab.nombre, "desc": "Subir a nivel %d — %s" % [nv_hab + 1, hab.desc]})
	pool.shuffle()
	var opciones: Array = []
	for i in mini(cantidad, pool.size()):
		var opcion: Dictionary = pool[i]
		opcion.merge(_rareza_aleatoria())
		opciones.append(opcion)
	return opciones


func _al_subir_nivel(_nivel: int) -> void:
	_estado.registrar_maximo("nivel_max", _nivel)
	Efectos.sonido(self, "levelup")
	if is_instance_valid(jugador):
		Efectos.explosion(self, jugador.global_position, Color(0.3, 1.0, 0.5), 30)
	mejoras_pendientes += 1
	hud.anunciar("¡NIVEL %d!" % _nivel, Color(0.4, 1.0, 0.6))
	_mostrar_mejoras_si_toca()


func _mostrar_mejoras_si_toca() -> void:
	if menu.visible or not partida_activa or mejoras_pendientes <= 0:
		return
	_opciones_actuales = _generar_opciones()
	menu.mostrar(_opciones_actuales)


func _al_elegir_mejora(indice: int) -> void:
	var opcion: Dictionary = _opciones_actuales[indice]
	_aplicar_opcion(opcion)
	mejoras_pendientes -= 1
	if mejoras_pendientes > 0:
		_mostrar_mejoras_si_toca()
	else:
		get_tree().paused = false


func _aplicar_opcion(opcion: Dictionary) -> void:
	var mult: float = opcion.mult
	var extra := 1 if mult >= 1.7 else 0
	match opcion.id:
		"arma_fuego":
			_dar_arma("fuego")
			if extra > 0:
				armas["fuego"].mejorar(extra)
		"arma_arco":
			_dar_arma("arco")
			if extra > 0:
				armas["arco"].mejorar(extra)
		"arma_rayo":
			_dar_arma("rayo")
			if extra > 0:
				armas["rayo"].mejorar(extra)
		"arma_dagas":
			_dar_arma("dagas")
			if extra > 0:
				armas["dagas"].mejorar(extra)
		"arma_martillo":
			_dar_arma("martillo")
			if extra > 0:
				armas["martillo"].mejorar(extra)
		"disparo":
			jugador.nivel_disparo += 1 + extra
			jugador.cadencia_disparo = maxf(0.12, jugador.cadencia_disparo * pow(0.92, 1 + extra))
		"nova":
			jugador.nivel_nova += 1 + extra
			jugador.cd_nova = maxf(3.0, jugador.cd_nova * pow(0.9, 1 + extra))
		"dash":
			jugador.cd_dash = maxf(1.5, jugador.cd_dash * pow(0.85, 1 + extra))
		"vida":
			jugador.vida_max += 15.0 * mult
			jugador.curar(15.0 * mult)
		"velocidad":
			jugador.velocidad *= 1.0 + 0.05 * mult
		"dano":
			jugador.mult_dano *= 1.0 + 0.08 * mult
		"iman":
			jugador.radio_iman *= 1.0 + 0.20 * mult
		"pacto":
			jugador.mult_dano *= 1.0 + 0.12 * mult
			jugador.anadir_corrupcion(15.0)
		_:
			if opcion.id.begins_with("hab_"):
				var id_hab: String = opcion.id.trim_prefix("hab_")
				var era_nueva := jugador.nivel_habilidad(id_hab) == 0
				jugador.aprender_habilidad(id_hab, 1 + extra)
				if era_nueva:
					hud.anunciar("HABILIDAD: " + String(opcion.titulo).trim_prefix("★ ").to_upper(), Color(1.0, 0.85, 0.4))
				_actualizar_slots_habilidad()
			elif opcion.id.begins_with("evolucionar_"):
				var clave_evo: String = opcion.id.trim_prefix("evolucionar_")
				if armas.has(clave_evo):
					armas[clave_evo].evolucionar()
			else:
				var clave: String = opcion.id.trim_prefix("mejorar_")
				if armas.has(clave):
					armas[clave].mejorar(1 + extra)


# --- Spawn continuo y enemigos ----------------------------------------------

func _spawn_continuo() -> void:
	if not partida_activa or get_tree().paused:
		return
	var vivos := get_tree().get_nodes_in_group("enemigos").size()
	if vivos >= MAX_ENEMIGOS:
		return
	# La dureza escala con el tiempo: mas enemigos por tick a medida que avanza.
	var dificultad := 1.0 + tiempo / 60.0
	var lote := mini(int(2 + dificultad), MAX_ENEMIGOS - vivos)
	for i in maxi(lote, 0):
		_generar_enemigo(_tipo_aleatorio())


func _generar_ayuda() -> void:
	if not partida_activa or get_tree().paused or not is_instance_valid(jugador):
		return
	if get_tree().get_nodes_in_group("ayudas").size() >= 3:
		return
	var ayuda := Node3D.new()
	ayuda.set_script(AyudaScript)
	var r := randf()
	ayuda.tipo = "pocion" if r < 0.5 else ("iman" if r < 0.8 else "bomba")
	ayuda.add_to_group("ayudas")
	ayuda.recogida.connect(_al_recoger_ayuda)
	add_child(ayuda)
	var angulo := randf() * TAU
	var pos := _limitar_pos(jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(8.0, 16.0))
	ayuda.global_position = Vector3(pos.x, 0.3, pos.z)


func _al_recoger_ayuda(tipo: String) -> void:
	match tipo:
		"pocion":
			jugador.curar(jugador.vida_max * 0.3)
			Efectos.sonido(self, "cofre")
			Efectos.explosion(self, jugador.global_position, Color(0.9, 0.2, 0.3), 18)
		"iman":
			Efectos.sonido(self, "levelup", -4.0)
			get_tree().call_group("gemas", "atraer")
		"bomba":
			Efectos.sonido(self, "nova")
			Efectos.explosion(self, jugador.global_position, Color(1.0, 0.6, 0.1), 40, 2.0)
			for enemigo in get_tree().get_nodes_in_group("enemigos"):
				if enemigo.global_position.distance_to(jugador.global_position) <= 8.0:
					enemigo.recibir_dano(120.0)


func _tipo_aleatorio() -> String:
	# La variedad de enemigos escala con el tiempo (antes con la oleada).
	var minutos := tiempo / 60.0
	var pool: Array[String] = ["zombie"]
	if minutos >= 0.5:
		pool.append("esqueleto")
	if minutos >= 1.0:
		pool.append("arana_gigante")
	if minutos >= 1.5:
		pool.append("demonio_menor")
	if minutos >= 2.0:
		pool.append("caballero_oscuro")
	return pool.pick_random()


func _generar_enemigo(tipo: String, forzar_elite := false) -> Node3D:
	# La dureza escala con el tiempo (antes con la oleada/fase de noche).
	var minutos := tiempo / 60.0
	var enemigo := CharacterBody3D.new()
	enemigo.set_script(EnemigoScript)
	enemigo.configurar(tipo, (1.0 + minutos * 0.25) * NivelesScript.escala(nivel_actual))
	if not (tipo in EnemigoScript.JEFES) and (forzar_elite or (minutos >= 3.0 and randf() < 0.15)):
		enemigo.configurar_elite()
	if minutos >= 5.0:
		enemigo.dano *= 1.25
		enemigo.velocidad *= 1.15
	enemigo.velocidad *= _mult_vel_enemigos
	enemigo.mult_evento = _mult_vel_evento
	enemigo.murio.connect(_al_morir_enemigo)
	add_child(enemigo)
	var angulo := randf() * TAU
	var distancia := randf_range(22.0, 32.0)
	var pos := _limitar_pos(jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * distancia)
	pos.y = 1.2
	enemigo.global_position = pos
	return enemigo


func _invocar_jefe_nivel() -> void:
	var tipo: String = NivelesScript.jefe(nivel_actual)
	_invocar_jefe(tipo)
	hud.anunciar("¡EL JEFE HA APARECIDO!", Color(1.0, 0.3, 0.25))


func _invocar_jefe(tipo: String) -> void:
	jefe = _generar_enemigo(tipo)
	jefe.pide_esbirros.connect(_al_pedir_esbirros)
	hud.mostrar_jefe(NOMBRES_JEFES.get(tipo, "JEFE"))
	hud.anunciar(NOMBRES_JEFES.get(tipo, "JEFE"), Color(1.0, 0.25, 0.2))
	sonido_mgr.tocar_musica("res://audio/musica_jefe.wav")


func _al_pedir_esbirros(pos: Vector3, cantidad: int) -> void:
	for i in cantidad:
		var esbirro := _generar_enemigo("esqueleto")
		var angulo := TAU * i / cantidad
		var destino := _limitar_pos(pos + Vector3(cos(angulo), 0, sin(angulo)) * 2.5)
		esbirro.global_position = Vector3(destino.x, 1.2, destino.z)


func _al_morir_enemigo(enemigo: Node) -> void:
	kills += 1
	hud.actualizar_kills(kills)
	if is_instance_valid(jugador):
		jugador.al_matar()
	_estado.evento("kills")
	if enemigo.es_jefe:
		_estado.evento("jefes")
	var pos: Vector3 = enemigo.global_position
	var color: Color = EnemigoScript.TIPOS[enemigo.tipo]["color"]
	Efectos.explosion(self, pos, color, 20, 2.0 if enemigo.es_jefe else 1.0)
	Efectos.sonido(self, "muerte", -6.0)
	if clase_jugador == "nigromante" and randf() < 0.10:
		_invocar_aliado(pos)
	_soltar_gema(pos, enemigo.xp)
	if enemigo.es_jefe:
		# Recompensa de jefe: cofre (mejora). Almas-de-run eliminadas en Capa N1.
		_soltar_cofre(pos)
		# ¿Queda otro jefe vivo? (futuras capas pueden invocar varios)
		var otro_jefe: Node = null
		for e in get_tree().get_nodes_in_group("enemigos"):
			if e != enemigo and e.es_jefe:
				otro_jefe = e
				break
		if otro_jefe:
			jefe = otro_jefe
			hud.mostrar_jefe(NOMBRES_JEFES.get(otro_jefe.tipo, "JEFE"))
		else:
			hud.ocultar_jefe()
			_completar_nivel()
	elif enemigo.es_elite and randf() < 0.2:
		_soltar_cofre(pos)
	elif enemigo.tipo in ["demonio_menor", "caballero_oscuro"] and randf() < 0.06:
		_soltar_cofre(pos)


func _invocar_aliado(pos: Vector3) -> void:
	var aliado := CharacterBody3D.new()
	aliado.set_script(AliadoScript)
	add_child(aliado)
	aliado.global_position = Vector3(pos.x, 1.2, pos.z)
	var nv_pacto: int = jugador.nivel_habilidad("pacto_almas") if is_instance_valid(jugador) else 0
	if nv_pacto > 0:
		aliado.vida_util += 4.0 * nv_pacto
		aliado.dano *= 1.0 + 0.5 * nv_pacto
	var nv_huesos: int = jugador.nivel_habilidad("huesos_frios") if is_instance_valid(jugador) else 0
	if nv_huesos > 0:
		aliado.explosion_dano = 30.0 * nv_huesos


func _al_invocar_aliados(cantidad: int) -> void:
	for i in cantidad:
		var angulo := randf() * TAU
		_invocar_aliado(jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * 1.6)


func _soltar_gema(pos: Vector3, valor: float) -> void:
	# Tope de gemas: el exceso se fusiona con la más cercana (estilo VS)
	var gemas := get_tree().get_nodes_in_group("gemas")
	if gemas.size() >= 80:
		var cercana: Node3D = null
		var mejor := INF
		for g in gemas:
			var d: float = g.global_position.distance_to(pos)
			if d < mejor:
				mejor = d
				cercana = g
		if cercana:
			cercana.valor += valor
			return
	var gema := Node3D.new()
	gema.set_script(GemaScript)
	gema.valor = valor
	add_child(gema)
	gema.global_position = Vector3(pos.x, 0.5, pos.z)


func _soltar_cofre(pos: Vector3) -> void:
	var cofre := Node3D.new()
	cofre.set_script(CofreScript)
	cofre.abierto.connect(_al_abrir_cofre)
	add_child(cofre)
	cofre.global_position = Vector3(pos.x, 0.5, pos.z)


func _al_abrir_cofre() -> void:
	Efectos.sonido(self, "cofre")
	mejoras_pendientes += 1
	_mostrar_mejoras_si_toca()


# --- Eventos dinámicos ------------------------------------------------------

func _evento_aleatorio() -> void:
	if not partida_activa or get_tree().paused:
		return
	match ["lluvia_sangre", "invasion_elite", "altar_maldito", "eclipse"].pick_random():
		"lluvia_sangre":
			hud.anunciar("LLUVIA DE SANGRE", Color(1.0, 0.2, 0.2))
			_mult_vel_evento = 1.4
			_prob_oro = 0.6
			get_tree().call_group("enemigos", "set", "mult_evento", 1.4)
			_temporizar(20.0, _fin_evento_velocidad)
		"invasion_elite":
			hud.anunciar("INVASIÓN ÉLITE", Color(1.0, 0.7, 0.2))
			for i in 6:
				_generar_enemigo(_tipo_aleatorio(), true)
		"altar_maldito":
			hud.anunciar("UN ALTAR MALDITO EMERGE", Color(0.8, 0.3, 1.0))
			_soltar_altar()
		"eclipse":
			hud.anunciar("ECLIPSE", Color(0.6, 0.6, 0.9))
			_entorno.fog_density = 0.06
			_mult_vel_evento = 0.7
			get_tree().call_group("enemigos", "set", "mult_evento", 0.7)
			_temporizar(15.0, _fin_eclipse)


func _fin_evento_velocidad() -> void:
	_mult_vel_evento = 1.0
	_prob_oro = 0.25
	get_tree().call_group("enemigos", "set", "mult_evento", 1.0)


func _fin_eclipse() -> void:
	_entorno.fog_density = 0.012
	_fin_evento_velocidad()


func _temporizar(segundos: float, accion: Callable) -> void:
	var temporizador := Timer.new()
	temporizador.one_shot = true
	temporizador.wait_time = segundos
	temporizador.timeout.connect(accion)
	temporizador.timeout.connect(temporizador.queue_free)
	add_child(temporizador)
	temporizador.start()


func _soltar_altar() -> void:
	if not is_instance_valid(jugador):
		return
	var altar := Node3D.new()
	altar.set_script(AltarScript)
	altar.tocado.connect(_al_tocar_altar)
	add_child(altar)
	var angulo := randf() * TAU
	var pos := _limitar_pos(jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(6.0, 10.0))
	altar.global_position = Vector3(pos.x, 0.0, pos.z)


func _al_tocar_altar() -> void:
	Efectos.sonido(self, "cofre")
	jugador.anadir_corrupcion(20.0)
	hud.anunciar("PODER A CAMBIO DE CORRUPCIÓN", Color(0.8, 0.3, 1.0))
	mejoras_pendientes += 1


# --- Pausa y fin de partida -------------------------------------------------

func _actualizar_slots_habilidad() -> void:
	var lista: Array = jugador.activas()
	var teclas := ["E", "R"]
	for i in lista.size():
		if jugador.nivel_habilidad(lista[i].id) > 0:
			hud.configurar_habilidad(i, "%s · %s" % [teclas[i], lista[i].nombre])
	if controles:
		controles.refrescar_habilidades()


func _conmutar_pausa() -> void:
	if menu.visible or not partida_activa or menu_ajustes.visible:
		return
	var pausado := not get_tree().paused
	get_tree().paused = pausado
	menu_pausa.visible = pausado


func _aplicar_graficos() -> void:
	if _entorno:
		_entorno.glow_enabled = bool(_estado.ajustes.glow)
	if _luz:
		_luz.shadow_enabled = bool(_estado.ajustes.sombras)


func _salir_al_menu() -> void:
	if oro_partida > 0 and partida_activa:
		_estado.oro_total += oro_partida
		_estado.pase_xp += oro_partida
		_estado.evento("oro_ganado", oro_partida)
		_estado.guardar()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")


func _victoria() -> void:
	if not partida_activa:
		return
	partida_activa = false
	sonido_mgr.detener_musica()
	oro_partida = int(oro_partida * 1.5)
	_estado.oro_total += oro_partida
	_estado.pase_xp += oro_partida
	_estado.evento("oro_ganado", oro_partida)
	_estado.evento("victorias")
	_estado.guardar()
	get_tree().paused = true
	_go_titulo.text = "¡VICTORIA!"
	EstiloUI.titulo_epico(_go_titulo, 38, Color(1.0, 0.85, 0.3))
	Efectos.sonido(self, "levelup", 2.0)
	_refrescar_game_over()
	_go_seguir.visible = true
	_capa_game_over.visible = true
	# El oro ya quedó bancado: la continuación acumula desde cero
	oro_partida = 0


func _estrellas_por_tiempo(t: float) -> int:
	return NivelesScript.estrellas_por_tiempo(nivel_actual, t)


func _completar_nivel() -> void:
	if not partida_activa:
		return
	partida_activa = false
	sonido_mgr.detener_musica()
	# Banca el oro de la run al meta (igual que _victoria) con bonus de complecion.
	oro_partida = int(oro_partida * 1.5)
	_estado.oro_total += oro_partida
	_estado.pase_xp += oro_partida
	_estado.evento("oro_ganado", oro_partida)
	_estado.evento("victorias")
	# Desbloquea el siguiente nivel.
	_estado.desbloquear_nivel(nivel_actual + 1)
	var estrellas := _estrellas_por_tiempo(tiempo)
	_estado.registrar_estrellas(nivel_actual, estrellas)
	_estado.guardar()
	oro_partida = 0
	get_tree().paused = true
	var glifos := "★".repeat(estrellas) + "☆".repeat(3 - estrellas)
	_go_titulo.text = "NIVEL %d COMPLETADO  %s" % [nivel_actual + 1, glifos]
	EstiloUI.titulo_epico(_go_titulo, 38, Color(1.0, 0.85, 0.3))
	Efectos.sonido(self, "levelup", 2.0)
	_refrescar_game_over()
	_go_seguir.visible = false
	_capa_game_over.visible = true


func _continuar_tras_victoria() -> void:
	_capa_game_over.visible = false
	_go_seguir.visible = false
	get_tree().paused = false
	partida_activa = true
	hud.actualizar_oro(oro_partida)
	sonido_mgr.tocar_musica("res://audio/musica.wav")
	hud.anunciar("MODO INFINITO", Color(0.85, 0.4, 1.0))


func _game_over() -> void:
	if not partida_activa:
		return
	partida_activa = false
	_go_titulo.text = "HAS CAÍDO"
	EstiloUI.titulo_epico(_go_titulo, 38, EstiloUI.CARMESI)
	_go_seguir.visible = false
	sonido_mgr.detener_musica()
	_estado.oro_total += oro_partida
	_estado.pase_xp += oro_partida
	_estado.evento("oro_ganado", oro_partida)
	_estado.evento("muertes")
	_estado.guardar()
	get_tree().paused = true
	_refrescar_game_over()
	_capa_game_over.visible = true


func _crear_game_over() -> void:
	_capa_game_over = CanvasLayer.new()
	_capa_game_over.layer = 30
	_capa_game_over.process_mode = Node.PROCESS_MODE_ALWAYS
	_capa_game_over.visible = false
	add_child(_capa_game_over)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.75)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_game_over.add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_game_over.add_child(centro)
	var panel := PanelContainer.new()
	panel.theme = EstiloUI.tema()
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	_go_titulo = Label.new()
	_go_titulo.text = "HAS CAÍDO"
	_go_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(_go_titulo, 38, EstiloUI.CARMESI)
	caja.add_child(_go_titulo)
	_go_stats = Label.new()
	_go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_go_stats)
	_go_oro_total = Label.new()
	_go_oro_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_oro_total.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(_go_oro_total)
	var subtitulo := Label.new()
	subtitulo.text = "Talentos permanentes:"
	caja.add_child(subtitulo)
	for clave in _estado.talentos.keys():
		var boton := Button.new()
		boton.pressed.connect(_comprar_talento.bind(clave))
		caja.add_child(boton)
		_go_botones_talentos[clave] = boton
	_go_seguir = Button.new()
	_go_seguir.text = "SEGUIR JUGANDO (∞)"
	_go_seguir.add_theme_font_size_override("font_size", 18)
	_go_seguir.visible = false
	_go_seguir.pressed.connect(_continuar_tras_victoria)
	caja.add_child(_go_seguir)
	var reiniciar := Button.new()
	reiniciar.text = "JUGAR DE NUEVO"
	reiniciar.add_theme_font_size_override("font_size", 20)
	reiniciar.pressed.connect(_reiniciar)
	caja.add_child(reiniciar)
	# Monetización (sec. 18): anuncio recompensado SIMULADO.
	# TODO: en el build Android conectar con el plugin de AdMob (rewarded ad).
	var anuncio := Button.new()
	anuncio.text = "▶ VER ANUNCIO · +50 ORO"
	anuncio.add_theme_font_size_override("font_size", 15)
	anuncio.pressed.connect(func() -> void:
		anuncio.disabled = true
		anuncio.text = "Viendo anuncio…"
		await get_tree().create_timer(3.0, true).timeout
		_estado.oro_total += 50
		_estado.guardar()
		anuncio.text = "✓ RECOMPENSA RECIBIDA"
		_refrescar_game_over())
	caja.add_child(anuncio)
	var salir := Button.new()
	salir.text = "SALIR AL MENÚ"
	salir.add_theme_font_size_override("font_size", 16)
	salir.pressed.connect(_salir_al_menu)
	caja.add_child(salir)


func _refrescar_game_over() -> void:
	var s := int(tiempo)
	_go_stats.text = "Sobreviviste %02d:%02d  ·  Bajas: %d  ·  Almas: %d" % [s / 60, s % 60, kills, oro_partida]
	_go_oro_total.text = "Oro total: %d" % _estado.oro_total
	for clave in _go_botones_talentos:
		var boton: Button = _go_botones_talentos[clave]
		if int(_estado.talentos[clave]) >= _estado.TALENTO_MAX:
			boton.text = "%s  —  ★ MÁXIMO" % _estado.NOMBRES_TALENTOS[clave]
			boton.disabled = true
		else:
			boton.text = "%s  Nv.%d  —  %d oro" % [_estado.NOMBRES_TALENTOS[clave], _estado.talentos[clave], _estado.costo_talento(clave)]
			boton.disabled = _estado.oro_total < _estado.costo_talento(clave)


func _comprar_talento(clave: String) -> void:
	if _estado.comprar_talento(clave):
		_refrescar_game_over()


func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
