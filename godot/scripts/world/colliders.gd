class_name Colliders
extends RefCounted
## Colisiones simples del jugador (círculo) contra cajas AABB y los límites del mapa
## (equivale a `Colliders.ts`). Lógica pura, sin nodos: se puede testear en headless.

var _boxes: Array[AabbBox] = []
var _min_x: float
var _max_x: float
var _min_z: float
var _max_z: float


func _init(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	_min_x = min_x
	_max_x = max_x
	_min_z = min_z
	_max_z = max_z


func add(x: float, z: float, hw: float, hd: float) -> AabbBox:
	var b: AabbBox = AabbBox.new(x, z, hw, hd)
	_boxes.append(b)
	return b


func remove(b: AabbBox) -> void:
	var i: int = _boxes.find(b)
	if i >= 0:
		_boxes.remove_at(i)


## Empuja `p` (Vector2 en el plano XZ, radio `r`) fuera de las cajas y lo deja dentro de
## los límites. Se llama dos veces porque resolver una caja puede meter el punto en otra.
func resolve(p: Vector2, r: float) -> Vector2:
	var px: float = p.x
	var pz: float = p.y
	for _pass: int in range(2):
		for c: AabbBox in _boxes:
			var cx: float = clampf(px, c.x - c.hw, c.x + c.hw)
			var cz: float = clampf(pz, c.z - c.hd, c.z + c.hd)
			var dx: float = px - cx
			var dz: float = pz - cz
			var d: float = sqrt(dx * dx + dz * dz)
			if d >= r:
				continue
			if d > 1e-4:
				px = cx + (dx / d) * r
				pz = cz + (dz / d) * r
			else:
				# centro adentro de la caja: salir por el lado más cercano
				var ox: float = c.hw - absf(px - c.x)
				var oz: float = c.hd - absf(pz - c.z)
				if ox < oz:
					px = c.x + signf(px - c.x if px != c.x else 1.0) * (c.hw + r)
				else:
					pz = c.z + signf(pz - c.z if pz != c.z else 1.0) * (c.hd + r)
	px = clampf(px, _min_x, _max_x)
	pz = clampf(pz, _min_z, _max_z)
	return Vector2(px, pz)
