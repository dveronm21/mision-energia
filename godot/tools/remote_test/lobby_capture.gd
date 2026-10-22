extends SceneTree
## Capturas de la sala de espera (LobbyView) con render real y prueba de navegación con D-pad.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 \
##       --resolution 1920x1080 -s res://tools/remote_test/lobby_capture.gd -- <carpeta> [sufijo]
## Escribe lobby-empty-<sufijo>.png, lobby-<sufijo>.png (2 jugadores) y lobby-reconnecting-<sufijo>.png.

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	var suffix: String = args[1] if args.size() > 1 else "1080"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bridge := RemoteFakeBridge.new("http://192.168.0.23:8765/", "Tele del living")
	var host := RemoteHost.new(bridge)
	var lobby := LobbyView.new()
	root.add_child(lobby)
	lobby.setup(host)
	var started: Array[int] = [0]
	lobby.start_requested.connect(func() -> void: started[0] += 1)
	var backs: Array[int] = [0]
	lobby.back_requested.connect(func() -> void: backs[0] += 1)
	lobby.show_lobby()
	await _frames(6)
	_check(lobby.start_button.disabled, "sin jugadores: Empezar deshabilitado")
	_check(root.gui_get_focus_owner() == lobby.back_button, "sin jugadores: foco en Volver")
	await _save(out_dir.path_join("lobby-empty-%s.png" % suffix))

	var ana := bridge.connect_client(); ana.hello("Ana")
	var beto := bridge.connect_client(); beto.hello("Beto")
	host.update()
	ana.ping(1.0, 45); beto.ping(1.0, 25)
	host.update()
	lobby.refresh()
	await _frames(6)
	_check(not lobby.start_button.disabled, "con jugadores: Empezar habilitado")
	_check(root.gui_get_focus_owner() == lobby.start_button, "foco salta a Empezar")
	await _save(out_dir.path_join("lobby-%s.png" % suffix))

	# D-pad: arriba → un "Quitar"; abajo → vuelve; derecha → Volver; OK → Empezar.
	await _press("ui_up")
	var f: Control = root.gui_get_focus_owner()
	_check(f == lobby.slots[1].kick_button, "flecha arriba → Quitar del lugar 2 (%s)" % (f.name if f else "nada"))
	await _press("ui_down")
	_check(root.gui_get_focus_owner() == lobby.start_button, "flecha abajo → Empezar")
	await _press("ui_right")
	_check(root.gui_get_focus_owner() == lobby.back_button, "flecha derecha → Volver")
	await _press("ui_left")
	await _press("ui_accept")
	_check(started[0] == 1, "OK (ui_accept) en Empezar → start_requested")
	await _press("ui_cancel")
	_check(backs[0] == 1, "ui_cancel → back_requested")

	# Reconexión: Ana se cae, su lugar queda guardado; el foco queda en Quitar de Beto.
	ana.drop()
	beto.ping(2.0, 31)   # Beto sigue vivo (si no, el host lo marca por timeout a los 3 s)
	host.update()
	lobby.refresh()
	lobby.slots[1].kick_button.grab_focus()
	await _frames(6)
	await _save(out_dir.path_join("lobby-reconnecting-%s.png" % suffix))
	print("%s — %d fallas" % ["LOBBY OK" if _fails == 0 else "LOBBY FALLA", _fails])
	quit(0 if _fails == 0 else 1)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("captura: ", path)


func _check(cond: bool, what: String) -> void:
	print(("OK    " if cond else "FALLA ") + what)
	if not cond:
		_fails += 1
