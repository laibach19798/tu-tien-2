extends SceneTree
## Bộ sưu tập: dữ liệu bộ hợp lệ, danh hiệu theo bộ / theo mốc, lưu-tải, rơi đồ theo vùng (Hang Linh Mạch).
## Chạy: godot --headless --path . --script res://tools/collection_test.gd
var main: Node
var frame := 0
var _titles: Array = []


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 6:
		return false
	var ok := true
	# 1) dữ liệu: mọi món của bộ có thật, đúng ô, và khoá lẫn nhau hợp lý
	for sid in Wardrobe.SETS:
		var pieces: Dictionary = Wardrobe.SETS[sid]["pieces"]
		for slot in pieces:
			var id := str(pieces[slot])
			if not Wardrobe.ITEMS.has(id) or Wardrobe.ITEMS[id]["slot"] != slot:
				print("FAIL bộ ", sid, " món lỗi: ", slot, "=", id)
				ok = false
		var maxneed := 0
		for need in Wardrobe.SETS[sid]["bonus"]:
			maxneed = maxi(maxneed, int(need))
		if maxneed > pieces.size():
			print("FAIL bộ ", sid, " mốc thưởng vượt số món")
			ok = false
		if str(Wardrobe.SETS[sid].get("title", "")) == "":
			print("FAIL bộ ", sid, " thiếu danh hiệu")
			ok = false
	# mốc sưu tầm đạt được (không vượt tổng số món)
	for m in Wardrobe.MILESTONES:
		if int(m[0]) > Wardrobe.ITEMS.size():
			print("FAIL mốc ", m, " lớn hơn tổng số món ", Wardrobe.ITEMS.size())
			ok = false
	print("tổng số món: ", Wardrobe.ITEMS.size(), " | mốc: ", Wardrobe.MILESTONES)
	# 2) danh hiệu theo bộ: gom đủ bộ Lang Vương -> báo đúng một lần, tự đeo
	var w := Wardrobe.new()
	w.title_earned.connect(func(tname: String, _how: String): _titles.append(tname))
	var pieces: Dictionary = Wardrobe.SETS["lang_vuong"]["pieces"]
	var keys := pieces.keys()
	for i in keys.size():
		w.grant(str(pieces[keys[i]]))
		if i < keys.size() - 1 and w.earned_titles.has("set:lang_vuong"):
			print("FAIL đạt danh hiệu bộ khi chưa đủ món")
			ok = false
	print("danh hiệu đạt: ", _titles, " | đang đeo: ", Wardrobe.title_name(w.title))
	ok = ok and _titles.has("Thợ Săn Lang Vương") and w.title == "set:lang_vuong"
	var cnt_before := _titles.size()
	w.grant(str(pieces[keys[0]]))   # cấp trùng không báo lại
	ok = ok and _titles.size() == cnt_before
	# 3) đổi / bỏ danh hiệu; không đeo được danh hiệu chưa đạt
	w.set_title("set:dao_si")
	ok = ok and w.title == "set:lang_vuong"
	w.set_title("")
	ok = ok and w.title == ""
	w.set_title("set:lang_vuong")
	# 4) lưu - tải giữ nguyên; save cũ (không có titles) tính lại im lặng
	var w2 := Wardrobe.new()
	var n2 := _titles.size()
	w2.title_earned.connect(func(tname: String, _how: String): _titles.append(tname))
	w2.from_dict(w.to_dict())
	ok = ok and w2.title == "set:lang_vuong" and w2.earned_titles.has("set:lang_vuong")
	var old := {"owned": w.owned, "equipped": w.equipped}
	var w3 := Wardrobe.new()
	w3.title_earned.connect(func(tname: String, _how: String): _titles.append(tname))
	w3.from_dict(old)
	ok = ok and w3.earned_titles.has("set:lang_vuong") and _titles.size() == n2
	print("lưu-tải: ", w2.title, " | save cũ: ", w3.earned_titles, " | báo thừa: ", _titles.size() - n2)
	# 5) tiến độ và mô tả cách có
	var pr := Wardrobe.new().set_progress("linh_mach")
	print("tiến độ Linh Mạch: ", pr)
	ok = ok and int(pr["have"]) == 0 and int(pr["total"]) == 5 and (pr["missing"] as Array).size() == 5
	var txt := Wardrobe.acquire_text("sword_crystal")
	print("cách có kiếm tinh thạch: ", txt)
	ok = ok and txt.contains("Hang Linh Mạch") and txt.contains("6%")
	ok = ok and Wardrobe.acquire_text("outfit_lam") == ""
	# 6) rơi đồ theo vùng: trong hang có đồ Linh Mạch, ngoài hang thì không
	ok = ok and main.in_drop_region(WorldExpansion.CAVE + Vector2(100, 0), "cave") and not main.in_drop_region(Vector2(500, 800), "cave")
	var cave_ids: Array = []
	for slot in Wardrobe.SETS["linh_mach"]["pieces"]:
		cave_ids.append(str(Wardrobe.SETS["linh_mach"]["pieces"][slot]))
	var gob = null
	for m in main.monsters:
		if m.kind_id == "goblin_elite":
			gob = m
			break
	var in_cave := _count_cave_loot(gob, WorldExpansion.CAVE + Vector2(40, 40), cave_ids, 300)
	var outside := _count_cave_loot(gob, Vector2(1000, 900), cave_ids, 300)
	print("rơi trong hang: ", in_cave, " | ngoài hang: ", outside)
	ok = ok and in_cave > 0 and outside == 0
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
	return true


func _count_cave_loot(gob: Node, at: Vector2, ids: Array, kills: int) -> int:
	var before := _cave_loot(ids)
	gob.position = at
	for i in kills:
		main.on_monster_killed(gob)
	return _cave_loot(ids) - before


func _cave_loot(ids: Array) -> int:
	var n := 0
	for c in main.world.get_children():
		if c is Loot and ids.has(c.item):
			n += 1
	return n
