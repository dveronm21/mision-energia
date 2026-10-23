class_name AudioSynth
extends Node
## Audio sintetizado sin archivos (equivale a `SynthAudio` de `Audio.ts`).
##
## - Sobre la web: efectos extra (`EXTRA_RECIPES`), pulido de cada efecto (`polish()`),
##   variación de tono por reproducción, y grabaciones opcionales en `res://assets/sfx/`.
##
## - Los efectos se generan con las mismas recetas de la web (osciladores con envolvente
##   exponencial) y se empujan a un `AudioStreamGenerator`.
## - Viento (Zonda): ruido blanco por un filtro pasabanda de 500 Hz (Q 0,7), con fundido.
## - Mute persistente en el `SaveStore` (clave "audio.muted").
## - En headless (driver "Dummy") todo sigue funcionando sin fallar: el generador simplemente
##   no consume muestras.
##
## Uso: `var audio := AudioSynth.new(); audio.setup(store); add_child(audio)`; llamar `unlock()`
## en el primer toque (o al arrancar en Android, donde no hace falta gesto).

const MUTE_KEY: String = "audio.muted"
const MIX_RATE: float = 22050.0
const BUFFER_SEC: float = 0.15
const STOP_TAIL_SEC: float = 0.05

const SFX_NAMES: Array[String] = ["pick", "place", "ok", "bad", "beep", "power", "alarm", "win", "lose", "coin", "click"]

## Recetas: cada tono es [frecuencia Hz, duración s, onda, volumen, inicio s, deslizar a Hz (0 = no)].
const SFX_RECIPES: Dictionary[String, Array] = {
	"pick": [[520.0, 0.12, "triangle", 0.12, 0.0, 780.0]],
	"place": [[180.0, 0.18, "square", 0.08, 0.0, 90.0], [660.0, 0.1, "triangle", 0.08, 0.06, 0.0]],
	"ok": [[660.0, 0.12, "triangle", 0.12, 0.0, 0.0], [990.0, 0.18, "triangle", 0.12, 0.1, 0.0]],
	"bad": [[140.0, 0.3, "sawtooth", 0.08, 0.0, 0.0]],
	"beep": [[1400.0, 0.08, "square", 0.06, 0.0, 0.0], [1400.0, 0.08, "square", 0.06, 0.12, 0.0]],
	"power": [
		[262.0, 0.5, "triangle", 0.1, 0.0, 0.0], [330.0, 0.5, "triangle", 0.1, 0.12, 0.0],
		[392.0, 0.5, "triangle", 0.1, 0.24, 0.0], [523.0, 0.5, "triangle", 0.1, 0.36, 0.0],
		[80.0, 1.2, "sine", 0.2, 0.0, 160.0],
	],
	"alarm": [
		[700.0, 0.18, "square", 0.07, 0.0, 0.0], [520.0, 0.18, "square", 0.07, 0.18, 0.0],
		[700.0, 0.18, "square", 0.07, 0.35, 0.0], [520.0, 0.18, "square", 0.07, 0.53, 0.0],
		[700.0, 0.18, "square", 0.07, 0.7, 0.0], [520.0, 0.18, "square", 0.07, 0.88, 0.0],
	],
	"win": [
		[523.0, 0.35, "triangle", 0.12, 0.0, 0.0], [659.0, 0.35, "triangle", 0.12, 0.15, 0.0],
		[784.0, 0.35, "triangle", 0.12, 0.3, 0.0], [1046.0, 0.35, "triangle", 0.12, 0.45, 0.0],
	],
	"lose": [
		[392.0, 0.4, "sawtooth", 0.06, 0.0, 0.0], [330.0, 0.4, "sawtooth", 0.06, 0.2, 0.0],
		[262.0, 0.4, "sawtooth", 0.06, 0.4, 0.0], [196.0, 0.4, "sawtooth", 0.06, 0.6, 0.0],
	],
	"coin": [[988.0, 0.08, "square", 0.07, 0.0, 0.0], [1319.0, 0.28, "square", 0.07, 0.07, 0.0]],
	"click": [[1800.0, 0.03, "triangle", 0.05, 0.0, 0.0]],
}

