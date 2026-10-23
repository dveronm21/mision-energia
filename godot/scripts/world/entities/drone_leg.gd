class_name DroneLeg
extends RefCounted
## Un tramo del vuelo del dron: adónde va y, si al llegar hay que avisar que limpió una fila,
## cuál (−1 = ningún aviso). Equivale a la interfaz `Leg` de `Drone.ts`.

var to: Vector3
var row: int


func _init(p_to: Vector3, p_row: int = -1) -> void:
	to = p_to
	row = p_row
