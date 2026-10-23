class_name UiRoot
extends UiRootPort
## Raíz de la UI: crea las capas (HUD, pantallas, avisos) y expone el `ScreenManager`.
## Equivale a `UiRoot.ts`. Capas (de abajo hacia arriba): `hud_layer` → `screen_layer` →
## `top_layer` (toast).
##
## A diferencia de la web no hace falta inyectar CSS (`injectStyles`): cada `Control` se
## estiliza en código. Tampoco hay un "click global con sonido" genérico por `data-sfx`: cada
## botón llama `audio.play(...)` donde haga falta, o se puede usar `wire_click_sfx()` para no
## repetir la conexión a mano.

## Nodo de verdad: agregalo a la escena (ocupa toda la pantalla).
var root: Control
var hud_layer: Control
var screen_layer: Control
var top_layer: Control
var screens: ScreenManager

var _audio: AudioSynth


func _init(audio: AudioSynth = null) -> void:
	_audio = audio
	root = Control.new()
	root.name = "ui-root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fuentes y colores por defecto de toda la UI (pantallas, HUD y toast).
	root.theme = UiTheme.build()

	hud_layer = _layer("ui-hud")
	hud_layer.visible = false
	root.add_child(hud_layer)

	screen_layer = _layer("ui-screens")
	root.add_child(screen_layer)

	top_layer = _layer("ui-top")
	top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_layer)

	screens = ScreenManager.new(screen_layer)
	toast = Toast.new()
	toast.root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.root.offset_top = 12
	top_layer.add_child(toast.root)


## Las capas no atrapan toques: los toman las pantallas y los controles del HUD, y lo que sobra
## llega al mundo 3D (la cámara escucha `_unhandled_input`).
func _layer(layer_name: String) -> Control:
	var c: Control = Control.new()
	c.name = layer_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Muestra/oculta el HUD de juego.
func set_hud_visible(on: bool) -> void:
	hud_layer.visible = on


func show_toast(text: String, kind: StringName = KIND_INFO, ms: int = -1) -> void:
	var t: Toast = toast
	if ms >= 0:
		t.show(text, kind, ms)
	else:
		t.show(text, kind)


## Para el botón atrás de Android (o Escape): true si una pantalla lo consumió.
func handle_back() -> bool:
	return screens.handle_back()


## Conecta un botón para que suene `sfx_name` al tocarlo (reemplaza el `data-sfx` genérico
## de la web, que escuchaba todos los clics de golpe).
func wire_click_sfx(button: Button, sfx_name: String = "click") -> void:
	if _audio == null:
		return
	button.pressed.connect(func() -> void: _audio.play(sfx_name))
