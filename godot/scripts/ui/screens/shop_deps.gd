class_name ShopDeps
extends RefCounted
## Dependencias de la tienda (equivale a `ShopDeps` de `ShopScreen.ts`). En vez de un callback
## `askParent(): Promise<bool>` genérico, se pasan `screens` + `gate` directo: `ShopScreen`
## llama `await ParentalGateModal.ask(screens, gate)` él mismo.

const TAB_SOLES: StringName = &"soles"
const TAB_MEJORAS: StringName = &"mejoras"
const TAB_VESTUARIO: StringName = &"vestuario"

var shop: Shop
var wallet: Wallet
var inventory: Inventory
var bus: EventBus
var screens: ScreenManager
var gate: ParentalGate
## Callable() -> void.
var on_back: Callable
## Callable(product: Product) -> void, opcional (ej. sonido "coin" al acreditar).
var on_purchased: Callable
var initial_tab: StringName = TAB_SOLES
