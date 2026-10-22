class_name PaymentResult
extends RefCounted
## Resultado de un intento de pago.

const APPROVED: String = "approved"
const CANCELLED: String = "cancelled"
const FAILED: String = "failed"
const PENDING: String = "pending"

## "approved" | "cancelled" | "failed" | "pending"
var status: String = FAILED
var order_id: String = ""
var product_id: String = ""
var message: String = ""


static func make(p_status: String, p_order: String, p_product: String, p_message: String = "") -> PaymentResult:
	var r: PaymentResult = PaymentResult.new()
	r.status = p_status
	r.order_id = p_order
	r.product_id = p_product
	r.message = p_message
	return r


func is_approved() -> bool:
	return status == APPROVED


## Copia con otro estado y/o mensaje (como `{...result, status, message}` de la web).
func with_changes(p_status: String, p_message: String) -> PaymentResult:
	return PaymentResult.make(p_status, order_id, product_id, p_message)
