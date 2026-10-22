class_name EquipmentVisual
extends Node3D
## Base de los equipos: instancia el .glb y expone el borne (`terminal_global()`) donde llegan los cables.
## Equivale a EquipmentModel de la versión web (root + terminal local).

## Punto de conexión en coordenadas locales del equipo.
var terminal_local: Vector3 = Vector3.ZERO
## Raíz del modelo importado.
var model: Node3D


func _init(model_name: StringName = &"", terminal: Vector3 = Vector3.ZERO) -> void:
	terminal_local = terminal
	if model_name != &"":
		model = ModelLibrary.instantiate(model_name)
		add_child(model)
		var t := model.find_child("terminal", true, false) as Node3D
		if t != null and terminal == Vector3.ZERO:
			terminal_local = t.position


## Borne en coordenadas globales (si el nodo no está en el árbol, en coordenadas del padre).
func terminal_global() -> Vector3:
	if is_inside_tree():
		return global_transform * terminal_local
	return transform * terminal_local


## Busca un nodo del modelo por nombre (sin rutas frágiles: nombres fijados por el exportador).
func part(part_name: String) -> Node3D:
	if model == null:
		return null
	return model.find_child(part_name, true, false) as Node3D


## Lerp exponencial independiente del framerate.
static func damp(a: float, b: float, k: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-k * dt))
