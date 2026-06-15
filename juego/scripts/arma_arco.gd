extends ArmaBase
## Arco Automático: flechas rápidas y perforantes hacia el enemigo más cercano.
## Evolución: Juicio Celestial (abanico de tres flechas muy perforantes).

var sinergia_explosiva := false

var _cd := 0.0


func nombre() -> String:
	return "Arco Automático"


func nombre_evolucion() -> String:
	return "Juicio Celestial"


func _process(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var objetivo := _enemigo_mas_cercano()
	if objetivo == null:
		return
	_cd = maxf(0.08, (1.3 - 0.1 * nivel) / jugador.stats.mult_cadencia())
	var direccion := objetivo.global_position - jugador.global_position
	direccion.y = 0.0
	if direccion.length() < 0.1:
		return
	direccion = direccion.normalized()
	var angulos := [0.0]
	if evolucionada:
		angulos = [0.0, 0.26, -0.26]
	for angulo in angulos:
		var proyectil := _lanzar_proyectil(Color(0.95, 0.9, 0.4), 0.14)
		proyectil.direccion = direccion.rotated(Vector3.UP, angulo)
		proyectil.velocidad = 20.0
		var base := 8.0 + 3.0 * nivel
		if evolucionada:
			base *= 1.4
		proyectil.dano = jugador.calcular_dano(base, "distancia")
		proyectil.perforaciones_restantes = 1 + nivel / 2 + (3 if evolucionada else 0)
		if sinergia_explosiva:
			proyectil.radio_explosion = 1.2
