extends SceneTree
## Hoja de muestra de los íconos de `IconArt` en los colores que usa la UI, sobre fondo oscuro
## y claro, a dos tamaños. Guarda res://tools/out/icons.png:
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_icons.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Window = get_root()
	root.size = Vector2i(1280, 720)
	var names: Array = IconArt.ART.keys()
	var tints: Array[Color] = [UiTheme.SUN, Color.WHITE, UiTheme.INK, UiTheme.LEAF_DARK]
	var bgs: Array[Color] = [UiTheme.HUD, UiTheme.PAPER]
	var y: float = 0.0
	for bg: Color in bgs:
		var band: ColorRect = ColorRect.new()
		band.color = bg
		band.position = Vector2(0, y)
		band.size = Vector2(1280, 360)
		root.add_child(band)
		var row_y: float = y + 10.0
		for t: Color in tints:
			if (bg == UiTheme.PAPER and t == Color.WHITE) or (bg == UiTheme.HUD and t == UiTheme.INK):
				continue
			var x: float = 10.0
			for n: Variant in names:
				var ic: HudIcon = HudIcon.new(n, 36.0, t)
				ic.position = Vector2(x, row_y)
				ic.size = Vector2(36, 36)
				root.add_child(ic)
				x += 38.0
			row_y += 44.0
		# Fila grande, para ver el detalle del volumen.
		var x2: float = 10.0
		for i: int in mini(names.size(), 16):
			var big: HudIcon = HudIcon.new(names[i], 72.0, UiTheme.SUN)
			big.position = Vector2(x2, row_y + 6.0)
			big.size = Vector2(72, 72)
			root.add_child(big)
			x2 += 78.0
		y += 360.0
	for i: int in 8:
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	root.get_texture().get_image().save_png("res://tools/out/icons.png")
	print("guardado res://tools/out/icons.png (%d íconos)" % names.size())
	quit()
