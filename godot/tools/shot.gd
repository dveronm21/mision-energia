extends SceneTree
## Capturas de la escena de muestra (scenes/visual/Showcase.tscn) con render real.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 \
##       --audio-driver Dummy -s res://tools/shot.gd -- [nombre ...] [--size=1280x720]
##
## Sin nombres saca todas. Guarda en res://tools/out/<nombre>.png e imprime draw calls y primitivas
## (Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, incluye la pasada de sombras).

const SHOWCASE := "res://scenes/visual/Showcase.tscn"
const OUT_DIR := "res://tools/out/"
const WARMUP_FRAMES := 8

## nombre → parámetros de VisualShowcase.configure()
const SHOTS := {
	"day-closeup": {"view": "closeup", "hour": 10.0},
	"day-game": {"view": "game", "hour": 10.5},
	"dusk-game": {"view": "game", "hour": 19.4, "clouds": 0.5},
	"night-city": {"view": "city", "hour": 22.0},
	"night-game": {"view": "game", "hour": 23.5},
	"zonda-game": {"view": "game", "hour": 15.0, "zonda": 0.85, "defense": true},
	"clouds-sky": {"view": "sky", "hour": 9.0, "clouds": 0.75},
	"workers-poses": {"view": "lineup", "hour": 10.5},
	"overview-16": {"view": "overview", "hour": 11.0},
	"typical-medium": {"view": "game", "hour": 10.5, "typical": true, "quality": 1},
	"typical-low": {"view": "game", "hour": 10.5, "typical": true, "quality": 0},
	"typical-high": {"view": "game", "hour": 10.5, "typical": true, "quality": 2},
	"overview-low": {"view": "overview", "hour": 10.5, "quality": 0},
	"tablet-game": {"view": "game", "hour": 16.5, "size": Vector2i(960, 720)},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = []
	var size := Vector2i(1280, 720)
	var env_over: Dictionary = {}
	var rig_over: Dictionary = {}
	var sun_over: Dictionary = {}
	var suffix := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--env="):
			# ajustes de prueba del Environment: --env=tonemap_exposure:0.8,tonemap_white:2
			for kv: String in a.substr(6).split(","):
				var p2 := kv.split(":")
				env_over[p2[0]] = float(p2[1])
		elif a.begins_with("--rig="):
			# propiedades de EnvironmentRig: --rig=ambient_scale:0.6,sun_scale:1.0
			for kv: String in a.substr(6).split(","):
				var p3 := kv.split(":")
				rig_over[p3[0]] = float(p3[1])
		elif a.begins_with("--sun="):
			# propiedades del DirectionalLight3D: --sun=shadow_blur:0.5,directional_shadow_mode:1
			for kv: String in a.substr(6).split(","):
				var p4 := kv.split(":")
				sun_over[p4[0]] = float(p4[1])
		elif a.begins_with("--suffix="):
			suffix = a.substr(9)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		else:
			names.append(a)
	if names.is_empty():
		for k: String in SHOTS:
			names.append(k)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	root.size = size
	DisplayServer.window_set_size(size)
	var packed: PackedScene = load(SHOWCASE)
	for n: String in names:
		if not SHOTS.has(n):
			push_error("shot: no existe la captura " + n)
			continue
		var sc := packed.instantiate() as VisualShowcase
		if sc == null or sc.get_script() == null:
			push_error("shot: no se pudo instanciar la escena de muestra (¿error de script?)")
			quit(1)
			return
		var params: Dictionary = SHOTS[n]
		var shot_size: Vector2i = params.get("size", size)
		root.size = shot_size
		DisplayServer.window_set_size(shot_size)
		sc.configure(params)
		sc.animate_time = false
		root.add_child(sc)
		for k: String in rig_over:
			sc.env.set(k, rig_over[k])
		for k: String in sun_over:
			sc.env.sun.set(k, sun_over[k])
		for k: String in env_over:
			sc.env.environment.set(k, env_over[k])
		for f: int in WARMUP_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var vis_calls := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var vis_objs := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
		var sh_calls := root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var img := root.get_texture().get_image()
		var path := OUT_DIR + n + suffix + ".png"
		img.save_png(path)
		print("SHOT %-16s q=%d calls=%d (main %d / objs %d, shadow %d) prims=%d objects=%d -> %s" % [n, int(params.get("quality", 1)), int(calls), vis_calls, vis_objs, sh_calls, int(prims), int(objs), path])
		sc.queue_free()
		await process_frame
	quit()
