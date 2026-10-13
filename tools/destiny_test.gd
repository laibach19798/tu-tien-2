extends SceneTree
## Cơ duyên và động phủ: dữ liệu, kỳ ngộ, duyên, mảnh bản đồ, cổng, rune/bẫy/truyền thừa/sụp đổ, tái tạo, lưu/tải.
const KNOWN_EFFECTS := ["item", "stones", "merit", "duyen", "flag", "xp_frac", "heal_frac", "damage_frac", "chance", "toast", "map_fragment",
	"book_fragment", "reroll_affix", "buff", "schedule", "bond", "spawn"]
var main: Node
var failures := 0
var checks := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)


func effects_ok(list: Array) -> bool:
	for e in list:
		if str(e.get("type", "")) not in KNOWN_EFFECTS:
			return false
		if e.has("effects") and not effects_ok(e["effects"]):
			return false
	return true


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var d: Destiny = main.destiny
	var enc: Dictionary = d.encounters()
	check(enc.size() >= 8 and enc.size() <= 10, "số loại kỳ ngộ ít và tinh (8–10 gồm cả loại hẹn trước)")
	var all_ok := true
	for id in enc:
		var e: Dictionary = enc[id]
		for c in e.get("choices", []):
			all_ok = all_ok and effects_ok(c.get("effects", []))
		if e.has("riddle"):
			all_ok = all_ok and effects_ok(e["riddle"]["right_effects"]) and effects_ok(e["riddle"]["wrong_effects"])
	check(all_ok, "mọi hiệu ứng trong dữ liệu đều thuộc bộ hiệu ứng đã hỗ trợ")
	check(d.dong_phu().has("dp_vo_danh") and Maps.exists("dp_vo_danh"), "động phủ Vô Danh có dữ liệu và bản đồ")
	check(Hell.DAYS_PER_YEAR * 10 == 1200, "lịch: 1 năm game = 120 ngày")

	# --- duyên: ẩn, giới hạn theo ngày
	d.duyen = 20.0
	d._duyen_today = 0.0
	d.add_duyen(25.0)
	check(is_equal_approx(d.duyen, 30.0), "duyên tăng tối đa 10 mỗi ngày game")
	d.add_duyen(-50.0)
	check(is_equal_approx(d.duyen, 0.0), "duyên giảm không bị giới hạn ngày và không âm")
	d.duyen = 20.0

	# --- kỳ ngộ: chọn lựa đổi duyên, nhận vật phẩm, nút biến mất
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	main.dialogue.open = false
	var node: EncounterNode = d._make_node("bone_sitter", enc["bone_sitter"], main.player.position + Vector2(150, 0), true)
	check(node != null and node in main.npcs, "kỳ ngộ xuất hiện trong danh sách tương tác")
	d.open(node)
	check(main.dialogue.open, "mở hộp thoại lựa chọn khi tương tác")
	main.dialogue.open = false
	var yeu: int = main.inv.count("yeu_dan")
	var loot: Dictionary = enc["bone_sitter"]["choices"][1]
	d._choose(node, loot)
	check(main.inv.count("yeu_dan") == yeu + 1 and is_equal_approx(d.duyen, 17.0), "lấy túi: nhận yêu đan và duyên −3")
	check(not (node in main.npcs), "kỳ ngộ biến mất sau khi chọn")
	main.dialogue.open = false

	# --- cần trả giá: thiếu đan thì không thực hiện được
	var beast: EncounterNode = d._make_node("hurt_beast", enc["hurt_beast"], main.player.position + Vector2(150, 0), true)
	main.inv.items.erase("dan_hoi_huyet")
	var d0 := d.duyen
	d._choose(beast, enc["hurt_beast"]["choices"][0])
	check(is_equal_approx(d.duyen, d0) and beast in main.npcs, "thiếu đan: không cứu được, kỳ ngộ vẫn còn")
	main.inv.add("dan_hoi_huyet", 1)
	d._duyen_today = 0.0
	d._choose(beast, enc["hurt_beast"]["choices"][0])
	check(main.inv.count("dan_hoi_huyet") == 0 and d.duyen > d0, "cứu hắc lang: tốn một đan, duyên tăng")
	main.dialogue.open = false

	# --- hẹn trả ơn
	var beggar: EncounterNode = d._make_node("beggar", enc["beggar"], main.player.position + Vector2(150, 0), true)
	var day: int = int(main.sect_life.day)
	main.inv.add_stones(1000)
	d._choose(beggar, enc["beggar"]["choices"][0])
	var sched := false
	for s in d.scheduled:
		sched = sched or (str(s["id"]) == "beggar_return" and int(s["day"]) == day + 3)
	check(sched, "cho nhiều: ba ngày sau lão ăn mày quay lại")
	d.scheduled.clear()
	main.dialogue.open = false

	# --- mảnh bản đồ → cổng động phủ
	d.fragments.clear()
	d.dp_state.clear()
	for i in 3:
		d._apply({"type": "map_fragment"}, node)
	check(int(d.fragments.get("dp_vo_danh", 0)) == 3, "ba mảnh bản đồ ghép đủ động phủ")
	var gate_found := false
	for n in main.npcs:
		gate_found = gate_found or (n is EncounterNode and n.enc_id == "dp_gate")
	check(gate_found, "đủ mảnh: cổng động phủ lộ ra ở Sói Lĩnh")

	# --- tông địch mở trước
	d._rival_takes("dp_vo_danh", int(main.sect_life.day))
	check(str(d.dp_state["dp_vo_danh"]["state"]) == "destroyed" and int(d.fragments["dp_vo_danh"]) == 0, "tông địch mở trước: động phủ mất")
	var regen_gap := int(d.dp_state["dp_vo_danh"]["regen_day"]) - int(main.sect_life.day)
	check(regen_gap >= 10 * Hell.DAYS_PER_YEAR and regen_gap <= 20 * Hell.DAYS_PER_YEAR, "tái tạo sau 10–20 năm game (%d ngày)" % regen_gap)

	# --- tái tạo khi đủ ngày
	d.dp_state["dp_vo_danh"]["regen_day"] = int(main.sect_life.day) + 2
	main.sect_life.day += 3
	d._on_new_days()
	check(str(d.dp_state["dp_vo_danh"]["state"]) == "sealed", "đến hạn: động phủ tái tạo")

	# --- vào động phủ: rune, bẫy, truyền thừa, sụp đổ
	d.dp_state["dp_vo_danh"] = {"state": "open", "regen_day": 0}
	d._run = {"id": "dp_vo_danh", "order": [], "progress": 0, "done": false, "trap_t": 0.0, "collapse": -1.0, "taken": false}
	var info: Dictionary = d.dong_phu()["dp_vo_danh"]
	main.switch_map_now("dp_vo_danh", Vector2(float(info["entry"][0]), float(info["entry"][1])))
	await process_frame
	await process_frame
	var ids: Array = []
	for n in main.npcs:
		if n is EncounterNode:
			ids.append(n.enc_id)
	check("dp_stele" in ids and "dp_legacy" in ids and "dp_rune_kiem" in ids and "dp_rune_hoa" in ids and "dp_rune_thuy" in ids, "động phủ có bia, 3 rune và di hài")
	var order: Array = d._run["order"]
	check(order.size() == 3, "thứ tự rune được sinh ngẫu nhiên")
	var wrong_first: String = "kiem" if str(order[0]) != "kiem" else "hoa"
	var any_node: EncounterNode = null
	for n in main.npcs:
		if n is EncounterNode:
			any_node = n
	main.vitals.invuln = 0.0
	d._press_rune(wrong_first, any_node)
	check(int(d._run["progress"]) == 0 and not bool(d._run["done"]), "bấm sai thứ tự: đặt lại tiến độ")
	for r in order:
		d._press_rune(str(r), any_node)
	check(bool(d._run["done"]), "bấm đúng thứ tự: mở cấm chế")
	# di hài: thiếu duyên chỉ nhận ít
	d.duyen = 5.0
	var books_before: int = main.cultivation_v1.state.instances.size()
	var potion: int = main.inv.count("dan_hoi_huyet")
	d._legacy("dp_vo_danh", "inherit")
	check(main.cultivation_v1.state.instances.size() == books_before and main.inv.count("dan_hoi_huyet") == potion + 1, "thiếu duyên: tiên nhân không truyền, chỉ cho một viên đan")
	check(str(d.dp_state["dp_vo_danh"]["state"]) == "destroyed" and float(d._run["collapse"]) > 0.0, "lấy truyền thừa: động phủ bắt đầu sụp đổ")
	# kế thừa đủ duyên
	d.dp_state["dp_vo_danh"] = {"state": "open", "regen_day": 0}
	d.duyen = 50.0
	d._run["taken"] = false
	d._legacy("dp_vo_danh", "inherit")
	var got_book := false
	for uid in main.cultivation_v1.state.instances:
		var it: Dictionary = main.cultivation_v1.state.instances[uid]
		got_book = got_book or (str(it["source"]) == "dong_phu" and bool(it["fragment"]))
	check(got_book, "đủ duyên: nhận tàn quyển nguồn động phủ")
	# chôn cất
	d.duyen = 30.0
	d._duyen_today = 0.0
	d._legacy("dp_vo_danh", "bury")
	check(d.has_flag("buried_immortal") and d.duyen > 30.0, "chôn cất: duyên tăng và có cờ nhân quả")
	# sụp đổ
	main.inv.items.clear()
	main.inv.add("linh_thao", 10)
	d._run["collapse"] = 0.5
	d._tick_dong_phu(1.0)
	check(d._run.is_empty() and main.inv.count("linh_thao") == 5, "sụp đổ: bị đẩy ra và mất một nửa một loại nguyên liệu")

	# --- bộ đệm hiệu ứng thời gian
	d.buffs["linh_vu"] = 5.0
	check(d.density_mult() == 2.0, "mưa linh khí nhân đôi mật độ")
	d.buffs["oan_khi"] = 5.0
	check(d.meditate_mult() < 1.0, "oán khí làm chậm hấp thụ")
	d.buffs.clear()

	# --- lưu / tải
	d.duyen = 42.0
	d.fragments["dp_vo_danh"] = 2
	d.flags["x"] = true
	var saved := d.to_dict()
	d.duyen = 0.0
	d.fragments.clear()
	d.flags.clear()
	d.from_dict(saved)
	check(is_equal_approx(d.duyen, 42.0) and int(d.fragments["dp_vo_danh"]) == 2 and d.has_flag("x"), "lưu/tải giữ duyên, mảnh bản đồ và cờ")
	d.from_dict({})
	check(is_equal_approx(d.duyen, 20.0), "bản lưu cũ không có khóa destiny vẫn tải được")

	# --- nhịp HIẾM: cơ duyên theo ngân sách khám phá, tối đa một cái mỗi lần ghé bản đồ
	d.duyen = 20.0
	var gaps: Array = []
	for i in 200:
		gaps.append(d._next_gap())
	var gmin: float = gaps.min()
	var gmax: float = gaps.max()
	check(gmin >= 3600.0 and gmax <= 9000.0 * 1.4 + 1.0, "khoảng cách tới cơ duyên kế tiếp 1–3,5 giờ khám phá (đo %.0f–%.0f giây)" % [gmin, gmax])
	d.duyen = 100.0
	var hi := d._next_gap()
	d.duyen = 0.0
	var gaps_lo: Array = []
	for i in 200:
		gaps_lo.append(d._next_gap())
	check(hi <= 9000.0 * 0.8 + 1.0 and gaps_lo.min() >= 3600.0 * 1.4 - 1.0, "duyên cao đến sớm hơn, duyên thấp muộn hơn")
	d.duyen = 20.0
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	d._on_map_changed()
	for n in d._nodes.duplicate():
		d._consume(n)
	d._spawned_in_visit = false
	d._explore_left = 2.0
	main.dialogue.open = false
	var spawned := 0
	for i in 20:
		d._tick_second()
		for n in d._nodes:
			if is_instance_valid(n) and not str(n.enc_id).begins_with("dp_"):
				spawned += 1
		break
	check(d._explore_left > 3000.0 or spawned > 0 or not d._eligible(), "hết ngân sách khám phá thì xếp lại khoảng cách mới")
	var live := 0
	for i in 5:
		d._explore_left = 0.5
		d._tick_second()
	for n in d._nodes:
		if is_instance_valid(n) and not str(n.enc_id).begins_with("dp_"):
			live += 1
	check(live <= 1, "mỗi lần ghé bản đồ tối đa một cơ duyên đang chờ")

	# --- nhật ký
	d.log.clear()
	d.flags.clear()
	d.scheduled.clear()
	d.fragments.clear()
	d.dp_state.clear()
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	var n2: EncounterNode = d._make_node("bone_sitter", enc["bone_sitter"], main.player.position + Vector2(150, 0), true)
	d._choose(n2, enc["bone_sitter"]["choices"][2])
	check(d.log.size() == 1 and str(d.log[0]["title"]) == "Di hài ngồi thiền" and str(d.log[0]["text"]).contains("Chôn cất"), "chọn lựa kỳ ngộ được ghi vào nhật ký")
	main.dialogue.open = false
	var dia: Dictionary = d.diary()
	check((dia["marks"] as Array).size() == 1 and (dia["places"] as Array).is_empty(), "dấu ấn nhân quả hiện ở nhật ký")
	d.fragments["dp_vo_danh"] = 2
	d.scheduled.append({"id": "beggar_return", "day": int(main.sect_life.day) + 3})
	dia = d.diary()
	check((dia["places"] as Array).size() == 1 and str(dia["places"][0]["line"]).contains("2/3"), "mảnh bản đồ hiện tiến độ trong nhật ký")
	check((dia["hunches"] as Array).size() == 1 and not str(dia["hunches"][0]).contains("ngày"), "linh cảm không tiết lộ ngày")
	check(Hell.date_text(1) == "Năm 1, ngày 1" and Hell.date_text(121) == "Năm 2, ngày 1", "định dạng ngày theo năm game")
	for i in 200:
		d.note("t", "x")
	check(d.log.size() == Destiny.LOG_LIMIT, "nhật ký có giới hạn độ dài")
	var saved_log := d.to_dict()
	d.log.clear()
	d.from_dict(saved_log)
	check(d.log.size() == Destiny.LOG_LIMIT, "nhật ký được lưu và tải lại")
	main.journal.open_ui("diary")
	await process_frame
	check(main.journal.is_open(), "mở được tab Nhật ký trong sổ tay")
	main.journal.close_ui()

	print("DESTINY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
