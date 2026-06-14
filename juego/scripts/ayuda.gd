extends Node3D
## Ayuda recogible: poción (cura), bomba (daño en área) o imán (atrae todas las gemas).
## Modelos KayKit Dungeon (botella/barril); el imán mantiene su aro azul.
## Desaparece a los 30 segundos si nadie la recoge.

signal recogida(tipo: String)

const MODELOS := {
	"pocion": "res://art/models/dungeon/bottle_A_green.glb",
	"bomba": "res://art/models/dungeon/barrel_small.glb",
}

var tipo := "pocion"

var _tiempo := 0.0
var _jugador: Node3D


func _ready() -> void:
	var ruta: String = MODELOS.get(tipo, "")
	if ruta != "" and ResourceLoader.exists(ruta):
		var modelo: Node3D = (load(ruta) as PackedScene).instantiate()
		modelo.scale = Vector3.ONE * (1.6 if tipo == "pocion" else 0.8)
		add_child(modelo)
		var halo := OmniLight3D.new()
		halo.light_color = Color(0.4, 1.0, 0.4) if tipo == "pocion" else Color(1.0, 0.55, 0.2)
		halo.light_energy = 0.9
		halo.omni_range = 2.2
		halo.position.y = 0.6
		add_child(halo)
	else:
		match tipo:
			"pocion":
				var botella := CylinderMesh.new()
				botella.top_radius = 0.1
				botella.bottom_radius = 0.14
				botella.height = 0.35
				botella.material = _material(Color(0.9, 0.15, 0.25))
				_anadir(botella, Vector3(0, 0.2, 0))
			"bomba":
				var esfera := SphereMesh.new()
				esfera.radius = 0.2
				esfera.height = 0.4
				esfera.material = _material(Color(0.15, 0.15, 0.18))
				_anadir(esfera, Vector3(0, 0.25, 0))
			"iman":
				pass
	if tipo == "iman":
		var aro := TorusMesh.new()
		aro.inner_radius = 0.12
		aro.outer_radius = 0.2
		aro.material = _material(Color(0.3, 0.6, 1.0))
		_anadir(aro, Vector3(0, 0.3, 0))


func _material(color: Color, brillo := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if brillo:
		mat.emission_enabled = true
		mat.emission = color
	return mat


func _anadir(malla: Mesh, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	mesh.position = pos
	add_child(mesh)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	rotation.y += delta * 2.0
	position.y = 0.25 + sin(_tiempo * 2.5) * 0.1
	if _tiempo > 30.0:
		queue_free()
		return
	if _jugador == null or not is_instance_valid(_jugador):
		var lista := get_tree().get_nodes_in_group("jugador")
		if lista.is_empty():
			return
		_jugador = lista[0]
	if global_position.distance_to(_jugador.global_position) <= 1.3:
		recogida.emit(tipo)
		queue_free()
