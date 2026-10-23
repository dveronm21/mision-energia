class_name MainMenuDeps
extends RefCounted
## Dependencias del menú principal (equivale a `MainMenuDeps` de `MainMenu.ts`).

var wallet: Wallet
## null = sin bono diario.
var rewards: RewardService
var bus: EventBus
## Callable() -> void, cada uno.
var on_play: Callable
var on_shop: Callable
var on_wardrobe: Callable
var on_settings: Callable