## Efectos propios de la versión Godot (no están en la web). Misma forma de receta; la onda
## "noise" es ruido blanco (la frecuencia se ignora).
const EXTRA_RECIPES: Dictionary[String, Array] = {
	# Chispa al conectar: chasquido de ruido + zumbido eléctrico que cae.
	"spark": [[0.0, 0.06, "noise", 0.16, 0.0, 0.0], [2400.0, 0.12, "square", 0.035, 0.0, 600.0], [0.0, 0.04, "noise", 0.08, 0.09, 0.0]],
	# Barrido de cámara al entrar al nivel.
	"whoosh": [[0.0, 0.55, "noise", 0.07, 0.0, 0.0], [180.0, 0.55, "sine", 0.06, 0.0, 420.0]],
	# Pop corto de tarjeta o modal.
	"pop": [[420.0, 0.07, "sine", 0.14, 0.0, 900.0]],
	# Estrellas del resultado: campanitas que suben una nota por estrella.
	"star_1": [[784.0, 0.32, "triangle", 0.12, 0.0, 0.0], [1568.0, 0.24, "sine", 0.05, 0.02, 0.0]],
	"star_2": [[988.0, 0.32, "triangle", 0.12, 0.0, 0.0], [1976.0, 0.24, "sine", 0.05, 0.02, 0.0]],
	"star_3": [[1175.0, 0.42, "triangle", 0.13, 0.0, 0.0], [2349.0, 0.32, "sine", 0.06, 0.02, 0.0], [1568.0, 0.42, "triangle", 0.07, 0.08, 0.0]],
	# Confeti: ráfaga de ruido + arpegio brillante.
	"confetti": [
		[0.0, 0.25, "noise", 0.09, 0.0, 0.0],
		[1046.0, 0.18, "triangle", 0.07, 0.04, 0.0], [1319.0, 0.18, "triangle", 0.07, 0.1, 0.0],
		[1568.0, 0.18, "triangle", 0.07, 0.16, 0.0], [2093.0, 0.3, "triangle", 0.07, 0.22, 0.0],
	],
}

## Carpeta de efectos grabados: si existe `<nombre>.ogg` o `<nombre>.wav`, suena ese archivo
## en vez del sintetizado (así se pueden sumar grabaciones sin tocar código).
const SFX_DIR: String = "res://assets/sfx/"
const FILE_VOICES: int = 6
const FILE_VOLUME_DB: float = -10.0
## Variación de tono por reproducción (±), para que un efecto repetido no suene idéntico.
const PITCH_JITTER: float = 0.035
## Pulido: suavizado de agudos (filtro de un polo), saturación suave y eco corto de sala.
const POLISH_LOWPASS: float = 0.55
const POLISH_ECHOES: Array[Vector2] = [Vector2(0.067, 0.22), Vector2(0.131, 0.11), Vector2(0.211, 0.05)]

const WIND_FREQ: float = 500.0
const WIND_Q: float = 0.7
const WIND_GAIN: float = 0.12
const WIND_FLOOR: float = 0.0001
const WIND_FADE_IN_SEC: float = 1.2
const WIND_FADE_OUT_SEC: float = 1.0

var _store: SaveStore = null
var _muted: bool = false
var _unlocked: bool = false
var _wind_wanted: bool = false
var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
## Cola de mezcla de efectos desde "ahora" (mono).
var _pending: PackedFloat32Array = PackedFloat32Array()
var _pending_pos: int = 0
## Viento: activo, ganancia actual, multiplicador por muestra, muestras hasta apagarse (-1 = sin fin).
var _wind_on: bool = false
var _wind_gain: float = WIND_FLOOR
var _wind_target: float = WIND_FLOOR
var _wind_mult: float = 1.0
var _wind_left: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Estado del biquad pasabanda (forma directa I).
var _bq_b0: float = 0.0
var _bq_b2: float = 0.0
var _bq_a1: float = 0.0
var _bq_a2: float = 0.0
var _x1: float = 0.0
var _x2: float = 0.0
var _y1: float = 0.0
var _y2: float = 0.0
## Efectos ya sintetizados y pulidos (se generan una vez por nombre).
var _polished: Dictionary[String, PackedFloat32Array] = {}
## Archivos grabados encontrados en `SFX_DIR` (null = se buscó y no hay).
var _files: Dictionary[String, Variant] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


## Inyecta el guardado para el mute persistente (puede ser null).
func setup(store: SaveStore) -> void:
	_store = store
	_muted = bool(store.load_value(MUTE_KEY, false)) if store != null else false


func _init() -> void:
	# Coeficientes del pasabanda RBJ (ganancia 0 dB en el pico), como BiquadFilterNode 'bandpass'.
	var w0: float = TAU * WIND_FREQ / MIX_RATE
	var alpha: float = sin(w0) / (2.0 * WIND_Q)
	var a0: float = 1.0 + alpha
	_bq_b0 = alpha / a0
	_bq_b2 = -alpha / a0
	_bq_a1 = -2.0 * cos(w0) / a0
	_bq_a2 = (1.0 - alpha) / a0


