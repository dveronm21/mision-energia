class_name UiFormat
extends RefCounted
## Formatos en español rioplatense para la UI (equivale a `ui/format.ts`). `fmt1`/`fmtHour` ya
## viven en `JsMath` (los usa también el dominio, en `world/`); acá solo lo que es pura UI.


## Entero con separador de miles "." (es-AR), redondeado igual que JS.
static func fmt_int(n: float) -> String:
	var v: int = JsMath.js_round(n)
	var neg: bool = v < 0
	var digits: String = str(absi(v))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


## `p` en 0..1 → "0".."100%".
static func fmt_pct(p: float) -> String:
	return "%d%%" % roundi(clampf(p, 0.0, 1.0) * 100.0)


## Centavos → "$ 999" (ARS) o "US$ 9,99" (USD), es-AR.
static func fmt_money(cents: int, currency: String = "ARS") -> String:
	var amount: float = float(cents) / 100.0
	if currency == "USD":
		return "US$ %s" % JsMath.fmt_decimal(amount)
	return "$ %s" % fmt_int(roundi(amount))


## Segundos → "1:15".
static func fmt_clock(sec: float) -> String:
	var s: int = maxi(0, int(floor(sec)))
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
