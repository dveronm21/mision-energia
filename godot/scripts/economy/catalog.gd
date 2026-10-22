class_name Catalog
extends RefCounted
## Catálogo de productos (igual a `Catalog.ts`). Principios (público infantil/familiar):
##  - Toda la campaña se puede terminar sin pagar (los Soles se ganan con estrellas, regalo y bono diario).
##  - Nada aleatorio pago: cada producto dice exactamente lo que da.
##  - Los boosters ayudan pero no reemplazan aprender (no ganan el nivel solos).
## Precios de packs en centavos de ARS: son PRECIOS DE PRUEBA mientras el pago real no esté configurado.

## Colores (hex RGB) de cada cosmético, para el modelo del técnico.
const COSMETIC_COLORS: Dictionary[String, int] = {
	"skin_helmet_blue": 0x2f7be0, "skin_helmet_orange": 0xf28c28, "skin_helmet_white": 0xf4f4f0,
	"skin_vest_green": 0x3cc65a, "skin_vest_yellow": 0xf2d22e, "skin_vest_violet": 0x8b5cf6,
}

const SLOT_HELMET: String = "helmet"
const SLOT_VEST: String = "vest"

var _products: Array[Product] = []


## `products` vacío = catálogo oficial.
func _init(products: Array[Product] = []) -> void:
	_products = products.duplicate() if not products.is_empty() else default_products()


static func default_products() -> Array[Product]:
	return [
		Product.pack("pack_small", "Bolsita de Soles", "120 Soles.", 120, 99900, "ARS", "sun-small"),
		Product.pack("pack_medium", "Caja de Soles", "500 Soles + 150 de regalo.", 650, 399900, "ARS", "sun-medium"),
		Product.pack("pack_large", "Cofre de Soles", "1000 Soles + 400 de regalo.", 1400, 699900, "ARS", "sun-large"),

		Product.priced("boost_hint", Product.KIND_BOOSTER, "Pista", "Resalta el próximo paso de la obra.", 10, true, "hint"),
		Product.priced("boost_drone", Product.KIND_BOOSTER, "Dron limpiador", "Después del Zonda, limpia el polvo de todas las filas.", 25, true, "drone"),
		Product.priced("boost_battery", Product.KIND_BOOSTER, "Batería de emergencia", "Suma 4 kWh ya cargados, una sola vez.", 35, true, "battery-plus"),
		Product.priced("boost_budget", Product.KIND_BOOSTER, "Presupuesto extra", "+15% de créditos de obra en un nivel.", 40, true, "coins"),

		Product.priced("skin_helmet_blue", Product.KIND_COSMETIC, "Casco azul", "Casco de técnico color azul.", 60, false, "helmet"),
		Product.priced("skin_helmet_orange", Product.KIND_COSMETIC, "Casco naranja", "Casco de técnico color naranja.", 60, false, "helmet"),
		Product.priced("skin_helmet_white", Product.KIND_COSMETIC, "Casco blanco", "Casco de ingeniería, blanco.", 90, false, "helmet"),
		Product.priced("skin_vest_green", Product.KIND_COSMETIC, "Chaleco verde", "Chaleco reflectivo verde.", 60, false, "vest"),
		Product.priced("skin_vest_yellow", Product.KIND_COSMETIC, "Chaleco amarillo", "Chaleco reflectivo amarillo.", 60, false, "vest"),
		Product.priced("skin_vest_violet", Product.KIND_COSMETIC, "Chaleco violeta", "Chaleco reflectivo violeta.", 90, false, "vest"),
	]


## Copias de todos los productos.
func all() -> Array[Product]:
	var out: Array[Product] = []
	for p: Product in _products:
		out.append(p.clone())
	return out


## Copia del producto, o null si no existe.
func find(id: String) -> Product:
	for p: Product in _products:
		if p.id == id:
			return p.clone()
	return null


## Como `find`, pero registra un error si no existe (en la web lanzaba excepción).
func get_product(id: String) -> Product:
	var p: Product = find(id)
	if p == null:
		push_error("Producto desconocido: %s" % id)
	return p


func by_kind(kind: String) -> Array[Product]:
	var out: Array[Product] = []
	for p: Product in _products:
		if p.kind == kind:
			out.append(p.clone())
	return out


## Slot de un cosmético según su id ('skin_helmet_*' → "helmet", 'skin_vest_*' → "vest"), o "".
func cosmetic_slot(id: String) -> String:
	if id.begins_with("skin_helmet_"):
		return SLOT_HELMET
	if id.begins_with("skin_vest_"):
		return SLOT_VEST
	return ""


## Color del cosmético (blanco si no existe).
static func cosmetic_color(id: String) -> Color:
	if not COSMETIC_COLORS.has(id):
		return Color.WHITE
	return Color.hex((COSMETIC_COLORS[id] << 8) | 0xff)
