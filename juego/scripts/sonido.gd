extends Node
## Gestor de SFX y música. Los .wav se generan proceduralmente en res://audio/.
## Volúmenes controlados por Estado.ajustes (vol_musica / vol_sfx).

const RUTAS := {
	"disparo": "res://audio/disparo.wav",
	"golpe": "res://audio/golpe.wav",
	"muerte": "res://audio/muerte.wav",
	"levelup": "res://audio/levelup.wav",
	"cofre": "res://audio/cofre.wav",
	"nova": "res://audio/nova.wav",
	"dash": "res://audio/dash.wav",
	"dano_jugador": "res://audio/dano_jugador.wav",
}

var _streams := {}
var _reproductores: Array[AudioStreamPlayer] = []
var _musica: AudioStreamPlayer
var _estado: Node


func _ready() -> void:
	add_to_group("sonido")
	_estado = get_node(^"/root/Estado")
	for clave in RUTAS:
		if ResourceLoader.exists(RUTAS[clave]):
			_streams[clave] = load(RUTAS[clave])
	for i in 12:
		var reproductor := AudioStreamPlayer.new()
		add_child(reproductor)
		_reproductores.append(reproductor)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	actualizar_volumenes()


func _db_sfx() -> float:
	return linear_to_db(maxf(0.01, float(_estado.ajustes.vol_sfx)))


func actualizar_volumenes() -> void:
	_musica.volume_db = -16.0 + linear_to_db(maxf(0.01, float(_estado.ajustes.vol_musica)))


func tocar(nombre: String, volumen_db := 0.0) -> void:
	if not _streams.has(nombre):
		return
	for reproductor in _reproductores:
		if not reproductor.playing:
			reproductor.stream = _streams[nombre]
			reproductor.volume_db = -8.0 + volumen_db + _db_sfx()
			reproductor.pitch_scale = randf_range(0.92, 1.08)
			reproductor.play()
			return


func tocar_musica(ruta: String) -> void:
	if not ResourceLoader.exists(ruta):
		return
	var stream = load(ruta)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	actualizar_volumenes()
	_musica.stream = stream
	_musica.play()


func detener_musica() -> void:
	_musica.stop()
