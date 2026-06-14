extends Node3D
## Gema de experiencia: atraída por el imán del jugador (GDD sección 7).

var valor := 1.0

var _jugador: Jugador
var _tiempo := 0.0
var _atraida := false


func atraer() -> void:
	_atraida = true


func _ready() -> void:
	add_to_group("gemas")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.35, 0.95)
	var malla := SphereMesh.new()
	malla.radius = 0.18
	malla.height = 0.36
	malla.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	add_child(mesh)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	position.y = 0.5 + sin(_tiempo * 3.0) * 0.12
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	var distancia := global_position.distance_to(_jugador.global_position)
	if _atraida or distancia <= _jugador.radio_iman:
		var direccion := (_jugador.global_position - global_position).normalized()
		global_position += direccion * (16.0 if _atraida else 11.0) * delta
	if distancia <= 0.8:
		_jugador.ganar_xp(valor)
		queue_free()
