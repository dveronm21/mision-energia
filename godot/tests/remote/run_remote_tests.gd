extends SceneTree
## Tests headless del control remoto (host, validación, entrada y QR).
## Misma lista de casos que app/tests/remote.test.ts, más los del codificador QR.
##   godot --headless --path godot -s res://tests/remote/run_remote_tests.gd
## Termina con código 0 si todo pasa.

var _t: float = 1000.0
var _n: int = 0
var _failures: Array[String] = []
var _current: String = ""
var _checks: int = 0


func _init() -> void:
	var cases: Array[Array] = [
		["RemoteHost: sin puente queda inactivo y no rompe", t_inactive],
		["RemoteHost: asigna asientos 0 y 1, colores y token; el tercero recibe full", t_seats],
		["RemoteHost: reconexión con token dentro de la ventana recupera el asiento", t_resume],
		["RemoteHost: fuera de la ventana el asiento se libera y el token ya no sirve", t_expired],
		["RemoteHost: token de una conexión viva reemplaza a la vieja (tablet que se reconecta rápido)", t_replace],
		["RemoteHost: timeout sin mensajes marca desconectado y cierra; hello que no llega también", t_timeout],
		["RemoteHost: bye libera el asiento al instante; kick avisa y libera", t_bye_kick],
		["RemoteInputSource: flancos de toques sin perder pulsaciones aunque falten mensajes", t_taps],
		["RemoteInputSource: reconexión conserva contadores; página recargada (contador menor) no inventa toques", t_taps_reconnect],
		["RemoteInputSource: zona muerta, curva y RUN", t_stick],
		["RemoteHost: setContext solo si cambió y a lo sumo 10 por segundo", t_ctx_rate],
		["RemoteHost: ping→pong, latencia, haptic y toast saneados", t_ping_haptic],
		["RemoteHost: mensajes inválidos se ignoran sin romper", t_invalid],
		["RemoteHost: limita ráfagas de mensajes por conexión", t_rate_limit],
		["validate: nombres y mensajes del tele", t_validate],
		["QrEncoder: Reed-Solomon (ejemplo ISO 1-M)", t_qr_rs],
		["QrEncoder: versión, tamaño, patrones y bits de formato", t_qr_structure],
		["QrEncoder: textos largos y fuera de capacidad", t_qr_capacity],
		["StaticFileServer: rutas seguras y MIME", t_static_paths],
		["HttpRequestParser: cabeceras, límites y tokens", t_http_parser],
		["WsConnection: clave Accept del RFC 6455 y Origin", t_ws_accept],
		["NetUtils: orden de IPs LAN", t_net_utils],
	]
	var passed: int = 0
	for c: Array in cases:
		_current = c[0]
		var before: int = _failures.size()
		_t = 1000.0
		_n = 0
		(c[1] as Callable).call()
		if _failures.size() == before:
			passed += 1
			print("OK    ", _current)
		else:
			print("FALLA ", _current)
			for i: int in range(before, _failures.size()):
				print("      ", _failures[i])
	print("\n%d/%d casos OK (%d verificaciones)" % [passed, cases.size(), _checks])
	quit(0 if _failures.is_empty() else 1)


# ---------- utilidades ----------

func ok(cond: bool, msg: String = "") -> void:
	_checks += 1
	if not cond:
		_failures.append("se esperaba verdadero: " + msg)


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	_checks += 1
	if not _same(a, b):
		_failures.append("%s: obtenido %s, esperado %s" % [msg, var_to_str(a), var_to_str(b)])


