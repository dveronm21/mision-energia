class_name WorkshopDeps
extends RefCounted
## Dependencias del taller (equivale a `WorkshopDeps` de `WorkshopScreen.ts`). A diferencia de
## la web, en vez de un callback `budgetFor` se pasa `boosters` (el servicio de verdad: ya
## sabe calcular el presupuesto con o sin "Presupuesto extra").

var level: LevelDefinition
## Productos tipo booster del catálogo (se muestran los que el jugador tiene).
var boosters_catalog: Array[Product] = []
var inventory: Inventory
var boosters: Boosters
## null = sin saldo visible.
var wallet: Wallet
var bus: EventBus
## null = usar la compra por defecto (mínimo de paneles, 1 batería si hay cupo, sin kit).
var initial: Purchase
## Callable(purchase: Purchase, booster_ids: Array[String]) -> void.
var on_build: Callable
## Callable() -> void.
var on_back: Callable
## Callable() -> void, opcional.
var on_shop: Callable
