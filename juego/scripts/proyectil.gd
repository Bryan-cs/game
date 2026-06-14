extends Area3D
## Proyectil genérico de armas: directo, perforante, explosivo o venenoso.

var direccion := Vector3.FORWARD
var velocidad := 14.0
var dano := 10.0
var radio_explosion := 0.0
var perforaciones_restantes := 0
var vida_util := 3.5
var veneno_dps := 0.0
var robo_vida := 0.0  # % del daño que cura al jugador al impactar


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	body_entered.connect(_al_golpear)


func _physics_process(delta: float) -> void:
	global_position += direccion * velocidad * delta
	vida_util -= delta
	if vida_util <= 0.0:
		queue_free()


func _al_golpear(cuerpo: Node3D) -> void:
	if not cuerpo.is_in_group("enemigos"):
		return
	if radio_explosion > 0.0:
		Efectos.explosion(get_tree().current_scene, global_position, Color(1.0, 0.5, 0.15), 28, 1.5)
		Efectos.sonido(self, "golpe", -4.0)
		for enemigo in get_tree().get_nodes_in_group("enemigos"):
			if enemigo.global_position.distance_to(global_position) <= radio_explosion:
				enemigo.recibir_dano(dano)
		_curar_jugador()
		queue_free()
		return
	Efectos.sonido(self, "golpe", -10.0)
	if veneno_dps > 0.0 and cuerpo.has_method("envenenar"):
		cuerpo.envenenar(veneno_dps, 3.0)
	cuerpo.recibir_dano(dano)
	_curar_jugador()
	if perforaciones_restantes <= 0:
		queue_free()
	else:
		perforaciones_restantes -= 1


func _curar_jugador() -> void:
	if robo_vida <= 0.0:
		return
	var lista := get_tree().get_nodes_in_group("jugador")
	if not lista.is_empty():
		lista[0].curar(dano * robo_vida / 100.0)
