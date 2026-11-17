class_name WorldAction
extends RefCounted
## Acción contextual en el mundo (equivale a `WorldAction` de `interaction/types.ts`).
## `pos` es el punto de acceso en el piso (fuera de los colisionadores).

var id: String
var label: String
var pos: Vector3
## Callable() -> void: qué hacer si el jugador toca el botón de acción.
var run: Callable
## Centro del objeto si se puede usar desde cualquier lado (ver `around`); si no, se usa solo `pos`.
var center: Vector3
## Distancia en el piso de `center` a `pos`, o -1 si la acción es solo de frente.
var ring: float = -1.0


func _init(p_id: String, p_label: String, p_pos: Vector3, p_run: Callable) -> void:
	id = p_id
	label = p_label
	pos = p_pos
	run = p_run


## Hace que la acción se pueda usar desde cualquier ángulo: el punto de acceso pasa a ser un
## anillo alrededor de `c` (a la misma distancia que `pos`). Devuelve la misma acción.
func around(c: Vector3) -> WorldAction:
	center = c
	ring = Vector2(pos.x - c.x, pos.z - c.z).length()
	return self


## Qué tan lejos está `at` de poder usar la acción (en el piso). Con anillo, estar más cerca del
## objeto que el anillo cuenta como estar en él (0) y desempata quien está más pegado.
func distance_from(at: Vector3) -> float:
	if ring < 0.0:
		return Vector2(pos.x - at.x, pos.z - at.z).length()
	var dc: float = Vector2(center.x - at.x, center.z - at.z).length()
	return maxf(dc - ring, 0.0) + dc * 0.001


## Lleva `pos` al punto del anillo que mira hacia `at` (donde se dibuja el aro y el cartel).
func face(at: Vector3) -> void:
	if ring < 0.0:
		return
	var dir: Vector2 = Vector2(at.x - center.x, at.z - center.z)
	if dir.length() < 0.001:
		return
	dir = dir.normalized() * ring
	pos = Vector3(center.x + dir.x, pos.y, center.z + dir.y)
