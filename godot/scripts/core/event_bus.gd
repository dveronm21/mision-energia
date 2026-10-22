class_name EventBus
extends Node
## Bus de eventos globales del juego (equivale a `EventBus.ts`).
##
## Es un Node para poder registrarse como autoload (nombre propuesto: `Bus`, ver CONVENCIONES.md);
## también se puede instanciar suelto en tests (`EventBus.new()` y `free()` al terminar).
## Las señales de Godot son sincrónicas, igual que en la web; si un suscriptor falla,
## Godot registra el error y sigue con el resto.

## Cambió el saldo de Soles.
signal wallet_changed(balance: int)
## Empezó un nivel (id de `LevelDefinition`).
signal level_started(level_id: String)
## Terminó un nivel con su resultado ya evaluado.
signal level_finished(result: LevelResult)
## Mensaje corto para el HUD. `kind`: "good" | "bad" | "info".
signal toast(text: String, kind: String)
## Pedido de efecto de sonido (ver `AudioSynth.SFX_NAMES`).
signal sfx(sfx_name: String)


func emit_wallet_changed(balance: int) -> void:
	wallet_changed.emit(balance)


func emit_level_started(level_id: String) -> void:
	level_started.emit(level_id)


func emit_level_finished(result: LevelResult) -> void:
	level_finished.emit(result)


func emit_toast(text: String, kind: String = "info") -> void:
	toast.emit(text, kind)


func emit_sfx(sfx_name: String) -> void:
	sfx.emit(sfx_name)
