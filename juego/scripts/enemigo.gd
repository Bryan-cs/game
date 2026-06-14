extends CharacterBody3D
## Enemigo genérico: el tipo define stats y aspecto (GDD secciones 11 y 12).
## Cuerpo humanoide procedural con animación de paso.

signal murio(enemigo: Node)
signal pide_esbirros(pos: Vector3, cantidad: int)

const TIPOS := {
	"zombie": {"vida": 30.0, "velocidad": 2.0, "dano": 8.0, "xp": 1.0, "color": Color(0.35, 0.6, 0.3), "escala": 1.0,
		"modelo": "res://art/models/skeletons/Skeleton_Rogue.glb", "escala_modelo": 0.62},
	"esqueleto": {"vida": 20.0, "velocidad": 3.2, "dano": 6.0, "xp": 1.0, "color": Color(0.9, 0.9, 0.85), "escala": 0.9,
		"modelo": "res://art/models/skeletons/Skeleton_Minion.glb", "escala_modelo": 0.6},
	"arana_gigante": {"vida": 15.0, "velocidad": 4.2, "dano": 5.0, "xp": 2.0, "color": Color(0.35, 0.18, 0.45), "escala": 0.7},
	"demonio_menor": {"vida": 55.0, "velocidad": 2.6, "dano": 12.0, "xp": 3.0, "color": Color(0.75, 0.2, 0.15), "escala": 1.1,
		"modelo": "res://art/models/skeletons/Skeleton_Mage.glb", "escala_modelo": 0.78},
	"caballero_oscuro": {"vida": 130.0, "velocidad": 1.8, "dano": 18.0, "xp": 5.0, "color": Color(0.22, 0.22, 0.3), "escala": 1.25,
		"modelo": "res://art/models/skeletons/Skeleton_Warrior.glb", "escala_modelo": 0.8},
	"gigante_putrefacto": {"vida": 1600.0, "velocidad": 1.6, "dano": 30.0, "xp": 50.0, "color": Color(0.45, 0.55, 0.25), "escala": 3.0,
		"modelo": "res://art/models/skeletons/Skeleton_Warrior.glb", "escala_modelo": 2.2},
	"senor_sombras": {"vida": 3200.0, "velocidad": 2.2, "dano": 35.0, "xp": 90.0, "color": Color(0.3, 0.2, 0.45), "escala": 2.6,
		"modelo": "res://art/models/skeletons/Skeleton_Rogue.glb", "escala_modelo": 2.0},
	"rey_vacio": {"vida": 5200.0, "velocidad": 1.4, "dano": 40.0, "xp": 150.0, "color": Color(0.4, 0.2, 0.6), "escala": 3.2,
		"modelo": "res://art/models/skeletons/Skeleton_Mage.glb", "escala_modelo": 2.4},
}

const JEFES := ["gigante_putrefacto", "senor_sombras", "rey_vacio"]

var tipo := "zombie"
var es_jefe := false
var es_elite := false
var mult_evento := 1.0
var vida_max := 30.0
var vida := 30.0
var velocidad := 2.0
var dano := 8.0
var xp := 1.0
var radio_golpe := 1.4

var _jugador: Node3D
var _cd_golpe := 0.0
var _flash := 0.0
var _empuje := Vector3.ZERO
var _fase_paso := 0.0
var _material: StandardMaterial3D
var _partes: Dictionary
var _modelo: Node3D
var _estado: Node
var _barra: Node3D
var _barra_relleno: MeshInstance3D
var _anim_modelo: AnimationPlayer
var _num_acumulado := 0.0
var _num_cd := 0.0
var _congelado := 0.0
var _veneno_dps := 0.0
var _veneno_t := 0.0
var _veneno_tick := 0.0
var _hab_jefe_cd := 4.0
var _ranged_jefe_cd := 2.5


func congelar(segundos: float) -> void:
	_congelado = maxf(_congelado, segundos)


func envenenar(dps: float, segundos: float) -> void:
	_veneno_dps = maxf(_veneno_dps, dps)
	_veneno_t = maxf(_veneno_t, segundos)


func configurar(nuevo_tipo: String, escala_dificultad: float = 1.0) -> void:
	tipo = nuevo_tipo
	es_jefe = tipo in JEFES
	var datos: Dictionary = TIPOS[tipo]
	vida_max = datos.vida * escala_dificultad
	vida = vida_max
	velocidad = datos.velocidad
	# El daño escala a la mitad del ritmo que la vida (+6%/oleada efectivo)
	dano = datos.dano * (1.0 + (escala_dificultad - 1.0) * 0.5)
	xp = datos.xp
	radio_golpe = 0.9 + 0.7 * datos.escala


func configurar_elite() -> void:
	es_elite = true
	vida_max *= 3.0
	vida = vida_max
	dano *= 1.5
	xp *= 3.0


