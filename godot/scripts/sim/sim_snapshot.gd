class_name SimSnapshot
extends RefCounted
## Foto del simulador en un instante.

var hour: float = 0.0
## 0..1 (sol × nubes × tormenta).
var irradiance: float = 0.0
var gen_kw: float = 0.0
var load_kw: float = 0.0
## gen − load (positivo = carga baterías).
var net_kw: float = 0.0
var soc_kwh: float = 0.0
var cap_kwh: float = 0.0
## 0..1
var soc_pct: float = 0.0
var is_night: bool = true
var blackout: bool = false
var finished: bool = false
var won: bool = false


func clone() -> SimSnapshot:
	var s: SimSnapshot = SimSnapshot.new()
	s.hour = hour
	s.irradiance = irradiance
	s.gen_kw = gen_kw
	s.load_kw = load_kw
	s.net_kw = net_kw
	s.soc_kwh = soc_kwh
	s.cap_kwh = cap_kwh
	s.soc_pct = soc_pct
	s.is_night = is_night
	s.blackout = blackout
	s.finished = finished
	s.won = won
	return s


func to_dict() -> Dictionary:
	return {
		"hour": hour, "irradiance": irradiance, "genKw": gen_kw, "loadKw": load_kw, "netKw": net_kw,
		"socKwh": soc_kwh, "capKwh": cap_kwh, "socPct": soc_pct, "isNight": is_night,
		"blackout": blackout, "finished": finished, "won": won,
	}
