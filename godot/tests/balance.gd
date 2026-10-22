extends SceneTree
## Chequeo de balance (port de `npm run balance`):
##   godot --headless --path godot -s res://tests/balance.gd
## Imprime la misma tabla que la versión web y sale con código ≠ 0 si hay problemas.


func _initialize() -> void:
	var bc: BalanceCheck = BalanceCheck.new()
	var ok: bool = bc.run()
	for line: String in bc.lines:
		print(line)
	quit(0 if ok else 1)
