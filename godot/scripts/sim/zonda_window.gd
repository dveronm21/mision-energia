class_name ZondaWindow
extends RefCounted
## Ventana del Zonda en horas de juego: aviso desde `warn_from`, tormenta de `storm_from` a `storm_to`.

var warn_from: float = 0.0
var storm_from: float = 0.0
var storm_to: float = 0.0


static func make(p_warn: float, p_storm_from: float, p_storm_to: float) -> ZondaWindow:
	var w: ZondaWindow = ZondaWindow.new()
	w.warn_from = p_warn
	w.storm_from = p_storm_from
	w.storm_to = p_storm_to
	return w
