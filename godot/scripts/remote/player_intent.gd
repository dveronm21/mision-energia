class_name PlayerIntent
extends RefCounted
## Lo que un jugador "quiere hacer" en este frame, venga de pantalla táctil, teclado o tablet.
## Espejo de PlayerIntent en app/src/remote/protocol.ts.

## Movimiento −1..1 (derecha +).
var x: float = 0.0
## Movimiento −1..1 (abajo +).
var y: float = 0.0
var run: bool = false
## Flanco: se pulsó acción en este frame.
var action: bool = false
## Flanco: se pulsó revisar.
var inspect: bool = false
## Flanco: se pulsó la herramienta (multímetro).
var tool: bool = false
## Flanco: se pulsó pausa.
var pause: bool = false
var connected: bool = false


func _init(p_x: float = 0.0, p_y: float = 0.0, p_run: bool = false, p_action: bool = false,
		p_inspect: bool = false, p_tool: bool = false, p_pause: bool = false, p_connected: bool = false) -> void:
	x = p_x
	y = p_y
	run = p_run
	action = p_action
	inspect = p_inspect
	tool = p_tool
	pause = p_pause
	connected = p_connected


## Intención neutra (sin movimiento ni pulsaciones).
static func neutral(p_connected: bool = false) -> PlayerIntent:
	return PlayerIntent.new(0.0, 0.0, false, false, false, false, false, p_connected)


func to_dict() -> Dictionary:
	return {"x": x, "y": y, "run": run, "action": action, "inspect": inspect, "tool": tool,
		"pause": pause, "connected": connected}
