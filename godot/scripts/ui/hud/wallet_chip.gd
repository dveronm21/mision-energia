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
## Callable() -> void, opcional.
var on_click: Callable


func _init(wallet: Wallet, bus: EventBus = null, click_cb: Callable = Callable()) -> void:
	_wallet = wallet
	_bus = bus
	on_click = click_cb
	_shown = wallet.balance()
	flat = true
	disabled = not on_click.is_valid()
	focus_mode = Control.FOCUS_NONE
	# Ancho mínimo fijo: Button no calcula su tamaño a partir de hijos Control agregados a mano
	# (solo de su propio texto/ícono nativos), así que sin esto puede colapsar casi invisible.
	custom_minimum_size = Vector2(100, 40)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(HudIcon.new(&"coins", 22.0, VisualMaterials.C_SUN))
	_num = Label.new()
	_num.text = UiFormat.fmt_int(_shown)
	_num.add_theme_font_size_override("font_size", 16)
	row.add_child(_num)
	if on_click.is_valid():
		_plus_mark = HudIcon.new(&"star", 14.0)
		row.add_child(_plus_mark)
	add_child(row)

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
	_tween.tween_method(_set_shown, from, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(v: int) -> void:
	_shown = v
	_num.text = UiFormat.fmt_int(v)


func _float_delta(delta: int) -> void:
	if not is_inside_tree():
		return
	var f: Label = Label.new()
	f.text = "+%s" % UiFormat.fmt_int(delta)
	f.add_theme_color_override("font_color", VisualMaterials.C_OK)
	f.position = Vector2(0, -28)
	add_child(f)
	var t: Tween = create_tween()
	t.tween_property(f, "position:y", -48.0, 1.1)
	t.parallel().tween_property(f, "modulate:a", 0.0, 1.1)
	t.tween_callback(f.queue_free)
