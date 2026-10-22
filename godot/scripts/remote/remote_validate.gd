class_name RemoteValidate
extends RefCounted
## Validación defensiva de lo que llega por la red (tablet → tele) y por el puente.
## Port fiel de app/src/remote/validate.ts: tipos, rangos y largos acotados. Nada de afuera se usa sin pasar por acá.

## Largo máximo de un mensaje crudo (un input real ocupa ~110 caracteres).
const MAX_MSG_CHARS: int = 1024
const MAX_NAME_CHARS: int = 14
const MAX_TOKEN_CHARS: int = 64
## Eventos procesados como máximo en un poll (protege el frame).
const MAX_EVENTS_PER_POLL: int = 1000
## Contadores de toques: enteros 0..2^31.
const MAX_COUNTER: int = 0x7fffffff
const MAX_TOAST_CHARS: int = 80
const MAX_HAPTIC_STEPS: int = 12
const MAX_HAPTIC_MS: int = 2000
const MAX_RTT_MS: int = 10000

static var _re_space: RegEx
static var _re_invisible: RegEx
static var _re_spaces: RegEx
static var _re_token: RegEx
static var _re_nul_escape: RegEx
static var _re_hex_color: RegEx


static func _regexes() -> void:
	if _re_space != null:
		return
	_re_space = RegEx.create_from_string("\\s+")
	# Controles, marcas de dirección, separadores de línea, caracteres invisibles y el de reemplazo (U+FFFD).
	_re_invisible = RegEx.create_from_string("[\\x{0000}-\\x{001f}\\x{007f}-\\x{009f}\\x{200b}-\\x{200f}\\x{2028}-\\x{202e}\\x{2060}-\\x{206f}\\x{feff}\\x{fffd}]")
	_re_spaces = RegEx.create_from_string(" +")
	_re_token = RegEx.create_from_string("^[A-Za-z0-9_-]*$")
	# "\u0000" real dentro de un string JSON (precedido por una cantidad par de barras invertidas).
	_re_nul_escape = RegEx.create_from_string("(?<!\\\\)((?:\\\\\\\\)*)\\\\u0000")
	_re_hex_color = RegEx.create_from_string("^#[0-9a-fA-F]{6}$")


static func is_num(v: Variant) -> bool:
	var t: int = typeof(v)
	if t == TYPE_INT:
		return true
	if t == TYPE_FLOAT:
		return is_finite(float(v))
	return false


static func is_counter(v: Variant) -> bool:
	if not is_num(v):
		return false
	var f: float = float(v)
	return f == floorf(f) and f >= 0.0 and f <= float(MAX_COUNTER)


## Parsea JSON sin imprimir errores; devuelve null si es inválido.
static func parse_json(raw: String) -> Variant:
	_regexes()
	var text: String = raw
	if text.contains("\\u0000"):
		# Godot no admite NUL dentro de un String: se quita antes (sanitizeName lo quitaría igual).
		text = _re_nul_escape.sub(text, "$1", true)
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## Limpia un nombre: sin caracteres de control ni marcas invisibles, espacios colapsados, largo acotado.
static func sanitize_name(raw: Variant, max_chars: int = MAX_NAME_CHARS) -> String:
	if typeof(raw) != TYPE_STRING:
		return ""
	_regexes()
	var s: String = _re_space.sub(String(raw), " ", true)
	s = _re_invisible.sub(s, "", true)
	s = _re_spaces.sub(s, " ", true).strip_edges()
	return s.substr(0, max_chars).strip_edges()


