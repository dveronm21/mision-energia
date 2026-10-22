extends TestCase
## Port de economy.test.ts: billetera, inventario, tienda, catálogo, boosters, recompensas y control parental.


## Proveedor controlado: la verificación espera a que el test llame a `release(ok)`.
class ControlledProvider:
	extends IPaymentProvider
	signal released(ok: bool)
	var verify_called: bool = false
	var _status: String

	func _init(status: String = PaymentResult.APPROVED) -> void:
		_status = status

	func provider_id() -> String:
		return IPaymentProvider.ID_MERCADOPAGO

	func release(ok: bool) -> void:
		released.emit(ok)

	func _do_purchase(product: Product) -> PaymentResult:
		await _next_frame()
		return PaymentResult.make(_status, "ORD-1", product.id)

	func _do_verify(_result: PaymentResult) -> bool:
		verify_called = true
		var ok: bool = await released
		return ok


class ShopRig:
	extends RefCounted
	var store: SaveStore = SaveStore.in_memory()
	var wallet: Wallet
	var inv: Inventory
	var shop: Shop
	## Último resultado recibido por señal. Se captura un Array (no `self`) para no crear un ciclo de referencias.
	var _got: Array[PaymentResult] = []

	func _init(provider: IPaymentProvider) -> void:
		wallet = Wallet.new(store)
		inv = Inventory.new(store)
		shop = Shop.new(Catalog.new(), wallet, inv, provider, store)
		var got: Array[PaymentResult] = _got
		shop.token_pack_finished.connect(func(r: PaymentResult) -> void:
			got.clear()
			got.append(r))

	func last() -> PaymentResult:
		return _got.back() if not _got.is_empty() else null

	func clear_last() -> void:
		_got.clear()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_wallet() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var bus: EventBus = EventBus.new()
	var seen: Array[int] = []
	var bus_seen: Array[int] = []
	bus.wallet_changed.connect(func(b: int) -> void: bus_seen.append(b))
	var w: Wallet = Wallet.new(store, bus, func() -> int: return 42)
	var cb: Callable = func(b: int) -> void: seen.append(b)
	w.balance_changed.connect(cb)
	w.add(100, "regalo")
	check_eq(w.spend(150, "caro"), false, "no alcanza")
	check_eq(w.spend(30, "pista"), true, "gasta")
	w.add(-5, "ignorado")
	w.balance_changed.disconnect(cb)
	w.add(1, "x")
	check_eq(w.balance(), 71, "saldo")
	check_eq(seen, [100, 70] as Array[int], "listeners")
	check_eq(bus_seen, [100, 70, 71] as Array[int], "bus")
	var deltas: Array[int] = []
	for h: Dictionary in w.history():
		deltas.append(int(h["delta"]))
	check_eq(deltas, [100, -30, 1] as Array[int], "historial")
	check_eq(int(w.history()[0]["at"]), 42, "reloj inyectado")
	check_eq(Wallet.new(store).balance(), 71, "persistencia")
	check_eq(w.spend(0, "gratis"), true, "gastar 0")
	check_eq(w.spend(71.2, "redondea arriba"), false, "ceil")
	w.add(2.9, "redondea abajo")
	check_eq(w.balance(), 73, "floor")
	for k: int in 120:
		w.add(1, "muchos")
	check_eq(w.history().size(), Wallet.HISTORY_MAX, "historial acotado")
	bus.free()


func test_inventory() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var inv: Inventory = Inventory.new(store)
	inv.grant("boost_hint", 2)
	check_eq(inv.consume("boost_hint"), true, "consume")
	check_eq(inv.count("boost_hint"), 1, "quedan 1")
	check_eq(inv.consume("nada"), false, "nada")
	inv.equip("helmet", "skin_helmet_blue")
	check_eq(inv.equipped_cosmetic("helmet"), "", "no lo tiene")
	inv.grant("skin_helmet_blue", 1)
	inv.equip("helmet", "skin_helmet_blue")
	var again: Inventory = Inventory.new(store)
	check_eq(again.equipped_cosmetic("helmet"), "skin_helmet_blue", "persiste equipado")
	check_eq(again.count("boost_hint"), 1, "persiste cantidad")
	check_eq(again.equipped_cosmetic("vest"), "", "chaleco default")
	again.equip("helmet", "")
	check_eq(Inventory.new(store).equipped_cosmetic("helmet"), "", "desequipa")


func test_shop_demo_acredita() -> void:
	var rig: ShopRig = ShopRig.new(DemoPaymentProvider.new(0.01))
	check(rig.shop.is_demo(), "es demo")
	var r: PaymentResult = await rig.shop.buy_token_pack("pack_small")
	check_eq(r.status, PaymentResult.APPROVED, "aprobado")
	check(r.order_id.begins_with("DEMO-"), "orden DEMO-")
	check_eq(rig.wallet.balance(), 120, "acreditó")
	check(rig.last() == r, "señal token_pack_finished")
	var r2: PaymentResult = await rig.shop.buy_token_pack("pack_small")
	check(r2.order_id != r.order_id, "ids distintos")
	check_eq(rig.wallet.balance(), 240, "segunda compra")
	var ids: DemoPaymentProvider = DemoPaymentProvider.new(0.0, func() -> String: return "fijo")
	check_eq((await ids.purchase(Catalog.new().find("pack_small"))).order_id, "DEMO-fijo", "id inyectado")


