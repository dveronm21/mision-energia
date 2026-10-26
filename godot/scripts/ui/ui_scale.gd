class_name UiScale
extends RefCounted
## Tamaño de la UI según la pantalla. La base de diseño es 1280×720 (`stretch canvas_items` +
## `expand`), que en un teléfono deja el texto de 16 px en ~1,5 mm. Acá se agranda con
## `content_scale_factor` para que el alto lógico salga del tamaño físico de la pantalla:
## ~157 px lógicos por pulgada de alto (16 px ≈ 2,6 mm, como la versión web en el teléfono).
##   - Teléfono (~2,7" de alto apaisado): alto lógico ~420 → factor ~1,7.
##   - Tablet chica: ~580 → ~1,25. Tablet grande 4:3: 720 de alto → ~1,33. Compu: 1.
##   - Tele (se mira de lejos): factor fijo 1,2.
## El jugador puede corregirlo en Ajustes (Chica / Normal / Grande).

const KEY: String = "settings.ui_size"
const SMALL: StringName = &"small"
const NORMAL: StringName = &"normal"
const LARGE: StringName = &"large"
const SIZE_FACTOR: Dictionary[StringName, float] = {SMALL: 0.85, NORMAL: 1.0, LARGE: 1.2}

const BASE_H: float = 720.0
const MIN_LOGICAL_H: float = 400.0
const MIN_GRANDE_H: float = 360.0
const LOGICAL_PX_PER_INCH: float = 157.0
## Con la base de 1280×720, cualquier tele queda en 1067×600 lógicos: el texto de 16 se ve de
## ~29 px reales en 1080p (pauta de lectura a 3 m) y entran la misión entera y la sala de espera.
const TV_FACTOR: float = 1.2

## > 0: usa este factor en vez de medir la pantalla (capturas en la compu).
static var forced_factor: float = 0.0


static func load_size(store: SaveStore) -> StringName:
	var v: StringName = StringName(store.load_value(KEY, String(NORMAL)))
	return v if SIZE_FACTOR.has(v) else NORMAL


static func save_size(store: SaveStore, v: StringName) -> void:
	store.save_value(KEY, String(v if SIZE_FACTOR.has(v) else NORMAL))


## Factor automático para la pantalla actual (sin la preferencia del jugador).
static func auto_factor(tv: bool) -> float:
	if forced_factor > 0.0:
		return forced_factor
	if tv:
		return TV_FACTOR
	if not OS.has_feature("mobile"):
		return 1.0
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return 1.5
	var win: Vector2i = DisplayServer.window_get_size()
	var short_px: float = float(mini(win.x, win.y))
	var long_px: float = float(maxi(win.x, win.y))
	var wanted: float = clampf(short_px / float(dpi) * LOGICAL_PX_PER_INCH, MIN_LOGICAL_H, BASE_H)
	# Lado corto lógico que deja `expand` sin factor: 720 en pantallas anchas, más en una tablet
	# 4:3 (ahí manda el ancho de 1280).
	var base_scale: float = minf(long_px / 1280.0, short_px / BASE_H)
	return maxf(1.0, (short_px / base_scale) / wanted)


## Con "Grande" en un teléfono el alto lógico no baja de `MIN_GRANDE_H` (si no, el HUD no entra).
static func apply(window: Window, tv: bool, ui_size: StringName) -> void:
	var f: float = auto_factor(tv) * float(SIZE_FACTOR.get(ui_size, 1.0))
	f = minf(f, BASE_H / MIN_GRANDE_H)
	# Solo si cambia: el cambio redispara `size_changed`, que vuelve a llamar acá.
	if not is_equal_approx(window.content_scale_factor, f):
		window.content_scale_factor = f
