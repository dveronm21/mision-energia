extends SceneTree
## Captura rápida de pantallas mientras se arman (no es parte del juego final):
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_ui.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Window = get_root()
	root.size = Vector2i(1280, 720)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0e2420")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var mgr: ScreenManager = ScreenManager.new(host)

	var store: SaveStore = SaveStore.in_memory()
	var bus: EventBus = EventBus.new()
	var wallet: Wallet = Wallet.new(store, bus)
	wallet.add(640, "test")
	var inventory: Inventory = Inventory.new(store)
	var catalog: Catalog = Catalog.new()
	var shop: Shop = Shop.new(catalog, wallet, inventory, DemoPaymentProvider.new(), store, bus)

	var sd: ShopDeps = ShopDeps.new()
	sd.shop = shop
	sd.wallet = wallet
	sd.inventory = inventory
	sd.bus = bus
	sd.initial_tab = ShopDeps.TAB_MEJORAS
	var screen: ShopScreen = ShopScreen.new(sd)
	mgr.push(screen)

	for i: int in 10:
		await process_frame
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	img.save_png("res://tools/out/ui_check.png")
	print("guardado res://tools/out/ui_check.png (tab Mejoras)")

	# Simular el toque de "Comprar" en el primer booster (abre la confirmación en la tarjeta).
	screen._start_confirm(catalog.all().filter(func(p: Product) -> bool: return p.kind == Product.KIND_BOOSTER)[0].id)
	for i: int in 10:
		await process_frame
	img = root.get_texture().get_image()
	img.save_png("res://tools/out/ui_check2.png")
	print("guardado res://tools/out/ui_check2.png (confirmación de compra con Soles)")

	# Vestuario (sin wallet esta vez no haría falta, pero probamos con item ya equipado).
	inventory.grant("skin_helmet_blue", 1)
	inventory.equip("helmet", "skin_helmet_blue")
	screen._set_tab(ShopDeps.TAB_VESTUARIO)
	for i: int in 10:
		await process_frame
	img = root.get_texture().get_image()
	img.save_png("res://tools/out/ui_check3.png")
	print("guardado res://tools/out/ui_check3.png (tab Vestuario, uno equipado)")
	quit()
