extends TestCase
## Test de humo: instancia un PlantWorld completo (sin árbol de escena) y chequea invariantes
## básicos. No reproduce PlantWorld.ts línea por línea (ya lo hace test_layout.gd indirectamente
## vía LevelLayout); esto verifica que el ensamblado entero no explota y cuenta bien.


func test_plant_world_casa_arma_todo_sin_crashear() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var w: PlantWorld = PlantWorld.new(level, purchase, Callable())

	check_eq(w.mounts.size(), 4, "4 montajes (1 fila x 4)")
	check_eq(w.rows.size(), 1, "1 fila")
	check_eq(w.posts.size(), 1, "1 poste de fila")
	check_eq(w.batteries.size(), 1, "1 base de batería")
	check_eq(w.panels_installed(), 0, "sin paneles instalados todavía")
	check_eq(w.panels_in_row(0), 0, "fila 0 sin paneles instalados")
	check(not w.any_faulty(), "sin paneles falla instalados")
	check_eq(w.batteries_installed(), 0, "sin baterías instaladas")
	check(not w.row_dirty(0), "fila recién armada, sin polvo")
	check(w.pump == null, "casa no tiene bomba")
	check_eq(w.pallet.remaining(), 4, "pallet con los 4 paneles comprados")
	# protección (fija) + 1 batería comprada.
	check_eq(w.pickups.size(), 2, "2 cajones en el depósito")
	check(not w.protection.installed(), "protección sin instalar todavía")
	check(not w.batteries[0].installed(), "batería sin instalar todavía")
	# Lejos de cualquier colisionador, un punto no se mueve (el comportamiento de empuje
	# cerca de cajas ya lo cubre test_world.gd).
	check_eq(w.colliders.resolve(Vector2(0.0, 0.0), 0.1), Vector2(0.0, 0.0), "lejos de todo, no se mueve")
	w.free()


func test_plant_world_instala_panel_bateria_y_protege() -> void:
	var level: LevelDefinition = Levels.casa()
	var w: PlantWorld = PlantWorld.new(level, Purchase.make(4, 1, false), Callable())

	w.mounts[0].install(false)
	check(w.mounts[0].filled(), "panel instalado")
	check_eq(w.panels_installed(), 1, "1 panel instalado")
	check_eq(w.panels_in_row(0), 1, "1 panel en la fila 0")

	w.protection.install()
	check(w.protection.installed(), "protección instalada")
	w.link_protection()
	check(w.protection_link != null, "cable de protección creado")
	w.link_protection()  # llamarlo dos veces no debe crear un segundo cable.

	w.batteries[0].install()
	check(w.batteries[0].installed(), "batería instalada")
	check_eq(w.batteries_installed(), 1, "1 batería instalada")

	w.ensure_row_wire(0)
	check(w.row_wires[0] != null, "cable de la fila 0 creado")
	w.free()


func test_plant_world_finca_tiene_bomba_con_cable() -> void:
	var level: LevelDefinition = Levels.finca()
	var w: PlantWorld = PlantWorld.new(level, Purchase.make(level.min_panels, 0, false), Callable())
	check(w.pump != null, "finca tiene bomba")
	check(w.pump_wire != null, "cable de la bomba creado")
	w.free()
