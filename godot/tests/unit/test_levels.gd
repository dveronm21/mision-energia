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
