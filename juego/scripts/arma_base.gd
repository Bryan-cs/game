extends Node3D
class_name ArmaBase
## Base de armas pasivas: nivel, mejora, evolución y utilidades de objetivo/proyectil.

const ProyectilScript := preload("res://scripts/proyectil.gd")

var nivel := 1
var evolucionada := false
var jugador: Jugador


func nombre() -> String:
	return "Arma"


func nombre_evolucion() -> String:
	return ""


func mejorar(niveles: int = 1) -> void:
	nivel += niveles
	_al_mejorar()


func evolucionar() -> void:
	evolucionada = true
	_al_evolucionar()


func _al_mejorar() -> void:
	pass


func _al_evolucionar() -> void:
	pass


func _enemigo_mas_cercano() -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := INF
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		var d: float = enemigo.global_position.distance_to(jugador.global_position)
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = enemigo
	return mejor


func _lanzar_proyectil(color: Color, tamano: float) -> Area3D:
	var proyectil := Area3D.new()
	proyectil.set_script(ProyectilScript)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	var malla := SphereMesh.new()
	malla.radius = tamano
	malla.height = tamano * 2.0
	malla.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = malla
	proyectil.add_child(mesh)
	var forma := SphereShape3D.new()
	forma.radius = maxf(tamano, 0.25)
	var colision := CollisionShape3D.new()
	colision.shape = forma
	proyectil.add_child(colision)
	get_tree().current_scene.add_child(proyectil)
	proyectil.global_position = jugador.global_position + Vector3.UP * 0.4
	return proyectil
