extends Node
class_name Inventory
## Túi đồ + linh thạch (tiền tệ).

signal changed
signal message(text: String)

var stones := 0
var merit := 0         # điểm cống hiến Kiếm Tông (dùng để đổi đồ)
var merit_total := 0   # tổng đã nhận, quyết định chức vị
var inner_exam_passed := false
var items: Dictionary = {}
var vitals: Vitals
var use_check: Callable          # (id) -> bool: vật phẩm đặc biệt (bản đồ...) có dùng được lúc này không
var on_special: Callable         # (id) -> void: hiệu ứng đặc biệt, do main xử lý
var tolerance: Dictionary = {}   # kháng dược: id đan -> số lần dùng gần đây (giảm 1 mỗi ngày game)


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
	var old_rank := sect_rank()
	merit += n
	merit_total += n
	_reward_ranks(old_rank, sect_rank())
	changed.emit()


func sect_rank() -> int:
	return Sect.rank_of(merit_total) if inner_exam_passed else 0


func sect_rank_name() -> String:
	return str(Sect.RANKS[sect_rank()]["name"])


func pass_inner_exam() -> void:
	if inner_exam_passed:
		return
	var old_rank := sect_rank()
	inner_exam_passed = true
	_reward_ranks(old_rank, sect_rank())
	changed.emit()


func _reward_ranks(old_rank: int, new_rank: int) -> void:
	for r in range(old_rank + 1, new_rank + 1):
		var rk: Dictionary = Sect.RANKS[r]
		stones += int(rk["stones"])
		var its: Dictionary = rk["items"]
		for k in its:
			items[k] = count(k) + int(its[k])
		message.emit("Thăng chức: %s  (+%d linh thạch)" % [rk["name"], int(rk["stones"])])
		Sfx.play("levelup")


func spend_merit(n: int) -> bool:
	if merit < n:
		return false
	merit -= n
	changed.emit()
	return true


## Kháng dược hết dần theo thời gian: 1 lần dùng mỗi ngày game (360 giây).
func decay_tolerance(delta: float) -> void:
	for id in tolerance.keys():
		tolerance[id] = maxf(0.0, float(tolerance[id]) - delta / 360.0)
		if float(tolerance[id]) <= 0.0:
			tolerance.erase(id)


func use(id: String, cult: Cultivation) -> bool:
	var d: Dictionary = Items.DATA.get(id, {})
	if d.is_empty() or not d.get("usable", false) or count(id) <= 0:
		return false
	if d.has("special") and use_check.is_valid() and not bool(use_check.call(id)):
		return false
	remove(id)
	if d.has("special") and on_special.is_valid():
		on_special.call(id)
	Sfx.play("heal")
	var strength := 1.0 / (1.0 + float(tolerance.get(id, 0.0)))
	if d.get("xp_frac", 0) > 0:
		tolerance[id] = float(tolerance.get(id, 0.0)) + 1.0
		cult.add_xp(cult.xp_needed() * float(d["xp_frac"]) * strength)
		if strength < 0.999:
			message.emit("Kháng dược: %s chỉ phát huy %d%%." % [d["name"], roundi(strength * 100.0)])
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
	return {"stones": stones, "items": items, "merit": merit, "merit_total": merit_total, "inner_exam_passed": inner_exam_passed, "tolerance": tolerance}


func from_dict(d: Dictionary) -> void:
	stones = int(d.get("stones", 0))
	merit = int(d.get("merit", 0))
	merit_total = int(d.get("merit_total", 0))
	# Bản lưu cũ đã lên nội môn giữ nguyên quyền và không nhận lại thưởng.
	inner_exam_passed = bool(d.get("inner_exam_passed", merit_total >= 100))
	tolerance = (d.get("tolerance", {}) as Dictionary).duplicate()
	items = {}
	var src: Dictionary = d.get("items", {})
	for k in src:
		if Items.DATA.has(str(k)):   # bỏ vật phẩm của hệ cũ (sách nội công, bí kíp công pháp)
			items[str(k)] = int(src[k])
	changed.emit()
