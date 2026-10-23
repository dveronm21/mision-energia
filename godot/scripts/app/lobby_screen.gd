class_name LobbyScreen
extends UiScreen
## Sala de espera del modo TV como pantalla de la pila (envuelve `LobbyView`: QR con la URL del
## control, los 2 lugares y "Empezar"). La vista ya maneja sola "Atrás" (tecla, ui_cancel y el
## botón del sistema) y emite `back_requested`; por eso `on_back()` solo lo consume.

var view: LobbyView


## `on_start`/`on_back`: Callable() -> void.
func _init(host: RemoteHost, on_start: Callable, on_back: Callable) -> void:
	view = LobbyView.new()
	view.name = "lobby"
	view.setup(host)
	view.start_requested.connect(on_start)
	view.back_requested.connect(on_back)
	root = view


func on_enter() -> void:
	view.show_lobby()


func on_leave() -> void:
	view.hide_lobby()


func on_back() -> bool:
	return true
