extends Node
class_name Inventory
## Túi đồ + linh thạch (tiền tệ).

signal changed
signal message(text: String)

var stones := 0
var merit := 0         # điểm cống hiến Kiếm Tông (dùng để đổi đồ)
var merit_total := 0   # tổng đã nhận, quyết định chức vị
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


## Cộng điểm cống hiến; nếu đủ điểm lên chức thì thưởng ngay.
func add_merit(n: int) -> void:
	if n <= 0:
		return
	var old_rank := Sect.rank_of(merit_total)
	merit += n
	merit_total += n
	var new_rank := Sect.rank_of(merit_total)
	for r in range(old_rank + 1, new_rank + 1):
		var rk: Dictionary = Sect.RANKS[r]
		stones += int(rk["stones"])
		var its: Dictionary = rk["items"]
		for k in its:
			items[k] = count(k) + int(its[k])
		message.emit("Thăng chức: %s  (+%d linh thạch)" % [rk["name"], int(rk["stones"])])
		Sfx.play("levelup")
	changed.emit()


func spend_merit(n: int) -> bool:
	if merit < n:
		return false
	merit -= n
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
	return {"stones": stones, "items": items, "merit": merit, "merit_total": merit_total}


func from_dict(d: Dictionary) -> void:
	stones = int(d.get("stones", 0))
	merit = int(d.get("merit", 0))
	merit_total = int(d.get("merit_total", 0))
	items = {}
	var src: Dictionary = d.get("items", {})
	for k in src:
		items[str(k)] = int(src[k])
	changed.emit()
