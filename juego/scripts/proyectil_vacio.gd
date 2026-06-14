extends Area3D
## Orbe de vacío del Rey del Vacío: daña al JUGADOR al contacto.

var direccion := Vector3.FORWARD
var velocidad := 9.0
var dano := 25.0
var _vida := 4.0
var _jugador: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.2, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.25, 0.9)
	var malla := SphereMesh.new()
	malla.radius = 0.32
	malla.height = 0.64
	malla.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	add_child(mesh)


func _physics_process(delta: float) -> void:
	global_position += direccion * velocidad * delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	var dh := Vector2(global_position.x - _jugador.global_position.x, global_position.z - _jugador.global_position.z)
	if dh.length() <= 0.9:
		_jugador.recibir_dano(dano)
		Efectos.explosion(get_tree().current_scene, global_position, Color(0.5, 0.25, 0.8), 16)
		queue_free()
