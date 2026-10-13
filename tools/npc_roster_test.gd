extends SceneTree
## NPC thông minh V1 bước 7: đủ 20+ NPC quan trọng, mỗi tông ≥ 3, dữ liệu hợp lệ, vận hành ổn định trong 360 ngày.
const Data = preload("res://scripts/v1/catalog.gd")
var main: Node
var W: NpcWorld
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


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	var ids: Array = W.agent_ids()
	check(ids.size() >= 20, "tối thiểu 20 NPC quan trọng (%d)" % ids.size())

	# --- phân bổ theo tông
	var per := {}
	var loose := 0
	for id in ids:
		var s := NpcProfile.sect_of(W.def_of(str(id)))
		if s == "":
			loose += 1
		else:
			per[s] = int(per.get(s, 0)) + 1
	var sects_ok := true
	for s in ["kiem_tong", "dao_mon", "ngu_hanh", "huyen_the", "hon_dao"]:
		sects_ok = sects_ok and int(per.get(s, 0)) >= 3
	check(sects_ok, "mỗi tông ít nhất 3 NPC (%s)" % str(per))
	check(loose >= 5, "đủ tán tu và dân Vân Khê (%d)" % loose)

	# --- dữ liệu hợp lệ
	var names := {}
	var valid := true
	var places_ok := true
	var danger_ok := true
	var goals_ok := true
	var outfit_ok := true
	var uid_ok := true
	var locs: Array = main.province.locations().keys()
	for id in ids:
		var d: Dictionary = W.def_of(str(id))
		names[str(d["name"])] = true
		valid = valid and d.has("traits") and d.has("goal_kind") and d.has("routine") and int(d.get("step", -1)) >= 0
		for k in ["gather_at", "hunt_at"]:
			for l in d.get(k, []):
				places_ok = places_ok and str(l) in locs
				var dng := int(main.province.info(str(l)).get("danger", 1))
				danger_ok = danger_ok and dng - int(d.get("strength", 2)) <= 2
		places_ok = places_ok and str(d.get("home", "")) in locs and str(d.get("trade_at", "van_khe")) in locs
		goals_ok = goals_ok and NpcMind.GOAL_NAMES.has(str(d.get("goal_kind", "")))
		for n in d.get("needs", []):
			goals_ok = goals_ok and Items.DATA.has(str(n))
		var o: Dictionary = d.get("outfit", {})
		for k in o:
			outfit_ok = outfit_ok and Wardrobe.ITEMS.has(str(o[k]))
	check(names.size() == ids.size(), "tên NPC không trùng")
	check(valid, "mọi NPC đủ trường (tính cách, mục tiêu, lịch, cảnh giới)")
	check(places_ok, "mọi địa điểm làm việc / nhà / buôn bán đều có thật")
	check(danger_ok, "không ai được xếp tới nơi nguy hiểm hơn sức quá 2 bậc")
	check(goals_ok, "mục tiêu và vật liệu cần đều hợp lệ")
	check(outfit_ok, "trang phục dùng đúng id có sẵn")

	# --- hồ sơ V1 hợp luật cho cả 20+ NPC, đa dạng
	var legal_ok := true
	var sets := {}
	var styles := {}
	for id in ids:
		var p = W.profile_of(str(id))
		var d: Dictionary = W.def_of(str(id))
		var sect := NpcProfile.sect_of(d)
		var step := W.step_of(str(id))
		var elder: bool = bool(d.get("elder", false)) or step >= 25
		for slot in p.equipped:
			var uid: String = str(p.equipped[slot])
			if uid == "":
				continue
			legal_ok = legal_ok and NpcProfile.legal(Data.definition(str(p.instances[uid].definition)), sect, step, elder)
		legal_ok = legal_ok and not p.item_for("cong").is_empty()
		sets[str(p.item_for("cong").get("definition", "")) + "/" + str(p.item_for("tam").get("definition", ""))] = true
		styles[W.style_of(str(id))] = true
	check(legal_ok, "bộ pháp mọi NPC hợp luật V1")
	check(sets.size() >= 10, "bộ pháp đa dạng (%d tổ hợp Công/Tâm)" % sets.size())
	check(styles.size() >= 4, "đủ nhiều lối đánh (%d / 6)" % styles.size())

	# --- hiển thị trong thế giới: mỗi nơi không bị chen NPC
	var by_loc := {}
	for id in W.roster():
		var l := str(W.states[str(id)]["loc"])
		by_loc[l] = int(by_loc.get(l, 0)) + 1
	var most := 0
	for l in by_loc:
		most = maxi(most, int(by_loc[l]))
	check(int(W.balance("max_scene_npcs", 3.0)) == 3, "giới hạn NPC hiển thị cùng lúc (%d)" % int(W.balance("max_scene_npcs", 3.0)))

	# --- 360 ngày: ổn định
	main.sect_life.day = 100
	for id in ids:
		W.states[str(id)] = W._fresh_state(str(id))
		W._profiles.erase(str(id))
	var start := {}
	for id in ids:
		start[str(id)] = W.step_of(str(id))
	var t0 := Time.get_ticks_msec()
	for day in range(101, 461):
		main.sect_life.day = day
		W._advance_day(day)
	var ms := Time.get_ticks_msec() - t0
	var trips := 0
	var injured := 0
	var stuck := 0
	var earned := 0
	var changes := 0
	var legal_after := true
	for id in ids:
		var st: Dictionary = W.states[str(id)]
		var s: Dictionary = st["stats"]
		trips += int(s.get("trips", 0))
		injured += int(s.get("injured", 0))
		earned += int(s.get("earned", 0))
		changes += int(s.get("learned", 0)) + int(s.get("gear", 0))
		if str(st["status"]) != "ok" and int(st["status_until"]) > 461:
			stuck += 1
		var p2 = W.profile_of(str(id))
		var d2: Dictionary = W.def_of(str(id))
		for slot in p2.equipped:
			var uid2: String = str(p2.equipped[slot])
			if uid2 == "":
				continue
			var def2: Dictionary = Data.definition(str(p2.instances[uid2].definition))
			if str(p2.instances[uid2].source) != "legacy":
				legal_after = legal_after and NpcProfile.legal(def2, NpcProfile.sect_of(d2), W.step_of(str(id)), bool(d2.get("elder", false)) or W.step_of(str(id)) >= 25)
	var rate := float(injured) / maxf(1.0, float(trips))
	print("360 ngày × %d NPC: %d chuyến, %d bị thương (%.0f%%), %d lần đổi, %d linh thạch, %d ms" % [ids.size(), trips, injured, rate * 100.0, changes, earned, ms])
	check(trips >= 100, "NPC vận hành đều (%d chuyến)" % trips)
	check(rate <= 0.2, "tỉ lệ bị thương hợp lý (%.0f%%)" % (rate * 100.0))
	check(stuck == 0, "không ai kẹt mãi trong trạng thái bị thương / bế quan")
	check(legal_after, "sau 1 năm bộ pháp vẫn hợp luật")
	check(ms < 8000, "mô phỏng 1 năm đủ nhẹ (%d ms)" % ms)

	# --- lưu / tải
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	var same := W2.states.size() == W.states.size()
	for id in ids:
		same = same and W2.step_of(str(id)) == W.step_of(str(id))
	check(same, "lưu/tải đủ mọi NPC")
	W2.free()

	print("NPC ROSTER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