func test_shop_no_acredita_hasta_verificar() -> void:
	var p: ControlledProvider = ControlledProvider.new()
	var rig: ShopRig = ShopRig.new(p)
	rig.shop.buy_token_pack("pack_medium") # sin await: queda esperando la verificación
	await _tree().process_frame
	await _tree().process_frame
	check(p.verify_called, "pidió verificar")
	check_eq(rig.wallet.balance(), 0, "no acreditó todavía")
	check(rig.last() == null, "no terminó")
	p.release(true)
	await _tree().process_frame
	check(rig.last() != null and rig.last().status == PaymentResult.APPROVED, "aprobado tras verificar")
	check_eq(rig.wallet.balance(), 650, "acreditó")
	check(rig.shop.is_credited("ORD-1"), "orden guardada")
	# misma orden otra vez: no duplica
	rig.clear_last()
	rig.shop.buy_token_pack("pack_medium")
	await _tree().process_frame
	await _tree().process_frame
	p.release(true)
	await _tree().process_frame
	check_eq(rig.wallet.balance(), 650, "no duplica")
	check(rig.last() != null and rig.last().message == "Esta compra ya estaba acreditada.", "mensaje de ya acreditada")
	# La orden acreditada sobrevive a reiniciar la tienda.
	var shop2: Shop = Shop.new(Catalog.new(), rig.wallet, rig.inv, p, rig.store)
	check(shop2.is_credited("ORD-1"), "persistida")


func test_shop_fallas_no_acreditan() -> void:
	var p: ControlledProvider = ControlledProvider.new()
	var a: ShopRig = ShopRig.new(p)
	a.shop.buy_token_pack("pack_large")
	await _tree().process_frame
	await _tree().process_frame
	p.release(false)
	await _tree().process_frame
	check(a.last() != null and a.last().status == PaymentResult.FAILED, "verificación fallida")
	check_eq(a.wallet.balance(), 0, "sin saldo")

	var b: ShopRig = ShopRig.new(ControlledProvider.new(PaymentResult.CANCELLED))
	check_eq((await b.shop.buy_token_pack("pack_large")).status, PaymentResult.CANCELLED, "cancelado")
	check_eq(b.wallet.balance(), 0, "cancelado no acredita")

	var mp: ShopRig = ShopRig.new(MercadoPagoProvider.new())
	var r: PaymentResult = await mp.shop.buy_token_pack("pack_small")
	check_eq(r.status, PaymentResult.FAILED, "MP falla")
	check_eq(r.message, "Pagos reales aún no configurados", "mensaje MP")
	check_eq(mp.wallet.balance(), 0, "MP no acredita")
	check_eq((await mp.shop.buy_token_pack("boost_hint")).status, PaymentResult.FAILED, "no es pack")

	var gp: ShopRig = ShopRig.new(GooglePlayBillingProvider.new())
	var g: PaymentResult = await gp.shop.buy_token_pack("pack_medium")
	check_eq(g.status, PaymentResult.FAILED, "Google Play stub falla")
	check_eq(g.message, "Pagos reales aún no configurados", "mensaje GP")
	check_eq(gp.wallet.balance(), 0, "GP no acredita")
	check(not gp.shop.is_demo(), "GP no es demo")


func test_shop_con_soles() -> void:
	var rig: ShopRig = ShopRig.new(DemoPaymentProvider.new(0.0))
	check_eq(rig.shop.buy_with_soles("boost_drone"), false, "sin saldo")
	rig.wallet.add(200, "test")
	check_eq(rig.shop.buy_with_soles("boost_drone"), true, "dron 1")
	check_eq(rig.shop.buy_with_soles("boost_drone"), true, "dron 2")
	check_eq(rig.inv.count("boost_drone"), 2, "2 drones")
	check_eq(rig.shop.buy_with_soles("skin_vest_green"), true, "chaleco")
	check_eq(rig.shop.buy_with_soles("skin_vest_green"), false, "chaleco ya comprado")
	check_eq(rig.shop.buy_with_soles("pack_small"), false, "pack no se paga con Soles")
	check_eq(rig.wallet.balance(), 200 - 25 * 2 - 60, "saldo")


