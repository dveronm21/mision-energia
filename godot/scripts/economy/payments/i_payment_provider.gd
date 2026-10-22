class_name IPaymentProvider
extends RefCounted
## Proveedor de pago intercambiable (equivale a `IPaymentProvider` de `contracts.ts`).
## Hoy: `DemoPaymentProvider` (simulado). Real: `GooglePlayBillingProvider` (si se publica en Play Store)
## o `MercadoPagoProvider` (otras distribuciones).
##
## `purchase()` y `verify_on_server()` son corrutinas: se usan con `await`
##   var r: PaymentResult = await provider.purchase(product)
## y además emiten `purchase_finished` / `verify_finished` para quien prefiera señales.
##
## Regla de seguridad: un proveedor real NUNCA acredita del lado del cliente sin una confirmación
## del servidor (`verify_on_server`). El demo marca sus órdenes con prefijo "DEMO-".
## Las subclases sobrescriben `_do_purchase` / `_do_verify` (también corrutinas).

signal purchase_finished(result: PaymentResult)
signal verify_finished(result: PaymentResult, ok: bool)

const ID_DEMO: String = "demo"
const ID_MERCADOPAGO: String = "mercadopago"
const ID_GOOGLEPLAY: String = "googleplay"


## "demo" | "mercadopago" | "googleplay"
func provider_id() -> String:
	return ""


func is_demo() -> bool:
	return false


func purchase(product: Product) -> PaymentResult:
	var r: PaymentResult = await _do_purchase(product)
	if r == null:
		r = PaymentResult.make(PaymentResult.FAILED, "", product.id, "No se pudo iniciar el pago.")
	purchase_finished.emit(r)
	return r


## Para proveedores reales: confirma con el backend antes de acreditar.
func verify_on_server(result: PaymentResult) -> bool:
	var ok: bool = await _do_verify(result)
	verify_finished.emit(result, ok)
	return ok


## Implementación por defecto: no hay proveedor (falla).
func _do_purchase(product: Product) -> PaymentResult:
	await _next_frame()
	return PaymentResult.make(PaymentResult.FAILED, "", product.id, "Sin proveedor de pago.")


func _do_verify(_result: PaymentResult) -> bool:
	await _next_frame()
	return false


## Espera un frame del SceneTree (asincronía equivalente a una Promise resuelta). Sin árbol, sigue de largo.
func _next_frame() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame


## Espera `seconds` con un timer del SceneTree (o un frame si es 0).
func _wait(seconds: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if seconds > 0.0:
		await tree.create_timer(seconds, true, false, true).timeout
	else:
		await tree.process_frame
