class_name DuelMatch
extends RefCounted
## Estado de un duelo entre dos teles (sin interfaz: la App lo mira y arma las pantallas).
## Reglas: los dos juegan el mismo nivel con la misma compra fija, sin potenciadores y a velocidad
## ×1; gana el primero que deja la planta activada y funcionando al 100 % (sin la fila del conector
## flojo). El árbitro (`DuelLink.is_referee`) elige el nivel, da la largada y decide el ganador.
## Como el clima corre recién después de activar, en el duelo no se sortea Zonda.
##
##   var duel := DuelMatch.new(link)
##   # cada cuadro:
##   for e: StringName in duel.update(dt): ...   # &"paired", &"setup", &"countdown", &"go", ...

enum Phase { SEARCHING, LOBBY, SETUP, COUNTDOWN, PLAYING, FINISHED }

const COUNTDOWN_SEC: float = 3.0
## Compra fija por nivel: la mínima cómoda para activar (paneles, baterías). Sin kit anti-Zonda.
const FIXED_PURCHASE: Dictionary[String, Array] = {
	"casa": [4, 1], "escuela": [4, 2], "finca": [5, 2], "pueblo": [8, 3], "parque": [10, 4],
}

const WIN_ME: StringName = &"me"
const WIN_PEER: StringName = &"peer"

var link: DuelLink
var phase: Phase = Phase.SEARCHING
var level_id: String = ""
var my_ready: bool = false
var peer_ready: bool = false
## Segundos que faltan para la largada (en COUNTDOWN).
var countdown: float = 0.0
## Segundos desde la largada (en PLAYING y FINISHED).
var elapsed: float = 0.0
## Último avance del rival: {panels, total, batteries, batteries_total, activated, ok}.
var peer_progress: Dictionary = {}
## Quién ganó (`WIN_ME` / `WIN_PEER`) y en cuántos segundos desde la largada.
var winner: StringName = &""
var win_sec: float = 0.0
## Se cortó el enlace en plena partida: cada uno termina la suya.
var peer_lost: bool = false

var _events: Array[StringName] = []
var _my_done_sec: float = -1.0


func _init(p_link: DuelLink) -> void:
	link = p_link


static func fixed_purchase(id: String) -> Purchase:
	var p: Array = FIXED_PURCHASE.get(id, [4, 1])
	return Purchase.make(int(p[0]), int(p[1]), false)


func purchase() -> Purchase:
	return fixed_purchase(level_id)


func is_referee() -> bool:
	return link.is_referee


func peer_name() -> String:
	return link.peer_name if link.peer_name != "" else "la otra pantalla"


## Procesa la red y el reloj. Devuelve lo que pasó desde la llamada anterior, en orden (también
## lo que provocó este tele: elegir el nivel, "¡Listo!").
func update(dt: float) -> Array[StringName]:
	for m: Dictionary in link.poll(dt):
		_on_message(m)
	if phase == Phase.COUNTDOWN:
		countdown -= dt
		if countdown <= 0.0:
			countdown = 0.0
			phase = Phase.PLAYING
			elapsed = 0.0
			_events.append(&"go")
	elif phase == Phase.PLAYING:
		elapsed += dt
	var out: Array[StringName] = _events
	_events = []
	return out


## Árbitro: elige el nivel y se lo manda al otro tele.
func choose_level(id: String) -> void:
	if not is_referee() or phase != Phase.LOBBY:
		return
	_enter_setup(id)
	link.send({"t": "setup", "level": id})


## Este tele está listo para largar. El árbitro larga cuando están los dos.
func set_ready() -> void:
	if phase != Phase.SETUP or my_ready:
		return
	my_ready = true
	link.send({"t": "ready"})
	_events.append(&"ready")
	_try_start()


## Avance propio, para la franja del rival en el otro tele.
func report_progress(p: Dictionary) -> void:
	if phase == Phase.PLAYING:
		link.send({"t": "progress", "p": p})


## La planta quedó activada y funcionando al 100 %.
func report_done() -> void:
	if phase != Phase.PLAYING or _my_done_sec >= 0.0:
		return
	_my_done_sec = elapsed
	if peer_lost or not link.is_connected_to_peer():
		_finish(WIN_ME, elapsed)
	elif is_referee():
		_decide(WIN_ME, elapsed)
	else:
		link.send({"t": "done", "sec": elapsed})


## Revancha o volver a elegir nivel: los dos teles vuelven a la sala del duelo.
func back_to_lobby() -> void:
	link.send({"t": "lobby"})
	_enter_lobby()


func _on_message(m: Dictionary) -> void:
	match String(m["t"]):
		"_connected":
			if phase == Phase.SEARCHING:
				_enter_lobby()
				_events.append(&"paired")
		"_lost":
			if phase == Phase.PLAYING:
				peer_lost = true
				_events.append(&"peer_lost")
			elif phase != Phase.FINISHED:
				phase = Phase.SEARCHING
				_events.append(&"lost")
		"setup":
			if not is_referee() and (phase == Phase.LOBBY or phase == Phase.SETUP):
				var id: String = String(m.get("level", ""))
				if FIXED_PURCHASE.has(id):
					_enter_setup(id)
		"ready":
			if phase == Phase.SETUP:
				peer_ready = true
				_events.append(&"peer_ready")
				_try_start()
		"start":
			if not is_referee() and phase == Phase.SETUP:
				_start_countdown()
		"progress":
			if phase == Phase.PLAYING and m.get("p") is Dictionary:
				peer_progress = m["p"]
				_events.append(&"progress")
		"done":
			if is_referee() and phase == Phase.PLAYING:
				_decide(WIN_PEER, float(m.get("sec", elapsed)))
		"result":
			if not is_referee() and phase == Phase.PLAYING:
				# El árbitro habla de sí mismo: "referee" ganó él, "guest" gané yo.
				_finish(WIN_PEER if String(m.get("winner", "")) == "referee" else WIN_ME, float(m.get("sec", 0.0)))
		"lobby":
			if phase != Phase.SEARCHING:
				_enter_lobby()
				_events.append(&"lobby")


## Árbitro: el primero que avisa gana (lo que llegó antes a este tele).
func _decide(who: StringName, sec: float) -> void:
	if winner != &"":
		return
	link.send({"t": "result", "winner": "referee" if who == WIN_ME else "guest", "sec": sec})
	_finish(who, sec)


func _finish(who: StringName, sec: float) -> void:
	winner = who
	win_sec = sec
	phase = Phase.FINISHED
	_events.append(&"finished")


func _try_start() -> void:
	if is_referee() and my_ready and peer_ready and phase == Phase.SETUP:
		link.send({"t": "start"})
		_start_countdown()


func _start_countdown() -> void:
	phase = Phase.COUNTDOWN
	countdown = COUNTDOWN_SEC
	_events.append(&"countdown")


func _enter_setup(id: String) -> void:
	level_id = id
	my_ready = false
	peer_ready = false
	phase = Phase.SETUP
	_events.append(&"setup")


func _enter_lobby() -> void:
	phase = Phase.LOBBY if link.is_connected_to_peer() else Phase.SEARCHING
	level_id = ""
	my_ready = false
	peer_ready = false
	peer_progress = {}
	winner = &""
	win_sec = 0.0
	elapsed = 0.0
	peer_lost = false
	_my_done_sec = -1.0
