class_name RowLayout
extends RefCounted
## Una fila de montajes del campo solar (equivale a `RowLayout` de `LevelLayout.ts`).

var index: int
var z: float
var mounts: Array[Vector3] = []
var post: Vector3
## Extremo de la fila por donde sale el cable hacia la caja de conexión.
var wire_start: Vector3


func _init(p_index: int, p_z: float, p_mounts: Array[Vector3], p_post: Vector3, p_wire_start: Vector3) -> void:
	index = p_index
	z = p_z
	mounts = p_mounts
	post = p_post
	wire_start = p_wire_start
