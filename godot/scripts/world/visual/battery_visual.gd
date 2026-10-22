class_name BatteryVisual
extends EquipmentVisual
## Gabinete de baterías con barra de carga de 5 segmentos + LED (malla de brillo regenerada al cambiar).

const SEGMENTS := 5
const SEG_OFF := Color(0.11, 0.14, 0.14)

var _bar: MeshInstance3D
var _key := ""
var _pct := -1.0


func _init() -> void:
	super(&"battery", Vector3(0.35, 1.25, 0.34))
	name = "battery"
	_bar = MeshInstance3D.new()
	_bar.name = "charge_bar"
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.material_override = VisualMaterials.glow()
	add_child(_bar)
	set_charge(0.0)


## Carga 0..1: segmentos encendidos (rojo < 25 %, ámbar < 55 %, verde) y LED (verde con carga, rojo vacía).
func set_charge(pct: float) -> void:
	pct = clampf(pct, 0.0, 1.0)
	_pct = pct
	var on := 0 if pct <= 0.0 else maxi(1, ceili(pct * SEGMENTS - 0.0001))
	var col := VisualMaterials.C_BAD if pct < 0.25 else (VisualMaterials.C_WARN if pct < 0.55 else VisualMaterials.C_OK)
	var key := "%d:%s" % [on, col.to_html()]
	if key == _key:
		return
	_key = key
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in SEGMENTS:
		MeshKit.box(st, Vector3(0.25, 0.75 + i * 0.1, 0.318), Vector3(0.16, 0.075, 0.01), col if i < on else SEG_OFF, false)
	MeshKit.disc(st, Vector3(0.25, 1.25, 0.318), 0.018, VisualMaterials.C_OK if pct > 0.0 else VisualMaterials.C_BAD, 10)
	_bar.mesh = st.commit()


func charge() -> float:
	return _pct
