class_name Solar
extends RefCounted
## Funciones físicas puras y didácticas compartidas por el simulador, el clima y los tests
## (equivale a `solar.ts`).


## Hora del día 0..24 a partir de una hora de juego (puede ser > 24).
static func day_hour(hour: float) -> float:
	return fmod(fmod(hour, 24.0) + 24.0, 24.0)


## Elevación solar normalizada 0..1: sale 6:30, pico ~13:15, se pone 20:00.
static func sun_factor(hour: float) -> float:
	return maxf(0.0, sin(PI * (day_hour(hour) - 6.5) / 13.5))


## Factor de irradiancia por nubes (0..1). Las franjas usan horas de juego (sin módulo).
## Si se superponen, gana la más oscura.
static func cloud_factor(clouds: Array[CloudBand], hour: float) -> float:
	var f: float = 1.0
	for c: CloudBand in clouds:
		if hour >= c.from_hour and hour < c.to_hour:
			f = minf(f, c.factor)
	return f


## ¿La franja de consumo está activa a esa hora? Soporta franjas que cruzan medianoche (from > to).
static func block_active(b: LoadBlock, hour: float) -> bool:
	var x: float = day_hour(hour)
	if b.from_hour <= b.to_hour:
		return x >= b.from_hour and x < b.to_hour
	return x >= b.from_hour or x < b.to_hour


## Consumo total en kW a esa hora, sin las cargas apagadas por el jugador.
static func load_kw(loads: Array[LoadBlock], hour: float, shed: Array[String] = []) -> float:
	var kw: float = 0.0
	for b: LoadBlock in loads:
		if not shed.has(b.label) and block_active(b, hour):
			kw += b.kw
	return kw
