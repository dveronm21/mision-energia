extends Node
## Banco de pruebas headless del modo TV (NO es parte del juego): RemoteServer + RemoteHost con una
## "partida" mínima (igual que app/src/remote/dev/TvHarness.ts). Lo usan tools/remote_test/test.mjs
## (Node ws + UDP + Playwright).
##
##   godot --headless --path godot res://scenes/remote/RemoteTestServer.tscn -- --http 18765 --udp 18766 --bind 127.0.0.1 --fps 60
##
## Salida por stdout: "READY <puerto> <url>", "EVT open <id> <ip>", "EVT close <id>", "HOST join <slot> <nombre>"…
## Conexiones especiales (primer mensaje):
##   "__echo__"  → eco de cada mensaje ("__close__" = el juego cierra, "__stats__" = contadores).
##   "__admin__" → comandos: "state" (JSON), "start", "lobby", "kick <slot>", "quit".
## Cualquier otro primer mensaje va al RemoteHost (protocolo real).

var server: RemoteServer
var host: RemoteHost
var _bridge: RemoteHarnessBridge
var _pending_open: Dictionary = {}   # id → evento open aún no entregado al host
var _echo: Dictionary = {}
var _admin: Dictionary = {}
var _counters: Dictionary = {"open": 0, "msg": 0, "close": 0}
var _quitting: bool = false
var _names: Dictionary = {}   # nombre del hello → id de conexión (para "drop <nombre>")
var stats: Dictionary = {
	"actions": [0, 0], "inspects": [0, 0], "tools": [0, 0], "pauses": [0, 0], "maxX": [0.0, 0.0],
	"minY": [0.0, 0.0], "joins": 0, "resumes": 0, "leaves": 0, "drops": 0, "started": false,
	"paused": false, "toolOn": [false, false], "last": [null, null], "frames": 0,
}
const LABELS: Array[String] = ["Tomar panel", "Colocar panel", "Conectar cable"]


func _ready() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	Engine.max_fps = int(args.get("fps", "60"))
	server = RemoteServer.new()
	server.http_port = int(args.get("http", str(RemoteProtocol.HTTP_PORT)))
	server.fallback_http_ports = [] as Array[int]
	server.discovery_port = int(args.get("udp", str(RemoteProtocol.DISCOVERY_PORT)))
	server.bind_address = args.get("bind", "*")
	server.tv_name = "Tele de prueba"
	server.pause_in_background = false
	add_child(server)
	var err: Error = server.start()
	if err != OK:
		print("ERROR start ", err)
		get_tree().quit(2)
		return
	_bridge = RemoteHarnessBridge.new(server)
	host = RemoteHost.new(_bridge)
	host.joined.connect(func(p: RemotePlayer) -> void:
		stats["joins"] += 1
		_out("HOST join %d %s" % [p.slot, p.name]))
	host.resumed.connect(func(p: RemotePlayer) -> void:
		stats["resumes"] += 1
		_out("HOST resume %d %s" % [p.slot, p.name]))
	host.left.connect(func(s: int, r: String) -> void:
		stats["leaves"] += 1
		_out("HOST leave %d %s" % [s, r]))
	host.dropped.connect(func(s: int, r: String) -> void:
		stats["drops"] += 1
		_out("HOST drop %d %s" % [s, r]))
	_out("READY %d %s udp=%s" % [server.get_http_port(), server.controller_url(), str(server.is_discovery_running())])


func _process(_delta: float) -> void:
	if _quitting:
		return
	stats["frames"] += 1
	_route(server.poll_events())
	host.update()
	_game_frame()


