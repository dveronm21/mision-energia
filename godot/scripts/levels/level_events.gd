class_name LevelEvents
extends RefCounted
## Eventos de un nivel: conector flojo, viento Zonda y nubes.

const NO_ZONDA: float = -1.0

## Un panel viene con conector flojo: abre su fila (en serie) hasta repararlo con el multímetro.
var loose_connector: bool = false
## Hora de juego en que empieza el aviso de Zonda, o `NO_ZONDA` si el nivel no tiene.
var zonda_at_hour: float = NO_ZONDA
## Franjas nubladas.
var clouds: Array[CloudBand] = []


static func make(p_loose: bool, p_zonda: float, p_clouds: Array[CloudBand]) -> LevelEvents:
	var e: LevelEvents = LevelEvents.new()
	e.loose_connector = p_loose
	e.zonda_at_hour = p_zonda
	e.clouds = p_clouds
	return e


static func calm() -> LevelEvents:
	return LevelEvents.make(false, NO_ZONDA, [] as Array[CloudBand])


func has_zonda() -> bool:
	return zonda_at_hour >= 0.0


func clone() -> LevelEvents:
	var c: Array[CloudBand] = []
	for band: CloudBand in clouds:
		c.append(band.clone())
	return LevelEvents.make(loose_connector, zonda_at_hour, c)
