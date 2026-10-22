class_name WeatherSchedule
extends RefCounted
## Calendario climático del nivel (equivale a `WeatherSchedule.ts`). El juego lo consulta cada frame
## con la hora de juego: calm → zonda-warning (aviso, ~0,7 h) → zonda-storm (~0,3 h, polvo y riesgo
## de perder paneles) → zonda-over. Sugerencia: ralentizar el reloj durante el aviso.

const CALM: String = "calm"
const ZONDA_WARNING: String = "zonda-warning"
const ZONDA_STORM: String = "zonda-storm"
const ZONDA_OVER: String = "zonda-over"

const DEFAULT_WARNING_HOURS: float = 0.7
const DEFAULT_STORM_HOURS: float = 0.3

var _events: LevelEvents
var _warning_hours: float
var _storm_hours: float


func _init(events: LevelEvents, warning_hours: float = DEFAULT_WARNING_HOURS, storm_hours: float = DEFAULT_STORM_HOURS) -> void:
	_events = events
	_warning_hours = warning_hours
	_storm_hours = storm_hours


func phase_at(hour: float) -> String:
	if not _events.has_zonda():
		return CALM
	var z: float = _events.zonda_at_hour
	if hour < z:
		return CALM
	if hour < z + _warning_hours:
		return ZONDA_WARNING
	if hour < z + _warning_hours + _storm_hours:
		return ZONDA_STORM
	return ZONDA_OVER


## Ventana del Zonda, o null si el nivel no tiene.
func zonda_window() -> ZondaWindow:
	if not _events.has_zonda():
		return null
	var z: float = _events.zonda_at_hour
	var storm_from: float = z + _warning_hours
	return ZondaWindow.make(z, storm_from, storm_from + _storm_hours)


## Nubosidad visual 0..1 (0 = despejado) para el ambiente 3D.
func cloudiness_at(hour: float) -> float:
	return 1.0 - Solar.cloud_factor(_events.clouds, hour)


## Horas restantes de aviso (para el cartel "Llega en…"); 0 fuera del aviso.
func warning_remaining(hour: float) -> float:
	var w: ZondaWindow = zonda_window()
	if w != null and hour >= w.warn_from and hour < w.storm_from:
		return w.storm_from - hour
	return 0.0
