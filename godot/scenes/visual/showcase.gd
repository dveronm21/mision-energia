class_name VisualShowcase
extends Node3D
## Escena de muestra de los gráficos (port de app/dev/showcase.ts): campo solar de 2 filas × 8, sala de
## equipos, cables con flujo de energía, depósito, bomba, ciudad con postes y personajes en sus poses.
## Se configura con `configure()` antes de entrar al árbol (lo usa tools/shot.gd) o desde el inspector.


## Vistas de cámara: posición, punto mirado, fov vertical (mismas que la versión web).
const VIEWS := {
	"overview": [Vector3(16, 21, 24), Vector3(-1, 0, -6), 45.0],
	"game": [Vector3(2.2, 7.2, 11.5), Vector3(0.5, 0.8, -2.5), 50.0],
	"closeup": [Vector3(3.4, 2.1, 5.4), Vector3(1.2, 1.15, 0.2), 42.0],
	"equip": [Vector3(6.6, 3.0, 2.6), Vector3(7.6, 1.3, -6), 50.0],
	"city": [Vector3(4, 9, 2), Vector3(26, 5, -26), 50.0],
	"lineup": [Vector3(-12.2, 1.45, 7.4), Vector3(-12.2, 1.0, 1.2), 38.0],
	"sky": [Vector3(2, 1.8, 10), Vector3(-6, 10, -40), 55.0],
	"field": [Vector3(-2, 4.2, 6.5), Vector3(-10, 0.5, -5), 50.0],
}

@export var view := "overview"
@export var hour := 10.5
@export_range(0.0, 1.0) var zonda := 0.0
@export_range(0.0, 1.0) var clouds := 0.0
@export_range(0, 2) var quality := 1
## Escena de juego típica: 1 personaje, sin bomba, cajones ni árboles sueltos (para medir rendimiento).
@export var typical := false
@export var defense := false
## -1 = automático (noche 1, día 0,15).
@export var glow := -1.0
@export var animate_time := true

var env: EnvironmentRig
var camera: Camera3D
var workers: Array[WorkerVisual] = []
var buildings: Array[BuildingVisual] = []
var panels: Array[PanelVisual] = []
var flows: Array[EnergyFlowVisual] = []


func configure(params: Dictionary) -> void:
	view = params.get("view", view)
	hour = params.get("hour", hour)
	zonda = params.get("zonda", zonda)
	clouds = params.get("clouds", clouds)
	quality = params.get("quality", quality)
	typical = params.get("typical", typical)
	defense = params.get("defense", defense)
	glow = params.get("glow", glow)


func _ready() -> void:
	var g := glow if glow >= 0.0 else (1.0 if hour > 20.0 or hour < 6.5 else 0.15)
	env = EnvironmentRig.new()
	add_child(env)
	env.set_quality(quality)
	_build_field(g)
	var equip := _build_room(g)
	_build_yard()
	_build_city(equip)
	_build_workers()
	_build_camera()
	_tick(0.0)


func _process(dt: float) -> void:
	_tick(dt if animate_time else 0.0)


func _tick(dt: float) -> void:
	var look: Vector3 = (VIEWS.get(view, VIEWS["overview"]) as Array)[1]
	var follow := Vector3(14, 0, -14) if view == "city" else Vector3(look.x, 0, look.z)
	env.update(dt, hour, zonda, clouds, follow)
	var nf := env.night_factor()
	for b: BuildingVisual in buildings:
		b.set_lights(nf)


func _add(n: Node3D, p: Vector3, ry: float = 0.0, parent: Node = self) -> Node3D:
	parent.add_child(n)
	n.position = p
	n.rotation.y = ry
	return n


# --------------------------------------------------------------------------------------- campo solar