func test_catalogo() -> void:
	var cat: Catalog = Catalog.new()
	check_eq(cat.by_kind(Product.KIND_TOKEN_PACK).size(), 3, "3 packs")
	for p: Product in cat.by_kind(Product.KIND_TOKEN_PACK):
		check(p.currency == "ARS" and p.price_cents > 0, "precio " + p.id)
	check_eq(cat.by_kind(Product.KIND_BOOSTER).size(), 4, "4 boosters")
	check_eq(cat.by_kind(Product.KIND_COSMETIC).size(), 6, "6 cosméticos")
	check_eq(cat.cosmetic_slot("skin_vest_green"), "vest", "slot")
	var ethical: bool = true
	var rx: RegEx = RegEx.create_from_string("(?i)sorpresa|aleatori|caja misteriosa")
	for p: Product in cat.all():
		ethical = ethical and rx.search(p.title + p.description) == null
	check(ethical, "sin aleatorios")
	var campaign: int = 0
	for l: LevelDefinition in Levels.all():
		campaign += l.rewards[0] + l.rewards[1] + l.rewards[2]
	check(campaign + RewardService.WELCOME_SOLES >= 300, "la campaña se cubre sin pagar")
	check_eq(cat.find("pack_medium").soles, 650, "pack mediano")
	check_eq(cat.find("boost_battery").cost_soles, 35, "batería de emergencia")
	check(cat.find("nada") == null, "inexistente")
	var copy: Product = cat.find("boost_hint")
	copy.cost_soles = 1
	check_eq(cat.find("boost_hint").cost_soles, 10, "find devuelve copia")
	check_eq(Catalog.cosmetic_color("skin_helmet_blue").to_html(false), "2f7be0", "color")


func test_boosters() -> void:
	var inv: Inventory = Inventory.new(SaveStore.in_memory())
	var b: Boosters = Boosters.new(inv)
	check_eq(b.use(Boosters.BUDGET), false, "sin booster")
	inv.grant(Boosters.BUDGET, 1)
	check_eq(b.available(Boosters.BUDGET), 1, "disponible")
	check_eq(b.use(Boosters.BUDGET), true, "usa")
	check_eq(b.budget_for(Levels.casa(), true), JsMath.js_round(7400 * 1.15), "presupuesto +15%")
	check_eq(b.budget_for(Levels.casa(), true), 8510, "8510")
	check_eq(b.budget_for(Levels.casa(), false), 7400, "sin boost")
	check_eq(b.bonus_kwh(true), 4.0, "bonus")
	check_eq(b.bonus_kwh(false), 0.0, "sin bonus")


func test_recompensas_con_reloj_inyectado() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var w: Wallet = Wallet.new(store)
	var now: Array[Dictionary] = [{"year": 2026, "month": 10, "day": 22, "hour": 9, "minute": 0}]
	var clock: Callable = func() -> Dictionary: return now[0]
	var rs: RewardService = RewardService.new(w, store, clock)
	check(rs.can_claim_welcome(), "puede bienvenida")
	check_eq(rs.claim_welcome(), RewardService.WELCOME_SOLES, "bienvenida")
	check_eq(rs.claim_welcome(), 0, "una sola vez")
	check_eq(rs.claim_daily(), RewardService.DAILY_SOLES, "diario")
	now[0] = {"year": 2026, "month": 10, "day": 22, "hour": 23, "minute": 59}
	check_eq(rs.claim_daily(), 0, "mismo día")
	check_eq(RewardService.new(w, store, clock).can_claim_daily(), false, "persistido")
	check_eq(RewardService.new(w, store, clock).can_claim_welcome(), false, "bienvenida persistida")
	now[0] = {"year": 2026, "month": 10, "day": 23, "hour": 0, "minute": 1}
	check_eq(rs.claim_daily(), RewardService.DAILY_SOLES, "día siguiente")
	check_eq(w.balance(), RewardService.WELCOME_SOLES + 2 * RewardService.DAILY_SOLES, "saldo")


func test_control_parental() -> void:
	var seq: Array[float] = [0.0, 0.99, 0.5, 0.3]
	var idx: Array[int] = [0]
	var g: ParentalGate = ParentalGate.new(func() -> float:
		var v: float = seq[idx[0] % seq.size()]
		idx[0] += 1
		return v)
	var c1: ParentalChallenge = g.challenge()
	check_eq(c1.answer, 6 * 9, "6 × 9")
	check(c1.question.contains("6 × 9"), "pregunta")
	check_eq(c1.question, "Para seguir, pedile a una persona adulta: ¿cuánto es 6 × 9?", "texto exacto")
	check_eq(g.check(c1, " 54 "), true, "tolera espacios")
	check_eq(g.check(c1, "45"), false, "incorrecta")
	check_eq(g.check(c1, 54), true, "número")
	check_eq(g.check(c1, "54abc"), false, "basura")
	var c2: ParentalChallenge = g.challenge()
	check_eq(c2.answer, 8 * 7, "8 × 7")
	var rnd: ParentalGate = ParentalGate.new()
	var ok: bool = true
	for k: int in 200:
		var c: ParentalChallenge = rnd.challenge()
		ok = ok and c.answer >= 36 and c.answer <= 81
	check(ok, "factores 6..9")
