class_name Inventory
extends RefCounted
## Inventario persistente: boosters (consumibles) y cosméticos (permanentes, uno equipado por slot).
## Igual a `Inventory.ts`. "Nada equipado" se representa con "".

const KEY: String = "inventory"

var _store: SaveStore
var _items: Dictionary[String, int] = {}
var _equipped: Dictionary[String, String] = {Catalog.SLOT_HELMET: "", Catalog.SLOT_VEST: ""}


func _init(store: SaveStore) -> void:
	_store = store
	var d: Variant = store.load_value(KEY, {})
	if d is Dictionary:
		var dict: Dictionary = d
		var items: Variant = dict.get("items", {})
		if items is Dictionary:
			var items_dict: Dictionary = items
			for k: Variant in items_dict.keys():
				var q: int = int(items_dict[k])
				if q > 0:
					_items[str(k)] = q
		var eq: Variant = dict.get("equipped", {})
		if eq is Dictionary:
			var eq_dict: Dictionary = eq
			for slot: String in [Catalog.SLOT_HELMET, Catalog.SLOT_VEST]:
				var v: Variant = eq_dict.get(slot, "")
				_equipped[slot] = str(v) if v is String else ""


func count(product_id: String) -> int:
	return _items.get(product_id, 0)


func grant(product_id: String, qty: float) -> void:
	if is_nan(qty):
		return
	var q: int = floori(qty)
	if not (q > 0):
		return
	_items[product_id] = count(product_id) + q
	_persist()


func consume(product_id: String) -> bool:
	var c: int = count(product_id)
	if c <= 0:
		return false
	if c == 1:
		_items.erase(product_id)
	else:
		_items[product_id] = c - 1
	_persist()
	return true


## Cosmético equipado en el slot ("helmet" | "vest"), o "" si ninguno.
func equipped_cosmetic(slot: String) -> String:
	return _equipped.get(slot, "")


## Equipa un cosmético que se tenga (o "" para el default). Si no se tiene, no hace nada.
func equip(slot: String, product_id: String) -> void:
	if product_id != "" and count(product_id) <= 0:
		return
	_equipped[slot] = product_id
	_persist()


func _persist() -> void:
	var eq: Dictionary = {}
	for slot: String in _equipped.keys():
		var v: Variant = null
		if _equipped[slot] != "":
			v = _equipped[slot]
		eq[slot] = v
	_store.save_value(KEY, {"items": _items, "equipped": eq})
