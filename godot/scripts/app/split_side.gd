class_name SplitSide
extends RefCounted
## Una mitad del versus en pantalla dividida (`SplitVersus`): quién juega, su partida y su interfaz.

## Asiento de la tablet, o −1 = teclado.
var slot: int = -1
var name: String = ""
var color: Color = UiTheme.SUN
var session: GameSession
var hud: Hud
var ui: SplitHalfUi
var viewport: SubViewport
var area: Control
var banner: DuelBanner
var last_banner: String = ""
