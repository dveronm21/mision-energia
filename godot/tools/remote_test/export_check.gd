extends SceneTree
## Verifica que la página de control quedó dentro de un export (PCK/APK) y se lee por res://.
##   godot --headless --main-pack MisionEnergia.pck -s res://tools/remote_test/export_check.gd
## (el preset tiene que incluir "controller/*" y "tools/remote_test/export_check.gd" en include_filter)

func _init() -> void:
	var files := StaticFileServer.new("res://controller/")
	var bad: int = 0
	for rel: String in ["index.html", "controller.js", "fonts/fredoka-latin-700-normal.woff2", "fonts/nunito-latin-800-normal.woff2"]:
		var data: PackedByteArray = files.read_asset(rel)
		var resp: PackedByteArray = files.respond("/" + rel, true, false)
		var status: String = resp.slice(0, 12).get_string_from_ascii()
		var ok: bool = data.size() > 100 and status == "HTTP/1.1 200"
		if not ok:
			bad += 1
		print("%s res://controller/%s  %d B  %s" % ["OK   " if ok else "FALLA", rel, data.size(), StaticFileServer.mime_for(rel)])
	var woff: PackedByteArray = files.read_asset("fonts/fredoka-latin-700-normal.woff2")
	var magic_ok: bool = woff.size() > 4 and woff.slice(0, 4).get_string_from_ascii() == "wOF2"
	print("%s woff2 original (firma wOF2), no el .fontdata importado" % ["OK   " if magic_ok else "FALLA"])
	if not magic_ok:
		bad += 1
	quit(1 if bad > 0 else 0)
