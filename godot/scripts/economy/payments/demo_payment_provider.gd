class_name DemoPaymentProvider
extends IPaymentProvider
## Pago SIMULADO (igual a `DemoPaymentProvider.ts`): espera ~0,6 s y aprueba.
## Órdenes con prefijo "DEMO-". No mueve dinero real.

var _delay_sec: float
var _id_gen: Callable
var _seq: int = 0


## `id_gen` opcional para ids reproducibles en tests (devuelve String).
func _init(delay_sec: float = 0.6, id_gen: Callable = Callable()) -> void:
	_delay_sec = delay_sec
	_id_gen = id_gen


func provider_id() -> String:
	return IPaymentProvider.ID_DEMO


func is_demo() -> bool:
	return true


func _do_purchase(product: Product) -> PaymentResult:
	await _wait(_delay_sec)
	return PaymentResult.make(PaymentResult.APPROVED, "DEMO-" + _next_id(), product.id, "Pago de prueba aprobado.")


func _do_verify(result: PaymentResult) -> bool:
	await _next_frame()
	return result.status == PaymentResult.APPROVED and result.order_id.begins_with("DEMO-")


func _next_id() -> String:
	if _id_gen.is_valid():
		return str(_id_gen.call())
	_seq += 1
	return "%s-%s" % [JsMath.to_base36(int(Time.get_unix_time_from_system() * 1000.0)), JsMath.to_base36(_seq)]
