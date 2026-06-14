class_name Equipo
extends Object
## Armas de mano y adornos (skins) que diferencian visualmente a cada clase.
## Las armas se cuelgan del pivote del brazo: se mueven con la animación de ataque.


static func equipar(partes: Dictionary, clase: String) -> void:
	match clase:
		"guerrero":
			partes.brazo_d.add_child(_espada())
			partes.cabeza.add_child(_casco(Color(0.55, 0.2, 0.15)))
			_hombreras(partes, Color(0.5, 0.18, 0.12))
		"arquero":
			partes.brazo_i.add_child(_arco())
			partes.cabeza.add_child(_capucha(Color(0.12, 0.32, 0.16)))
		"mago":
			partes.brazo_d.add_child(_baston(Color(0.45, 0.6, 1.0)))
			partes.cabeza.add_child(_sombrero(Color(0.18, 0.22, 0.55)))
		"nigromante":
			partes.brazo_d.add_child(_baston(Color(0.35, 1.0, 0.45)))
			partes.cabeza.add_child(_capucha(Color(0.18, 0.08, 0.24)))
		"asesino":
			partes.brazo_d.add_child(_daga())
			partes.brazo_i.add_child(_daga())
			partes.cabeza.add_child(_bufanda())
		"paladin":
			partes.brazo_d.add_child(_martillo())
			partes.brazo_i.add_child(_escudo())
			partes.cabeza.add_child(_casco(Color(0.85, 0.7, 0.25)))


## Devuelve una malla 3D representativa de un tipo de ítem (para iconos y preview).
static func malla_item(tipo: String) -> Node3D:
	match tipo:
		"espada": return _espada()
		"arco": return _arco()
		"baston": return _baston(Color(0.5, 0.65, 1.0))
		"daga": return _daga()
		"martillo": return _martillo()
		"escudo": return _escudo()
		"casco": return _casco(Color(0.7, 0.7, 0.78))
		"coraza":
			var n := Node3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.5, 0.6, 0.28)
			m.material = _material(Color(0.55, 0.55, 0.62), true)
			n.add_child(_pieza(m, Vector3(0, -0.5, 0)))
			return n
		"botas":
			var n := Node3D.new()
			for lado in [-1.0, 1.0]:
				var m := BoxMesh.new()
				m.size = Vector3(0.18, 0.16, 0.34)
				m.material = _material(Color(0.4, 0.28, 0.18), true)
				n.add_child(_pieza(m, Vector3(0.13 * lado, -0.55, 0.05)))
			return n
		"anillo":
			var n := Node3D.new()
			var m := TorusMesh.new()
			m.inner_radius = 0.16
			m.outer_radius = 0.24
			m.material = _material(Color(0.95, 0.8, 0.3), true)
			n.add_child(_pieza(m, Vector3(0, -0.5, 0), Vector3(PI / 2.0, 0, 0)))
			return n
		_:
			var n := Node3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.3, 0.3, 0.3)
			m.material = _material(Color(0.6, 0.6, 0.6))
			n.add_child(_pieza(m, Vector3(0, -0.5, 0)))
			return n


static func adornar_enemigo(partes: Dictionary, tipo: String) -> void:
	match tipo:
		"zombie":
			var posiciones := [Vector3(-0.12, 0.1, 0.24), Vector3(0.1, -0.15, 0.24), Vector3(0.05, 0.28, 0.24)]
			for k in 3:
				var mancha := BoxMesh.new()
				mancha.size = Vector3(0.16, 0.12, 0.06)
				mancha.material = _material(Color(0.16, 0.3, 0.12))
				partes.torso.add_child(_pieza(mancha, posiciones[k]))
			var ojo := SphereMesh.new()
			ojo.radius = 0.05
			ojo.height = 0.1
			ojo.material = _material(Color(0.9, 0.85, 0.25), true)
			partes.cabeza.add_child(_pieza(ojo, Vector3(0.09, 0.0, 0.19)))
		"esqueleto":
			var craneo := SphereMesh.new()
			craneo.radius = 0.24
			craneo.height = 0.48
			craneo.material = _material(Color(0.93, 0.93, 0.88))
			partes.cabeza.add_child(_pieza(craneo, Vector3.ZERO))
		"arana_gigante":
			partes.raiz.scale.y *= 0.6
			for lado in [-1.0, 1.0]:
				for k in 3:
					var pata := BoxMesh.new()
					pata.size = Vector3(0.7, 0.05, 0.05)
					pata.material = _material(Color(0.2, 0.1, 0.28))
					var pieza := _pieza(pata, Vector3(0.5 * lado, 0.1 + k * 0.18, -0.25 + k * 0.25))
					pieza.rotation.z = 0.5 * lado
					partes.raiz.add_child(pieza)
		"demonio_menor":
			for lado in [-1.0, 1.0]:
				var cuerno := CylinderMesh.new()
				cuerno.top_radius = 0.0
				cuerno.bottom_radius = 0.06
				cuerno.height = 0.3
				cuerno.material = _material(Color(0.9, 0.8, 0.7))
				var pieza := _pieza(cuerno, Vector3(0.14 * lado, 0.22, 0))
				pieza.rotation.z = -0.4 * lado
				partes.cabeza.add_child(pieza)
		"caballero_oscuro":
			partes.cabeza.add_child(_casco(Color(0.15, 0.15, 0.2)))
			partes.brazo_i.add_child(_escudo())
		"gigante_putrefacto":
			var corona := CylinderMesh.new()
			corona.top_radius = 0.26
			corona.bottom_radius = 0.22
			corona.height = 0.18
			corona.material = _material(Color(0.8, 0.65, 0.15), true)
			partes.cabeza.add_child(_pieza(corona, Vector3(0, 0.18, 0)))


