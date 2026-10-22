class_name CloudBand
extends RefCounted
## Franja nublada en horas de JUEGO (sin módulo 24) con factor de irradiancia 0..1.

var from_hour: float = 0.0
var to_hour: float = 0.0
var factor: float = 1.0


static func make(p_from: float, p_to: float, p_factor: float) -> CloudBand:
	var c: CloudBand = CloudBand.new()
	c.from_hour = p_from
	c.to_hour = p_to
	c.factor = p_factor
	return c


func clone() -> CloudBand:
	return CloudBand.make(from_hour, to_hour, factor)
