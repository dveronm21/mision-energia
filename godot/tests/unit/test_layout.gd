extends TestCase
## Port de los casos relevantes de LevelLayout.ts, con los números calculados a mano
## para el nivel "casa" (1 fila × 4 paneles, 1 batería, sin bomba).

const TOL: float = 1e-6


func test_layout_casa_campo_y_sala() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var l: LevelLayout = LevelLayout.build(level, purchase)

	check_eq(l.rows.size(), 1, "una fila")
	var row: RowLayout = l.rows[0]
	check_near(row.z, -3.4, TOL, "z de la fila")
	check_eq(row.mounts.size(), 4, "4 montajes")
	var expected_x: Array[float] = [-11.35, -9.1, -6.85, -4.6]
	for i: int in 4:
		check_near(row.mounts[i].x, expected_x[i], TOL, "mount %d x" % i)
		check_near(row.mounts[i].z, -3.4, TOL, "mount %d z" % i)
	check_near(row.post.x, -14.15, TOL, "poste de fila")
	check_near(row.wire_start.x, -3.55, TOL, "inicio del cable")
	check_near(row.wire_start.y, 0.85, TOL, "altura del cable")

	check_near(l.room.inverter.x, 5.2, TOL, "inversor")
	check_near(l.room.switchboard.x, 11.2, TOL, "tablero")
	check_eq(l.room.batteries.size(), 1, "1 banco de batería (battery_slots)")
	check_near(l.room.batteries[0].x, 6.5, TOL, "posición batería")
	check(l.pump == null, "casa no tiene bomba")


func test_layout_casa_depot_y_limites() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var l: LevelLayout = LevelLayout.build(level, purchase)

	# protección (fija) + 1 batería comprada, sin kit.
	check_eq(l.crates.size(), 2, "cajones: protección + 1 batería")
	check_eq(l.crates[0].kind, &"protection", "primer cajón es protección")
	check_eq(l.crates[1].kind, &"battery", "segundo cajón es batería")
	check_near(l.depot_label.x, 5.0, TOL, "cartel del depósito")

	check_near(l.bounds.min_x, -15.95, TOL, "límite oeste")
	check_near(l.bounds.max_x, 21.0, TOL, "límite este")
	check_near(l.bounds.min_z, -8.6, TOL, "límite norte")
	check_near(l.bounds.max_z, 7.5, TOL, "límite sur")
	check(l.on_slab(7.0, -4.2), "el centro de la sala está sobre la platea")
	check(not l.on_slab(-20.0, -20.0), "lejos de la sala, no está sobre la platea")


func test_layout_casa_ciudad_cercana() -> void:
	var level: LevelDefinition = Levels.casa()
	var l: LevelLayout = LevelLayout.build(level, Purchase.make(4, 1, false))
	check_eq(l.city.city_name, "CASA QUIROGA", "nombre de la ciudad")
	check_near(l.city.origin.x, 19.5, TOL, "origen cercano")
	check_eq(l.city.poles.size(), 2, "2 postes para ciudad cercana")
	check_near(l.city.label.y, 5.0, TOL, "altura del cartel (alto del edificio + 1.6)")


func test_layout_con_kit_zonda_agrega_un_cajon() -> void:
	var level: LevelDefinition = Levels.casa()
	var l: LevelLayout = LevelLayout.build(level, Purchase.make(4, 0, true))
	check_eq(l.crates.size(), 2, "protección + kit")
	check_eq(l.crates[1].kind, &"kit", "segundo cajón es el kit Zonda")


func test_layout_pueblo_ciudad_lejana_y_bomba() -> void:
	var level: LevelDefinition = Levels.pueblo()
	var l: LevelLayout = LevelLayout.build(level, Purchase.make(level.min_panels, 0, false))
	check(l.city.poles.size() == 3, "3 postes para ciudad lejana")
	check(l.pump == null, "pueblo no tiene bomba")


func test_layout_finca_tiene_bomba() -> void:
	var level: LevelDefinition = Levels.finca()
	var l: LevelLayout = LevelLayout.build(level, Purchase.make(level.min_panels, 0, false))
	check(l.pump != null, "finca tiene bomba")
	if l.pump != null:
		var pump: Vector3 = l.pump
		check_near(pump.x, 15.2, TOL, "posición x de la bomba")
