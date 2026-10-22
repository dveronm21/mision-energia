class_name ShopPrices
extends RefCounted
## Precios del taller en créditos de obra.

var panel: int = 0
var battery: int = 0
var kit_zonda: int = 0
## Inversor + protección + tablero (obligatorio).
var base_package: int = 0


static func make(p_panel: int, p_battery: int, p_kit: int, p_base: int) -> ShopPrices:
	var p: ShopPrices = ShopPrices.new()
	p.panel = p_panel
	p.battery = p_battery
	p.kit_zonda = p_kit
	p.base_package = p_base
	return p


func clone() -> ShopPrices:
	return ShopPrices.make(panel, battery, kit_zonda, base_package)
