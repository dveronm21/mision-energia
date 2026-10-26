class_name Shop
extends RefCounted
## Tienda (igual a `Shop.ts`). Packs de Soles: proveedor.purchase → proveedor.verify_on_server →
## recién ahí acredita (y una sola vez por orderId, guardado). Boosters/cosméticos: se pagan con Soles.
## La UI debe pasar el `ParentalGate` ANTES de llamar a `buy_token_pack`.

## Terminó una compra de pack (mismo resultado que devuelve `buy_token_pack`).
signal token_pack_finished(result: PaymentResult)

const ORDERS_KEY: String = "shop.credited_orders"

var _products: Catalog
var _wallet: Wallet
var _inventory: Inventory
var _payments: IPaymentProvider
var _store: SaveStore
var _bus: EventBus
var _credited: Array[String] = []


func _init(products: Catalog, wallet: Wallet, inventory: Inventory, payments: IPaymentProvider,
		store: SaveStore, bus: EventBus = null) -> void:
	_products = products
	_wallet = wallet
	_inventory = inventory
	_payments = payments
	_store = store
	_bus = bus
	var saved: Variant = store.load_value(ORDERS_KEY, [])
	if saved is Array:
		for o: Variant in saved:
			_credited.append(str(o))


func catalog() -> Array[Product]:
	return _products.all()


## true si el proveedor actual es de demostración (la UI muestra "precio de prueba").
func is_demo() -> bool:
	return _payments.is_demo()


## false si esta versión no vende packs con dinero real (Play Store sin Billing todavía).
func sells_real_money() -> bool:
	return _payments.sells_real_money()


func is_credited(order_id: String) -> bool:
	return _credited.has(order_id)


## Compra un pack de Soles con dinero real (vía proveedor) y acredita si se verifica. Corrutina.
func buy_token_pack(product_id: String) -> PaymentResult:
	var r: PaymentResult = await _buy_token_pack(product_id)
	token_pack_finished.emit(r)
	return r


func _buy_token_pack(product_id: String) -> PaymentResult:
	var p: Product = _products.find(product_id)
	if p == null or p.kind != Product.KIND_TOKEN_PACK or p.soles <= 0:
		return PaymentResult.make(PaymentResult.FAILED, "", product_id, "Ese producto no es un pack de Soles.")
	var result: PaymentResult = await _payments.purchase(p)
	if result == null:
		return PaymentResult.make(PaymentResult.FAILED, "", product_id, "No se pudo iniciar el pago.")
	if result.status != PaymentResult.APPROVED:
		return result
	var verified: bool = await _payments.verify_on_server(result)
	if not verified:
		return result.with_changes(PaymentResult.FAILED, "No pudimos confirmar el pago. No se cobró ningún Sol.")
	if _credited.has(result.order_id):
		return result.with_changes(result.status, "Esta compra ya estaba acreditada.")
	_credited.append(result.order_id)
	_store.save_value(ORDERS_KEY, _credited)
	_wallet.add(p.soles, "Compra %s (%s)" % [p.id, result.order_id])
	if _bus != null:
		_bus.emit_sfx("coin")
	return result.with_changes(result.status, "¡Listo! Sumaste %d Soles." % p.soles)


## Compra un booster / cosmético con Soles.
func buy_with_soles(product_id: String) -> bool:
	var p: Product = _products.find(product_id)
	if p == null or (p.kind != Product.KIND_BOOSTER and p.kind != Product.KIND_COSMETIC) or not p.has_cost_soles():
		return false
	if p.kind == Product.KIND_COSMETIC and _inventory.count(p.id) > 0:
		return false # permanente: ya lo tenés
	if not _wallet.spend(p.cost_soles, "Tienda: %s" % p.title):
		return false
	_inventory.grant(p.id, 1)
	if _bus != null:
		_bus.emit_sfx("coin")
	return true
