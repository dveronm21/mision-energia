class_name SessionDeps
extends RefCounted
## Lo que `GameSession` necesita de afuera para armar una partida (equivale a `SessionDeps`
## de `GameSession.ts`). A diferencia de la web no hace falta inyectar `factory`/`env`/`camera`/
## `dragSurface`: `PlantWorld` arma sus propios visuales y `CameraRig` crea su propia cámara.

var level: LevelDefinition
var purchase: Purchase
## Créditos gastados en el taller.
var spent: int = 0
## Boosters ya consumidos en el taller para esta partida ("boost_hint", "boost_drone", ...).
var active_boosters: Array[StringName] = []
## {"helmet": Color, "vest": Color}, ambas opcionales (quien arma esto resuelve el cosmético
## equipado contra `Catalog.COSMETIC_COLORS`).
var cosmetics: Dictionary = {}
var audio: AudioSynth
var inventory: Inventory
var boosters: Boosters
var hud: HudPort
var ui: UiRootPort
## Callable(result: LevelResult) -> void.
var on_finished: Callable
