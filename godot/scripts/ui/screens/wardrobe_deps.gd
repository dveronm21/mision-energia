class_name WardrobeDeps
extends RefCounted
## Dependencias de la pantalla de vestuario (equivale a `WardrobeDeps` de `WardrobeScreen.ts`).

var catalog: Catalog
var inventory: Inventory
## null = sin saldo visible (sin acceso a la tienda desde acá).
var wallet: Wallet
var bus: EventBus
## Callable() -> void.
var on_back: Callable
## Callable() -> void, opcional.
var on_shop: Callable
## Callable(slot: StringName, product_id: String) -> void, opcional (""=ninguno, para
## actualizar el personaje 3D fuera de esta pantalla).
var on_equip: Callable