static func _parse_taps(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	var out: Dictionary = {}
	for k: String in RemoteProtocol.TAP_KEYS:
		if not is_counter(d.get(k)):
			return {}
		out[k] = int(d[k])
	return out


## InputState validado {seq, x, y, held, taps} o {} si es inválido.
static func parse_input_state(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if not is_counter(d.get("seq")) or not is_num(d.get("x")) or not is_num(d.get("y")) or not is_counter(d.get("held")):
		return {}
	var taps: Dictionary = _parse_taps(d.get("taps"))
	if taps.is_empty():
		return {}
	return {
		"seq": int(d["seq"]),
		"x": clampf(float(d["x"]), -1.0, 1.0),
		"y": clampf(float(d["y"]), -1.0, 1.0),
		"held": int(d["held"]),
		"taps": taps,
	}


## Parsea un mensaje de la tablet. Devuelve {} si es inválido (se ignora en silencio).
static func parse_client_msg(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_STRING:
		return {}
	var s: String = raw
	if s.is_empty() or s.length() > MAX_MSG_CHARS:
		return {}
	var v: Variant = parse_json(s)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if typeof(d.get("t")) != TYPE_STRING:
		return {}
	match String(d["t"]):
		"hello":
			if not is_num(d.get("v")):
				return {}
			if typeof(d.get("name")) != TYPE_STRING:
				return {}
			var device: String = "app" if d.get("device") == "app" else "browser"
			var token: String = ""
			if d.has("token"):
				if typeof(d["token"]) != TYPE_STRING:
					return {}
				var tk: String = d["token"]
				_regexes()
				if tk.length() > MAX_TOKEN_CHARS or _re_token.search(tk) == null:
					return {}
				token = tk
			return {"t": "hello", "v": float(d["v"]), "name": sanitize_name(d["name"]), "token": token, "device": device}
		"input":
			var st: Dictionary = parse_input_state(d.get("s"))
			if st.is_empty():
				return {}
			return {"t": "input", "s": st}
		"ping":
			if not is_num(d.get("at")):
				return {}
			var msg: Dictionary = {"t": "ping", "at": d["at"]}
			var rtt: Variant = d.get("rtt")
			if is_num(rtt) and float(rtt) >= 0.0 and float(rtt) <= float(MAX_RTT_MS):
				msg["rtt"] = int(roundf(float(rtt)))
			return msg
		"bye":
			return {"t": "bye"}
	return {}


## Valida los eventos del puente ({e:'open'|'msg'|'close', id, ...}). Ignora los mal formados.
static func parse_bridge_events(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var arr: Array = raw
	for i: int in arr.size():
		if out.size() >= MAX_EVENTS_PER_POLL:
			break
		var ev: Variant = arr[i]
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = ev
		if not is_counter(d.get("id")):
			continue
		var id: int = int(d["id"])
		match d.get("e"):
			"open":
				var addr: String = String(d["addr"]).substr(0, 64) if typeof(d.get("addr")) == TYPE_STRING else ""
				out.append({"e": "open", "id": id, "addr": addr})
			"close":
				out.append({"e": "close", "id": id})
			"msg":
				if typeof(d.get("data")) == TYPE_STRING:
					out.append({"e": "msg", "id": id, "data": d["data"]})
	return out


static func _str(v: Variant, max_chars: int) -> String:
	return String(v).substr(0, max_chars) if typeof(v) == TYPE_STRING else ""


## Parsea un mensaje del tele (lo usa la página de control; acá sirve para tests y herramientas).
static func parse_server_msg(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_STRING:
		return {}
	var s: String = raw
	if s.is_empty() or s.length() > 8192:
		return {}
	var v: Variant = parse_json(s)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if typeof(d.get("t")) != TYPE_STRING:
		return {}
	match String(d["t"]):
		"welcome":
			var slot: Variant = d.get("slot")
			if not is_num(slot) or (float(slot) != 0.0 and float(slot) != 1.0) or typeof(d.get("token")) != TYPE_STRING:
				return {}
			_regexes()
			var col: String = _str(d.get("color"), 7)
			return {"t": "welcome", "v": float(d["v"]) if is_num(d.get("v")) else 0.0, "slot": int(slot),
				"token": _str(d["token"], MAX_TOKEN_CHARS),
				"color": col if _re_hex_color.search(col) != null else "#F28C28",
				"colorName": _str(d.get("colorName"), 24), "tvName": _str(d.get("tvName"), 40),
				"resumed": d.get("resumed") == true}
		"full":
			return {"t": "full", "reason": _str(d.get("reason"), 120)}
		"kick":
			return {"t": "kick", "reason": _str(d.get("reason"), 120)}
		"pong":
			return {"t": "pong", "at": d["at"]} if is_num(d.get("at")) else {}
		"toast":
			var kind: Variant = d.get("kind")
			var out: Dictionary = {"t": "toast", "text": _str(d.get("text"), MAX_TOAST_CHARS)}
			if kind == "good" or kind == "bad" or kind == "info":
				out["kind"] = kind
			return out
		"haptic":
			var p: Array[int] = sanitize_haptic(d.get("pattern"))
			return {"t": "haptic", "pattern": p} if not p.is_empty() else {}
		"ctx":
			var c: Variant = d.get("c")
			if typeof(c) != TYPE_DICTIONARY or typeof((c as Dictionary).get("action")) != TYPE_DICTIONARY:
				return {}
			var cd: Dictionary = c
			var a: Dictionary = cd["action"]
			var style: String = String(a["style"]) if (a.get("style") == "idle" or a.get("style") == "drop") else "normal"
			var screen: String = "playing"
			if typeof(cd.get("screen")) == TYPE_STRING and RemoteProtocol.SCREENS.has(String(cd["screen"])):
				screen = cd["screen"]
			var ctx: Dictionary = {
				"action": {"label": _str(a.get("label"), 40), "style": style, "enabled": a.get("enabled") != false},
				"inspectEnabled": cd.get("inspectEnabled") == true,
				"toolOn": cd.get("toolOn") == true,
				"toolEnabled": cd.get("toolEnabled") == true,
				"objective": _str(cd.get("objective"), 140),
				"screen": screen,
			}
			if typeof(cd.get("status")) == TYPE_STRING:
				ctx["status"] = _str(cd["status"], 80)
			return {"t": "ctx", "c": ctx}
	return {}


## Patrón de vibración seguro: enteros 0..2000 ms, máx 12 pasos. Vacío si es inválido.
static func sanitize_haptic(p: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(p) != TYPE_ARRAY and typeof(p) != TYPE_PACKED_INT32_ARRAY and typeof(p) != TYPE_PACKED_FLOAT32_ARRAY:
		return out
	var arr: Array = Array(p)
	if arr.is_empty():
		return out
	for i: int in mini(arr.size(), MAX_HAPTIC_STEPS):
		var n: Variant = arr[i]
		if not is_num(n):
			return [] as Array[int]
		out.append(int(roundf(clampf(float(n), 0.0, float(MAX_HAPTIC_MS)))))
	return out
