class_name GooglePlayBillingProvider
extends IPaymentProvider
## STUB de Google Play Billing. Es EL camino si el juego se publica en Play Store (los bienes digitales
## dentro de apps de Play deben cobrarse con Play Billing). Hoy rechaza todo con status "failed".
##
## Integración real con el plugin oficial `GodotGooglePlayBilling` (Android plugin v2 de Godot 4):
##  0. Export Android con "Use Gradle Build" y el plugin habilitado; productos "in-app" creados en
##     Play Console con los mismos ids del catálogo (pack_small, pack_medium, pack_large).
##  1. Al iniciar: `Engine.has_singleton("GodotGooglePlayBilling")` (o el nodo BillingClient del plugin),
##     conectar señales (connected, query_product_details_response, on_purchase_updated, consume_response)
##     y llamar start_connection().
##  2. purchase(product): query_product_details([product.id], "inapp") y después purchase(product.id).
##     El resultado llega por on_purchase_updated con purchase_token y order_id. Si el estado es
##     PURCHASED → resolver { status: "pending", orderId: order_id } y guardar el purchase_token;
##     USER_CANCELED → "cancelled"; error → "failed".
##  3. verify_on_server(result): POST {backend_url}/payments/googleplay/verify { productId, purchaseToken }.
##     El BACKEND valida con la Google Play Developer API (purchases.products.get, cuenta de servicio
##     que nunca viaja a la app): purchaseState == 0 y que el token no se haya usado; devuelve true.
##  4. Solo si verificó: la Shop acredita (una vez por orderId) y después el cliente llama
##     consume_purchase(purchase_token) para que el pack se pueda volver a comprar.
##     Compras pendientes/no consumidas: al iniciar, query_purchases("inapp") y repetir 3-4.

const NOT_CONFIGURED: String = "Pagos reales aún no configurados"
const PLUGIN_SINGLETON: String = "GodotGooglePlayBilling"

var _backend_url: String


func _init(p_backend_url: String = "") -> void:
	_backend_url = p_backend_url


func provider_id() -> String:
	return IPaymentProvider.ID_GOOGLEPLAY


## true si el plugin está presente en este build (solo Android con el plugin habilitado).
func plugin_available() -> bool:
	return Engine.has_singleton(PLUGIN_SINGLETON)


func _do_purchase(product: Product) -> PaymentResult:
	await _next_frame()
	return PaymentResult.make(PaymentResult.FAILED, "", product.id, NOT_CONFIGURED)


func _do_verify(_result: PaymentResult) -> bool:
	await _next_frame()
	return false