func _build_field(g: float) -> void:
	# Lotes: todos los montajes quietos y todos los paneles en 1 llamada de dibujo cada uno
	var mount_batch := MountVisual.create_batch(MountVisual.DEFAULT_TILT)
	var mount_batch_def := MountVisual.create_batch(0.0)
	var panel_batch := PanelVisual.create_batch()
	add_child(mount_batch)
	add_child(mount_batch_def)
	add_child(panel_batch)
	var row_z: Array[float] = [-3.4, -7.0]
	for row: int in 2:
		var z := row_z[row]
		for i: int in 8:
			var m := MountVisual.new()
			_add(m, Vector3(-19 + i * 2.25, 0, z))
			m.use_batch(mount_batch, mount_batch_def)
			if row == 1 and defense:
				m.set_defense(true, true)
			var filled := not (row == 1 and i >= 6)
			m.set_ghost(not filled)
			if filled:
				var p := PanelVisual.new()
				m.attach_panel(p)
				p.use_batch(panel_batch)
				if row == 0 and i == 2:
					p.set_dirty(true)
				p.set_glow(g * 0.6)
				panels.append(p)
		var post := RowPostVisual.new()
		_add(post, Vector3(-21.2, 0, z), PI / 2)
		if row == 1 and defense:
			post.set_defense(true, true)
		_add(LabelVisual.new("FILA %d" % (row + 1), 0.55), Vector3(-21.2, 1.75, z))
	_add(LabelVisual.new("CAMPO SOLAR", 0.8), Vector3(-11, 2.6, -5.2))


# ---------------------------------------------------------------------------------- sala de equipos

