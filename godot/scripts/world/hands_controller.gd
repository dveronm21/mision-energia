class_name HandsController
extends RefCounted
## Qué tiene el técnico en las manos (nada, una carga sobre la cabeza, un cable o el
## multímetro) y su representación 3D en los anclajes del rig (equivale a `HandsController.ts`).
## A diferencia de la web no hace falta un `ModelFactory`: usa directo los visuales ya
## portados (`PanelVisual`, `CrateVisual`, `VisualMaterials`).

var _rig: WorkerVisual
var _state: HandsState = HandsState.free_hands()
var _carried: Node3D
var _meter: Node3D


func _init(rig: WorkerVisual) -> void:
	_rig = rig
	_meter = _build_meter()
	_meter.visible = false
	_rig.hand_anchor.add_child(_meter)


func hands() -> HandsState:
	return _state


func kind() -> StringName:
	return _state.kind


func is_free() -> bool:
	return _state.kind == HandsState.KIND_FREE


## Pose que le corresponde al rig según lo que hay en las manos.
func pose() -> WorkerVisual.Pose:
	match _state.kind:
		HandsState.KIND_CARRY:
			return WorkerVisual.Pose.CARRY
		HandsState.KIND_CABLE:
			return WorkerVisual.Pose.CABLE
		HandsState.KIND_METER:
			return WorkerVisual.Pose.TOOL
		_:
			return WorkerVisual.Pose.IDLE


## Agarra algo: "panel" usa el modelo del panel; el resto, un cajón (equivale a `carry()`).
func carry(item_kind: StringName, faulty: bool = false) -> void:
	clear()
	_state = HandsState.carry(item_kind, faulty)
	var obj: Node3D
	if item_kind == &"panel":
		var p: PanelVisual = PanelVisual.new()
		obj = p
		obj.position = Vector3(0, 0.02, 0)
	else:
		var c: CrateVisual = CrateVisual.new(item_kind)
		c.scale = Vector3.ONE * 0.55
		c.position = Vector3(0, -0.06, 0)
		obj = c
	_rig.carry_anchor.add_child(obj)
	_carried = obj


## Agarra la punta de un cable para tenderlo (equivale a `takeCable()`).
func take_cable(color: StringName, from: StringName, from_point: Vector3) -> void:
	clear()
	_state = HandsState.cable(color, from, from_point)


## Prende/apaga el multímetro en la mano (equivale a `setMeter()`).
func set_meter(on: bool) -> void:
	clear()
	if on:
		_state = HandsState.meter()
	_meter.visible = on


## Suelta todo sin dejar nada en el mundo (equivale a `clear()`).
func clear() -> void:
	if _carried != null:
		_carried.get_parent().remove_child(_carried)
		_carried.queue_free()
		_carried = null
	_meter.visible = false
	_state = HandsState.free_hands()


## Posición de la mano en el mundo (para dibujar el cable en mano mientras se tiende).
func hand_world() -> Vector3:
	return _rig.hand_anchor.global_position


func _build_meter() -> Node3D:
	var meter: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.1, 0.16, 0.045)
	body.mesh = box
	body.material_override = VisualMaterials.surface(VisualMaterials.C_SUN, 0.5)
	meter.add_child(body)
	var screen: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.07, 0.05)
	plane.orientation = PlaneMesh.FACE_Z
	screen.mesh = plane
	var screen_mat: StandardMaterial3D = StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Color("#9fe8b0")
	screen.material_override = screen_mat
	screen.position = Vector3(0, 0.035, 0.024)
	meter.add_child(screen)
	meter.position = Vector3(0, 0, 0.05)
	meter.rotation.x = -0.6
	return meter
