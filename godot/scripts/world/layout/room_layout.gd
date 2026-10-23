class_name RoomLayout
extends RefCounted
## Posiciones de la sala de equipos (equivale a `LevelLayout['room']` de `LevelLayout.ts`).

var slab: LayoutRect
var floor_y: float
var wall_z: float
var inverter: Vector3
var protection: Vector3
var switchboard: Vector3
var batteries: Array[Vector3] = []
var console: Vector3
var label: Vector3
