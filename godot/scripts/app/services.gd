class_name AppServices
extends Node
## Composición de servicios del dominio (equivale a `Services.ts`). Autoload `Services`.
##
## Orden de construcción (igual que la web): store → bus → audio → wallet → inventory →
## catalog → shop (con DemoPaymentProvider) → rewards → levels → progress → boosters → gate.
## El audio vive como hijo de este nodo y sobrevive a "Reiniciar progreso" (solo se
## reinicia el `SaveStore`, no el `AudioSynth`).

var store: SaveStore
var bus: EventBus
var audio: AudioSynth

var wallet: Wallet
var inventory: Inventory
var catalog: Catalog
var shop: Shop
var rewards: RewardService
var levels: LevelCatalog
var progress: LevelManager
var boosters: Boosters
var gate: ParentalGate


func _enter_tree() -> void:
	bus = get_node_or_null("/root/Bus") as EventBus
	_build(SaveStore.new())


## Reconstruye todos los servicios de dominio sobre un `SaveStore` nuevo (p. ej. "Reiniciar
## progreso", o para tests que necesitan un `Services` aislado). El audio NO se reconstruye.
func _build(new_store: SaveStore) -> void:
	store = new_store
	wallet = Wallet.new(store, bus)
	inventory = Inventory.new(store)
	catalog = Catalog.new()
	shop = Shop.new(catalog, wallet, inventory, payment_provider(), store, bus)
	rewards = RewardService.new(wallet, store)
	levels = LevelCatalog.new()
	progress = LevelManager.new(levels, store, wallet)
	boosters = Boosters.new(inventory)
	gate = ParentalGate.new()
	if audio == null:
		audio = AudioSynth.new()
		audio.setup(store)
		add_child(audio)
	else:
		audio.setup(store)


## Versión de Play Store (característica de exportación `play`): sin compras con dinero real
## hasta integrar Google Play Billing. APK de la feria y desarrollo: pagos simulados.
static func payment_provider() -> IPaymentProvider:
	if OS.has_feature("play"):
		return NoPaymentProvider.new()
	return DemoPaymentProvider.new()


## Borra todo el progreso guardado y reconstruye los servicios desde cero. El audio
## sigue siendo la misma instancia (su mute persiste si se vuelve a leer del nuevo store).
func reset_progress() -> void:
	store.clear_all()
	_build(SaveStore.new())