static func _material(color: Color, brillo := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if brillo:
		mat.emission_enabled = true
		mat.emission = color
	return mat


static func _pieza(malla: Mesh, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	mesh.position = pos
	mesh.rotation = rot
	return mesh


static func _espada() -> Node3D:
	var arma := Node3D.new()
	var mango := CylinderMesh.new()
	mango.top_radius = 0.035
	mango.bottom_radius = 0.035
	mango.height = 0.2
	mango.material = _material(Color(0.3, 0.2, 0.1))
	arma.add_child(_pieza(mango, Vector3(0, -0.58, 0)))
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.09, 0.85, 0.03)
	hoja.material = _material(Color(0.8, 0.85, 0.95), true)
	arma.add_child(_pieza(hoja, Vector3(0, -1.1, 0)))
	return arma


static func _arco() -> Node3D:
	var arma := Node3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = 0.26
	aro.outer_radius = 0.31
	aro.material = _material(Color(0.35, 0.22, 0.1))
	var pieza := _pieza(aro, Vector3(0, -0.55, 0), Vector3(PI / 2.0, 0, 0))
	pieza.scale = Vector3(0.55, 1.0, 1.0)
	arma.add_child(pieza)
	return arma


static func _baston(color_orbe: Color) -> Node3D:
	var arma := Node3D.new()
	var palo := CylinderMesh.new()
	palo.top_radius = 0.03
	palo.bottom_radius = 0.03
	palo.height = 1.2
	palo.material = _material(Color(0.3, 0.2, 0.12))
	arma.add_child(_pieza(palo, Vector3(0, -0.5, 0)))
	var orbe := SphereMesh.new()
	orbe.radius = 0.1
	orbe.height = 0.2
	orbe.material = _material(color_orbe, true)
	arma.add_child(_pieza(orbe, Vector3(0, 0.16, 0)))
	return arma


static func _daga() -> Node3D:
	var arma := Node3D.new()
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.05, 0.32, 0.02)
	hoja.material = _material(Color(0.75, 0.8, 0.85), true)
	arma.add_child(_pieza(hoja, Vector3(0, -0.75, 0)))
	return arma


static func _martillo() -> Node3D:
	var arma := Node3D.new()
	var mango := CylinderMesh.new()
	mango.top_radius = 0.035
	mango.bottom_radius = 0.035
	mango.height = 0.7
	mango.material = _material(Color(0.3, 0.2, 0.1))
	arma.add_child(_pieza(mango, Vector3(0, -0.8, 0)))
	var cabeza := BoxMesh.new()
	cabeza.size = Vector3(0.26, 0.15, 0.15)
	cabeza.material = _material(Color(0.6, 0.6, 0.65), true)
	arma.add_child(_pieza(cabeza, Vector3(0, -1.12, 0)))
	return arma


static func _escudo() -> Node3D:
	var arma := Node3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.32
	disco.bottom_radius = 0.32
	disco.height = 0.06
	disco.material = _material(Color(0.8, 0.65, 0.2), true)
	arma.add_child(_pieza(disco, Vector3(0, -0.5, -0.12), Vector3(PI / 2.0, 0, 0)))
	return arma


static func _casco(color: Color) -> Node3D:
	var adorno := Node3D.new()
	var aro := CylinderMesh.new()
	aro.top_radius = 0.24
	aro.bottom_radius = 0.245
	aro.height = 0.16
	aro.material = _material(color, true)
	adorno.add_child(_pieza(aro, Vector3(0, 0.08, 0)))
	return adorno


static func _capucha(color: Color) -> Node3D:
	var adorno := Node3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.25
	cono.height = 0.32
	cono.material = _material(color)
	adorno.add_child(_pieza(cono, Vector3(0, 0.2, 0)))
	return adorno


static func _sombrero(color: Color) -> Node3D:
	var adorno := Node3D.new()
	var ala := CylinderMesh.new()
	ala.top_radius = 0.33
	ala.bottom_radius = 0.33
	ala.height = 0.03
	ala.material = _material(color)
	adorno.add_child(_pieza(ala, Vector3(0, 0.08, 0)))
	var copa := CylinderMesh.new()
	copa.top_radius = 0.0
	copa.bottom_radius = 0.22
	copa.height = 0.45
	copa.material = _material(color)
	adorno.add_child(_pieza(copa, Vector3(0, 0.3, 0)))
	return adorno


static func _bufanda() -> Node3D:
	var adorno := Node3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = 0.16
	aro.outer_radius = 0.24
	aro.material = _material(Color(0.35, 0.35, 0.4))
	adorno.add_child(_pieza(aro, Vector3(0, -0.2, 0)))
	return adorno


static func _hombreras(partes: Dictionary, color: Color) -> void:
	for lado in [-1.0, 1.0]:
		var hombrera := BoxMesh.new()
		hombrera.size = Vector3(0.22, 0.12, 0.24)
		hombrera.material = _material(color)
		partes.raiz.add_child(_pieza(hombrera, Vector3(0.38 * lado, 0.72, 0)))
