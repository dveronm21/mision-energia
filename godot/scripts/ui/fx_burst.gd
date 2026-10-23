class_name FxBurst
extends Control
## Partículas 2D de la interfaz, dibujadas a mano (sin texturas ni GPUParticles2D, que en
## GL Compatibility de algunos teléfonos fallan):
##   coins()    soles que saltan desde un punto y vuelan hasta el saldo
##   confetti() lluvia de papelitos de colores en toda la pantalla
##   sparkle()  destello de estrellitas alrededor de un punto
## Cada ráfaga es un nodo `top_level` (coordenadas de pantalla, encima de todo) que se borra
## solo al terminar. `host` es cualquier `Control` que esté en pantalla.

enum Kind { COINS, CONFETTI, SPARKLE }

const COIN_R: float = 11.0
const CONFETTI_COLORS: Array[Color] = [
	Color("#ffb82e"), Color("#3fa34d"), Color("#f28c28"), Color("#7fb3ff"), Color("#ffffff"), Color("#d6c2ff"), Color("#ff6f61"),
]

var kind: Kind = Kind.COINS
## Callable() -> void: se llama cada vez que una moneda llega a destino (p. ej. hacer saltar el saldo).
var on_arrive: Callable = Callable()

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _rot: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _col: PackedColorArray = PackedColorArray()
var _done: PackedByteArray = PackedByteArray()
var _from: PackedVector2Array = PackedVector2Array()
var _target: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_kind: Kind = Kind.COINS) -> void:
	kind = p_kind
	name = "fx-burst"
	top_level = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


static func _spawn(host: Control, p_kind: Kind) -> FxBurst:
	if host == null or not host.is_inside_tree():
		return null
	var fx: FxBurst = FxBurst.new(p_kind)
	host.add_child(fx)
	fx.position = Vector2.ZERO
	fx.size = host.get_viewport_rect().size
	return fx


## Monedas: salen disparadas desde `from`, flotan un instante y vuelan con aceleración a `to`.
static func coins(host: Control, from: Vector2, to: Vector2, count: int = 10, arrive_cb: Callable = Callable()) -> FxBurst:
	var fx: FxBurst = _spawn(host, Kind.COINS)
	if fx == null:
		return null
	fx._target = to
	fx.on_arrive = arrive_cb
	for i: int in count:
		var a: float = fx._rng.randf() * TAU
		fx._add(from, Vector2(cos(a), sin(a)) * fx._rng.randf_range(160.0, 420.0) + Vector2(0, -140.0),
			fx._rng.randf() * TAU, fx._rng.randf_range(6.0, 12.0), 0.55 + i * 0.045 + fx._rng.randf() * 0.1, 1.0, UiTheme.SUN)
	return fx


## Confeti: papelitos que caen desde arriba de la pantalla girando y bamboleándose.
static func confetti(host: Control, count: int = 110) -> FxBurst:
	var fx: FxBurst = _spawn(host, Kind.CONFETTI)
	if fx == null:
		return null
	var w: float = fx.size.x
	for i: int in count:
		var p: Vector2 = Vector2(fx._rng.randf() * w, -20.0 - fx._rng.randf() * 260.0)
		var v: Vector2 = Vector2(fx._rng.randf_range(-60.0, 60.0), fx._rng.randf_range(120.0, 260.0))
		fx._add(p, v, fx._rng.randf() * TAU, fx._rng.randf_range(-7.0, 7.0), fx._rng.randf_range(2.4, 3.6),
			fx._rng.randf_range(0.7, 1.3), CONFETTI_COLORS[i % CONFETTI_COLORS.size()])
	return fx


## Destello: estrellitas de 4 puntas que salen en anillo desde `at` y se apagan.
static func sparkle(host: Control, at: Vector2, count: int = 14, color: Color = Color("#ffe066")) -> FxBurst:
	var fx: FxBurst = _spawn(host, Kind.SPARKLE)
	if fx == null:
		return null
	for i: int in count:
		var a: float = (float(i) / count) * TAU + fx._rng.randf() * 0.3
		fx._add(at, Vector2(cos(a), sin(a)) * fx._rng.randf_range(90.0, 220.0), a, fx._rng.randf_range(-4.0, 4.0),
			fx._rng.randf_range(0.45, 0.7), fx._rng.randf_range(0.7, 1.3), color if i % 3 != 0 else Color.WHITE)
	return fx


