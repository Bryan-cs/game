extends CanvasLayer
## Tienda de cofres (gacha): abrir cofres y comprar gemas (stub de pago real). EQ4.

const EquipamientoScript := preload("res://scripts/equipamiento.gd")

## Paquetes de gemas (stub: acreditan sin billing real).
const PAQUETES_GEMAS := [
	{"gemas": 50, "etiqueta": "50 gemas · $0.99"},
	{"gemas": 120, "etiqueta": "120 gemas · $1.99"},
	{"gemas": 300, "etiqueta": "300 gemas · $4.99"},
]

var _estado: Node
var _monedas: Label
var _resultado: Label


func _ready() -> void:
	layer = 27
	visible = false
	_estado = get_node(^"/root/Estado")
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.06, 0.94)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.add_theme_constant_override("separation", 10)
	add_child(caja)

	var titulo := Label.new()
	titulo.text = "COFRES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EstiloUI.titulo_epico(titulo, 30)
	caja.add_child(titulo)

	_monedas = Label.new()
	_monedas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monedas.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(_monedas)

	# Botones de cofre
	for tipo in _estado.COFRES:
		var cofre: Dictionary = _estado.COFRES[tipo]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(480, 52)
		btn.text = "%s — %d %s" % [cofre.nombre, cofre.precio, cofre.moneda]
		var t := String(tipo)
		btn.pressed.connect(func() -> void: _abrir(t))
		caja.add_child(btn)

	_resultado = Label.new()
	_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resultado.custom_minimum_size = Vector2(480, 60)
	_resultado.add_theme_font_size_override("font_size", 16)
	caja.add_child(_resultado)

	var sub := Label.new()
	sub.text = "Comprar gemas"
	sub.add_theme_color_override("font_color", Color(0.6, 0.58, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(sub)
	for paq in PAQUETES_GEMAS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(480, 40)
		b.text = paq.etiqueta
		var n: int = paq.gemas
		b.pressed.connect(func() -> void:
			_estado.comprar_gemas(n)
			_refrescar()
			_resultado.text = "+%d gemas (compra simulada)" % n
			_resultado.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0)))
		caja.add_child(b)

	var cerrar := Button.new()
	cerrar.text = "CERRAR"
	cerrar.custom_minimum_size = Vector2(200, 44)
	cerrar.pressed.connect(func() -> void: visible = false)
	caja.add_child(cerrar)


func abrir() -> void:
	visible = true
	_resultado.text = ""
	_refrescar()


func _refrescar() -> void:
	_monedas.text = "Oro: %d     Gemas: %d" % [_estado.oro_total, _estado.gemas]


func _abrir(tipo: String) -> void:
	var pieza: Dictionary = _estado.abrir_cofre(tipo)
	_refrescar()
	if pieza.is_empty():
		_resultado.text = "Moneda insuficiente"
		_resultado.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return
	var rareza: String = pieza.get("rareza", "Común")
	var color: Color = EquipamientoScript.RAREZAS.get(rareza, {}).get("color", Color.WHITE)
	var afijos := ""
	for stat in pieza.get("afijos", {}):
		afijos += " +%s %s" % [str(pieza.afijos[stat]), stat]
	_resultado.text = "¡%s! %s%s" % [rareza, pieza.get("slot", "?"), afijos]
	_resultado.add_theme_color_override("font_color", color)
