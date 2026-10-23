class_name JsMath
extends RefCounted
## Utilidades numéricas que reproducen exactamente la semántica de JavaScript de la versión web,
## para que puntajes, presupuestos y textos den lo mismo que en `app/`.


## Igual que `Math.round` de JS: redondea al entero más cercano y los empates van hacia +∞
## (`round()` de Godot los manda lejos del cero: -2.5 → -3, en JS da -2).
static func js_round(x: float) -> int:
	var r: float = floor(x)
	if x - r >= 0.5:
		r += 1.0
	return int(r)


## Como `(Math.round(n * 10) / 10).toString().replace('.', ',')`: un decimal como máximo,
## sin ",0" final y con coma decimal (formato rioplatense).
static func fmt_decimal(n: float) -> String:
	var tenths: int = js_round(n * 10.0)
	var sign_txt: String = "-" if tenths < 0 else ""
	var abs_tenths: int = absi(tenths)
	@warning_ignore("integer_division")
	var whole: int = abs_tenths / 10
	var frac: int = abs_tenths % 10
	if frac == 0:
		return "%s%d" % [sign_txt, whole]
	return "%s%d,%d" % [sign_txt, whole, frac]


## Hora de juego (10.5, o 30 = 06:00 del día siguiente) a reloj "HH:MM" (equivale a `fmtHour`
## de `ui/format.ts`): `10.5` → "10:30"; `30` → "06:00".
static func fmt_hour(hour: float) -> String:
	var h: float = fposmod(hour, 24.0)
	var hh: int = int(floor(h))
	var mm: int = js_round((h - hh) * 60.0)
	if mm == 60:
		mm = 0
		hh = (hh + 1) % 24
	return "%02d:%02d" % [hh, mm]


## Número en base 36 (como `n.toString(36)` de JS) para ids de órdenes.
static func to_base36(n: int) -> String:
	if n == 0:
		return "0"
	const DIGITS: String = "0123456789abcdefghijklmnopqrstuvwxyz"
	var neg: bool = n < 0
	var v: int = absi(n)
	var out: String = ""
	while v > 0:
		out = DIGITS[v % 36] + out
		@warning_ignore("integer_division")
		v = v / 36
	return ("-" + out) if neg else out


## Rellena con espacios a la derecha hasta `width` caracteres (como `pad` del balance web).
static func pad_right(s: String, width: int) -> String:
	if s.length() >= width:
		return s
	return s + " ".repeat(width - s.length())
