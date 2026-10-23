class_name Pallet
extends RefCounted
## Pallet de paneles nuevos, de a uno (equivale a `Pallet` de `entities/Pickups.ts`).

## Nodo visual: agregalo a la escena antes de usar.
var visual: PalletVisual
var approach: Vector3

var _left: int
## Índice (en orden de retiro) del panel que viene con el conector flojo, o -1.
var _faulty_index: int
var _taken: int = 0


func _init(pos: Vector3, count: int, loose_connector: bool) -> void:
	visual = PalletVisual.new(count)
	visual.position = pos
	visual.rotation.y = 0.06
	_left = count
	_faulty_index = mini(count - 1, 1) if (loose_connector and count > 0) else -1
	approach = Vector3(pos.x, 0.0, pos.z + 1.35)


func remaining() -> int:
	return _left


## Retira un panel. Devuelve si viene con conector flojo.
func take() -> bool:
	if _left <= 0:
		return false
	_left -= 1
	visual.set_count(_left)
	var was_faulty_slot: bool = (_taken == _faulty_index)
	_taken += 1
	return was_faulty_slot
