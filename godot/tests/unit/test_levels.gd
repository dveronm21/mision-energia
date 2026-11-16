extends TestCase
## Port de levels.test.ts: catálogo, progreso, Soles por estrellas nuevas y desbloqueo con Soles.

var catalog: LevelCatalog = LevelCatalog.new()


func _result(stars: int, won: bool = true, score: int = 1000) -> LevelResult:
	var r: LevelResult = LevelResult.make(LevelDefinition.CASA, won, stars, score)
	r.final_soc_pct = 0.3
	r.duration_sec = 60.0
	return r


func test_catalogo_encadenado() -> void:
	var all: Array[LevelDefinition] = catalog.all()
	var ids: Array[String] = []
	for l: LevelDefinition in all:
		ids.append(l.id)
	check_eq(ids, ["casa", "escuela", "finca", "pueblo", "parque"] as Array[String], "orden")
	for i: int in all.size():
		var l: LevelDefinition = all[i]
		check_eq(l.order, i + 1, "order " + l.id)
		check_eq(l.requires, "" if i == 0 else all[i - 1].id, "requires " + l.id)
		check(l.min_panels <= l.max_panels(), "min_panels " + l.id)
		check(catalog.cost(l, Purchase.make(l.min_panels, 1, false)) <= l.budget, "compra mínima " + l.id)
	check(catalog.get_level("finca").has_pump, "bomba en finca")
	check(catalog.find_level("nada") == null, "inexistente")
	check(catalog.next_of("casa").id == "escuela", "siguiente")
	check(catalog.next_of("parque") == null, "último")
	var desordenado: LevelCatalog = LevelCatalog.new([Levels.parque(), Levels.casa()] as Array[LevelDefinition])
	check_eq(desordenado.all()[0].id, "casa", "ordena por order")
	check_eq(catalog.cost(Levels.finca(), Purchase.make(5, 2, true)), 600 + 5 * 900 + 2 * 3200 + 700, "costo")


func test_cada_nivel_tres_estrellas() -> void:
	for l: LevelDefinition in catalog.all():
		check_eq(Autoplay.best_purchase(l).outcome.result.stars, 3, l.id)


func test_desbloqueo_por_victoria() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var lm: LevelManager = LevelManager.new(catalog, store, Wallet.new(store))
	check(lm.is_unlocked("casa"), "casa abierta")
	check(not lm.is_unlocked("escuela"), "escuela cerrada")
	check_eq(lm.record_result(_result(0, false)).newly_unlocked, "", "perder no desbloquea")
	check(not lm.is_unlocked("escuela"), "sigue cerrada")
	check_eq(lm.record_result(_result(1)).newly_unlocked, "escuela", "ganar desbloquea")
	check(lm.is_unlocked("escuela"), "escuela abierta")
	check_eq(lm.record_result(_result(1)).newly_unlocked, "", "no repite")


func test_soles_por_estrellas_nuevas() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var wallet: Wallet = Wallet.new(store)
	var lm: LevelManager = LevelManager.new(catalog, store, wallet)
	var rw: Array[int] = catalog.get_level("casa").rewards
	check_eq(lm.record_result(_result(2)).soles_earned, rw[0] + rw[1], "1ª y 2ª estrella")
	check_eq(lm.record_result(_result(2)).soles_earned, 0, "repetir 2★")
	check_eq(lm.record_result(_result(1)).soles_earned, 0, "peor resultado")
	check_eq(lm.record_result(_result(3, true, 2000)).soles_earned, rw[2], "3ª estrella")
	check_eq(wallet.balance(), rw[0] + rw[1] + rw[2], "saldo")
	var again: LevelManager = LevelManager.new(catalog, store, Wallet.new(store))
	check_eq(again.progress("casa").to_dict(), LevelProgress.make(true, 3, 2000, true).to_dict(), "persistido")
	check_eq(again.total_stars(), 3, "total de estrellas")
	check_eq(Wallet.new(store).balance(), 35, "saldo persistido")


func test_desbloqueo_con_soles() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var wallet: Wallet = Wallet.new(store)
	var lm: LevelManager = LevelManager.new(catalog, store, wallet)
	var cost: int = catalog.get_level("finca").unlock_cost_soles
	check_eq(lm.unlock_with_soles("finca"), false, "sin saldo")
	wallet.add(cost + 5, "test")
	check_eq(lm.unlock_with_soles("finca"), true, "paga")
	check_eq(wallet.balance(), 5, "cobró")
	check(lm.is_unlocked("finca"), "abierta")
	check_eq(lm.unlock_with_soles("finca"), true, "ya abierta")
	check_eq(wallet.balance(), 5, "no cobra dos veces")
	check(LevelManager.new(catalog, store, wallet).is_unlocked("finca"), "persistido")


func test_casa_trae_cuatro_paneles_y_zonda_al_azar() -> void:
	var casa: LevelDefinition = Levels.casa()
	check_eq(casa.default_panels, 4, "el taller trae la fila completa")
	check(not casa.events.has_zonda(), "la definición sigue sin Zonda (balance y golden)")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var with_zonda: int = 0
	for _i: int in 400:
		var l: LevelDefinition = casa.roll_weather(rng)
		if l.events.has_zonda():
			with_zonda += 1
			check(l != casa, "el Zonda va en una copia")
			var h: float = l.events.zonda_at_hour
			check(h >= 13.0 and h <= 15.0, "llega a la siesta (%.2f)" % h)
			check_near(fmod(h * 4.0, 1.0), 0.0, 1e-6, "en cuartos de hora")
		else:
			check(l == casa, "sin Zonda devuelve el mismo nivel")
	check(with_zonda > 150 and with_zonda < 250, "más o menos la mitad de las partidas (%d/400)" % with_zonda)
	check(not casa.events.has_zonda(), "sortear no toca la definición")


func test_niveles_con_zonda_fijo_no_se_sortean() -> void:
	var finca: LevelDefinition = Levels.finca()
	finca.random_zonda_chance = 1.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	check(finca.roll_weather(rng) == finca, "con Zonda fijo no cambia")
	var esc: LevelDefinition = Levels.escuela()
	check(esc.roll_weather(rng) == esc, "escuela no sortea Zonda")
