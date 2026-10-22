class_name RemoteProtocol
extends RefCounted
## Constantes del protocolo de control remoto (tele ⇄ tablets).
## Espejo de app/src/remote/protocol.ts y docs/REMOTE_PROTOCOL.md: si cambia algo allá, cambiarlo acá.

const PROTOCOL_VERSION: int = 1
const HTTP_PORT: int = 8765
## Puertos alternativos si HTTP_PORT está ocupado (la URL del QR y el DiscoveryReply llevan el real).
const FALLBACK_HTTP_PORTS: Array[int] = [8775, 8785]
const DISCOVERY_PORT: int = 8766
const DISCOVERY_QUERY: String = "MISION-ENERGIA-DISCOVER-1"
const APP_ID: String = "mision-energia-tv"
const MAX_PLAYERS: int = 2
const KEEPALIVE_MS: int = 100
## Sin mensajes → jugador "desconectado" (personaje quieto).
const PLAYER_TIMEOUT_MS: int = 3000
## Asiento reservado para reconectar con el mismo token.
const RESUME_WINDOW_MS: int = 60000

const WS_PATH: String = "/ws"
const INFO_PATH: String = "/api/info"
## Tamaño máximo de un mensaje WebSocket (entrante o saliente), en bytes.
const MAX_MESSAGE_BYTES: int = 64 * 1024

## Botones mantenidos (bitmask en InputState.held).
const BTN_RUN: int = 1

const TAP_KEYS: Array[String] = ["action", "inspect", "tool", "pause"]

const SLOT_COLOR_HEX: Array[String] = ["#F28C28", "#2F7BE0"]
const SLOT_COLOR_NAME: Array[String] = ["Naranja", "Azul"]
const SLOT_VEST: Array[int] = [0xf28c28, 0x2f7be0]
const SLOT_HELMET: Array[int] = [0xffd23f, 0xffffff]

const SCREENS: Array[String] = ["lobby", "menu", "playing", "paused", "result"]
const ACTION_STYLES: Array[String] = ["normal", "idle", "drop"]


static func slot_color(slot: int) -> Color:
	return Color(SLOT_COLOR_HEX[slot])


## Contexto inicial de la tablet (sala de espera). Mismo contenido que defaultContext() en RemoteHost.ts.
static func default_context() -> Dictionary:
	return {
		"action": {"label": "¡Listo!", "style": "idle", "enabled": false},
		"inspectEnabled": false,
		"toolOn": false,
		"toolEnabled": false,
		"objective": "Mirá el tele: la partida empieza en un momento",
		"screen": "lobby",
	}


## Arma un ControllerContext (Dictionary con las claves del protocolo).
static func make_context(label: String, style: String, enabled: bool, objective: String, screen: String,
		inspect_enabled: bool = false, tool_on: bool = false, tool_enabled: bool = false, status: String = "") -> Dictionary:
	var c: Dictionary = {
		"action": {"label": label, "style": style, "enabled": enabled},
		"inspectEnabled": inspect_enabled,
		"toolOn": tool_on,
		"toolEnabled": tool_enabled,
		"objective": objective,
		"screen": screen,
	}
	if status != "":
		c["status"] = status
	return c


## JSON compacto, conservando el orden de las claves y la precisión completa de los números.
static func to_json(v: Variant) -> String:
	return JSON.stringify(v, "", false, true)
