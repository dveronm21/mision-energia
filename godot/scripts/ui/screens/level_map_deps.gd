class_name LevelMapDeps
extends RefCounted
## Dependencias del mapa de niveles (equivale a `LevelMapDeps` de `LevelMapScreen.ts`).

var levels: Array[LevelDefinition] = []
var manager: LevelManager
var wallet: Wallet
var bus: EventBus
## Callable(id: String) -> void.
var on_play: Callable
## Callable() -> void.
var on_back: Callable
## Callable() -> void, opcional.
var on_shop: Callable
