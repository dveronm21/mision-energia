class_name ProtectionSlot
extends Node3D
## Lugar donde va la caja de protección: arranca como silueta (ghost) hasta que el jugador
## la instala (equivale a `ProtectionSlot` de `entities/Equipment.ts`).

var approach: Vector3
var terminal: Vector3

var _ghost: MeshInstance3D
var _model: ProtectionVisual


func _init(pos: Vector3) -> void:
	name = "protection_slot"
	position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.5)
	_ghost = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.6, 0.8, 0.22)
	_ghost.mesh = box
	_ghost.material_override = VisualMaterials.ghost()
	_ghost.position = Vector3(0.0, 1.5, 0.11)
	add_child(_ghost)
	terminal = pos + Vector3(0.0, 1.06, 0.11)


func installed() -> bool:
	return _model != null


func install() -> void:
	if _model != null:
		return
	_model = ProtectionVisual.new()
	add_child(_model)
	_ghost.visible = false
	# `_model` no tiene offset propio dentro del slot: su borne local alcanza para ubicarlo,
	# sin depender de si ya estamos en el árbol (igual que el `worldTerminal()` de la web).
	terminal = position + _model.terminal_local

