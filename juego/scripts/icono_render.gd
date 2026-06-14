class_name IconoRender
extends Node
## Renderiza una malla de ítem (de Equipo.malla_item) a una ImageTexture cacheada.

const EquipoScript := preload("res://scripts/equipo.gd")

static var _cache: Dictionary = {}


## Devuelve la textura del icono para 'tipo'. Asíncrono la 1ª vez (renderiza); cacheado luego.
## 'host' = un Node ya en el árbol (para añadir el SubViewport temporal).
func generar(tipo: String, host: Node) -> Texture2D:
	if _cache.has(tipo):
		return _cache[tipo]
	var malla := EquipoScript.malla_item(tipo)
	if malla == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, 35, 0)
	luz.light_energy = 1.4
	vp.add_child(luz)
	var amb := DirectionalLight3D.new()
	amb.rotation_degrees = Vector3(40, -120, 0)
	amb.light_energy = 0.5
	vp.add_child(amb)
	var pivote := Node3D.new()
	vp.add_child(pivote)
	pivote.add_child(malla)
	var cam := Camera3D.new()
	cam.position = Vector3(0, -0.5, 2.0)
	cam.fov = 40.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, -0.5, 0), Vector3.UP)
	# Esperar dos frames para que el render quede listo, luego leer la imagen.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	_cache[tipo] = tex
	vp.queue_free()
	return tex
