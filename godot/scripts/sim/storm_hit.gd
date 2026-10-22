class_name StormHit
extends RefCounted
## Resultado de aplicar el golpe de Zonda: planta nueva, paneles perdidos y pérdida por fila.

var plant: PlantState
var panels_lost: int = 0
var lost_per_row: Array[int] = []
