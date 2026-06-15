extends ArmaBase
## Espada Giratoria: espadas REALES (modelo KayKit) que orbitan al jugador.
## Evolución: Tormenta de Cuchillas (más hojas, giro y daño).

const RADIO_ORBITA := 1.9
const INTERVALO_DANO := 0.35
const MODELO_ESPADA := "res://art/models/armas/sword_1handed.gltf"

var velocidad_giro := 3.2
var sinergia_fuego := false
var mult_forja := 1.0

var _pivote: Node3D
var _tick := 0.0


func nombre() -> String:
	return "Espada Giratoria"


func nombre_evolucion() -> String:
	return "Tormenta de Cuchillas"


func activar_sinergia_fuego() -> void:
	sinergia_fuego = true
	_reconstruir_hojas()


func _ready() -> void:
	_pivote = Node3D.new()
	add_child(_pivote)
	_reconstruir_hojas()


func _al_mejorar() -> void:
	_reconstruir_hojas()


func _al_evolucionar() -> void:
	velocidad_giro = 5.2
	_reconstruir_hojas()


func _crear_hoja() -> Node3D:
	if ResourceLoader.exists(MODELO_ESPADA):
		var espada: Node3D = (load(MODELO_ESPADA) as PackedScene).instantiate()
		espada.scale = Vector3.ONE * 1.25
		# Acostada, con la punta hacia fuera de la órbita
		espada.rotation = Vector3(-PI / 2.0, 0, 0)
		return espada
	# Fallback procedural si falta el modelo
	var malla := BoxMesh.new()
	malla.size = Vector3(0.15, 0.06, 1.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.65, 1.0)
	malla.material = mat
	var hoja := MeshInstance3D.new()
	hoja.mesh = malla
	return hoja


func _reconstruir_hojas() -> void:
	for hijo in _pivote.get_children():
		hijo.queue_free()
	var cantidad := 1 + nivel + (4 if evolucionada else 0)
	var color_estela := Color(0.45, 0.65, 1.0)
	if sinergia_fuego:
		color_estela = Color(1.0, 0.3, 0.1)
	elif evolucionada:
		color_estela = Color(1.0, 0.6, 0.2)
	for i in cantidad:
		var soporte := Node3D.new()
		var angulo := TAU * i / cantidad
		soporte.position = Vector3(cos(angulo) * RADIO_ORBITA, 0.5, sin(angulo) * RADIO_ORBITA)
		soporte.rotation.y = -angulo
		soporte.add_child(_crear_hoja())
		# Estela de energía bajo la espada (feedback de evolución/sinergia)
		var estela_malla := BoxMesh.new()
		estela_malla.size = Vector3(0.1, 0.03, 0.9)
		var mat_estela := StandardMaterial3D.new()
		mat_estela.albedo_color = Color(color_estela.r, color_estela.g, color_estela.b, 0.65)
		mat_estela.emission_enabled = true
		mat_estela.emission = color_estela
		mat_estela.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_estela.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		estela_malla.material = mat_estela
		var estela := MeshInstance3D.new()
		estela.mesh = estela_malla
		estela.position.y = -0.06
		soporte.add_child(estela)
		_pivote.add_child(soporte)


func _process(delta: float) -> void:
	_pivote.rotation.y += velocidad_giro * delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = INTERVALO_DANO / jugador.stats.mult_cadencia()
	var alcance := RADIO_ORBITA + (1.4 if evolucionada else 0.9)
	var base := (8.0 + 3.5 * nivel) * mult_forja
	if evolucionada:
		base *= 1.8
	if sinergia_fuego:
		base *= 1.3
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		if enemigo.global_position.distance_to(jugador.global_position) <= alcance:
			enemigo.recibir_dano(jugador.calcular_dano(base, "melee"))