func _route(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		var id: int = ev["id"]
		match String(ev["e"]):
			"open":
				_counters["open"] += 1
				_out("EVT open %d %s" % [id, ev["addr"]])
				_pending_open[id] = ev
			"close":
				_counters["close"] += 1
				_out("EVT close %d" % id)
				if _echo.erase(id) or _admin.erase(id) or _pending_open.erase(id):
					continue
				_bridge.queue.append(ev)
			"msg":
				_counters["msg"] += 1
				var data: String = ev["data"]
				if _echo.has(id):
					_on_echo(id, data)
				elif _admin.has(id):
					_on_admin(id, data)
				elif _pending_open.has(id):
					var open_ev: Dictionary = _pending_open[id]
					_pending_open.erase(id)
					if data == "__echo__":
						_echo[id] = true
					elif data == "__admin__":
						_admin[id] = true
					else:
						_remember_name(id, data)
						_bridge.queue.append(open_ev)
						_bridge.queue.append(ev)
				else:
					_remember_name(id, data)
					_bridge.queue.append(ev)


func _remember_name(id: int, data: String) -> void:
	if data.begins_with("{\"t\":\"hello\""):
		var m: Dictionary = RemoteValidate.parse_client_msg(data)
		if not m.is_empty():
			_names[m["name"]] = id


func _on_echo(id: int, data: String) -> void:
	if data == "__close__":
		server.close_connection(id, "cerrado por el juego")
	elif data == "__stats__":
		server.send(id, RemoteProtocol.to_json({"open": _counters["open"], "msg": _counters["msg"],
			"close": _counters["close"], "conns": server.connection_count(), "url": server.controller_url()}))
	else:
		server.send(id, data)


func _on_admin(id: int, data: String) -> void:
	var parts: PackedStringArray = data.split(" ")
	match parts[0]:
		"state":
			var ps: Array = []
			for p: RemotePlayer in host.players():
				ps.append(p.to_dict() if p != null else null)
			server.send(id, RemoteProtocol.to_json({"players": ps, "stats": stats, "url": host.controller_url(),
				"conns": server.connection_count()}))
		"start":
			stats["started"] = true
			server.send(id, "{\"ok\":true}")
		"lobby":
			stats["started"] = false
			server.send(id, "{\"ok\":true}")
		"kick":
			host.kick(int(parts[1]) if parts.size() > 1 else 0, "Fin de la demo")
			server.send(id, "{\"ok\":true}")
		"drop":
			# Corte de red "duro" de una tablet: el socket muere sin cierre limpio.
			server.abort_connection(int(_names.get(parts[1] if parts.size() > 1 else "", -1)))
			server.send(id, "{\"ok\":true}")
		"quit":
			_quit()


func _game_frame() -> void:
	for s: int in RemoteHost.SLOTS:
		var i: PlayerIntent = host.input(s).read()
		stats["last"][s] = i.to_dict()
		if not i.connected:
			host.set_context(s, _ctx_for(s))
			continue
		stats["maxX"][s] = maxf(stats["maxX"][s], i.x)
		stats["minY"][s] = minf(stats["minY"][s], i.y)
		if i.action:
			stats["actions"][s] += 1
			host.haptic(s, [30, 40, 30])
			host.toast(s, "¡Panel colocado!", "good")
			_out("INPUT %d action" % s)
		if i.inspect:
			stats["inspects"][s] += 1
			host.toast(s, "Inversor híbrido: OK", "info")
		if i.tool:
			stats["tools"][s] += 1
			stats["toolOn"][s] = not stats["toolOn"][s]
		if i.pause:
			stats["pauses"][s] += 1
			if stats["started"]:
				stats["paused"] = not stats["paused"]
		host.set_context(s, _ctx_for(s))


func _ctx_for(s: int) -> Dictionary:
	if not stats["started"]:
		return RemoteProtocol.make_context("¡Listo!", "normal", true, "Mirá el tele: la partida empieza en un momento", "lobby")
	var n: int = stats["actions"][s]
	return RemoteProtocol.make_context(LABELS[n % LABELS.size()], "drop" if n % 3 == 2 else "normal", true,
		"Colocá los 6 paneles en la estructura" if n < 3 else "Conectá el inversor a las baterías",
		"paused" if stats["paused"] else "playing", true, stats["toolOn"][s], true,
		"Paneles %d/6 · Batería %d%%" % [mini(6, n), 40 + n * 5])


func _quit() -> void:
	_quitting = true
	var t0: int = Time.get_ticks_msec()
	server.stop()
	var stop_ms: int = Time.get_ticks_msec() - t0
	var final_events: Array = []
	for ev: Dictionary in server.poll_events():
		final_events.append({"e": ev["e"], "id": ev["id"]})
	_out("FINAL " + RemoteProtocol.to_json(final_events))
	_out("STOPPED stopMs=%d conns=%d running=%s" % [stop_ms, server.connection_count(), str(server.is_running())])
	get_tree().quit(0)


func _out(line: String) -> void:
	print(line)


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	while i < args.size():
		if args[i].begins_with("--") and i + 1 < args.size():
			out[args[i].substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return out
