class_name Mount
extends RefCounted
## Estructura de montaje de un panel: estado de juego (puede tener panel, con o sin
## conector flojo, polvo del Zonda y posición de defensa) sobre el visual ya portado
## `MountVisual` (equivale a `entities/Mount.ts`).

const TILT_NORMAL: float = MountVisual.DEFAULT_TILT
const TILT_DEFENSE: float = 0.02

var row: int
var index: int
## Nodo visual: agregalo a la escena antes de usar (`add_child(mount.visual)`).
var visual: MountVisual
## true si el conector de este panel quedó flojo (evento del nivel).
var faulty: bool = false
## Se midió este panel con el multímetro y se encontró el conector abierto.
var fault_found: bool = false
## Punto de acceso frente a la estructura (donde se para el técnico para operarla).
var approach: Vector3

var _panel: PanelVisual
var _dirty: bool = false


func _init(p_row: int, p_index: int, pos: Vector3) -> void:
	row = p_row
	index = p_index
	visual = MountVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.3)


func filled() -> bool:
	return _panel != null


func position() -> Vector3:
	return visual.position


func is_dirty() -> bool:
	return _dirty and filled()


## Instala un panel nuevo (no hace nada si ya tenía uno).
func install(p_faulty: bool) -> void:
	if _panel != null:
		return
	_panel = PanelVisual.new()
	visual.attach_panel(_panel)
	_panel.set_dirty(_dirty)
	faulty = p_faulty
	fault_found = false


## Saca el panel (lo arrancó el viento). Devuelve si tenía el conector flojo.
func remove() -> bool:
	if _panel == null:
		return false
	visual.detach_panel()
	_panel.queue_free()
	_panel = null
	var was_faulty: bool = faulty
	faulty = false
	fault_found = false
	return was_faulty


func repair() -> void:
	faulty = false
	fault_found = false


func set_dirty(on: bool) -> void:
	_dirty = on
	if _panel != null:
		_panel.set_dirty(on)


func set_defense(on: bool, instant: bool = false) -> void:
	visual.set_defense(on, instant)


func set_glow(v: float) -> void:
	if _panel != null:
		_panel.set_glow(v)


func set_ghost_visible(on: bool) -> void:
	visual.set_ghost(on and _panel == null)