func _add(p: Vector2, v: Vector2, r: float, s: float, life: float, sz: float, c: Color) -> void:
	_pos.append(p)
	_from.append(p)
	_vel.append(v)
	_rot.append(r)
	_spin.append(s)
	_age.append(0.0)
	_life.append(life)
	_size.append(sz)
	_col.append(c)
	_done.append(0)


func _process(dt: float) -> void:
	var alive: int = 0
	for i: int in _pos.size():
		if _done[i] != 0:
			continue
		_age[i] += dt
		match kind:
			Kind.COINS:
				_step_coin(i, dt)
			Kind.CONFETTI:
				var v: Vector2 = _vel[i]
				v = Vector2((v.x + sin(_age[i] * 4.0 + i) * 120.0 * dt) * (1.0 - 0.8 * dt), minf(v.y + 260.0 * dt, 320.0))
				_vel[i] = v
				_pos[i] += v * dt
				_rot[i] += _spin[i] * dt
			Kind.SPARKLE:
				_vel[i] *= 1.0 - 3.5 * dt
				_pos[i] += _vel[i] * dt
				_rot[i] += _spin[i] * dt
		if _done[i] == 0 and _age[i] >= _life[i] and kind != Kind.COINS:
			_done[i] = 1
		if _done[i] == 0:
			alive += 1
	queue_redraw()
	if alive == 0:
		queue_free()


## Moneda: primero el salto (con gravedad y frenado), después vuela a destino acelerando.
func _step_coin(i: int, dt: float) -> void:
	var launch: float = 0.32
	if _age[i] < launch:
		_vel[i] = _vel[i] * (1.0 - 4.0 * dt) + Vector2(0, 520.0 * dt)
		_pos[i] += _vel[i] * dt
		_from[i] = _pos[i]
		return
	var k: float = clampf((_age[i] - launch) / maxf(_life[i] - launch, 0.05), 0.0, 1.0)
	var e: float = k * k * k
	# Curva hacia arriba en el viaje (no línea recta): se siente "lanzada".
	var mid: Vector2 = (_from[i] + _target) / 2.0 + Vector2(0, -90.0)
	_pos[i] = _from[i].lerp(mid, e).lerp(mid.lerp(_target, e), e)
	_rot[i] += dt * _spin[i]
	if k >= 1.0:
		_done[i] = 1
		if on_arrive.is_valid():
			on_arrive.call()


func _draw() -> void:
	for i: int in _pos.size():
		if _done[i] != 0:
			continue
		match kind:
			Kind.COINS:
				_draw_coin(_pos[i], _size[i], _rot[i])
			Kind.CONFETTI:
				var fade: float = clampf((_life[i] - _age[i]) / 0.5, 0.0, 1.0)
				var c: Color = Color(_col[i], fade)
				# Se "da vuelta": el ancho oscila (cara y canto del papelito).
				var w: float = 9.0 * _size[i] * absf(cos(_age[i] * 6.0 + i))
				var h: float = 14.0 * _size[i]
				draw_set_transform(_pos[i], _rot[i], Vector2.ONE)
				draw_rect(Rect2(-w / 2.0, -h / 2.0, maxf(w, 1.5), h), c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.SPARKLE:
				var t: float = _age[i] / _life[i]
				_draw_star4(_pos[i], 9.0 * _size[i] * (1.0 - t * 0.6), _rot[i], Color(_col[i], 1.0 - t))


## Sol-moneda: canto oscuro, cara amarilla, brillo arriba y el giro (se angosta y se ensancha).
func _draw_coin(p: Vector2, s: float, r: float) -> void:
	var sx: float = maxf(0.4, absf(cos(r)))
	draw_set_transform(p, 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2(0, 2.5), COIN_R * s, UiTheme.SUN_DARK, true, -1.0, true)
	draw_circle(Vector2.ZERO, COIN_R * s, UiTheme.SUN, true, -1.0, true)
	draw_arc(Vector2.ZERO, COIN_R * s * 0.66, 0.0, TAU, 20, UiTheme.SUN_DARK, 2.0, true)
	draw_circle(Vector2(-COIN_R * 0.35, -COIN_R * 0.4) * s, COIN_R * 0.22 * s, Color(1, 1, 1, 0.75), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_star4(p: Vector2, r: float, rot: float, c: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 8:
		var a: float = rot + k * TAU / 8.0
		var rr: float = r if k % 2 == 0 else r * 0.3
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)
