class_name HttpRequestParser
extends RefCounted
## Parser incremental y acotado de la cabecera de una petición HTTP/1.1 (port de HttpRequest.java).
## Se le pasan los bytes a medida que llegan (feed); cuando termina la cabecera deja la petición en
## `request` y conserva los bytes que sobraron (por ejemplo, frames WebSocket que llegaron pegados).

enum Result { NEED_MORE, DONE, ERROR }

## Máximo de la cabecera (431 si se excede).
const MAX_HEAD_BYTES: int = 8192

var request: HttpRequestHead
var error_status: int = 0
var error_message: String = ""
var _buf := PackedByteArray()
var _leftover := PackedByteArray()
var _scan_from: int = 0


func has_partial_data() -> bool:
	return not _buf.is_empty()


## Agrega bytes. DONE: `request` listo; ERROR: ver error_status (400/431).
func feed(data: PackedByteArray) -> Result:
	_buf.append_array(data)
	var end: int = _find_head_end()
	if end < 0:
		if _buf.size() > MAX_HEAD_BYTES:
			return _fail(431, "Cabecera demasiado grande")
		return Result.NEED_MORE
	if end > MAX_HEAD_BYTES:
		return _fail(431, "Cabecera demasiado grande")
	var head: String = _buf.slice(0, end).get_string_from_ascii()
	_leftover = _buf.slice(end + 4)
	_buf = PackedByteArray()
	_scan_from = 0
	return _parse(head)


## Bytes recibidos después de la cabecera (se vacían al tomarlos).
func take_leftover() -> PackedByteArray:
	var out: PackedByteArray = _leftover
	_leftover = PackedByteArray()
	return out


## Prepara para la siguiente petición (keep-alive), conservando los bytes sobrantes como inicio.
func reset_keep_leftover() -> void:
	request = null
	_buf = take_leftover()
	_scan_from = 0


func _find_head_end() -> int:
	var n: int = _buf.size()
	var i: int = maxi(0, _scan_from - 3)
	while i + 3 < n:
		if _buf[i] == 13 and _buf[i + 1] == 10 and _buf[i + 2] == 13 and _buf[i + 3] == 10:
			return i
		i += 1
	_scan_from = n
	return -1


func _parse(head: String) -> Result:
	var lines: PackedStringArray = head.split("\r\n")
	if lines.is_empty():
		return _fail(400, "Petición vacía")
	var rl: PackedStringArray = lines[0].split(" ")
	if rl.size() != 3 or not rl[2].begins_with("HTTP/1."):
		return _fail(400, "Línea de petición inválida")
	if not rl[1].begins_with("/"):
		return _fail(400, "Destino inválido")
	var headers: Dictionary = {}
	for i: int in range(1, lines.size()):
		var l: String = lines[i]
		if l.is_empty():
			continue
		var colon: int = l.find(":")
		if colon <= 0:
			return _fail(400, "Cabecera inválida")
		var k: String = l.substr(0, colon).strip_edges().to_lower()
		var v: String = l.substr(colon + 1).strip_edges()
		headers[k] = v if not headers.has(k) else String(headers[k]) + ", " + v
	request = HttpRequestHead.new(rl[0], rl[1], rl[2], headers)
	return Result.DONE


func _fail(status: int, msg: String) -> Result:
	error_status = status
	error_message = msg
	return Result.ERROR
