class_name TvMode
extends Node
## Modo TV: el tele levanta el servidor de control (HTTP + WebSocket + descubrimiento UDP) y
## hasta 2 tablets manejan un técnico cada una. Este nodo arma `RemoteServer` + `RemoteHost`,
## lee una vez por cuadro lo que quiere cada jugador y, fuera de la partida, convierte el stick
## y los botones de la tablet en navegación de menús (como el D-pad del control remoto).
##
##   var tv := TvMode.new(); add_child(tv); tv.start()
##   # cada cuadro: tv.poll(); tv.intent(0).x ...

## Umbral del stick para contar como "flecha" en los menús, y repetición al mantenerlo.
const NAV_THRESHOLD: float = 0.6
const NAV_FIRST_REPEAT_SEC: float = 0.45
const NAV_REPEAT_SEC: float = 0.22

var server: RemoteServer
var host: RemoteHost

var _intents: Dictionary[int, PlayerIntent] = {}
## Por asiento: última dirección de navegación y tiempo hasta repetirla.
var _nav_dir: Dictionary[int, Vector2i] = {}
var _nav_wait: Dictionary[int, float] = {}


## true si esta compilación es la del tele (preset de exportación con la característica "tv")
## o si se pidió con `-- --tv` (para probar en la compu).
static func wanted() -> bool:
	return OS.has_feature("tv") or OS.get_cmdline_user_args().has("--tv")


func _init() -> void:
	name = "tv-mode"
	server = RemoteServer.new()


## Arranca el servidor. false si no se pudo abrir ningún puerto (el juego sigue, sin tablets).
func start() -> bool:
	# Pruebas en la compu: `-- --tv --tv-bind=127.0.0.1 --tv-port=18765`.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tv-bind="):
			server.bind_address = a.trim_prefix("--tv-bind=")
		elif a.begins_with("--tv-port="):
			server.http_port = int(a.trim_prefix("--tv-port="))
			server.fallback_http_ports = [] as Array[int]
			server.discovery_port = server.http_port + 1
	add_child(server)
	var err: Error = server.start()
	host = RemoteHost.new(server.bridge())
	for slot: int in RemoteHost.SLOTS:
		_intents[slot] = PlayerIntent.neutral()
		_nav_dir[slot] = Vector2i.ZERO
		_nav_wait[slot] = 0.0
	return err == OK


## Una vez por cuadro, antes de usar `intent()`: procesa la red y toma la intención de cada asiento.
func poll() -> void:
	if host == null:
		return
	host.update()
	for slot: int in RemoteHost.SLOTS:
		_intents[slot] = host.input(slot).read()


func intent(slot: int) -> PlayerIntent:
	return _intents.get(slot, PlayerIntent.neutral())


## Jugadores con asiento (conectados o con el asiento reservado), ordenados por asiento.
func players() -> Array[RemotePlayer]:
	var out: Array[RemotePlayer] = host.players() if host != null else [] as Array[RemotePlayer]
	out.sort_custom(func(a: RemotePlayer, b: RemotePlayer) -> bool: return a.slot < b.slot)
	return out


## Fuera de la partida: el stick de cualquier tablet mueve el foco (con repetición si se lo
## mantiene), "acción" acepta y "pausa" vuelve atrás. Se inyecta como acciones `ui_*`, igual
## que las flechas y el OK del control remoto del tele.
func navigate_menus(dt: float) -> void:
	for slot: int in RemoteHost.SLOTS:
		var it: PlayerIntent = intent(slot)
		if not it.connected:
			continue
		var dir: Vector2i = Vector2i.ZERO
		if absf(it.x) >= NAV_THRESHOLD or absf(it.y) >= NAV_THRESHOLD:
			dir = Vector2i(signi(roundi(it.x)), 0) if absf(it.x) > absf(it.y) else Vector2i(0, signi(roundi(it.y)))
		if dir == Vector2i.ZERO:
			_nav_dir[slot] = Vector2i.ZERO
		elif dir != _nav_dir[slot]:
			_nav_dir[slot] = dir
			_nav_wait[slot] = NAV_FIRST_REPEAT_SEC
			_press(_nav_action(dir))
		else:
			_nav_wait[slot] -= dt
			if _nav_wait[slot] <= 0.0:
				_nav_wait[slot] = NAV_REPEAT_SEC
				_press(_nav_action(dir))
		if it.action:
			_press(&"ui_accept")
		if it.pause:
			_press(&"ui_cancel")


static func _nav_action(dir: Vector2i) -> StringName:
	if dir.x < 0:
		return &"ui_left"
	if dir.x > 0:
		return &"ui_right"
	return &"ui_up" if dir.y < 0 else &"ui_down"


## Simula apretar y soltar una acción de UI (llega al control con foco como si fuera el remoto).
static func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Contexto para todas las tablets fuera de la partida (menú, sala, resultado).
func menu_context(screen: String, objective: String) -> void:
	if host == null:
		return
	host.set_context_all(RemoteProtocol.make_context("Aceptar", "normal", true, objective, screen))


func dispose() -> void:
	if host != null:
		host.dispose()