func _same(a: Variant, b: Variant) -> bool:
	if RemoteValidate.is_num(a) and RemoteValidate.is_num(b):
		return float(a) == float(b)
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		var x: Array = a
		var y: Array = b
		if x.size() != y.size():
			return false
		for i: int in x.size():
			if not _same(x[i], y[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func now_ms() -> float:
	return _t


func advance(ms: float) -> void:
	_t += ms


func make_token() -> String:
	_n += 1
	return "tok%d" % _n


class Setup:
	var bridge: RemoteFakeBridge
	var host: RemoteHost
	var events: Array[String] = []


func setup() -> Setup:
	var s := Setup.new()
	s.bridge = RemoteFakeBridge.new()
	s.host = RemoteHost.new(s.bridge, now_ms, make_token)
	var ev: Array[String] = s.events
	s.host.joined.connect(func(p: RemotePlayer) -> void: ev.append("join%d:%s" % [p.slot, p.name]))
	s.host.left.connect(func(slot: int, r: String) -> void: ev.append("leave%d:%s" % [slot, r]))
	s.host.resumed.connect(func(p: RemotePlayer) -> void: ev.append("resume%d" % p.slot))
	s.host.dropped.connect(func(slot: int, r: String) -> void: ev.append("drop%d:%s" % [slot, r]))
	return s


func ctx(label: String, screen: String = "playing") -> Dictionary:
	return {"action": {"label": label, "style": "normal", "enabled": true}, "inspectEnabled": true,
		"toolOn": false, "toolEnabled": true, "objective": "Colocá los paneles", "screen": screen}


# ---------- casos (mismos que app/tests/remote.test.ts) ----------

func t_inactive() -> void:
	var host := RemoteHost.new(null)
	eq(host.active, false, "active")
	host.update()
	host.set_context(0, ctx("x"))
	host.haptic(1, [20])
	host.toast(0, "hola")
	ok(host.players()[0] == null and host.players()[1] == null, "sin jugadores")
	eq(host.input(0).read().connected, false, "connected")


func t_seats() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	var b := s.bridge.connect_client(); b.hello("Beto", "", "app")
	s.host.update()
	var wa: Dictionary = a.last("welcome")
	var wb: Dictionary = b.last("welcome")
	eq(wa.get("slot"), 0, "slot A"); eq(wa.get("color"), "#F28C28", "color A"); eq(wa.get("token"), "tok1", "token A")
	eq(wb.get("slot"), 1, "slot B"); eq(wb.get("colorName"), "Azul", "colorName B"); eq(wb.get("resumed"), false, "resumed B")
	eq(a.received[1].get("t"), "ctx", "ctx tras welcome")
	eq(a.last("ctx")["c"]["screen"], "lobby", "ctx lobby")
	var c := s.bridge.connect_client(); c.hello("Caro")
	s.host.update()
	eq(c.last("full").get("t"), "full", "full")
	eq(c.closed, true, "c cerrado")
	eq(c.count("welcome"), 0, "sin welcome")
	eq(s.events, ["join0:Ana", "join1:Beto"] as Array[String], "eventos")
	var ps: Array[RemotePlayer] = s.host.players()
	eq(ps[0].name, "Ana", "name"); eq(ps[1].device, "app", "device"); eq(s.host.connected_count(), 2, "conectados")


func t_resume() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	var b := s.bridge.connect_client(); b.hello("Beto")
	s.host.update()
	var token: String = a.last("welcome")["token"]
	a.drop()
	s.host.update()
	eq(s.host.players()[0].connected, false, "desconectada")
	eq(s.host.input(0).read().connected, false, "input desconectado")
	var x := s.bridge.connect_client(); x.hello("Intruso")
	s.host.update()
	eq(x.last("full").get("t"), "full", "intruso full")
	for i: int in RemoteProtocol.RESUME_WINDOW_MS / 1000 - 1:
		advance(1000); b.ping(i); s.host.update()
	var a2 := s.bridge.connect_client(); a2.hello("Ana", token)
	s.host.update()
	var w: Dictionary = a2.last("welcome")
	eq(w.get("slot"), 0, "slot"); eq(w.get("token"), token, "token"); eq(w.get("resumed"), true, "resumed")
	eq(s.host.players()[0].connected, true, "conectada")
	eq(s.events, ["join0:Ana", "join1:Beto", "drop0:closed", "resume0"] as Array[String], "eventos")


func t_expired() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	var token: String = a.last("welcome")["token"]
	a.drop()
	s.host.update()
	advance(RemoteProtocol.RESUME_WINDOW_MS + 1)
	s.host.update()
	ok(s.host.players()[0] == null, "asiento libre")
	ok(s.events.has("leave0:expired"), "leave expired")
	var a2 := s.bridge.connect_client(); a2.hello("Ana", token)
	s.host.update()
	var w: Dictionary = a2.last("welcome")
	eq(w.get("slot"), 0, "slot")
	ok(w.get("token") != token, "token nuevo")
	eq(w.get("resumed"), false, "no resumed")


func t_replace() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	var a2 := s.bridge.connect_client(); a2.hello("Ana", a.last("welcome")["token"])
	s.host.update()
	eq(a.closed, true, "vieja cerrada")
	eq(a2.last("welcome").get("slot"), 0, "slot")
	eq(s.host.player_count(), 1, "1 jugador")
	s.host.update()
	eq(s.host.players()[0].connected, true, "sigue conectada")
	eq(s.events, ["join0:Ana", "resume0"] as Array[String], "eventos")


func t_timeout() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	a.input({"x": 1.0, "y": 0.0})
	s.host.update()
	ok(s.host.input(0).read().x > 0.9, "x > 0.9")
	advance(RemoteProtocol.PLAYER_TIMEOUT_MS - 100)
	a.ping(1)
	s.host.update()
	advance(RemoteProtocol.PLAYER_TIMEOUT_MS - 100)
	s.host.update()
	eq(s.host.players()[0].connected, true, "sigue conectada")
	advance(200)
	s.host.update()
	eq(s.host.players()[0].connected, false, "desconectada")
	eq(a.closed, true, "cerrada")
	var i: PlayerIntent = s.host.input(0).read()
	eq(i.connected, false, "intent connected"); eq(i.x, 0.0, "intent x")
	ok(s.events.has("drop0:timeout"), "drop timeout")
	var drops: int = 0
	for e: String in s.events:
		if e.begins_with("drop"):
			drops += 1
	eq(drops, 1, "un solo drop")
	var mute := s.bridge.connect_client()
	s.host.update()
	advance(RemoteHost.HELLO_TIMEOUT_MS + 1)
	s.host.update()
	eq(mute.closed, true, "mudo cerrado")


func t_bye_kick() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	var b := s.bridge.connect_client(); b.hello("Beto")
	s.host.update()
	a.bye()
	s.host.update()
	ok(s.host.players()[0] == null, "asiento 0 libre")
	s.host.kick(1, "Fin de la demo")
	eq(b.last("kick").get("reason"), "Fin de la demo", "motivo kick")
	eq(b.closed, true, "b cerrado")
	eq(s.events, ["join0:Ana", "join1:Beto", "leave0:bye", "leave1:kick"] as Array[String], "eventos")


func t_taps() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	var src: RemoteInputSource = s.host.input(0)
	a.tap("action")
	s.host.update()
	eq(src.read().action, true, "flanco")
	eq(src.read().action, false, "un flanco por toque")
	a.tap("action", true); a.tap("action", true); a.tap("action")
	a.tap("pause")
	s.host.update()
	var f1: PlayerIntent = src.read()
	var f2: PlayerIntent = src.read()
	var f3: PlayerIntent = src.read()
	var f4: PlayerIntent = src.read()
	eq([f1.action, f2.action, f3.action, f4.action], [true, true, true, false], "3 pulsaciones")
	eq([f1.pause, f2.pause], [true, false], "pausa")
	a.input({}); a.input({})
	s.host.update()
	eq(src.read().action, false, "keepalive sin flancos")
	a.send_raw(JSON.stringify({"t": "input", "s": {"seq": 1, "x": 0, "y": 0, "held": 0, "taps": {"action": 99, "inspect": 0, "tool": 0, "pause": 0}}}))
	s.host.update()
	eq(src.read().action, false, "seq viejo ignorado")


func t_taps_reconnect() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	var token: String = a.last("welcome")["token"]
	var src: RemoteInputSource = s.host.input(0)
	a.tap("tool"); a.tap("tool")
	s.host.update()
	src.read(); src.read()
	a.drop(); s.host.update()
	var a2 := s.bridge.connect_client(); a2.hello("Ana", token)
	s.host.update()
	a2.continue_from(a)
	a2.tap("tool")
	s.host.update()
	eq(src.read().tool, true, "1 flanco tras reconectar")
	eq(src.read().tool, false, "solo 1")
	a2.drop(); s.host.update()
	var a3 := s.bridge.connect_client(); a3.hello("Ana", token)
	s.host.update()
	a3.input({})
	s.host.update()
	eq(src.read().tool, false, "recarga no inventa")
	a3.tap("tool")
	s.host.update()
	eq(src.read().tool, true, "toque tras recarga")
	eq(src.read().tool, false, "solo 1 tras recarga")


func t_stick() -> void:
	eq(RemoteInputSource.shape_stick(0.1, 0.05, 0.15, 1.5), Vector2.ZERO, "zona muerta")
	var v: Vector2 = RemoteInputSource.shape_stick(1, 0, 0.15, 1.5)
	eq(v.x, 1.0, "x=1"); eq(v.y, 0.0, "y=0")
	var h: Vector2 = RemoteInputSource.shape_stick(0.575, 0, 0.15, 1.5)
	ok(h.x > 0.3 and h.x < 0.4, "mitad del recorrido → %f" % h.x)
	var d: Vector2 = RemoteInputSource.shape_stick(2, 2, 0.15, 1.5)
	ok(absf(d.length() - 1.0) < 0.01 and absf(d.x - d.y) < 1e-9, "satura conservando dirección")
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	a.input({"x": 0.05, "y": -0.05, "held": 1})
	s.host.update()
	var i: PlayerIntent = s.host.input(0).read()
	eq(i.x, 0.0, "x"); eq(i.y, 0.0, "y"); eq(i.run, true, "run")


func t_ctx_rate() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	var base: int = a.count("ctx")
	advance(RemoteHost.CTX_MIN_INTERVAL_MS)
	s.host.set_context(0, ctx("Tomar panel"))
	eq(a.count("ctx"), base + 1, "envío inmediato")
	s.host.set_context(0, ctx("Tomar panel"))
	s.host.update()
	eq(a.count("ctx"), base + 1, "igual → nada")
	for f: int in 60:
		s.host.set_context(0, ctx("Paso %d" % (f / 3)))
		advance(1000.0 / 60.0)
		s.host.update()
	var sent: int = a.count("ctx") - base - 1
	ok(sent <= 10 and sent >= 8, "enviados %d" % sent)
	advance(RemoteHost.CTX_MIN_INTERVAL_MS)
	s.host.update()
	eq(a.last("ctx")["c"]["action"]["label"], "Paso 19", "el último estado siempre termina llegando")
	s.host.set_context(1, ctx("Conectar cable"))
	var b := s.bridge.connect_client(); b.hello("Beto")
	s.host.update()
	eq(b.last("ctx")["c"]["action"]["label"], "Conectar cable", "b recibe lo último")
	eq(s.host.get_context(1)["action"]["label"], "Conectar cable", "get_context")
	eq(RemoteProtocol.default_context()["screen"], "lobby", "default lobby")


func t_ping_haptic() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	a.ping(1234.5, 37)
	s.host.update()
	eq(a.last("pong").get("at"), 1234.5, "pong at")
	eq(s.host.players()[0].latency_ms, 37, "latencia")
	s.host.haptic(0, [40, 99999, -5])
	eq(a.last("haptic").get("pattern"), [40, 2000, 0], "haptic saneado")
	s.host.haptic(0, [])
	eq(a.count("haptic"), 1, "haptic vacío no se manda")
	s.host.toast(0, "x".repeat(200), "good")
	eq(String(a.last("toast").get("text")).length(), 80, "toast 80")


func t_invalid() -> void:
	var s := setup()
	var a := s.bridge.connect_client()
	a.input({"x": 1.0})
	a.send_raw("{malformado")
	a.send_raw(JSON.stringify({"t": "hello", "v": 1, "name": 42}))
	a.send_raw("x".repeat(5000))
	s.host.update()
	eq(a.count("welcome"), 0, "sin welcome")
	# Igual que JSON.stringify en JS: el NUL y la marca RTL llegan como escapes \uXXXX.
	a.send_raw("{\"t\":\"hello\",\"v\":1,\"name\":\"  Ana\\u0000\\u202e la   del   fondo azul  \",\"device\":\"browser\"}")
	s.host.update()
	eq(s.host.players()[0].name if s.host.players()[0] != null else "", "Ana la del fon", "nombre saneado")
	var src: RemoteInputSource = s.host.input(0)
	a.send_raw("{\"t\":\"input\",\"s\":{\"seq\":5,\"x\":\"a\",\"y\":0,\"held\":0,\"taps\":{\"action\":0,\"inspect\":0,\"tool\":0,\"pause\":0}}}")
	a.send_raw("{\"t\":\"input\",\"s\":{\"seq\":6,\"x\":null,\"y\":0,\"held\":0,\"taps\":{\"action\":1}}}")
	a.send_raw("{\"t\":\"input\",\"s\":{\"seq\":7,\"x\":0,\"y\":0,\"held\":0,\"taps\":{\"action\":-3,\"inspect\":0,\"tool\":0,\"pause\":0}}}")
	a.send_raw("{\"t\":\"nada\"}")
	a.send_raw("[1,2,3]")
	s.host.update()
	eq(src.read().action, false, "inválidos sin flancos")
	a.send_raw("{\"t\":\"input\",\"s\":{\"seq\":8,\"x\":50,\"y\":-50,\"held\":0,\"taps\":{\"action\":1e9,\"inspect\":0,\"tool\":0,\"pause\":0}}}")
	s.host.update()
	var r: Vector2 = src.raw()
	eq(r.x, 1.0, "x acotado"); eq(r.y, -1.0, "y acotado")
	var edges: int = 0
	for i: int in 20:
		if src.read().action:
			edges += 1
	eq(edges, 4, "ráfaga acotada")
	s.bridge.push_event({"e": "msg", "id": -1, "data": "x"})
	s.bridge.push_event({"e": "boom"})
	s.bridge.push_event(null)
	s.host.update()
	var old := s.bridge.connect_client(); old.hello("Viejo", "", "app", 99)
	s.host.update()
	ok(String(old.last("kick").get("reason", "")).contains("Versión"), "kick por versión")
	eq(s.host.player_count(), 1, "1 jugador")


func t_rate_limit() -> void:
	var s := setup()
	var a := s.bridge.connect_client(); a.hello("Ana")
	s.host.update()
	for i: int in 500:
		a.ping(i)
	s.host.update()
	var pongs: int = a.count("pong")
	ok(pongs >= 100 and pongs <= 120, "pongs %d" % pongs)


func t_validate() -> void:
	eq(RemoteValidate.sanitize_name("​Lu\tna\n"), "Lu na", "sanitize")
	eq(RemoteValidate.parse_client_msg(JSON.stringify({"t": "hello", "v": 1, "name": "A", "token": "bad token!"})), {}, "token malo")
	var m: Dictionary = RemoteValidate.parse_server_msg(JSON.stringify({"t": "ctx", "c": {"action": {"label": "Tomar", "style": "raro"}, "screen": "otra", "objective": 5}}))
	eq(m.get("t"), "ctx", "ctx")
	eq(m["c"]["action"]["style"], "normal", "style"); eq(m["c"]["screen"], "playing", "screen"); eq(m["c"]["objective"], "", "objective")
	eq(RemoteValidate.parse_server_msg(JSON.stringify({"t": "welcome", "slot": 3, "token": "x"})), {}, "slot 3")


# ---------- QR ----------

func t_qr_rs() -> void:
	# ISO/IEC 18004 anexo I: "01234567" en 1-M. Datos y corrección conocidos.
	var data := PackedByteArray([0x10, 0x20, 0x0C, 0x56, 0x61, 0x80, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11])
	var ecc: PackedByteArray = QrEncoder.reed_solomon_remainder(data, QrEncoder.reed_solomon_divisor(10))
	eq(ecc, PackedByteArray([0xA5, 0x24, 0xD4, 0xC1, 0xED, 0x36, 0xC7, 0x87, 0x2C, 0x55]), "ECC")
	eq(QrEncoder.num_data_codewords(1), 16, "datos v1-M")
	eq(QrEncoder.num_data_codewords(10), 216, "datos v10-M")
	eq(QrEncoder.alignment_positions(7), [6, 22, 38] as Array[int], "alineación v7")
	eq(QrEncoder.format_bits(0), 0x5412, "formato M/0")


func t_qr_structure() -> void:
	var q := QrEncoder.new()
	ok(q.encode("http://192.168.0.23:8765/"), "codifica")
	eq(q.version, 2, "versión (25 bytes → 2-M)")
	eq(q.size, 25, "tamaño")
	var m: Array[PackedByteArray] = q.matrix()
	eq(m.size(), 25, "filas")
	# Patrones de búsqueda en las 3 esquinas (anillo oscuro, anillo claro, centro 3×3 oscuro).
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(q.size - 7, 0), Vector2i(0, q.size - 7)]:
		var good: bool = true
		for dy: int in 7:
			for dx: int in 7:
				var dist: int = maxi(absi(dx - 3), absi(dy - 3))
				if (m[corner.y + dy][corner.x + dx] == 1) != (dist != 2):
					good = false
		ok(good, "finder %s" % corner)
	# Bits de formato leídos de la matriz coinciden con la máscara elegida.
	var bits: int = 0
	for i: int in 6:
		bits |= m[i][8] << i
	bits |= m[7][8] << 6
	bits |= m[8][8] << 7
	bits |= m[8][7] << 8
	for i: int in range(9, 15):
		bits |= m[8][14 - i] << i
	eq(bits, QrEncoder.format_bits(q.mask), "formato copia 1")
	var bits2: int = 0
	for i: int in 8:
		bits2 |= m[8][q.size - 1 - i] << i
	for i: int in range(8, 15):
		bits2 |= m[q.size - 15 + i][8] << i
	eq(bits2, bits, "formato copia 2")
	eq(m[q.size - 8][8], 1, "módulo oscuro fijo")
	var img: Image = q.to_image(4, 2)
	eq(img.get_width(), (25 + 4) * 4, "ancho imagen")
	ok(q.mask >= 0 and q.mask <= 7, "máscara")


func t_qr_capacity() -> void:
	var q := QrEncoder.new()
	ok(q.encode("x".repeat(213)), "213 bytes entran en 10-M")
	eq(q.version, 10, "versión 10")
	eq(q.size, 57, "57 módulos")
	ok(not q.encode("x".repeat(214)), "214 no entran")
	eq(QrEncoder.matrix_for("x".repeat(300)).size(), 0, "matriz vacía")
	ok(q.encode("ñandú ⚡"), "UTF-8")
	eq(q.version, 1, "v1")


# ---------- servidor (unitarios, sin red) ----------

func t_static_paths() -> void:
	eq(StaticFileServer.sanitize_path("/"), "index.html", "/")
	eq(StaticFileServer.sanitize_path("/fonts/a.woff2"), "fonts/a.woff2", "fuente")
	eq(StaticFileServer.sanitize_path("/sub/"), "sub/index.html", "carpeta")
	eq(StaticFileServer.sanitize_path("/a%20b.js"), "a b.js", "espacio")
	for bad: String in ["/../x", "/sub/../../x", "/%2e%2e/x", "/..%2fx", "/.hidden", "//x", "/a\\b", "/%00", "/%zz", "/a?b", "x", "/%c3%b1"]:
		eq(StaticFileServer.sanitize_path(bad), "", "rechaza " + bad)
	eq(StaticFileServer.mime_for("a.html"), "text/html; charset=utf-8", "html")
	eq(StaticFileServer.mime_for("a.JS"), "text/javascript; charset=utf-8", "js")
	eq(StaticFileServer.mime_for("f.woff2"), "font/woff2", "woff2")
	eq(StaticFileServer.mime_for("x.bin"), "application/octet-stream", "otro")


func t_http_parser() -> void:
	var p := HttpRequestParser.new()
	eq(p.feed("GET /ws?x=1 HTTP/1.1\r\nHost: a\r\nConnection: keep-alive, Upgrade\r\nUpgrade: WebSocket\r\n".to_ascii_buffer()), HttpRequestParser.Result.NEED_MORE, "incompleta")
	eq(p.feed("X-A: 1\r\nx-a: 2\r\n\r\nRESTO".to_ascii_buffer()), HttpRequestParser.Result.DONE, "completa")
	var r: HttpRequestHead = p.request
	eq(r.method, "GET", "método"); eq(r.path, "/ws", "ruta"); eq(r.target, "/ws?x=1", "target")
	ok(r.header_has_token("connection", "upgrade"), "token Upgrade")
	ok(r.header_has_token("Upgrade", "websocket"), "token websocket")
	eq(r.header("X-A"), "1, 2", "cabecera repetida")
	eq(p.take_leftover().get_string_from_ascii(), "RESTO", "bytes sobrantes")
	var big := HttpRequestParser.new()
	eq(big.feed(("GET / HTTP/1.1\r\nX: " + "a".repeat(9000)).to_ascii_buffer()), HttpRequestParser.Result.ERROR, "431")
	eq(big.error_status, 431, "status 431")
	var bad := HttpRequestParser.new()
	eq(bad.feed("HOLA\r\n\r\n".to_ascii_buffer()), HttpRequestParser.Result.ERROR, "400")
	eq(bad.error_status, 400, "status 400")


func t_ws_accept() -> void:
	eq(WsConnection.accept_key("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "RFC 6455 §1.3")
	ok(WsConnection.origin_allowed("", "127.0.0.1:8765"), "sin Origin")
	ok(WsConnection.origin_allowed("http://127.0.0.1:8765", "127.0.0.1:8765"), "mismo host")
	ok(not WsConnection.origin_allowed("http://evil.example", "127.0.0.1:8765"), "otro host")
	ok(WsConnection.origin_allowed("null", "x"), "null")
	var f: PackedByteArray = WsConnection.make_frame(1, "hola".to_utf8_buffer())
	eq(f, PackedByteArray([0x81, 4, 0x68, 0x6f, 0x6c, 0x61]), "frame texto")
	eq(WsConnection.make_frame(1, PackedByteArray(range(200))).slice(0, 4), PackedByteArray([0x81, 126, 0, 200]), "frame 16 bits")
	ok(WsConnection.is_valid_utf8("ñandú ⚡".to_utf8_buffer()), "UTF-8 válido")
	ok(not WsConnection.is_valid_utf8(PackedByteArray([0xc3, 0x28])), "UTF-8 inválido")
	ok(not WsConnection.is_valid_utf8(PackedByteArray([0xed, 0xa0, 0x80])), "surrogate inválido")
	var payload := "abcdefg".to_utf8_buffer()
	var key := PackedByteArray([1, 2, 3, 4])
	eq(WsConnection.unmask(WsConnection.unmask(payload, key), key), payload, "máscara XOR")


func t_net_utils() -> void:
	var ips: Array[String] = NetUtils.rank_ipv4([
		{"name": "docker0", "addresses": ["172.17.0.1"]},
		{"name": "rmnet0", "addresses": ["10.20.0.3"]},
		{"name": "lo", "addresses": ["127.0.0.1"]},
		{"name": "wlan0", "addresses": ["fe80::1", "192.168.0.23"]},
		{"name": "eth0", "addresses": ["10.0.0.5"]},
		{"name": "tun0", "addresses": ["10.8.0.2"]},
		{"name": "x", "addresses": ["169.254.3.3", "8.8.8.8"]},
	])
	eq(ips, ["192.168.0.23", "10.0.0.5", "172.17.0.1", "8.8.8.8"] as Array[String], "orden")
	eq(NetUtils.best_local_for("192.168.0.50", ["10.0.0.5", "192.168.0.23"] as Array[String]), "192.168.0.23", "misma red")
	eq(NetUtils.best_local_for("127.0.0.1", ["192.168.0.23"] as Array[String]), "127.0.0.1", "loopback")
	ok(NetUtils.is_private_ipv4("172.20.1.1") and not NetUtils.is_private_ipv4("172.40.1.1"), "172.16/12")
