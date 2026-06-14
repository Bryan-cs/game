extends CharacterBody3D
## Esqueleto aliado del Nigromante: persigue al enemigo más cercano y golpea.
## Con "Huesos Fríos" explota al expirar.

var dano := 10.0
var velocidad := 3.5
var vida_util := 12.0
var explosion_dano := 0.0

var _cd_golpe := 0.0
var _fase_paso := 0.0
var _partes: Dictionary


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_partes = Cuerpos.humanoide(Color(0.65, 0.72, 0.68), 0.85)
	add_child(_partes.raiz)
	var forma := CapsuleShape3D.new()
	forma.radius = 0.35
	forma.height = 1.4
	var colision := CollisionShape3D.new()
	colision.shape = forma
	add_child(colision)


func _physics_process(delta: float) -> void:
	vida_util -= delta
	if vida_util <= 0.0:
		if explosion_dano > 0.0:
			for enemigo in get_tree().get_nodes_in_group("enemigos"):
				if enemigo.global_position.distance_to(global_position) <= 3.0:
					enemigo.recibir_dano(explosion_dano)
			Efectos.explosion(get_parent(), global_position + Vector3.UP * 0.5, Color(0.5, 0.9, 0.6), 30, 1.6)
		else:
			Efectos.explosion(get_parent(), global_position, Color(0.65, 0.72, 0.68), 12)
		queue_free()
		return
	_cd_golpe = maxf(0.0, _cd_golpe - delta)
	var objetivo: Node3D = null
	var mejor := INF
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var d: float = enemigo.global_position.distance_to(global_position)
		if d < mejor:
			mejor = d
			objetivo = enemigo
	if objetivo == null:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var dir := objetivo.global_position - global_position
		dir.y = 0.0
		if dir.length() > 1.1:
			dir = dir.normalized()
			velocity.x = dir.x * velocidad
			velocity.z = dir.z * velocidad
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _cd_golpe <= 0.0:
				_cd_golpe = 0.8
				objetivo.recibir_dano(dano)
		if dir.length() > 0.1:
			_partes.raiz.rotation.y = atan2(dir.x, dir.z)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	_fase_paso += delta * velocidad * 2.4
	Cuerpos.animar_paso(_partes, _fase_paso, 1.0 if velocity.length() > 0.3 else 0.0)
