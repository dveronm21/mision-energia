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


func test_auto_quality_baja_con_fps_bajos_y_no_pasa_del_tope() -> void:
	var aq: AutoQuality = AutoQuality.new(null, null, 2)
	check_eq(aq.quality, 2, "arranca en la calidad de Ajustes")
	# Los primeros segundos (carga del nivel) no cuentan.
	for _i: int in 60:
		aq.update(0.05, 10.0)
	check_eq(aq.quality, 2, "durante el arranque no cambia")
	for _i: int in 200:
		aq.update(0.05, 12.0)
	check(aq.quality < 2, "con FPS bajos baja la calidad")
	for _i: int in 2000:
		aq.update(0.05, 12.0)
	check_eq(aq.quality, 0, "llega a la mínima")
	check_eq(aq.scale_step, AutoQuality.SCALES.size() - 1, "y después baja la resolución 3D")
	for _i: int in 2000:
		aq.update(0.05, 60.0)
	check_eq(aq.scale_step, 0, "con FPS de sobra recupera la resolución")
	check_eq(aq.quality, 0, "pero no vuelve a subir la calidad (sin vaivén)")
	aq.set_cap(1)
	check_eq(aq.quality, 1, "cambiar Ajustes reinicia en el tope nuevo")


## Punta de la mano según las rotaciones que devuelve el IK (cinemática directa en el espacio del torso).
func _ik_hand(shoulder: Vector3, elbow_rest: Vector3, hand_rest: Vector3, r: Array[Vector3]) -> Vector3:
	var arm: Transform3D = Transform3D(Basis.from_euler(r[0], EULER_ORDER_XYZ), shoulder)
	var forearm: Transform3D = Transform3D(Basis.from_euler(r[1], EULER_ORDER_XYZ), elbow_rest)
	return arm * forearm * hand_rest


func test_two_bone_ik_lleva_la_mano_al_objetivo() -> void:
	# Medidas del brazo derecho de worker.glb.
	var shoulder: Vector3 = Vector3(-0.268, 0.41, 0.0)
	var elbow_rest: Vector3 = Vector3(-0.022, -0.26, 0.0)
	var hand_rest: Vector3 = Vector3(-0.007, -0.28, 0.05)
	var targets: Array[Vector3] = [
		Vector3(-0.19, 0.935, 0.05),   # debajo del cajón, sobre la cabeza
		Vector3(-0.3, 0.2, 0.35),      # adelante, a la altura de la cintura
		Vector3(-0.55, 0.3, 0.1),      # al costado
		Vector3(-0.1, 0.5, 0.3),       # cruzado adelante del pecho
	]
	for t: Vector3 in targets:
		var r: Array[Vector3] = TwoBoneIk.solve(shoulder, elbow_rest, hand_rest, t, Vector3(-1.0, 0.0, 0.35))
		var hand: Vector3 = _ik_hand(shoulder, elbow_rest, hand_rest, r)
		check(hand.distance_to(t) < 0.03, "la mano llega a %s (quedó en %s)" % [t, hand])
		check_near(r[1].y, 0.0, 1e-6, "el codo es una bisagra (sin giro en Y)")
	# Fuera de alcance: el brazo se estira y apunta al objetivo.
	var far: Vector3 = Vector3(-0.268, 2.0, 0.0)
	var r2: Array[Vector3] = TwoBoneIk.solve(shoulder, elbow_rest, hand_rest, far, Vector3(-1.0, 0.0, 0.0))
	var hand2: Vector3 = _ik_hand(shoulder, elbow_rest, hand_rest, r2)
	check((hand2 - shoulder).normalized().dot((far - shoulder).normalized()) > 0.98, "fuera de alcance apunta al objetivo")


func test_two_bone_ik_el_codo_va_hacia_el_polo() -> void:
	var shoulder: Vector3 = Vector3(-0.268, 0.41, 0.0)
	var elbow_rest: Vector3 = Vector3(-0.022, -0.26, 0.0)
	var hand_rest: Vector3 = Vector3(-0.007, -0.28, 0.05)
	var t: Vector3 = Vector3(-0.268, 0.41, 0.4)
	for side: float in [-1.0, 1.0]:
		var r: Array[Vector3] = TwoBoneIk.solve(shoulder, elbow_rest, hand_rest, t, Vector3(0.0, side, 0.0))
		var elbow: Vector3 = Transform3D(Basis.from_euler(r[0], EULER_ORDER_XYZ), shoulder) * elbow_rest
		check(signf(elbow.y - shoulder.y) == side, "con el polo en y=%s el codo queda de ese lado (%s)" % [side, elbow])


func test_second_order_sigue_la_entrada_con_rebote() -> void:
	var s: SecondOrder = SecondOrder.new(2.6, 0.42, 0.0, Vector3.ZERO)
	var peak: float = 0.0
	for _i: int in 240:
		var v: Vector3 = s.update(1.0 / 60.0, Vector3(1, 0, 0))
		peak = maxf(peak, v.x)
	check(peak > 1.05, "con amortiguación < 1 se pasa un poco (%.3f)" % peak)
	check_near(s.value.x, 1.0, 0.01, "termina en la entrada")
	s.reset(Vector3(5, 0, 0))
	check_eq(s.update(1.0 / 60.0, Vector3(5, 0, 0)), Vector3(5, 0, 0), "reset deja el valor quieto")
	# Cuadros muy largos no la vuelven inestable.
	var big: SecondOrder = SecondOrder.new(8.0, 0.2, 2.0, Vector3.ZERO)
	for _i: int in 50:
		big.update(0.5, Vector3(1, 0, 0))
	check(absf(big.value.x) < 10.0, "estable con dt grande (%s)" % big.value)


func test_worker_sostiene_la_carga_con_las_manos() -> void:
	var w: WorkerVisual = WorkerVisual.new()
	w.set_carry_grip(Vector3(0.19, -0.075, 0.0), Vector3(-0.19, -0.075, 0.0))
	for _i: int in 60:
		w.animate(1.0 / 60.0, 0.0, WorkerVisual.Pose.CARRY)
	check(w.grip_weight() > 0.99, "el agarre entra del todo (%.3f)" % w.grip_weight())
	var torso: Node3D = w.bone(&"torso")
	for side: int in 2:
		var arm: Node3D = w.bone(&"arm_l" if side == 0 else &"arm_r")
		var forearm: Node3D = w.bone(&"forearm_l" if side == 0 else &"forearm_r")
		var hr: Vector3 = w.hand_anchor.position
		var hand_rest: Vector3 = Vector3(-hr.x, hr.y, hr.z) if side == 0 else hr
		var hand: Vector3 = arm.transform * forearm.transform * hand_rest
		var grip: Vector3 = w.carry_anchor.transform * Vector3(0.19 if side == 0 else -0.19, -0.075, 0.0)
		check(hand.distance_to(grip) < 0.04, "mano %d en el cajón (a %.3f)" % [side, hand.distance_to(grip)])
	check(torso != null, "tiene torso")
	w.clear_carry_grip()
	for _i: int in 60:
		w.animate(1.0 / 60.0, 0.0, WorkerVisual.Pose.IDLE)
	check(w.grip_weight() < 0.01, "al soltar, el agarre sale")
	w.free()
