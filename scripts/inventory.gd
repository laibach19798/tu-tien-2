extends Node
class_name Inventory
## Túi đồ + linh thạch (tiền tệ).

signal changed
signal message(text: String)

var stones := 0
var items: Dictionary = {}
var vitals: Vitals


func count(id: String) -> int:
	return int(items.get(id, 0))


func add(id: String, n := 1) -> void:
	items[id] = count(id) + n
	changed.emit()


func remove(id: String, n := 1) -> bool:
	var have := count(id)
	if have < n:
		return false
	if have == n:
		items.erase(id)
	else:
		items[id] = have - n
	changed.emit()
	return true


func add_stones(n: int) -> void:
	stones += n
	changed.emit()


func spend_stones(n: int) -> bool:
	if stones < n:
		return false
	stones -= n
	changed.emit()
	return true


func use(id: String, cult: Cultivation) -> bool:
	var d: Dictionary = Items.DATA.get(id, {})
	if d.is_empty() or not d.get("usable", false) or count(id) <= 0:
		return false
	remove(id)
	Sfx.play("heal")
	if d.get("xp", 0) > 0:
		cult.add_xp(float(d["xp"]))
	if d.get("qi", 0) > 0:
		cult.qi = minf(cult.qi_max(), cult.qi + float(d["qi"]))
		cult.changed.emit()
	if d.get("hp", 0) > 0 and vitals != null:
		vitals.heal(float(d["hp"]))
	message.emit("Đã dùng %s" % d["name"])
	return true


func to_dict() -> Dictionary:
	return {"stones": stones, "items": items}


func from_dict(d: Dictionary) -> void:
	stones = int(d.get("stones", 0))
	items = {}
	var src: Dictionary = d.get("items", {})
	for k in src:
		items[str(k)] = int(src[k])
	changed.emit()
