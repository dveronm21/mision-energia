class_name Product
extends RefCounted
## Producto del catálogo (pack de Soles, booster, cosmético o desbloqueo).

const KIND_TOKEN_PACK: String = "token-pack"
const KIND_BOOSTER: String = "booster"
const KIND_COSMETIC: String = "cosmetic"
const KIND_LEVEL_UNLOCK: String = "level-unlock"

## Valor de `cost_soles` cuando el producto no se paga con Soles.
const NO_COST: int = -1

## 'pack_small', 'boost_hint', 'skin_helmet_blue', ...
var id: String = ""
var kind: String = ""
var title: String = ""
var description: String = ""
## Packs: cuántos Soles entrega (0 si no aplica).
var soles: int = 0
## Packs: precio en moneda real, en centavos (0 si no aplica). En demo es "precio de prueba".
var price_cents: int = 0
## Packs: "ARS" | "USD" ("" si no aplica).
var currency: String = ""
## Boosters/cosméticos: precio en Soles, o `NO_COST`.
var cost_soles: int = NO_COST
## Booster consumible (se descuenta al usar) o permanente.
var consumable: bool = false
## Id de ícono del set de UI.
var icon: String = ""


static func pack(p_id: String, p_title: String, p_desc: String, p_soles: int, p_cents: int, p_currency: String, p_icon: String) -> Product:
	var p: Product = Product.new()
	p.id = p_id
	p.kind = KIND_TOKEN_PACK
	p.title = p_title
	p.description = p_desc
	p.soles = p_soles
	p.price_cents = p_cents
	p.currency = p_currency
	p.icon = p_icon
	return p


static func priced(p_id: String, p_kind: String, p_title: String, p_desc: String, p_cost: int, p_consumable: bool, p_icon: String) -> Product:
	var p: Product = Product.new()
	p.id = p_id
	p.kind = p_kind
	p.title = p_title
	p.description = p_desc
	p.cost_soles = p_cost
	p.consumable = p_consumable
	p.icon = p_icon
	return p


func has_cost_soles() -> bool:
	return cost_soles != NO_COST


func clone() -> Product:
	var p: Product = Product.new()
	p.id = id
	p.kind = kind
	p.title = title
	p.description = description
	p.soles = soles
	p.price_cents = price_cents
	p.currency = currency
	p.cost_soles = cost_soles
	p.consumable = consumable
	p.icon = icon
	return p
