class_name StaticFileServer
extends RefCounted
## Archivos estáticos de la página de control (res://controller/ por defecto) con MIME, rutas seguras
## y caché en memoria. Arma las respuestas HTTP completas (cabecera + cuerpo) como bytes.
## Port de la parte estática de HttpServer.java.

const MAX_ASSET_BYTES: int = 16 * 1024 * 1024
## Tope de la caché en memoria (la página de control ocupa ~120 KB).
const MAX_CACHE_BYTES: int = 4 * 1024 * 1024
const MIME: Dictionary = {
	"html": "text/html; charset=utf-8", "htm": "text/html; charset=utf-8",
	"js": "text/javascript; charset=utf-8", "mjs": "text/javascript; charset=utf-8",
	"css": "text/css; charset=utf-8", "json": "application/json; charset=utf-8",
	"map": "application/json; charset=utf-8", "webmanifest": "application/manifest+json; charset=utf-8",
	"txt": "text/plain; charset=utf-8", "svg": "image/svg+xml", "png": "image/png",
	"jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp",
	"ico": "image/x-icon", "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf",
	"otf": "font/otf", "mp3": "audio/mpeg", "ogg": "audio/ogg", "wav": "audio/wav",
	"wasm": "application/wasm",
}
const REASONS: Dictionary = {
	200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed",
	426: "Upgrade Required", 431: "Request Header Fields Too Large", 503: "Service Unavailable",
}

## Carpeta raíz (termina en "/"), ej. "res://controller/" o "user://controller/".
var root: String
var _cache: Dictionary = {}   # ruta relativa → PackedByteArray
var _cache_bytes: int = 0


func _init(p_root: String = "res://controller/") -> void:
	root = p_root if p_root.ends_with("/") else p_root + "/"


## true si existe el index.html de la página de control.
func has_index() -> bool:
	return FileAccess.file_exists(root + "index.html")


## Contenido del archivo (ruta relativa ya saneada) o vacío si no existe o es demasiado grande.
func read_asset(rel: String) -> PackedByteArray:
	if _cache.has(rel):
		return _cache[rel]
	var path: String = root + rel
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_ASSET_BYTES:
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	if _cache_bytes + data.size() <= MAX_CACHE_BYTES:
		_cache[rel] = data
		_cache_bytes += data.size()
	return data


func clear_cache() -> void:
	_cache.clear()
	_cache_bytes = 0


## Respuesta completa para GET/HEAD de una ruta URL (ya sin query). keep_alive va en la cabecera.
func respond(url_path: String, head_only: bool, keep_alive: bool) -> PackedByteArray:
	var rel: String = sanitize_path(url_path)
	if rel == "":
		return error_response(400, "Ruta inválida", head_only, keep_alive)
	if not _cache.has(rel) and not FileAccess.file_exists(root + rel):
		return error_response(404, "No encontrado", head_only, keep_alive)
	var body: PackedByteArray = read_asset(rel)
	if body.is_empty() and not _cache.has(rel):
		return error_response(404, "No encontrado", head_only, keep_alive)
	return response(200, mime_for(rel), body, head_only, keep_alive)


## Cabecera + cuerpo. extra: líneas de cabecera adicionales terminadas en "\r\n".
static func response(status: int, content_type: String, body: PackedByteArray, head_only: bool,
		keep_alive: bool, extra: String = "") -> PackedByteArray:
	var h: String = "HTTP/1.1 %d %s\r\n" % [status, REASONS.get(status, "Error")]
	h += "Content-Type: " + content_type + "\r\n"
	h += "Content-Length: %d\r\n" % body.size()
	h += "Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\n"
	h += "Connection: " + ("keep-alive" if keep_alive else "close") + "\r\n"
	h += extra + "\r\n"
	var out: PackedByteArray = h.to_utf8_buffer()
	if not head_only:
		out.append_array(body)
	return out


static func error_response(status: int, msg: String, head_only: bool, keep_alive: bool, extra: String = "") -> PackedByteArray:
	return response(status, "text/plain; charset=utf-8", ("%d %s\n" % [status, msg]).to_utf8_buffer(), head_only, keep_alive, extra)


## Ruta URL → ruta relativa segura dentro de la carpeta. "/" → "index.html"; "/a/" → "a/index.html".
## Devuelve "" para "..", ".", segmentos ocultos, "\\", NUL, "//", % inválido y caracteres fuera de
## [A-Za-z0-9._~ -/].
static func sanitize_path(url_path: String) -> String:
	if not url_path.begins_with("/") or url_path.length() > 512:
		return ""
	var decoded: String = _percent_decode(url_path)
	if decoded == "":
		return ""
	if decoded.ends_with("/"):
		decoded += "index.html"
	var segs: PackedStringArray = decoded.substr(1).split("/", true)
	for seg: String in segs:
		if seg.is_empty() or seg.begins_with("."):
			return ""
		for i: int in seg.length():
			var c: int = seg.unicode_at(i)
			var good: bool = (c >= 97 and c <= 122) or (c >= 65 and c <= 90) or (c >= 48 and c <= 57) \
				or c == 46 or c == 95 or c == 45 or c == 126 or c == 32
			if not good:
				return ""
	return "/".join(segs)


## Decodifica %xx. "" si hay escapes inválidos, bytes no imprimibles, NUL o "\\".
static func _percent_decode(s: String) -> String:
	var b := PackedByteArray()
	var i: int = 0
	var n: int = s.length()
	while i < n:
		var c: int = s.unicode_at(i)
		if c == 37:  # %
			if i + 2 >= n:
				return ""
			var hx: String = s.substr(i + 1, 2)
			if not hx.is_valid_hex_number(false):
				return ""
			b.append(hx.hex_to_int())
			i += 3
			continue
		if c > 0x7e or c < 0x20:
			return ""
		b.append(c)
		i += 1
	for v: int in b:
		if v == 0 or v == 92 or v > 0x7e:
			return ""
	return b.get_string_from_ascii()


static func mime_for(path: String) -> String:
	return MIME.get(path.get_extension().to_lower(), "application/octet-stream")
