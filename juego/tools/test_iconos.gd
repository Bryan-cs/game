extends Node
const IconoRenderScript := preload("res://scripts/icono_render.gd")
const EquipamientoScript := preload("res://scripts/equipamiento.gd")

func _check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)

func _ready() -> void:
	var ir := IconoRenderScript.new()
	add_child(ir)
	var tex: Texture2D = await ir.generar("espada", self)
	_check("genera textura de espada", tex != null)
	var no_vacia := false
	if tex:
		var img := tex.get_image()
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				if img.get_pixel(x, y).a > 0.05:
					no_vacia = true
					break
			if no_vacia:
				break
	_check("el icono no está vacío (renderizó algo)", no_vacia)
	# tipo_visual presente al generar pieza de arma
	var rng := RandomNumberGenerator.new()
	var pieza := EquipamientoScript.generar("arma", "Rara", "ninguna", rng)
	_check("arma tiene tipo_visual", pieza.get("tipo_visual", "") in EquipamientoScript.TIPOS_ARMA)
	print("FIN TEST ICONOS")
	get_tree().quit()
