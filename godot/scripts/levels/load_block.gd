class_name LoadBlock
extends RefCounted
## Franja de consumo: `kw` entre `from_hour` y `to_hour` (horas del día 0..24; si from > to cruza medianoche).

var from_hour: float = 0.0
var to_hour: float = 24.0
var kw: float = 0.0
var label: String = ""
var essential: bool = true


static func make(p_from: float, p_to: float, p_kw: float, p_label: String, p_essential: bool) -> LoadBlock:
	var b: LoadBlock = LoadBlock.new()
	b.from_hour = p_from
	b.to_hour = p_to
	b.kw = p_kw
	b.label = p_label
	b.essential = p_essential
	return b


func clone() -> LoadBlock:
	return LoadBlock.make(from_hour, to_hour, kw, label, essential)
