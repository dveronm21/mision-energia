class_name AudioSynth
extends Node
## Audio sintetizado sin archivos (equivale a `SynthAudio` de `Audio.ts`).
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
	if not SFX_RECIPES.has(sfx_name):
		push_warning("AudioSynth: efecto desconocido '%s'" % sfx_name)
		return
	_mix_in(render_recipe(SFX_RECIPES[sfx_name], MIX_RATE))


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
	var attack: float = 0.01
	var phase: float = 0.0
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
		out[idx] += g * _osc(wave, phase)
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
