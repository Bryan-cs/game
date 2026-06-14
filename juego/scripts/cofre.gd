extends Node3D
## Cofre: oro + una mejora gratis al recogerlo (GDD sección 4).
## Usa el modelo chest_gold de KayKit Dungeon; fallback a caja procedural.

signal abierto

const MODELO := "res://art/models/dungeon/chest_gold.glb"

var _tiempo := 0.0
var _jugador: Node3D


func _ready() -> void:
	if ResourceLoader.exists(MODELO):
		var cofre: Node3D = (load(MODELO) as PackedScene).instantiate()
		cofre.scale = Vector3.ONE * 0.85
		add_child(cofre)
		# Halo dorado para que se lea como botín
		var halo := OmniLight3D.new()
		halo.light_color = Color(1.0, 0.8, 0.3)
		halo.light_energy = 1.2
		halo.omni_range = 3.0
		halo.position.y = 0.8
		add_child(halo)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.65, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.45, 0.05)
		var malla := BoxMesh.new()
		malla.size = Vector3(0.7, 0.5, 0.5)
		malla.material = mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = malla
		add_child(mesh)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	rotation.y += delta * 1.2
	position.y = 0.15 + sin(_tiempo * 2.0) * 0.1
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	if global_position.distance_to(_jugador.global_position) <= 1.5:
		abierto.emit()
		queue_free()
