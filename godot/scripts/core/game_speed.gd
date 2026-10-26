class_name GameSpeed
extends RefCounted
## Velocidad del reloj de juego que elige el jugador (Ajustes y Pausa): ×1, ×2 o ×4.
## Solo acelera con tiempo tranquilo: con alerta o tormenta de Zonda, o con nubes, el reloj
## vuelve a ×1 para que haya tiempo de reaccionar (ver `GameSession._step_sim`).

const KEY: String = "settings.speed"
const OPTIONS: Array[int] = [1, 2, 4]


## Lee la velocidad guardada; cualquier valor raro vuelve a ×1.
static func load_from(store: SaveStore) -> int:
	var v: int = int(store.load_value(KEY, 1))
	return v if OPTIONS.has(v) else 1


static func save_to(store: SaveStore, v: int) -> void:
	store.save_value(KEY, v if OPTIONS.has(v) else 1)


## La siguiente opción en ronda (para el botón de la pausa).
static func next(v: int) -> int:
	return OPTIONS[(OPTIONS.find(v) + 1) % OPTIONS.size()]


static func label(v: int) -> String:
	return "×%d" % v
