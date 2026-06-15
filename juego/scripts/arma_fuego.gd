extends ArmaBase
## Bola de Fuego: proyectil explosivo hacia el enemigo más cercano.
## Evolución: Lluvia de Meteoritos (tres proyectiles, explosión mayor).

var sinergia_plasma := false

var _cd := 0.0


func nombre() -> String:
	return "Bola de Fuego"


func nombre_evolucion() -> String:
	return "Lluvia de Meteoritos"


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var objetivo := _enemigo_mas_cercano()
	if objetivo == null:
		return
	_cd = maxf(0.25, (2.6 - 0.15 * nivel) / jugador.stats.mult_cadencia())
	var direccion := objetivo.global_position - jugador.global_position
	direccion.y = 0.0
	if direccion.length() < 0.1:
		return
	direccion = direccion.normalized()
	var angulos := [0.0]
	if evolucionada:
		angulos = [0.0, 0.6, -0.6]
	for angulo in angulos:
		var proyectil := _lanzar_proyectil(Color(1.0, 0.45, 0.1), 0.32)
		proyectil.direccion = direccion.rotated(Vector3.UP, angulo)
		proyectil.velocidad = 10.0
		var base := 18.0 + 7.0 * nivel
		if evolucionada:
			base *= 1.4
		proyectil.dano = jugador.calcular_dano(base, "distancia")
		proyectil.radio_explosion = (2.2 + 0.2 * nivel) * (1.5 if evolucionada else 1.0) * (1.3 if sinergia_plasma else 1.0)
