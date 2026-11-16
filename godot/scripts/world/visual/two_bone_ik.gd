class_name TwoBoneIk
extends RefCounted
## IK analítico de dos huesos (hombro → codo → mano) para el rig rígido de `WorkerVisual`.
## `TwoBoneIK3D` de Godot pide un `Skeleton3D`; el técnico es una jerarquía de nodos sueltos, así
## que se resuelve acá con la ley de los cosenos. Trabaja en el espacio del padre del hombro (torso).
##
## Convención del rig: en reposo los brazos cuelgan hacia -Y y el codo dobla girando el antebrazo
## sobre su X local (ángulo negativo = la mano va hacia +Z, adelante).
##
##   var r := TwoBoneIk.solve(shoulder_pos, elbow_rest, hand_rest, target, pole)
##   arm.rotation = r[0]; forearm.rotation = r[1]

## Margen para no estirar el brazo del todo (con el brazo recto el codo "salta" de lado).
const REACH_MARGIN: float = 0.995


## shoulder: posición del hombro en el espacio del torso. elbow_rest: posición del codo en el
## espacio del brazo (= `forearm.position`). hand_rest: punto de la mano en el espacio del
## antebrazo. target: adónde tiene que llegar la mano (espacio del torso). pole: hacia dónde
## apunta el codo (dirección, espacio del torso).
## Devuelve [rotación del brazo, rotación del antebrazo] en Euler XYZ (el orden del rig).
static func solve(shoulder: Vector3, elbow_rest: Vector3, hand_rest: Vector3, target: Vector3,
		pole: Vector3) -> Array[Vector3]:
	var l1: float = elbow_rest.length()
	var l2: float = hand_rest.length()
	var to_target: Vector3 = target - shoulder
	var dist: float = clampf(to_target.length(), absf(l1 - l2) + 0.001, (l1 + l2) * REACH_MARGIN)
	var dir: Vector3 = to_target.normalized() if to_target.length() > 0.0001 else Vector3.DOWN
	# Codo: sobre la recta hombro→mano a distancia `a`, corrido `h` hacia el polo.
	var a: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h: float = sqrt(maxf(0.0, l1 * l1 - a * a))
	var bend: Vector3 = _orthogonal(pole, dir)
	if bend == Vector3.ZERO:
		bend = _orthogonal(Vector3.BACK, dir)
	if bend == Vector3.ZERO:
		bend = _orthogonal(Vector3.RIGHT, dir)
	var elbow: Vector3 = shoulder + dir * a + bend * h
	var hand: Vector3 = shoulder + dir * dist

	# Brazo: lleva la dirección del codo en reposo a la del codo resuelto, con el plano de
	# flexión (normal = X local del brazo) alineado con el plano hombro-codo-mano.
	var aim_rest: Vector3 = elbow_rest.normalized()
	var normal_rest: Vector3 = _orthogonal(Vector3.RIGHT, aim_rest)
	var rest: Basis = Basis(aim_rest, normal_rest, aim_rest.cross(normal_rest))
	var aim: Vector3 = (elbow - shoulder).normalized()
	var fold: Vector3 = _orthogonal(hand - elbow, aim)
	if fold == Vector3.ZERO:
		fold = bend
	var normal: Vector3 = fold.cross(aim).normalized()
	var solved: Basis = Basis(aim, normal, aim.cross(normal))
	var arm_basis: Basis = solved * rest.transposed()

	# Antebrazo: bisagra sobre X. En el espacio del brazo, el punto de la mano tiene que quedar
	# en la dirección codo→mano.
	var v: Vector3 = arm_basis.inverse() * (hand - elbow)
	var theta: float = wrapf(atan2(v.z, v.y) - atan2(hand_rest.z, hand_rest.y), -PI, PI)
	return [arm_basis.get_euler(EULER_ORDER_XYZ), Vector3(theta, 0.0, 0.0)]


## Parte de `v` perpendicular a `axis` (normalizada); ZERO si son paralelos.
static func _orthogonal(v: Vector3, axis: Vector3) -> Vector3:
	var p: Vector3 = v - axis * v.dot(axis)
	return p.normalized() if p.length() > 0.0001 else Vector3.ZERO
