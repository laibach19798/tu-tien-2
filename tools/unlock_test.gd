extends SceneTree
## Mở khóa trang phục bằng nhiệm vụ: món có "unlock" không mua được, hoàn thành nhiệm vụ thì được cấp.
## Chạy: godot --headless --path . --script res://tools/unlock_test.gd

func _init() -> void:
	var ok := true
	var w := Wardrobe.new()
	var inv := Inventory.new()
	inv.stones = 10000
	# 1) món khóa không mua được dù đủ tiền
	var locked_id := "sword_flame"
	var bought := w.buy(locked_id, inv)
	print("mua món khóa (phải false): ", bought, " | linh thạch còn: ", inv.stones)
	ok = ok and not bought and inv.stones == 10000
	# 2) món không khóa vẫn mua được
	var free_id := "sword_jade"
	ok = ok and w.buy(free_id, inv) and w.is_owned(free_id)
	# 3) nhiệm vụ nào mở món nào
	var unlocked_q9 := Wardrobe.items_unlocked_by("q9")
	print("q9 mở: ", unlocked_q9)
	ok = ok and unlocked_q9.has("sword_flame") and unlocked_q9.has("head_crown_gold")
	# 4) cấp món
	ok = ok and w.grant("sword_flame") and w.is_owned("sword_flame") and not w.grant("sword_flame")
	# 5) mọi unlock trỏ tới nhiệm vụ có thật
	var qids := {}
	for q in QuestLog.QUESTS:
		qids[q["id"]] = true
	for id in Wardrobe.ITEMS:
		var u: Dictionary = Wardrobe.ITEMS[id].get("unlock", {})
		if not u.is_empty() and not qids.has(u.get("quest", "")):
			print("FAIL unlock trỏ nhiệm vụ không tồn tại: ", id)
			ok = false
	# 6) món rơi từ quái: không mua được, bảng rơi khớp với quái có thật, xác suất hợp lệ
	var wk := Wardrobe.items_dropped_by("wolf_king")
	print("sói chúa rơi: ", wk)
	ok = ok and wk.size() >= 1
	var w2 := Wardrobe.new()
	var inv2 := Inventory.new()
	inv2.stones = 99999
	ok = ok and not w2.buy("outfit_wolf_king", inv2) and inv2.stones == 99999
	var mobs := Monster.KINDS
	for id in Wardrobe.ITEMS:
		var dd: Dictionary = Wardrobe.ITEMS[id].get("drop", {})
		if dd.is_empty():
			continue
		if not mobs.has(dd.get("mob", "")):
			print("FAIL drop trỏ quái không tồn tại: ", id)
			ok = false
		var ch := float(dd.get("chance", -1.0))
		if ch <= 0.0 or ch > 1.0:
			print("FAIL xác suất rơi không hợp lệ: ", id)
			ok = false
		if Wardrobe.ITEMS[id].has("unlock"):
			print("FAIL vừa khóa nhiệm vụ vừa rơi từ quái: ", id)
			ok = false
	# ảnh áo Lang Vương có đủ để dựng
	var sf := SkinLibrary.build("clothes", "langvuong")
	ok = ok and sf != null and sf.has_animation("walk_east")
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