## Llamar en el primer toque del usuario. Crea el reproductor (si no existe) y arranca el viento pendiente.
func unlock() -> void:
	_unlocked = true
	if _player == null:
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		gen.buffer_length = BUFFER_SEC
		_player = AudioStreamPlayer.new()
		_player.name = "SynthPlayer"
		_player.stream = gen
		add_child(_player)
	_ensure_playing()
	if _wind_wanted:
		_start_wind()


func _ready() -> void:
	if _unlocked:
		_ensure_playing()


func _ensure_playing() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	if not _player.playing:
		_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func play(sfx_name: String) -> void:
	if not _unlocked or _muted:
		return
	var recipe: Array = SFX_RECIPES.get(sfx_name, EXTRA_RECIPES.get(sfx_name, []))
	if recipe.is_empty():
		push_warning("AudioSynth: efecto desconocido '%s'" % sfx_name)
		return
	if _play_file(sfx_name):
		return
	if not _polished.has(sfx_name):
		_polished[sfx_name] = polish(render_recipe(recipe, MIX_RATE), MIX_RATE)
	_mix_in(_repitch(_polished[sfx_name], 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)))


## Reproduce la grabación de `SFX_DIR` si existe. true = sonó el archivo.
func _play_file(sfx_name: String) -> bool:
	if not _files.has(sfx_name):
		_files[sfx_name] = null
		for ext: String in ["ogg", "wav"]:
			var path: String = "%s%s.%s" % [SFX_DIR, sfx_name, ext]
			if ResourceLoader.exists(path):
				_files[sfx_name] = load(path) as AudioStream
				break
	var stream: AudioStream = _files[sfx_name] as AudioStream
	if stream == null or not is_inside_tree():
		return false
	if _voices.is_empty():
		for i: int in FILE_VOICES:
			var v: AudioStreamPlayer = AudioStreamPlayer.new()
			v.name = "FileVoice%d" % i
			# Las grabaciones vienen mucho más fuertes que la síntesis (picos de ~0,1).
			v.volume_db = FILE_VOLUME_DB
			add_child(v)
			_voices.append(v)
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	voice.play()
	return true


## Pulido de un efecto sintetizado: filtro pasabajos de un polo (redondea cuadradas y
## sierras), saturación suave (`tanh`, más cuerpo sin recortar) y tres ecos cortos que lo
## ubican en un lugar en vez de sonar "pegado al parlante". Agrega la cola del eco.
static func polish(samples: PackedFloat32Array, mix_rate: float) -> PackedFloat32Array:
	var tail: int = int(POLISH_ECHOES[POLISH_ECHOES.size() - 1].x * mix_rate) + 1
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(samples.size() + tail)
	var lp: float = 0.0
	for i: int in samples.size():
		lp += (samples[i] - lp) * POLISH_LOWPASS
		out[i] = tanh(lp * 1.6) / 1.6
	var dry: PackedFloat32Array = out.duplicate()
	for e: Vector2 in POLISH_ECHOES:
		var d: int = int(e.x * mix_rate)
		for i: int in range(0, out.size() - d):
			out[i + d] += dry[i] * e.y
	return out


## Cambia el tono (y la duración) por interpolación lineal: `k` > 1 más agudo.
static func _repitch(samples: PackedFloat32Array, k: float) -> PackedFloat32Array:
	if absf(k - 1.0) < 0.001:
		return samples
	var n: int = int(samples.size() / k)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var x: float = i * k
		var j: int = int(x)
		var f: float = x - j
		var a: float = samples[j]
		var b: float = samples[mini(j + 1, samples.size() - 1)]
		out[i] = a + (b - a) * f
	return out


func set_wind(on: bool) -> void:
	_wind_wanted = on
	if on:
		_start_wind()
	else:
		_stop_wind()


func set_muted(value: bool) -> void:
	_muted = value
	if _store != null:
		_store.save_value(MUTE_KEY, value)
	if value:
		_stop_wind()
		_pending = PackedFloat32Array()
		_pending_pos = 0
	elif _wind_wanted:
		_start_wind()


func is_muted() -> bool:
	return _muted


func is_wind_on() -> bool:
	return _wind_on


## Muestras pendientes de efectos (para diagnóstico/tests).
func pending_samples() -> int:
	return _pending.size() - _pending_pos


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var has_fx: bool = _pending_pos < _pending.size()
	if not has_fx and not _wind_on:
		return
	var buf: PackedVector2Array = PackedVector2Array()
	buf.resize(frames)
	for i: int in frames:
		var s: float = 0.0
		if _pending_pos < _pending.size():
			s = _pending[_pending_pos]
			_pending_pos += 1
		if _wind_on:
			s += _wind_sample()
		s = clampf(s, -1.0, 1.0)
		buf[i] = Vector2(s, s)
	if _pending_pos >= _pending.size():
		_pending = PackedFloat32Array()
		_pending_pos = 0
	_playback.push_buffer(buf)