func _ready() -> void:
	add_to_group("enemigos")
	collision_layer = 4
	collision_mask = 1 | 4
	_estado = get_node(^"/root/Estado")
	var datos: Dictionary = TIPOS[tipo]
	_crear_barra_vida(1.9 * float(datos.escala) + (0.5 if es_elite else 0.0))
	var escala: float = datos.escala
	var ruta_modelo: String = datos.get("modelo", "")
	if ruta_modelo != "" and ResourceLoader.exists(ruta_modelo):
		_modelo = (load(ruta_modelo) as PackedScene).instantiate()
		var em: float = datos.get("escala_modelo", 0.7) * (1.3 if es_elite else 1.0)
		_modelo.scale = Vector3.ONE * em
		_modelo.position.y = -0.8 * escala
		add_child(_modelo)
		_anim_modelo = _modelo.find_child("AnimationPlayer", true, false)
		if _anim_modelo and _anim_modelo.has_animation("Running_A"):
			_anim_modelo.get_animation("Running_A").loop_mode = Animation.LOOP_LINEAR
			_anim_modelo.play("Running_A")
			_anim_modelo.speed_scale = randf_range(0.9, 1.1)
			# Pausar la animación cuando el enemigo queda fuera de pantalla
			var notificador := VisibleOnScreenNotifier3D.new()
			notificador.aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3.5, 2))
			add_child(notificador)
			notificador.screen_exited.connect(func() -> void:
				if _anim_modelo:
					_anim_modelo.pause())
			notificador.screen_entered.connect(func() -> void:
				if _anim_modelo and not _anim_modelo.is_playing():
					_anim_modelo.play("Running_A"))
	else:
		_partes = Cuerpos.humanoide(datos.color, escala)
		_material = _partes.material
		_partes.raiz.position.y = 0.8 * escala - 0.8
		Equipo.adornar_enemigo(_partes, tipo)
		if es_elite:
			_partes.raiz.scale *= 1.3
		add_child(_partes.raiz)
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4 * escala
	forma.height = 1.6 * escala
	var colision := CollisionShape3D.new()
	colision.shape = forma
	colision.position.y = 0.8 * escala - 0.8
	add_child(colision)


func _physics_process(delta: float) -> void:
	_cd_golpe = maxf(0.0, _cd_golpe - delta)
	_flash = maxf(0.0, _flash - delta)
	_num_cd = maxf(0.0, _num_cd - delta)
	if _num_acumulado > 0.0 and _num_cd <= 0.0:
		_emitir_numero()
	_congelado = maxf(0.0, _congelado - delta)
	if _veneno_t > 0.0:
		_veneno_t -= delta
		_veneno_tick -= delta
		if _veneno_tick <= 0.0:
			_veneno_tick = 0.5
			recibir_dano(_veneno_dps * 0.5)
	if _material:
		_material.emission_enabled = _flash > 0.0 or es_elite
		_material.emission = Color(1, 0.6, 0.6) if _flash > 0.0 else Color(0.28, 0.22, 0.05)
	elif _modelo:
		_modelo.visible = _flash <= 0.0 or fmod(_flash * 30.0, 2.0) < 1.0
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	var direccion := _jugador.global_position - global_position
	direccion.y = 0.0
	var distancia := direccion.length()
	var factor_frio := 0.25 if _congelado > 0.0 else 1.0
	if distancia > 0.1:
		direccion = direccion.normalized()
		velocity.x = direccion.x * velocidad * mult_evento * factor_frio + _empuje.x
		velocity.z = direccion.z * velocidad * mult_evento * factor_frio + _empuje.z
		var raiz: Node3D = _modelo if _modelo else _partes.raiz
		raiz.rotation.y = atan2(direccion.x, direccion.z)
	else:
		velocity.x = _empuje.x
		velocity.z = _empuje.z
	_empuje = _empuje.lerp(Vector3.ZERO, minf(8.0 * delta, 1.0))
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	if not _partes.is_empty():
		_fase_paso += delta * velocidad * 2.4
		Cuerpos.animar_paso(_partes, _fase_paso, 1.0)
		if tipo == "zombie":
			# Pose clásica: brazos extendidos hacia delante
			_partes.brazo_i.rotation.x = -1.35 + sin(_fase_paso) * 0.15
			_partes.brazo_d.rotation.x = -1.35 - sin(_fase_paso) * 0.15
	if distancia <= radio_golpe and _cd_golpe <= 0.0:
		_cd_golpe = 1.0
		_jugador.recibir_dano(dano)
	if es_jefe:
		_hab_jefe_cd -= delta
		if _hab_jefe_cd <= 0.0:
			_habilidad_jefe(distancia)
		# Todos los jefes atacan a distancia: orbe dirigido cada 3.5 s
		_ranged_jefe_cd -= delta
		if _ranged_jefe_cd <= 0.0 and distancia > 4.0:
			_ranged_jefe_cd = 3.5
			var orbe := Area3D.new()
			orbe.set_script(preload("res://scripts/proyectil_vacio.gd"))
			get_tree().current_scene.add_child(orbe)
			orbe.global_position = global_position + Vector3.UP * 1.5
			var hacia: Vector3 = _jugador.global_position - global_position
			hacia.y = 0.0
			orbe.direccion = hacia.normalized()
			orbe.dano = dano * 0.5
			orbe.velocidad = 10.0


