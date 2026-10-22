class_name ParentalGate
extends RefCounted
## Control parental antes de pagar con dinero real (igual a `ParentalGate.ts`): una multiplicación de
## un dígito por un dígito con ambos factores 6..9, fácil para un adulto y difícil de acertar al azar
## para un chico chico.

var _rng: Callable


## `rng` devuelve un float en [0, 1) (por defecto `randf`).
func _init(rng: Callable = Callable()) -> void:
	_rng = rng if rng.is_valid() else func() -> float: return randf()


func challenge() -> ParentalChallenge:
	var a: int = _factor()
	var b: int = _factor()
	return ParentalChallenge.make("Para seguir, pedile a una persona adulta: ¿cuánto es %d × %d?" % [a, b], a * b)


## Compara la respuesta escrita (tolera espacios). `input` puede ser String o número.
func check(ch: ParentalChallenge, input: Variant) -> bool:
	var n: float
	if input is int or input is float:
		n = float(input)
	else:
		var s: String = str(input).strip_edges()
		if not s.is_valid_float():
			return false
		n = s.to_float()
	return is_finite(n) and n == float(ch.answer)


func _factor() -> int:
	return 6 + mini(3, floori(float(_rng.call()) * 4.0))
