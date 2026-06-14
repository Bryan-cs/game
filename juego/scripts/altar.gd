extends Node3D
## Altar Maldito: tocarlo da una mejora gratis a cambio de corrupción.
## Usa el santuario de KayKit Halloween con aura púrpura; fallback obelisco.
## Desaparece a los 25 segundos si nadie lo toca.

signal tocado

const MODELO := "res://art/models/halloween/shrine_candles.gltf"

var _tiempo := 0.0
var _jugador: Node3D


func _ready() -> void:
	if ResourceLoader.exists(MODELO):
		var santuario: Node3D = (load(MODELO) as PackedScene).instantiate()
		add_child(santuario)
		var aura := OmniLight3D.new()
		aura.light_color = Color(0.6, 0.25, 0.95)
		aura.light_energy = 1.6
		aura.omni_range = 4.0
		aura.position.y = 1.4
		add_child(aura)
		var orbe_malla := SphereMesh.new()
		orbe_malla.radius = 0.16
		orbe_malla.height = 0.32
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.25, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.25, 0.95)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orbe_malla.material = mat
		var orbe := MeshInstance3D.new()
		orbe.mesh = orbe_malla
		orbe.name = "Orbe"
		orbe.position.y = 1.6
		add_child(orbe)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.15, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.2, 0.9)
		var malla := BoxMesh.new()
		malla.size = Vector3(0.5, 1.7, 0.5)
		malla.material = mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = malla
		mesh.position.y = 0.85
		add_child(mesh)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	var orbe := get_node_or_null("Orbe")
	if orbe:
		orbe.position.y = 1.6 + sin(_tiempo * 2.2) * 0.15
		orbe.rotate_y(delta * 2.0)
	if _tiempo > 25.0:
		queue_free()
		return
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	if global_position.distance_to(_jugador.global_position) <= 1.8:
		Efectos.explosion(get_parent(), global_position + Vector3.UP, Color(0.6, 0.2, 0.9), 30)
		tocado.emit()
		queue_free()