func _build_room(g: float) -> Dictionary:
	var slab := ModelLibrary.instantiate(&"slab")
	_add(slab, Vector3(7, 0, -4.2))
	(ModelLibrary.find_mesh(slab)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(ModelLibrary.instantiate(&"wall"), Vector3(7, 0.16, -6.9))
	_add(ModelLibrary.instantiate(&"canopy"), Vector3(7, 0.16, -6.1))
	var inv := InverterVisual.new()
	_add(inv, Vector3(5.2, 0.16, -6.9))
	inv.set_screen("SOLAR ON" if g > 0.5 else "STANDBY", Color("#5fe3f5") if g > 0.5 else Color("#8fa7a1"))
	var prot := ProtectionVisual.new()
	_add(prot, Vector3(3.3, 0.16, -6.9))
	var sw := SwitchboardVisual.new()
	_add(sw, Vector3(11, 0.16, -6.9))
	var bats: Array[BatteryVisual] = []
	var charges: Array[float] = [1.0, 0.7, 0.4, 0.12]
	for i: int in 4:
		var b := BatteryVisual.new()
		_add(b, Vector3(6.5 + i * 1.15, 0.16, -6.3))
		b.set_charge(charges[i])
		bats.append(b)
	var jb := JunctionBoxVisual.new()
	_add(jb, Vector3(0.2, 0, -5.2))
	var con := ConsoleVisual.new()
	_add(con, Vector3(7, 0.16, -2.2))
	con.set_active(g > 0.5)
	_add(LabelVisual.new("SALA DE EQUIPOS", 0.7), Vector3(7, 3.75, -6.4))
	_add(LabelVisual.new("ACTIVAR PLANTA", 0.6, LabelVisual.BG_ACCENT), Vector3(7, 1.75, -2.2))

	# cables
	var j_t := jb.terminal_global()
	var i_t := inv.terminal_global()
	var pv := _cable([j_t, Vector3(1, 0.05, -4.8), Vector3(4.6, 0.2, -5.2), i_t], CableVisual.COLOR_PV, g)
	_cable([i_t + Vector3(-0.1, 0, 0), Vector3(5.6, 0.2, -5.6), bats[0].terminal_global()], CableVisual.COLOR_BAT, g)
	_cable([i_t + Vector3(0.1, 0, 0), Vector3(8, 0.2, -5.2), Vector3(10.6, 0.2, -5.6), sw.terminal_global()], CableVisual.COLOR_AC, g)
	_flow(pv, Color("#ffd166"))
	for z: float in [-3.4, -7.0]:
		var c := _cable([Vector3(-1.2, 0.85, z + 0.2), Vector3(-0.6, 0.04, z + 0.4), Vector3(-0.1, 0.04, -4.9), j_t + Vector3(-0.12, 0, 0)], CableVisual.COLOR_PV, g)
		if z > -4.0:
			_flow(c, Color("#ffd166"))
	return {"switchboard": sw}


func _cable(pts: Array, color: Color, g: float) -> CableVisual:
	var c := CableVisual.new()
	add_child(c)
	c.setup(PackedVector3Array(pts), color)
	c.set_glow(g)
	return c


func _flow(c: CableVisual, color: Color) -> void:
	var f := EnergyFlowVisual.new()
	c.add_child(f)
	f.setup(c.curve, color)
	f.set_on(true)
	flows.append(f)


# ------------------------------------------------------------------------------- depósito y bomba

func _build_yard() -> void:
	var pal := PalletVisual.new(8)
	_add(pal, Vector3(-4, 0, 3.2), 0.1)
	_add(LabelVisual.new("PANELES", 0.5), Vector3(-4, 1.25, 3.2))
	_add(LabelVisual.new("DEPÓSITO", 0.6), Vector3(14.8, 1.6, 1.6))
	if typical:
		return
	var kinds: Array[StringName] = [&"battery", &"protection", &"kit"]
	for i: int in 3:
		_add(CrateVisual.new(kinds[i]), Vector3(13.5 + i * 1.3, 0, 1.6), (i - 1) * 0.15)
	_add(CrateVisual.new(&"panel"), Vector3(14.8, 0, 3.6), 0.2)
	var pump := PumpVisual.new()
	_add(pump, Vector3(-9, 0, 5.5), -0.4)
	pump.set_running(hour > 6.5 and hour < 20.0)
	var trees: Array[Array] = [[-24, 4, 0], [-25, -12, 1], [19, 6, 1], [22, -4, 0], [-14, 9, 2], [10, 7, 2], [-2, 10, 2], [24, 3, 0], [-27, -2, 0]]
	var tree_models: Array[StringName] = [&"tree_alamo", &"tree_algarrobo", &"tree_jarilla"]
	for t: Array in trees:
		_add(ModelLibrary.instantiate(tree_models[int(t[2]) % 3]), Vector3(t[0], 0, t[1]), float(t[0]) * 0.3)


# ------------------------------------------------------------------------------------------- ciudad

func _build_city(equip: Dictionary) -> void:
	var city := Node3D.new()
	city.name = "city"
	city.position = Vector3(22, 0, -22)
	add_child(city)
	# [x, z, variante, giro]: alturas parecidas a las 10 de la versión web con las 4 variantes exportadas
	var spots: Array[Array] = [[0, 0, 0, 0], [5, 1, 1, 0], [9.5, -1, 2, 0], [14, 0.5, 3, 0], [2, -6, 3, 1],
		[7, -6.5, 2, 2], [12, -6, 0, 1], [-4, -3, 1, 3], [17, -4, 0, 2], [-3, -9, 1, 1]]
	for s: Array in spots:
		var b := BuildingVisual.new(int(s[2]))
		_add(b, Vector3(s[0], 0, s[1]), float(s[3]) * PI / 2, city)
		buildings.append(b)
	_add(LabelVisual.new("CIUDAD", 1.1), Vector3(28, 16.5, -24))
	var anchors: Array[Vector3] = []
	var pole_xz: Array[Vector2] = [Vector2(13, -8.5), Vector2(15.5, -13.5), Vector2(18.2, -18.5)]
	for i: int in 3:
		var p := PowerPoleVisual.new()
		_add(p, Vector3(pole_xz[i].x, 0, pole_xz[i].y), -0.5 + i * 0.05)
		anchors.append(p.wire_anchor_global(1))
	var sw: SwitchboardVisual = equip["switchboard"]
	var pts: Array = [sw.global_position + Vector3(0.2, 2.2, 0.1)]
	pts.append_array(anchors)
	pts.append(Vector3(20.5, 6, -21))
	var line := _cable(pts, Color("#2a2a2a"), 0.0)
	line.set_glow(0.0)


# --------------------------------------------------------------------------------------- personajes

func _build_workers() -> void:
	_worker(Vector3(1.5, 0, 1.6), 0.5, 1.0, WorkerVisual.Pose.IDLE)
	if not typical:
		if view == "lineup":
			_build_lineup()
		else:
			var w2 := _worker(Vector3(3.6, 0, 0.6), -0.9, 0.6, WorkerVisual.Pose.CARRY, Color.WHITE, Color("#d6f25a"))
			w2.carry_anchor.add_child(CrateVisual.new(&"battery"))
			var w3 := _worker(Vector3(-6.1, 0, -1.9), PI, 0.0, WorkerVisual.Pose.TOOL, VisualMaterials.C_BLUE)
			w3.hand_anchor.add_child(_multimeter())
			_worker(Vector3(5.6, 0, -1.6), 0.3, 0.0, WorkerVisual.Pose.IDLE, VisualMaterials.C_SUN, VisualMaterials.C_LEAF)
			_worker(Vector3(-0.9, 0, -1.4), -2.3, 0.4, WorkerVisual.Pose.CABLE)
	# pre-animación (40 frames, como la versión web) para no arrancar en la pose de enlace
	for f: int in 40:
		for w: WorkerVisual in workers:
			w.animate(1.0 / 30.0, w.speed, w.pose)


## Fila de poses frente a la cámara (vista "lineup"): idle, carry, cable, tool y uno caminando.
func _build_lineup() -> void:
	var poses: Array[WorkerVisual.Pose] = [WorkerVisual.Pose.IDLE, WorkerVisual.Pose.CARRY, WorkerVisual.Pose.CABLE, WorkerVisual.Pose.TOOL]
	var vests: Array[Color] = [VisualMaterials.C_ORANGE, Color("#d6f25a"), VisualMaterials.C_LEAF, VisualMaterials.C_ORANGE]
	var hats: Array[Color] = [VisualMaterials.C_SUN, Color.WHITE, VisualMaterials.C_SUN, VisualMaterials.C_BLUE]
	for i: int in 4:
		var w := _worker(Vector3(-14.4 + i * 1.3, 0, 1.6), 0.4 if i == 2 else 0.0, 0.0, poses[i], hats[i], vests[i])
		if poses[i] == WorkerVisual.Pose.CARRY:
			w.carry_anchor.add_child(CrateVisual.new(&"kit"))
		elif poses[i] == WorkerVisual.Pose.TOOL:
			w.hand_anchor.add_child(_multimeter())
	_worker(Vector3(-9.3, 0, 0.6), -0.7, 1.0, WorkerVisual.Pose.IDLE)


func _multimeter() -> MeshInstance3D:
	var meter := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.15, 0.04)
	meter.mesh = bm
	meter.material_override = VisualMaterials.surface(VisualMaterials.C_SUN, 0.5)
	meter.position = Vector3(0, 0, 0.03)
	return meter


func _worker(p: Vector3, ry: float, spd: float, pose: WorkerVisual.Pose, helmet: Color = VisualMaterials.C_SUN, vest: Color = VisualMaterials.C_ORANGE) -> WorkerVisual:
	var w := WorkerVisual.new(helmet, vest)
	_add(w, p, ry)
	w.speed = spd
	w.pose = pose
	w.auto_animate = animate_time
	workers.append(w)
	return w


func _build_camera() -> void:
	var v: Array = VIEWS.get(view, VIEWS["overview"])
	camera = Camera3D.new()
	camera.name = "camera"
	camera.fov = v[2]
	camera.near = 0.1
	camera.far = 1000.0
	add_child(camera)
	camera.look_at_from_position(v[0], v[1])
	camera.current = true
