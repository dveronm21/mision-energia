extends TestCase
## Port de los casos relevantes de Colliders.ts (world/).


func test_colliders_empuja_fuera_de_una_caja() -> void:
	var c: Colliders = Colliders.new(-100.0, 100.0, -100.0, 100.0)
	c.add(0.0, 0.0, 1.0, 1.0)
	var out: Vector2 = c.resolve(Vector2(0.5, 0.0), 0.4)
	check(out.x >= 1.0 - 1e-3, "empuja hacia afuera en X: %s" % out)
	check_near(out.y, 0.0, 1e-3, "no cambia Z cuando empuja por X")


func test_colliders_centro_adentro_sale_por_el_lado_mas_cerca() -> void:
	var c: Colliders = Colliders.new(-100.0, 100.0, -100.0, 100.0)
	c.add(0.0, 0.0, 1.0, 5.0)
	# Centro justo en el medio de la caja: el lado más corto es X (hw=1 < hd=5).
	var out: Vector2 = c.resolve(Vector2(0.0, 0.0), 0.4)
	check_near(absf(out.x), 1.4, 1e-3, "sale por X (el lado más angosto): %s" % out)


func test_colliders_respeta_los_limites_del_mapa() -> void:
	var c: Colliders = Colliders.new(-10.0, 10.0, -5.0, 5.0)
	var out: Vector2 = c.resolve(Vector2(50.0, -50.0), 0.4)
	check_eq(out.x, 10.0, "clamp en maxX")
	check_eq(out.y, -5.0, "clamp en minZ")


func test_colliders_remove_deja_de_colisionar() -> void:
	var c: Colliders = Colliders.new(-100.0, 100.0, -100.0, 100.0)
	var box: AabbBox = c.add(0.0, 0.0, 1.0, 1.0)
	c.remove(box)
	var out: Vector2 = c.resolve(Vector2(0.5, 0.0), 0.4)
	check_eq(out.x, 0.5, "sin caja, no empuja")
