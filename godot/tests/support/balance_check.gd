class_name BalanceCheck
extends RefCounted
## Chequeo de balance (port de `app/tests/balance.ts`): cada nivel ganable, no trivial, los errores
## típicos castigan y la dificultad sube del nivel 1 al 5. Produce la misma tabla de texto.

var lines: Array[String] = []
var problems: Array[String] = []


static func hhmm(h: float) -> String:
	var x: float = fmod(fmod(h, 24.0) + 24.0, 24.0)
	return "%d:%02d" % [floori(x), floori(fmod(x, 1.0) * 60.0)]


static func fmt_out(o: Autoplay.PlayOutcome) -> String:
	if o.result.won:
		return "%s%s %d%%" % ["★".repeat(o.result.stars), "☆".repeat(3 - o.result.stars), JsMath.js_round(o.result.final_soc_pct * 100.0)]
	return "APAGÓN %s" % hhmm(o.blackout_hour if o.blackout_hour >= 0.0 else 0.0)


func run(catalog: LevelCatalog = null) -> bool:
	if catalog == null:
		catalog = LevelCatalog.new()
	lines = []
	problems = []
	var pad: Callable = JsMath.pad_right
	lines.append(pad.call("nivel", 9) + pad.call("mejor compra", 25) + pad.call("perfecto", 13) + pad.call("-1 batería", 13)
		+ pad.call("conector", 13) + pad.call("polvo", 13) + pad.call("sin defensa", 13) + pad.call("mín. paneles", 14)
		+ pad.call("más barata", 13) + "compras ≥2★")
	var prev_rate: float = INF
	for level: LevelDefinition in catalog.all():
		var best: Autoplay.BestPurchase = Autoplay.best_purchase(level)
		if best == null or not best.outcome.result.won:
			problems.append("%s: IMPOSIBLE (ninguna compra gana con juego perfecto)" % level.id)
			lines.append(pad.call(level.id, 9) + "IMPOSIBLE")
			continue
		var buy: Purchase = best.buy
		var perfect: Autoplay.PlayOutcome = best.outcome
		if perfect.result.stars < 3:
			problems.append("%s: el juego perfecto no llega a 3 estrellas (%d)" % [level.id, perfect.result.stars])
		var names: Array[String] = ["-1 batería", "conector", "polvo", "sin defensa", "mín. paneles"]
		var cells: String = ""
		for name: String in names:
			var width: int = 14 if name == "mín. paneles" else 13
			var e_buy: Purchase = buy.clone()
			var e_s: Autoplay.Strategy = Autoplay.perfect()
			var applies: bool = true
			match name:
				"-1 batería":
					e_buy.batteries -= 1
				"conector":
					applies = level.events.loose_connector
					e_s.repair_connector = false
				"polvo":
					applies = level.events.has_zonda()
					e_s.clean_after_zonda = false
				"sin defensa":
					applies = level.events.has_zonda()
					e_buy.kit_zonda = false
					e_s.zonda = "none"
				"mín. paneles":
					e_buy.panels = level.min_panels
			if not applies:
				cells += pad.call("—", width)
				continue
			var o: Autoplay.PlayOutcome = Autoplay.play(level, e_buy, e_s)
			if o.result.won and o.result.stars >= perfect.result.stars:
				problems.append("%s: el error \"%s\" no castiga (%s)" % [level.id, name, fmt_out(o)])
			cells += pad.call(fmt_out(o), width)
		var cheapest: Autoplay.PlayOutcome = Autoplay.play(level, Purchase.make(level.min_panels, 1, false))
		if cheapest.result.won:
			problems.append("%s: TRIVIAL (la compra más barata gana)" % level.id)
		var all: Array[Purchase] = Autoplay.affordable_purchases(level)
		var good: int = 0
		for b: Purchase in all:
			if Autoplay.play(level, b).result.stars >= 2:
				good += 1
		var rate: float = float(good) / float(all.size())
		if rate > prev_rate + 0.05:
			problems.append("%s: más fácil que el nivel anterior (compras de ≥2★ %d%% > %d%%)" % [level.id, JsMath.js_round(rate * 100.0), JsMath.js_round(prev_rate * 100.0)])
		prev_rate = rate
		var buy_txt: String = "%dp %db%s $%d/%d" % [buy.panels, buy.batteries, " kit" if buy.kit_zonda else "", catalog.cost(level, buy), level.budget]
		lines.append(pad.call(level.id, 9) + pad.call(buy_txt, 25) + pad.call(fmt_out(perfect), 13) + cells
			+ pad.call(fmt_out(cheapest), 13) + "%d%% (%d)" % [JsMath.js_round(rate * 100.0), all.size()])
	if problems.is_empty():
		lines.append("")
		lines.append("Balance OK.")
	else:
		lines.append("")
		lines.append("PROBLEMAS DE BALANCE:")
		for p: String in problems:
			lines.append(" - " + p)
	return problems.is_empty()
