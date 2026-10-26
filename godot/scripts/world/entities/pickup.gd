class_name Pickup
extends Node3D
## Objeto en el piso que se puede levantar: cajón (batería, protección, kit) o panel suelto
## (soltado por el jugador o arrancado por el Zonda). Equivale a `Pickup` de `entities/Pickups.ts`.
## Es Node3D (no un wrapper con `.root`) porque es, en sí mismo, el nodo que va a la escena.

## "panel" | "battery" | "protection" | "kit".
var kind: StringName
var faulty: bool
var approach: Vector3

var _colliders: Colliders
var _box: AabbBox


func _init(p_kind: StringName, pos: Vector3, p_faulty: bool, colliders: Colliders, yaw: float = 0.0) -> void:
	kind = p_kind
	faulty = p_faulty
	_colliders = colliders
	name = "pickup-%s" % kind
	if kind == &"panel":
		var p: PanelVisual = PanelVisual.new()
		p.position.y = 0.06
		add_child(p)
		_box = colliders.add(pos.x, pos.z, 0.2, 0.2)
	else:
		add_child(CrateVisual.new(kind))
		# Aura del color del equipo: qué cajón llevar (y su destino tiene la misma).
		add_child(AuraVisual.new(AuraVisual.COLOR_KIT if kind == &"kit" else (AuraVisual.COLOR_BATTERY if kind == &"battery" else AuraVisual.COLOR_PROTECTION)))
		_box = colliders.add(pos.x, pos.z, 0.45, 0.45)
	position = pos
	rotation.y = yaw
	approach = Vector3(pos.x, 0.0, pos.z + (1.0 if kind == &"panel" else 1.1))


## Saca el colisionador y se da de baja a sí mismo. Llamalo en vez de `queue_free()` directo.
func dispose() -> void:
	_colliders.remove(_box)
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
