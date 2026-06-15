extends Node3D
## Drop de run: frasco rojo que cura 20% de vida máxima al recogerlo.
## Desaparece a los 30 s si nadie lo recoge.

signal recogido

const MODELO_RUTA := "res://art/models/dungeon/bottle_A_red.glb"

var _tiempo := 0.0
var _jugador: Node3D


func _ready() -> void:
	if ResourceLoader.exists(MODELO_RUTA):
		var modelo: Node3D = (load(MODELO_RUTA) as PackedScene).instantiate()
		modelo.scale = Vector3.ONE * 1.4
		add_child(modelo)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.12, 0.22)
		mat.emission_enabled = true
		mat.emission = Color(0.88, 0.08, 0.18)
		mat.emission_energy_multiplier = 1.6
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.12
		cyl.height = 0.28
		cyl.material = mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = cyl
		mesh.position.y = 0.2
		add_child(mesh)
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.22, 0.28)
	halo.light_energy = 1.1
	halo.omni_range = 2.4
	halo.position.y = 0.4
	add_child(halo)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	rotation.y += delta * 1.8
	position.y = 0.35 + sin(_tiempo * 2.8) * 0.1
	if _tiempo > 30.0:
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
