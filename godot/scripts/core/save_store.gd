class_name SaveStore
extends RefCounted
## Persistencia JSON del juego (equivale a `SaveStore.ts`, que usaba localStorage con prefijo "me.v1.").
##
## - Un solo archivo `user://save_v1.json` con la forma `{"version": 1, "data": {clave: valor}}`.
## - Escritura atómica: se escribe `save_v1.json.tmp` y después se renombra sobre el archivo real,
##   así un corte de luz a mitad de escritura nunca deja el guardado a medias.
## - Si el archivo está corrupto (JSON inválido o forma inesperada), se mueve a
##   `save_v1.corrupt-<unix>.json` como respaldo y se arranca vacío.
## - Siempre hay copia en memoria: si el disco falla, el juego sigue andando durante la sesión.
## - Con `SaveStore.in_memory()` no toca el disco (para tests).
##
## Ojo: como en la web, los valores pasan por JSON. Los enteros vuelven como `float`;
## quien lee convierte con `int(...)`.

const DEFAULT_PATH: String = "user://save_v1.json"
const FORMAT_VERSION: int = 1

## Ruta del archivo, o "" si es solo memoria.
var _path: String
## clave → texto JSON del valor (igual que el Map<string, string> de la web).
var _memory: Dictionary[String, String] = {}
## Ruta del respaldo creado al detectar un archivo corrupto ("" si no hubo).
var _backup_path: String = ""
## Último error de disco (para diagnóstico); OK si todo anduvo.
var _last_error: Error = OK


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	if _path != "":
		_read_file()


## Almacenamiento solo en memoria (tests, o si no se quiere tocar el disco).
static func in_memory() -> SaveStore:
	return SaveStore.new("")


func is_in_memory() -> bool:
	return _path == ""


func file_path() -> String:
	return _path


func backup_path() -> String:
	return _backup_path


func last_error() -> Error:
	return _last_error


## Devuelve una copia del valor guardado en `key`, o `fallback` si no existe o no se puede leer.
func load_value(key: String, fallback: Variant) -> Variant:
	if not _memory.has(key):
		return fallback
	var json: JSON = JSON.new()
	if json.parse(_memory[key]) != OK:
		return fallback
	return json.data


## Guarda `value` (cualquier cosa serializable a JSON) y lo baja a disco.
func save_value(key: String, value: Variant) -> void:
	_memory[key] = JSON.stringify(value, "", false, true)
	_flush()


func has_key(key: String) -> bool:
	return _memory.has(key)


## Borra todo lo del juego (memoria y archivo).
func clear_all() -> void:
	_memory.clear()
	_flush()


func _read_file() -> void:
	if not FileAccess.file_exists(_path):
		return
	var raw: String = FileAccess.get_file_as_string(_path)
	if raw == "" and FileAccess.get_open_error() != OK:
		_last_error = FileAccess.get_open_error()
		return
	var json: JSON = JSON.new()
	var ok: bool = json.parse(raw) == OK and json.data is Dictionary
	var data: Dictionary = {}
	if ok:
		var root: Dictionary = json.data
		ok = root.get("data") is Dictionary
		if ok:
			data = root["data"]
	if not ok:
		_backup_corrupt()
		return
	for k: Variant in data.keys():
		_memory[str(k)] = JSON.stringify(data[k], "", false, true)


func _backup_corrupt() -> void:
	var stamp: int = int(Time.get_unix_time_from_system())
	var base: String = _path.get_basename()
	var candidate: String = "%s.corrupt-%d.json" % [base, stamp]
	var n: int = 1
	while FileAccess.file_exists(candidate):
		candidate = "%s.corrupt-%d-%d.json" % [base, stamp, n]
		n += 1
	var err: Error = DirAccess.rename_absolute(_abs(_path), _abs(candidate))
	if err == OK:
		_backup_path = candidate
		push_warning("SaveStore: guardado corrupto, respaldo en %s; se arranca vacío." % candidate)
	else:
		_last_error = err
		push_warning("SaveStore: guardado corrupto y no se pudo respaldar (error %d); se arranca vacío." % err)


func _flush() -> void:
	if _path == "":
		return
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = _memory.keys()
	keys.sort()
	for k: Variant in keys:
		parts.append("%s:%s" % [JSON.stringify(k), _memory[k]])
	var text: String = "{\"version\":%d,\"data\":{%s}}" % [FORMAT_VERSION, ",".join(parts)]
	var tmp: String = _path + ".tmp"
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(_abs(_path.get_base_dir()))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		_last_error = dir_err
		return
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_last_error = FileAccess.get_open_error()
		return
	f.store_string(text)
	f.flush()
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		_last_error = write_err
		return
	var err: Error = DirAccess.rename_absolute(_abs(tmp), _abs(_path))
	if err != OK and FileAccess.file_exists(_path):
		# Algunas plataformas no pisan al renombrar: se borra el viejo y se reintenta.
		DirAccess.remove_absolute(_abs(_path))
		err = DirAccess.rename_absolute(_abs(tmp), _abs(_path))
	_last_error = err


static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)
