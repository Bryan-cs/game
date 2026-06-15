extends Node3D
## Drop de metaprogresión: libro que otorga 1 punto permanente de árbol de talentos.
## Fuentes: boss (garantizado), élite (20%). Desaparece a los 45 s.

signal recogido

var _tiempo := 0.0
var _jugador: Node3D


func _ready() -> void:
	var mat_tapa := StandardMaterial3D.new()
	mat_tapa.albedo_color = Color(0.14, 0.09, 0.28)
	mat_tapa.emission_enabled = true
	mat_tapa.emission = Color(0.48, 0.28, 0.82)
	mat_tapa.emission_energy_multiplier = 1.5
	var cuerpo := BoxMesh.new()
	cuerpo.size = Vector3(0.22, 0.30, 0.05)
	cuerpo.material = mat_tapa
	var libro := MeshInstance3D.new()
	libro.mesh = cuerpo
	libro.position.y = 0.32
	add_child(libro)
	var mat_gema := StandardMaterial3D.new()
	mat_gema.albedo_color = Color(1.0, 0.88, 0.28)
	mat_gema.emission_enabled = true
	mat_gema.emission = Color(1.0, 0.82, 0.18)
	mat_gema.emission_energy_multiplier = 2.2
	mat_gema.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var perla := SphereMesh.new()
	perla.radius = 0.045
	perla.height = 0.09
	perla.material = mat_gema
	var sello := MeshInstance3D.new()
	sello.mesh = perla
	sello.position = Vector3(0, 0.32, 0.028)
	add_child(sello)
	var halo := OmniLight3D.new()
	halo.light_color = Color(0.55, 0.3, 1.0)
	halo.light_energy = 1.5
	halo.omni_range = 3.2
	halo.position.y = 0.6
	add_child(halo)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	rotation.y += delta * 1.1
	position.y = 0.28 + sin(_tiempo * 2.2) * 0.12
	if _tiempo > 45.0:
		queue_free()
		return
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	if global_position.distance_to(_jugador.global_position) <= 1.4:
		recogido.emit()
		queue_free()
