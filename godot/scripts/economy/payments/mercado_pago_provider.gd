class_name MercadoPagoProvider
extends IPaymentProvider
## STUB de Mercado Pago (Checkout Pro). Hoy rechaza todo con status "failed".
##
## Flujo real a implementar (nunca acreditar desde el cliente sin confirmación del servidor):
##  1. purchase(product): POST {backend_url}/payments/preferences { productId, installId } con HTTPRequest.
##     El BACKEND (con el access token privado, que jamás viaja a la app) crea la preferencia en la API
##     de Mercado Pago con el precio del catálogo del servidor (no el del cliente),
##     external_reference = orderId propio y notification_url = webhook. Devuelve { orderId, initPoint }.
##  2. La app abre initPoint (Checkout Pro) con OS.shell_open() (Custom Tab / navegador externo).
##     Las back_urls vuelven a la app con el deep link misionenergia://pago (intent filter en el export Android).
##  3. Mercado Pago notifica al webhook del backend; el backend consulta GET /v1/payments/{id},
##     valida monto, moneda y external_reference, y marca la orden como "approved" (idempotente).
##  4. Al volver a la app, purchase resuelve { status: "pending", orderId }; la UI hace polling a
##     verify_on_server(result) → GET {backend_url}/payments/orders/{orderId} → true solo si "approved".
##     Recién ahí la Shop acredita los Soles (una vez por orderId).
##  Nota: para apps distribuidas por Google Play, los bienes digitales deben venderse con
##  Google Play Billing (GooglePlayBillingProvider); Mercado Pago aplica a otras distribuciones.

const NOT_CONFIGURED: String = "Pagos reales aún no configurados"

var _backend_url: String


func _init(p_backend_url: String = "") -> void:
	_backend_url = p_backend_url


func provider_id() -> String:
	return IPaymentProvider.ID_MERCADOPAGO


func backend_url() -> String:
	return _backend_url


func _do_purchase(product: Product) -> PaymentResult:
	await _next_frame()
	return PaymentResult.make(PaymentResult.FAILED, "", product.id, NOT_CONFIGURED)


func _do_verify(_result: PaymentResult) -> bool:
	await _next_frame()
	return false
