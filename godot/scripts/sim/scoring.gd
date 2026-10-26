class_name Scoring
extends RefCounted
## Puntaje y estrellas (igual a `Scoring.ts`).
##  ★ llegó al final · ★★ y batería final ≥ two_star_soc · ★★★ y gasto ≤ three_star_spend × presupuesto
##  y sin paneles perdidos.
## Puntaje: ganando 1000 + batería final (hasta 1000) + ahorro (hasta 500) − 50 por panel perdido;
## perdiendo, 25 por hora de juego sobrevivida.
## Tips: consejos didácticos, primero lo que más pesó en el resultado.

const MAX_TIPS: int = 3

const TIP_CONNECTOR: String = "Una fila nunca generó: tenía un conector flojo. Medí con el multímetro en la caja de conexión y reparalo: en serie, un solo panel flojo apaga toda la fila."
const TIP_DUST: String = "Los paneles quedaron con polvo del Zonda y rindieron 35% menos. Cuando pase el viento, limpialos en el poste de cada fila."
const TIP_WIND: String = "El Zonda voló %s. Cuando suene la alarma, poné cada fila en defensa (horizontal) o instalá las trabas anti-Zonda."
const TIP_BATTERIES: String = "Con %s no alcanza para toda la noche. En el taller, probá sumar otra batería."
const TIP_FEW_PANELS: String = "Con pocos paneles las baterías no llegan llenas a la noche. Instalá más paneles para generar el excedente que vas a guardar."
const TIP_NON_ESSENTIAL: String = "Quedaron encendidas cargas que no son esenciales. De noche, apagá lo que no haga falta para que la energía guardada alcance."
const TIP_THIRD_STAR: String = "¡Muy bien! Para la tercera estrella, buscá la misma luz gastando menos créditos de obra."
const TIP_WON: String = "De día los paneles alimentaron el consumo y cargaron las baterías; de noche, el inversor usó esa energía guardada."
const TIP_LOST: String = "Las baterías no llegaron llenas a la noche. Revisá cuántos paneles y baterías comprás y cuidá la planta durante el día."


func evaluate(level: LevelDefinition, input: ScoringInput) -> LevelResult:
	var soc: float = _clamp01(input.final_soc_pct)
	var star_count: int = stars(level, input.won, soc, input.spent, input.panels_lost)
	var saved: float = _clamp01(float(level.budget - input.spent) / float(level.budget)) if level.budget > 0 else 0.0
	var end_or_blackout: float = input.blackout_hour if input.has_blackout() else level.end_hour
	var survived: float = maxf(0.0, end_or_blackout - level.start_hour)
	var score: int
	if input.won:
		score = maxi(0, JsMath.js_round(1000.0 + soc * 1000.0 + saved * 500.0 - float(input.panels_lost * 50)))
	else:
		score = JsMath.js_round(survived * 25.0)
	var r: LevelResult = LevelResult.make(level.id, input.won, star_count, score)
	r.final_soc_pct = soc
	r.spent = input.spent
	r.budget = level.budget
	r.panels_lost = input.panels_lost
	r.blackout_hour = LevelResult.NO_BLACKOUT if input.won else input.blackout_hour
	r.duration_sec = input.duration_sec
	r.tips = _tips(level, input, star_count)
	return r


func stars(level: LevelDefinition, won: bool, soc: float, spent: int, panels_lost: int) -> int:
	if not won:
		return 0
	if soc + 1e-9 < level.two_star_soc:
		return 1
	if float(spent) > level.three_star_spend * float(level.budget) + 1e-9 or panels_lost > 0:
		return 2
	return 3


func _tips(level: LevelDefinition, i: ScoringInput, star_count: int) -> Array[String]:
	var t: Array[String] = []
	var struggled: bool = not i.won or star_count < 2
	if i.had_open_row_at_end:
		t.append(TIP_CONNECTOR)
	if i.had_dirty_row_at_end:
		t.append(TIP_DUST)
	if i.panels_lost > 0:
		t.append(TIP_WIND % ("un panel" if i.panels_lost == 1 else "%d paneles" % i.panels_lost))
	if struggled and i.batteries < level.battery_slots:
		var bats_txt: String = "una batería" if i.batteries == 1 else "%d baterías" % i.batteries
		t.append(TIP_BATTERIES % bats_txt)
	var max_panels: int = level.rows * level.panels_per_row
	if struggled and i.panels != ScoringInput.PANELS_UNKNOWN and i.panels < ceili(float(max_panels) * 0.75):
		t.append(TIP_FEW_PANELS)
	if not i.won and i.non_essential_on:
		t.append(TIP_NON_ESSENTIAL)
	if i.won and star_count == 2 and float(i.spent) > level.three_star_spend * float(level.budget) and i.panels_lost == 0:
		t.append(TIP_THIRD_STAR)
	if t.is_empty():
		t.append(TIP_WON if i.won else TIP_LOST)
	return t.slice(0, MAX_TIPS)


static func _clamp01(x: float) -> float:
	return maxf(0.0, minf(1.0, x))
