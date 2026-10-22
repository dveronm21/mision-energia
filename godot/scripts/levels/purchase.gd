class_name Purchase
extends RefCounted
## Compra que el jugador hace en el taller antes de construir.

var panels: int = 0
var batteries: int = 0
var kit_zonda: bool = false


static func make(p_panels: int, p_batteries: int, p_kit: bool) -> Purchase:
	var p: Purchase = Purchase.new()
	p.panels = p_panels
	p.batteries = p_batteries
	p.kit_zonda = p_kit
	return p


func clone() -> Purchase:
	return Purchase.make(panels, batteries, kit_zonda)


func describe() -> String:
	return "%dp %db%s" % [panels, batteries, " kit" if kit_zonda else ""]
