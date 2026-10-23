class_name CityLayout
extends RefCounted
## Posiciones de la ciudad que abastece la planta (equivale a `LevelLayout['city']`).

var city_name: String
var origin: Vector3
var buildings: Array[CityBuilding] = []
var poles: Array[Vector3] = []
var label: Vector3
