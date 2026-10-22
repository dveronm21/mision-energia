class_name HttpRequestHead
extends RefCounted
## Cabecera de una petición HTTP/1.1 ya parseada (sin cuerpo).

var method: String = ""
## Tal cual vino: "/ws?x=1".
var target: String = ""
## Sin query ni fragmento: "/ws".
var path: String = ""
var version: String = ""
var _headers: Dictionary = {}   # nombre en minúsculas → valor (repetidas unidas con ", ")


func _init(p_method: String, p_target: String, p_version: String, headers: Dictionary) -> void:
	method = p_method
	target = p_target
	version = p_version
	_headers = headers
	var cut: int = target.length()
	var q: int = target.find("?")
	var h: int = target.find("#")
	if q >= 0:
		cut = q
	if h >= 0 and h < cut:
		cut = h
	path = target.substr(0, cut)


## Valor de la cabecera (sin distinguir mayúsculas) o "" si no está.
func header(header_name: String) -> String:
	return _headers.get(header_name.to_lower(), "")


func has_header(header_name: String) -> bool:
	return _headers.has(header_name.to_lower())


## true si la cabecera (lista separada por comas) contiene el token, sin distinguir mayúsculas.
func header_has_token(header_name: String, token: String) -> bool:
	for part: String in header(header_name).split(","):
		if part.strip_edges().to_lower() == token.to_lower():
			return true
	return false