## Genera una receta completa como muestras mono (pura, testeable en headless).
static func render_recipe(recipe: Array, mix_rate: float) -> PackedFloat32Array:
	var total_sec: float = 0.0
	for tone: Array in recipe:
		total_sec = maxf(total_sec, float(tone[4]) + float(tone[1]) + STOP_TAIL_SEC)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(ceil(total_sec * mix_rate)))
	for tone: Array in recipe:
		_render_tone(out, mix_rate, float(tone[0]), float(tone[1]), str(tone[2]), float(tone[3]), float(tone[4]), float(tone[5]))
	return out


static func _render_tone(out: PackedFloat32Array, rate: float, freq: float, dur: float, wave: String,
		vol: float, when: float, slide_to: float) -> void:
	var start: int = int(round(when * rate))
	var count: int = int(ceil((dur + STOP_TAIL_SEC) * rate))
	var attack: float = 0.01 if wave != "noise" else 0.002
	var phase: float = 0.0
	# Ruido determinístico por tono (mismo sonido en cada render: se puede cachear y testear).
	var noise: RandomNumberGenerator = RandomNumberGenerator.new()
	noise.seed = hash(Vector3(freq, dur, when))
	for i: int in count:
		var idx: int = start + i
		if idx >= out.size():
			break
		var t: float = float(i) / rate
		# Frecuencia: rampa exponencial hasta slide_to en `dur` (exponentialRampToValueAtTime).
		var f: float = freq
		if slide_to > 0.0:
			f = freq * pow(slide_to / freq, minf(t, dur) / dur)
		# Envolvente: 0.0001 → vol en 10 ms, después vol → 0.0001 al final de `dur`.
		var g: float
		if t < attack:
			g = WIND_FLOOR * pow(vol / WIND_FLOOR, t / attack)
		elif t < dur:
			g = vol * pow(WIND_FLOOR / vol, (t - attack) / maxf(dur - attack, 1e-6))
		else:
			g = WIND_FLOOR
		out[idx] += g * (noise.randf_range(-1.0, 1.0) if wave == "noise" else _osc(wave, phase))
		phase = fmod(phase + f / rate, 1.0)


static func _osc(wave: String, phase: float) -> float:
	match wave:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"sawtooth":
			return 2.0 * phase - 1.0
		"triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
		_:
			return sin(TAU * phase)


func _mix_in(samples: PackedFloat32Array) -> void:
	var avail: int = _pending.size() - _pending_pos
	if avail <= 0:
		_pending = samples
		_pending_pos = 0
		return
	# Compacta y suma desde "ahora".
	var merged: PackedFloat32Array = _pending.slice(_pending_pos)
	if samples.size() > merged.size():
		merged.resize(samples.size())
	for i: int in samples.size():
		merged[i] += samples[i]
	_pending = merged
	_pending_pos = 0


func _start_wind() -> void:
	if not _unlocked or _muted:
		return
	if _wind_on and _wind_left < 0:
		return
	_wind_on = true
	_wind_left = -1
	_ramp_wind(WIND_GAIN, WIND_FADE_IN_SEC)


func _stop_wind() -> void:
	if not _wind_on:
		return
	_ramp_wind(WIND_FLOOR, WIND_FADE_OUT_SEC)
	_wind_left = int((WIND_FADE_OUT_SEC + 0.1) * MIX_RATE)


func _ramp_wind(target: float, seconds: float) -> void:
	_wind_target = target
	_wind_mult = pow(target / maxf(_wind_gain, WIND_FLOOR), 1.0 / (seconds * MIX_RATE))


func _wind_sample() -> float:
	var x: float = _rng.randf() * 2.0 - 1.0
	var y: float = _bq_b0 * x + _bq_b2 * _x2 - _bq_a1 * _y1 - _bq_a2 * _y2
	_x2 = _x1
	_x1 = x
	_y2 = _y1
	_y1 = y
	if (_wind_mult > 1.0 and _wind_gain < _wind_target) or (_wind_mult < 1.0 and _wind_gain > _wind_target):
		_wind_gain *= _wind_mult
	if _wind_left > 0:
		_wind_left -= 1
		if _wind_left == 0:
			_wind_on = false
			_wind_left = -1
			_wind_gain = WIND_FLOOR
	return y * _wind_gain
