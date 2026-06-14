extends CharacterBody3D

const VELOCIDAD := 5.0
const VELOCIDAD_SALTO := 6.0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = VELOCIDAD_SALTO

	var direccion := Vector3.ZERO
	direccion.x = Input.get_axis("ui_left", "ui_right")
	direccion.z = Input.get_axis("ui_up", "ui_down")

	if direccion.length() > 0:
		direccion = direccion.normalized()
		velocity.x = direccion.x * VELOCIDAD
		velocity.z = direccion.z * VELOCIDAD
	else:
		velocity.x = move_toward(velocity.x, 0, VELOCIDAD)
		velocity.z = move_toward(velocity.z, 0, VELOCIDAD)

	move_and_slide()
