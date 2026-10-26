class_name NoPaymentProvider
extends IPaymentProvider
## Sin compras con dinero real (versión de Play Store mientras no esté Google Play Billing):
## la tienda oculta los packs de Soles y los Soles se ganan jugando. Cualquier intento de
## compra falla sin acreditar nada.


func provider_id() -> String:
	return IPaymentProvider.ID_NONE


func sells_real_money() -> bool:
	return false
