class_name TestCase
extends RefCounted
## Base mínima de tests headless. Cada método `test_*` es un caso (puede ser corrutina).
## El runner (`tests/run_tests.gd`) los descubre, los corre y junta las fallas.

var _failures: Array[String] = []
var _checks: int = 0


func failures() -> Array[String]:
	return _failures


func checks() -> int:
	return _checks


func reset() -> void:
	_failures = []


func check(cond: bool, msg: String = "condición falsa") -> bool:
	_checks += 1
	if not cond:
		_failures.append(msg)
	return cond


func check_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	_checks += 1
	var same: bool = typeof(actual) == typeof(expected) and actual == expected
	if not same and (actual is int or actual is float) and (expected is int or expected is float):
		same = float(actual) == float(expected)
	if not same:
		_failures.append("%s: esperaba %s, dio %s" % [msg, var_to_str(expected), var_to_str(actual)])
	return same


func check_near(actual: float, expected: float, tol: float, msg: String = "") -> bool:
	_checks += 1
	var ok: bool = absf(actual - expected) <= tol
	if not ok:
		_failures.append("%s: esperaba %.12f ± %g, dio %.12f" % [msg, expected, tol, actual])
	return ok
