class_name HandsState
extends RefCounted
## Estado de las manos del técnico (equivale al tipo unión `Hands` de `interaction/types.ts`).
## Como GDScript no tiene unión discriminada, se arma como un registro con `kind` + los
## campos que correspondan a cada caso (el resto queda sin usar).

const KIND_FREE: StringName = &"free"
const KIND_CARRY: StringName = &"carry"
const KIND_CABLE: StringName = &"cable"
const KIND_METER: StringName = &"meter"

var kind: StringName = KIND_FREE
## Para KIND_CARRY: tipo de carga ("panel", "battery", "protection", "kit").
var item_kind: StringName = &""
var item_faulty: bool = false
## Para KIND_CABLE.
var cable_color: StringName = &""
var cable_from: StringName = &""
var cable_from_point: Vector3 = Vector3.ZERO


## Ojo: no se llama `free` porque ese nombre ya es un método de `Object`.
static func free_hands() -> HandsState:
	return HandsState.new()


static func carry(p_item_kind: StringName, faulty: bool = false) -> HandsState:
	var s: HandsState = HandsState.new()
	s.kind = KIND_CARRY
	s.item_kind = p_item_kind
	s.item_faulty = faulty
	return s


static func cable(color: StringName, from: StringName, from_point: Vector3) -> HandsState:
	var s: HandsState = HandsState.new()
	s.kind = KIND_CABLE
	s.cable_color = color
	s.cable_from = from
	s.cable_from_point = from_point
	return s


static func meter() -> HandsState:
	var s: HandsState = HandsState.new()
	s.kind = KIND_METER
	return s