func _habilidad_jefe(distancia: float) -> void:
	match tipo:
		"gigante_putrefacto":
			# Slam telegrafiado: anillo de aviso y golpe en área tras 1 s
			if distancia > 9.0:
				return
			_hab_jefe_cd = 6.0
			var centro: Vector3 = _jugador.global_position
			Efectos.onda(get_tree().current_scene, centro, 4.5, Color(1.0, 0.2, 0.15))
			var aviso := get_tree().create_timer(1.0)
			var dano_slam := dano * 1.6
			aviso.timeout.connect(func() -> void:
				if not is_instance_valid(self) or _jugador == null or not is_instance_valid(_jugador):
					return
				Efectos.explosion_grande(get_tree().current_scene, centro, Color(0.6, 0.7, 0.3))
				Efectos.sonido(self, "nova", -2.0)
				if _jugador.global_position.distance_to(centro) <= 4.5:
					_jugador.recibir_dano(dano_slam))
		"senor_sombras":
			# Se teletransporta junto al jugador e invoca esbirros
			_hab_jefe_cd = 8.0
			Efectos.explosion(get_tree().current_scene, global_position + Vector3.UP, Color(0.3, 0.2, 0.45), 24)
			var dir := (global_position - _jugador.global_position).normalized()
			global_position = _jugador.global_position + dir * 4.0
			Efectos.explosion(get_tree().current_scene, global_position + Vector3.UP, Color(0.5, 0.3, 0.7), 24)
			Efectos.sonido(self, "dash", 0.0)
			pide_esbirros.emit(global_position, 4)
		"rey_vacio":
			# Lanza una ráfaga de orbes de vacío al jugador
			_hab_jefe_cd = 5.0
			for k in 3:
				var orbe := Area3D.new()
				orbe.set_script(preload("res://scripts/proyectil_vacio.gd"))
				get_tree().current_scene.add_child(orbe)
				orbe.global_position = global_position + Vector3.UP * 1.5
				var hacia: Vector3 = _jugador.global_position - global_position
				hacia.y = 0.0
				orbe.direccion = hacia.normalized().rotated(Vector3.UP, (k - 1) * 0.25)
				orbe.dano = dano * 0.7
			Efectos.sonido(self, "nova", -4.0)


func aplicar_empuje(fuerza: Vector3) -> void:
	_empuje = fuerza


func _crear_barra_vida(altura: float) -> void:
	_barra = Node3D.new()
	_barra.position.y = altura
	_barra.visible = false
	add_child(_barra)
	var fondo := MeshInstance3D.new()
	var malla_fondo := QuadMesh.new()
	malla_fondo.size = Vector2(1.0, 0.12)
	malla_fondo.material = _material_barra(Color(0.04, 0.04, 0.07, 0.85), 0)
	fondo.mesh = malla_fondo
	_barra.add_child(fondo)
	_barra_relleno = MeshInstance3D.new()
	var malla_relleno := QuadMesh.new()
	malla_relleno.size = Vector2(0.94, 0.07)
	malla_relleno.material = _material_barra(Color(0.88, 0.16, 0.2, 1.0), 1)
	_barra_relleno.mesh = malla_relleno
	_barra.add_child(_barra_relleno)


func _material_barra(color: Color, prioridad: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = prioridad
	return mat


func _actualizar_barra() -> void:
	if _barra == null:
		return
	var pct := clampf(vida / vida_max, 0.0, 1.0)
	_barra.visible = pct < 1.0 and vida > 0.0
	_barra_relleno.scale.x = maxf(pct, 0.02)


func _emitir_numero() -> void:
	if _estado and bool(_estado.ajustes.get("numeros_dano", true)):
		var color := Color(1.0, 0.72, 0.2) if _num_acumulado >= 30.0 else Color(1, 1, 1)
		Efectos.numero_dano(get_tree().current_scene, global_position + Vector3.UP * 1.4, _num_acumulado, color)
	_num_acumulado = 0.0
	_num_cd = 0.15


func recibir_dano(cantidad: float) -> void:
	if vida <= 0.0:
		return
	vida -= cantidad
	_flash = 0.12
	_actualizar_barra()
	_num_acumulado += cantidad
	if vida <= 0.0:
		_emitir_numero()
		murio.emit(self)
		queue_free()
