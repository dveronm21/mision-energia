class_name WalletChip
extends Button
## Saldo de Soles. Se suscribe a `Bus.wallet_changed`; al sumar anima el contador y muestra
## "+N". Si se pasa `on_click` se arma como botón con un "+" (p. ej. abrir la tienda); si no,
## queda deshabilitado (es solo indicador). Equivale a `WalletChip.ts`.

var _wallet: Wallet
var _bus: EventBus
var _num: Label
var _plus_mark: Control
var _shown: int = 0
var _tween: Tween
var _bump_tween: Tween = null
var _coin_source: Vector2 = Vector2.INF
## Callable() -> void, opcional.
var on_click: Callable


func _init(wallet: Wallet, bus: EventBus = null, click_cb: Callable = Callable()) -> void:
	_wallet = wallet
	_bus = bus
	on_click = click_cb
	_shown = wallet.balance()
	disabled = not on_click.is_valid()
	focus_mode = Control.FOCUS_NONE
	# `.wallet-chip`: píldora oscura con borde, sol amarillo, número en Fredoka 20 y, si abre la
	# tienda, un "+" en un círculo amarillo.
	var pill: StyleBoxFlat = UiTheme.box(Color(UiTheme.HUD, 0.9), 999, 2, UiTheme.HUD_LINE)
	UiTheme.style_button(self, pill)
	add_theme_stylebox_override("disabled", pill)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -6
	var sun: HudIcon = HudIcon.new(&"sun", 22.0, UiTheme.SUN)
	sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sun)
	_num = UiTheme.label(UiFormat.fmt_int(_shown), UiTheme.display(600), 20)
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num.size_flags_vertical = Control.SIZE_FILL
	_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_num)
	var w: float = 10.0 + 22.0 + 6.0 + 56.0 + 10.0
	if on_click.is_valid():
		var plus: PanelContainer = PanelContainer.new()
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.custom_minimum_size = Vector2(32, 32)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SUN, 999))
		var pc: CenterContainer = CenterContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(HudIcon.new(&"plus", 16.0, UiTheme.INK))
		plus.add_child(pc)
		_plus_mark = plus
		row.add_child(plus)
		w += 32.0
	add_child(row)
	# Button no calcula su tamaño a partir de hijos agregados a mano: ancho para ~4 cifras.
	custom_minimum_size = Vector2(w, 48 if on_click.is_valid() else 44)

	if on_click.is_valid():
		pressed.connect(on_click)
	if _bus != null:
		_bus.wallet_changed.connect(_on_wallet_changed)


func refresh() -> void:
	_animate_to(_wallet.balance())


func dispose() -> void:
	if _bus != null and _bus.wallet_changed.is_connected(_on_wallet_changed):
		_bus.wallet_changed.disconnect(_on_wallet_changed)
	if _tween != null:
		_tween.kill()


func _on_wallet_changed(_balance: int) -> void:
	_animate_to(_wallet.balance())


func _animate_to(target: int) -> void:
	var from: int = _shown
	var delta: int = target - from
	if _tween != null:
		_tween.kill()
	if delta == 0:
		return
	if delta > 0:
		_float_delta(delta)
	if delta < 0 or not is_inside_tree():
		_shown = target
		_num.text = UiFormat.fmt_int(target)
		return
	var dur: float = minf(0.9, 0.3 + delta * 0.004)
	_tween = create_tween()
	# Espera a que lleguen las primeras monedas volando y recién ahí cuenta.
	_tween.tween_interval(0.5)
	_tween.tween_method(_set_shown, from, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(v: int) -> void:
	_shown = v
	_num.text = UiFormat.fmt_int(v)


## La próxima suma hace volar las monedas desde `global_pos` (p. ej. el bono diario); si no se
## llama, salen del centro de la pantalla.
func coins_from(global_pos: Vector2) -> void:
	_coin_source = global_pos


## `.is-bump`: el chip se agranda un instante al recibir monedas.
func _bump() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size / 2.0
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	scale = Vector2(1.14, 1.14)
	_bump_tween = create_tween()
	_bump_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _float_delta(delta: int) -> void:
	if not is_inside_tree():
		return
	var from: Vector2 = _coin_source if _coin_source != Vector2.INF else get_viewport_rect().size / 2.0
	_coin_source = Vector2.INF
	FxBurst.coins(self, from, global_position + Vector2(22.0, size.y / 2.0), clampi(3 + delta / 15, 4, 14), _bump)
	# `.wc-float`: "+N" amarillo que baja desde el chip y se desvanece.
	var f: Label = UiTheme.label("+%s" % UiFormat.fmt_int(delta), UiTheme.display(700), 17, UiTheme.SUN)
	f.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	f.add_theme_constant_override("shadow_offset_y", 2)
	f.position = Vector2(size.x - 50.0, size.y - 14.0)
	add_child(f)
	var t: Tween = create_tween()
	t.tween_property(f, "position:y", f.position.y + 24.0, 1.1)
	t.parallel().tween_property(f, "modulate:a", 0.0, 1.1)
	t.tween_callback(f.queue_free)
