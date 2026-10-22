class_name MeshKit
extends RefCounted
## Utilidades para armar mallas chicas por código (LEDs, segmentos, tubos) con SurfaceTool.
## Los colores se escriben en sRGB (los materiales usan vertex_color_is_srgb, igual que los .glb).


## Disco mirando a +Z centrado en `c`.
static func disc(st: SurfaceTool, c: Vector3, radius: float, color: Color, segs: int = 12) -> void:
	for i: int in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		st.set_color(color)
		st.set_normal(Vector3.BACK)
		st.add_vertex(c)
		st.add_vertex(c + Vector3(cos(a1), sin(a1), 0) * radius)
		st.add_vertex(c + Vector3(cos(a0), sin(a0), 0) * radius)


## Caja alineada a ejes con centro `c` y tamaño `s` (sólo la cara frontal +Z y los bordes si `full`).
static func box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color, full: bool = true) -> void:
	var h := s * 0.5
	var faces: Array[Array] = [
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
	]
	if full:
		faces.append([Vector3.FORWARD, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)])
		faces.append([Vector3.UP, Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)])
		faces.append([Vector3.DOWN, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)])
		faces.append([Vector3.RIGHT, Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)])
		faces.append([Vector3.LEFT, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)])
	for f: Array in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = c + (f[1] as Vector3)
		var b: Vector3 = c + (f[2] as Vector3)
		var d: Vector3 = c + (f[3] as Vector3)
		var e: Vector3 = c + (f[4] as Vector3)
		for v: Vector3 in [a, d, b, a, e, d]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


## Tubo a lo largo de una polilínea (marcos de transporte paralelo, sin torsión).
static func tube(points: PackedVector3Array, radius: float, sides: int = 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	if n < 2:
		return st.commit()
	var tangent := (points[1] - points[0]).normalized()
	var normal := tangent.cross(Vector3.UP)
	if normal.length_squared() < 1e-6:
		normal = tangent.cross(Vector3.RIGHT)
	normal = normal.normalized()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var lengths := PackedFloat32Array()
	var acc := 0.0
	for i: int in n:
		if i > 0:
			acc += points[i].distance_to(points[i - 1])
		lengths.append(acc)
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == n - 1:
			t = points[i] - points[i - 1]
		else:
			t = points[i + 1] - points[i - 1]
		t = t.normalized()
		# transporte paralelo: proyectar la normal anterior sobre el plano perpendicular a la tangente
		normal = (normal - t * normal.dot(t)).normalized()
		var binormal := t.cross(normal)
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for s: int in sides:
			var a := TAU * float(s) / float(sides)
			var dir := normal * cos(a) + binormal * sin(a)
			ring.append(points[i] + dir * radius)
			rn.append(dir)
		rings.append(ring)
		ring_normals.append(rn)
	for i: int in n - 1:
		for s: int in sides:
			var s2 := (s + 1) % sides
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			var quad: Array[Array] = [
				[i, s, u0], [i + 1, s, u0], [i + 1, s2, u1],
				[i, s, u0], [i + 1, s2, u1], [i, s2, u1],
			]
			for q: Array in quad:
				var ri: int = q[0]
				var si: int = q[1]
				st.set_normal(ring_normals[ri][si])
				st.set_uv(Vector2(q[2] as float, lengths[ri]))
				st.add_vertex(rings[ri][si])
	return st.commit()
