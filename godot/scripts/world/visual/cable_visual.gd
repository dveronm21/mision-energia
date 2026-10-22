class_name CableVisual
extends Path3D
## Cable con caída tipo catenaria entre puntos (coordenadas del padre), como malla de tubo.
## `curve` (Curve3D del Path3D) queda expuesta para EnergyFlowVisual y para PathFollow3D.
##
##   var cab := CableVisual.new()
##   add_child(cab)
##   cab.setup(PackedVector3Array([inv.terminal_global(), bat.terminal_global()]), VisualMaterials.C_BLUE)

const COLOR_PV := Color("#f28c28")
const COLOR_BAT := Color("#2f7be0")
const COLOR_AC := Color("#8b5cf6")

var radius := 0.035
var color := Color.WHITE
var tube: MeshInstance3D
var _mat: StandardMaterial3D
var _glow := 0.0


func _init() -> void:
	name = "cable"
	tube = MeshInstance3D.new()
	tube.name = "tube"
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube)
	curve = Curve3D.new()


## Arma el cable. Entre cada par de puntos agrega caída proporcional al largo (máx. 0,9 m) sin atravesar
## el piso; la curva queda suavizada (Catmull-Rom) y el tubo se genera con `sides` lados.
func setup(points: PackedVector3Array, cable_color: Color, cable_radius: float = 0.035, sides: int = 6) -> void:
	radius = cable_radius
	color = cable_color
	var src := points
	if src.size() == 1:
		src = PackedVector3Array([src[0], src[0] + Vector3(0, 0.01, 0)])
	var pts := PackedVector3Array()
	for i: int in src.size() - 1:
		var a := src[i]
		var b := src[i + 1]
		var len := a.distance_to(b)
		var n := maxi(2, ceili(len / 0.3))
		var sag := minf(0.9, 0.04 + len * 0.07)
		for k: int in range(0 if i == 0 else 1, n + 1):
			var t := float(k) / float(n)
			var p := a.lerp(b, t)
			p.y -= sag * 4.0 * t * (1.0 - t)
			p.y = maxf(p.y, radius + 0.01)
			pts.append(p)
	# Curva Catmull-Rom → Bézier (tangentes = (p[i+1] - p[i-1]) / 6)
	curve.clear_points()
	for i: int in pts.size():
		var prev := pts[maxi(0, i - 1)]
		var next := pts[mini(pts.size() - 1, i + 1)]
		var tan := (next - prev) / 6.0
		curve.add_point(pts[i], -tan, tan)
	curve.bake_interval = 0.08
	var baked := curve.get_baked_points()
	tube.mesh = MeshKit.tube(baked if baked.size() >= 2 else pts, radius, sides)
	_mat = VisualMaterials.surface(color, 0.45, 0.06)
	tube.material_override = _mat
	set_glow(_glow)


## Brillo 0..1 cuando circula energía.
func set_glow(v: float) -> void:
	_glow = maxf(0.0, v)
	if _mat != null:
		_mat.emission_energy_multiplier = 0.06 + _glow * 1.6


func length() -> float:
	return curve.get_baked_length()
