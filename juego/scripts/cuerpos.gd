class_name Cuerpos
extends Object
## Constructor de cuerpos humanoides procedurales (torso, cabeza, brazos, piernas)
## con pivotes para animación de paso.


static func humanoide(color: Color, escala: float) -> Dictionary:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var raiz := Node3D.new()
	raiz.name = "Cuerpo"

	var torso := MeshInstance3D.new()
	var malla_torso := CapsuleMesh.new()
	malla_torso.radius = 0.28
	malla_torso.height = 0.95
	malla_torso.material = mat
	torso.mesh = malla_torso
	torso.position.y = 0.15
	raiz.add_child(torso)

	var cabeza := MeshInstance3D.new()
	var malla_cabeza := SphereMesh.new()
	malla_cabeza.radius = 0.22
	malla_cabeza.height = 0.44
	malla_cabeza.material = mat
	cabeza.mesh = malla_cabeza
	cabeza.position.y = 0.85
	raiz.add_child(cabeza)

	var hacer_miembro := func(px: float, py: float, largo: float, radio: float) -> Node3D:
		var pivote := Node3D.new()
		pivote.position = Vector3(px, py, 0)
		var miembro := MeshInstance3D.new()
		var malla := CapsuleMesh.new()
		malla.radius = radio
		malla.height = largo
		malla.material = mat
		miembro.mesh = malla
		miembro.position.y = -largo * 0.5
		pivote.add_child(miembro)
		return pivote

	var brazo_i: Node3D = hacer_miembro.call(-0.38, 0.55, 0.6, 0.09)
	var brazo_d: Node3D = hacer_miembro.call(0.38, 0.55, 0.6, 0.09)
	var pierna_i: Node3D = hacer_miembro.call(-0.16, -0.3, 0.65, 0.11)
	var pierna_d: Node3D = hacer_miembro.call(0.16, -0.3, 0.65, 0.11)
	for pivote in [brazo_i, brazo_d, pierna_i, pierna_d]:
		raiz.add_child(pivote)
	raiz.scale = Vector3.ONE * escala
	return {
		"raiz": raiz,
		"material": mat,
		"torso": torso,
		"cabeza": cabeza,
		"brazo_i": brazo_i,
		"brazo_d": brazo_d,
		"pierna_i": pierna_i,
		"pierna_d": pierna_d,
	}


static func animar_paso(partes: Dictionary, fase: float, intensidad: float) -> void:
	var angulo := sin(fase) * 0.7 * clampf(intensidad, 0.0, 1.0)
	partes.pierna_i.rotation.x = angulo
	partes.pierna_d.rotation.x = -angulo
	partes.brazo_i.rotation.x = -angulo * 0.8
	partes.brazo_d.rotation.x = angulo * 0.8
