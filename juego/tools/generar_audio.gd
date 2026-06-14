extends Object
class_name GeneradorAudio
## Sintetiza los SFX y la música del juego como .wav en res://audio/.

const HZ := 22050


static func _guardar(nombre: String, muestras: PackedFloat32Array) -> void:
	var datos := PackedByteArray()
	datos.resize(muestras.size() * 2)
	for i in muestras.size():
		datos.encode_s16(i * 2, int(clampf(muestras[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = HZ
	wav.stereo = false
	wav.data = datos
	wav.save_to_wav("res://audio/%s.wav" % nombre)


static func generar_todo() -> Array:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	_disparo()
	_golpe()
	_muerte()
	_levelup()
	_cofre()
	_nova()
	_dash()
	_dano_jugador()
	_musica()
	_musica_jefe()
	return DirAccess.get_files_at("res://audio")


static func _disparo() -> void:
	var n := int(0.12 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / HZ
		var f := 700.0 - 450.0 * (float(i) / n)
		m[i] = sin(TAU * f * t) * exp(-12.0 * t) * 0.8
	_guardar("disparo", m)


static func _golpe() -> void:
	var n := int(0.08 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / HZ
		m[i] = randf_range(-1.0, 1.0) * exp(-30.0 * t) * 0.7
	_guardar("golpe", m)


static func _muerte() -> void:
	var n := int(0.25 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	var fase := 0.0
	for i in n:
		var t := float(i) / HZ
		var f := 280.0 - 210.0 * (float(i) / n)
		fase += f / HZ
		var sierra := 2.0 * (fase - floorf(fase)) - 1.0
		m[i] = (sierra * 0.6 + randf_range(-0.3, 0.3)) * exp(-6.0 * t) * 0.8
	_guardar("muerte", m)


static func _levelup() -> void:
	var notas := [523.25, 659.25, 783.99, 1046.5]
	var n := int(0.45 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / HZ
		var idx := mini(int(t / 0.11), notas.size() - 1)
		var tl := t - idx * 0.11
		m[i] = sin(TAU * notas[idx] * t) * exp(-8.0 * tl) * 0.6
	_guardar("levelup", m)


static func _cofre() -> void:
	var notas := [659.25, 987.77]
	var n := int(0.3 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / HZ
		var idx := mini(int(t / 0.14), notas.size() - 1)
		var tl := t - idx * 0.14
		m[i] = sin(TAU * notas[idx] * t) * exp(-7.0 * tl) * 0.6
	_guardar("cofre", m)


static func _nova() -> void:
	var n := int(0.35 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	var fase := 0.0
	for i in n:
		var prog := float(i) / n
		var f := 80.0 + 520.0 * prog
		fase += f / HZ
		m[i] = (sin(TAU * fase) * 0.6 + randf_range(-0.25, 0.25)) * (1.0 - prog) * 0.8
	_guardar("nova", m)


static func _dash() -> void:
	var n := int(0.12 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / HZ
		prev = prev * 0.7 + randf_range(-1.0, 1.0) * 0.3
		m[i] = prev * exp(-18.0 * t) * 0.8
	_guardar("dash", m)


static func _dano_jugador() -> void:
	var n := int(0.18 * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	for i in n:
		var t := float(i) / HZ
		m[i] = (sin(TAU * 110.0 * t) * 0.7 + sin(TAU * 55.0 * t) * 0.3) * exp(-10.0 * t) * 0.9
	_guardar("dano_jugador", m)


static func _musica() -> void:
	# Pad ambiental en La menor (A2+E3+A3) con arpegio lento; bucle de 16 s.
	var dur := 16.0
	var n := int(dur * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	var arpegio := [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 220.0, 196.0]
	for i in n:
		var t := float(i) / HZ
		var pad := sin(TAU * 110.0 * t) * 0.10 + sin(TAU * 164.81 * t) * 0.07 + sin(TAU * 220.0 * t) * 0.05
		pad *= 0.8 + 0.2 * sin(TAU * 0.12 * t)
		var paso := int(t / 2.0) % arpegio.size()
		var tl := fmod(t, 2.0)
		var nota: float = arpegio[paso]
		var arp := sin(TAU * nota * t) * exp(-2.0 * tl) * 0.12
		m[i] = pad + arp
	_guardar("musica", m)


static func _musica_jefe() -> void:
	# Pulso grave amenazante con tritono; bucle de 12 s.
	var dur := 12.0
	var n := int(dur * HZ)
	var m := PackedFloat32Array()
	m.resize(n)
	var arpegio := [233.08, 277.18, 311.13, 277.18]
	for i in n:
		var t := float(i) / HZ
		var pulso_t := fmod(t, 0.5)
		var bajo := sin(TAU * 55.0 * t)
		bajo = signf(bajo) * 0.16 * exp(-4.0 * pulso_t)
		var paso := int(t / 1.0) % arpegio.size()
		var tl := fmod(t, 1.0)
		var nota: float = arpegio[paso]
		var arp := sin(TAU * nota * t) * exp(-3.0 * tl) * 0.10
		var tension := sin(TAU * 77.78 * t) * 0.05
		m[i] = bajo + arp + tension
	_guardar("musica_jefe", m)
