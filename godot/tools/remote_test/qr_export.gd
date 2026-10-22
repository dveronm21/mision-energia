extends SceneTree
## Exporta PNGs de QrEncoder para verificarlos con un decodificador externo (qr_check.py, OpenCV).
##   godot --headless --path godot -s res://tools/remote_test/qr_export.gd -- <carpeta_salida>
## Escribe <carpeta>/qr_NN.png y <carpeta>/manifest.json [{file, text, version, mask}].

const TEXTS: Array[String] = [
	"http://192.168.0.23:8765/",
	"http://10.0.0.5:8775/",
	"http://172.16.254.201:8785/?app=1",
	"HOLA",
	"http://192.168.100.200:8765/?tv=Tele%20del%20living&app=1&x=0123456789",
	"Misión Energía · ¡Sumate con tu tablet! ⚡",
	"https://inkfusion.com.ar/mision-energia/control/?sala=feria-san-juan-2026&puesto=1&modo=tv&version=1.0.0",
	"x",
]


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://qr_out"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var manifest: Array = []
	var extra: Array[String] = TEXTS.duplicate()
	extra.append("A".repeat(150))
	extra.append("http://192.168.0.23:8765/" + "a".repeat(185))   # 210 bytes → versión 10
	for i: int in extra.size():
		var q := QrEncoder.new()
		if not q.encode(extra[i]):
			push_error("no entra: " + extra[i])
			quit(1)
			return
		var file: String = "qr_%02d.png" % i
		q.to_image(8, 4).save_png(out_dir.path_join(file))
		manifest.append({"file": file, "text": extra[i], "version": q.version, "mask": q.mask})
	var f := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  ", false))
	f.close()
	print("QR exportados: %d en %s" % [extra.size(), out_dir])
	quit(0)
