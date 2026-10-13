extends SceneTree
## Ba động phủ mới: Kiếm Trủng Chân Nhân (chín kiếm + tâm kính), Huyết Trì Cổ Phủ (khôi lỗi cự + hồ máu),
## Thiên Mạch Tiên Phủ (bản thân trong gương). Dữ liệu, bản đồ, thử thách, truyền thừa, mảnh bản đồ theo tầng tu vi.
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


func enter(d: Destiny, id: String) -> Dictionary:
	var info: Dictionary = d.dong_phu()[id]
	d.dp_state[id] = {"state": "open", "regen_day": 0}
	d._run = {"id": id, "order": [], "progress": 0, "done": false, "trap_t": 0.0, "collapse": -1.0, "taken": false}
	main.switch_map_now(str(info["map"]), Vector2(float(info["entry"][0]), float(info["entry"][1])))
	await process_frame
	await process_frame
	return info


func node_ids() -> Array:
	var ids: Array = []
	for n in main.npcs:
		if n is EncounterNode:
			ids.append(n.enc_id)
	return ids


func find_node(enc_id: String) -> EncounterNode:
	for n in main.npcs:
		if n is EncounterNode and n.enc_id == enc_id:
			return n
	return null


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var d: Destiny = main.destiny
	main.dialogue.open = false
	main.cultivation_v1.confirm_origin(preload("res://scripts/v1/origin.gd").sample(), "kiem_tong")

	# --- dữ liệu + bản đồ
	for id in ["dp_vo_danh", "dp_kiem_trung", "dp_huyet_tri", "dp_thien_mach"]:
		check(d.dong_phu().has(id) and Maps.exists(id) and bool(Maps.DEFS[id].get("dong_phu", false)), "%s có dữ liệu và bản đồ" % id)
	for kind in ["stone_golem", "stone_colossus", "blood_golem", "mirror_self"]:
		check(Monster.KINDS.has(kind), "quái %s đã định nghĩa" % kind)
	for book in ["bat_hoai_kim_than", "thien_mach_quyet", "kiem_guard"]:
		check(not CATALOG_DEF(book).is_empty(), "bí tịch %s có định nghĩa" % book)

	# --- mảnh bản đồ chỉ dẫn tới động phủ hợp tầng tu vi
	d.fragments.clear()
	d.dp_state.clear()
	main.cult.realm = 1
	main.cult.layer = 1
	for i in 12:
		d._apply({"type": "map_fragment"}, null)
	check(int(d.fragments.get("dp_vo_danh", 0)) == 3 and not d.fragments.has("dp_kiem_trung") and not d.fragments.has("dp_thien_mach"), "Luyện Khí tầng 1 chỉ nhận mảnh của Vô Danh Thạch Động")
	d.fragments.clear()
	d.dp_state.clear()
	main.cult.realm = 4
	main.cult.layer = 5   # Nguyên Anh tầng 5
	var seen := {}
	for i in 60:
		d.fragments.clear()
		d._apply({"type": "map_fragment"}, null)
		for k in d.fragments:
			seen[k] = true
	check(seen.has("dp_thien_mach") and seen.has("dp_huyet_tri") and seen.has("dp_kiem_trung"), "Nguyên Anh: mảnh bản đồ có thể dẫn tới cả ba động phủ mới")
	d.fragments.clear()
	d.dp_state.clear()
	main.cult.realm = 1
	main.cult.layer = 1

	# --- Kiếm Trủng: chín kiếm, tâm kính
	var info: Dictionary = await enter(d, "dp_kiem_trung")
	var ids := node_ids()
	var n_sword := 0
	for i in ids:
		if str(i).begins_with("dp_rune_"):
			n_sword += 1
	check(n_sword == 9 and "dp_stele" in ids and "dp_heart" in ids and "dp_legacy" in ids, "Kiếm Trủng: bia, 9 kiếm rune, tâm kính, di hài")
	var order: Array = d._run["order"]
	check(order.size() == 5, "thứ tự kiếm gồm 5 thanh")
	main.vitals.invuln = 0.0
	var any: EncounterNode = find_node("dp_stele")
	var wrong: String = "k1"
	for r in info["runes"]:
		if str(r["id"]) != str(order[0]):
			wrong = str(r["id"])
			break
	d._press_rune(wrong, any)
	check(int(d._run["progress"]) == 0, "kiếm sai thứ tự: đặt lại")
	for r in order:
		d._press_rune(str(r), any)
	check(bool(d._run["done"]), "đủ 5 kiếm đúng thứ tự: mở cấm chế")
	# thiếu duyên và chưa qua tâm kính: không được kế thừa
	d.duyen = 5.0
	var before: int = main.cultivation_v1.state.instances.size()
	d._legacy("dp_kiem_trung", "inherit")
	check(main.cultivation_v1.state.instances.size() == before, "thiếu duyên và chưa qua tâm kính: tiên nhân không truyền")
	# qua tâm kính thì được dù duyên thấp
	d.dp_state["dp_kiem_trung"] = {"state": "open", "regen_day": 0}
	d._run["taken"] = false
	d._run["collapse"] = -1.0
	d._run["heart"] = true
	d._legacy("dp_kiem_trung", "inherit")
	var got := false
	for uid in main.cultivation_v1.state.instances:
		var it: Dictionary = main.cultivation_v1.state.instances[uid]
		if str(it["definition"]) == "kiem_guard" and str(it["source"]) == "dong_phu":
			got = true
			check(str(it["quality"]) == "huyen", "Kiếm Ảnh Bộ nhận được ở phẩm Huyền")
	check(got, "qua tâm kính: nhận Kiếm Ảnh Bộ dù duyên thấp")
	# tâm kính: trả lời sai bị phản phệ mất tu vi, trả lời đúng cả ba thì qua
	d._run["heart"] = false
	var heart: EncounterNode = find_node("dp_heart")
	main.cult.xp = main.cult.xp_needed() * 0.5
	var xp0: float = main.cult.xp
	d._heart_answer(heart, 0, false)
	check(main.cult.xp < xp0, "trả lời sai: phản phệ mất tu vi")
	d._heart_answer(heart, 3, true)   # hết câu hỏi → qua
	check(bool(d._run["heart"]), "trả lời đủ: qua khảo nghiệm tâm")

	# --- Huyết Trì: khôi lỗi cự, hồ máu
	info = await enter(d, "dp_huyet_tri")
	ids = node_ids()
	check("dp_pool" in ids and "dp_legacy" in ids, "Huyết Trì: huyết trì và di hài")
	var guards: Array = d._run["guards"]
	var kinds: Array = []
	for g in guards:
		kinds.append(g.kind_id)
	check(guards.size() == 3 and "stone_colossus" in kinds and kinds.count("blood_golem") == 2, "1 cự khôi lỗi + 2 huyết khôi lỗi thủ hộ")
	var pc := Vector2(float(info["pool"]["pos"][0]), float(info["pool"]["pos"][1]))
	main.player.position = pc
	main.vitals.hp = main.vitals.max_hp * 0.5
	var hp0: float = main.vitals.hp
	d._tick_dong_phu(1.0)
	check(main.vitals.hp > hp0, "đứng trong huyết trì: hồi khí huyết")
	main.player.position = pc + Vector2(900, 0)
	var hp1: float = main.vitals.hp
	d._tick_dong_phu(1.0)
	check(is_equal_approx(main.vitals.hp, hp1), "ra khỏi huyết trì: không hồi")
	check(not bool(d._run["done"]), "khôi lỗi còn sống: truyền thừa chưa mở")
	for g in guards:
		g.take_hit(999999.0, main.player.position)
	d._tick_dong_phu(0.1)
	check(bool(d._run["done"]), "hạ hết thủ hộ: truyền thừa mở")
	d.duyen = 30.0
	d._legacy("dp_huyet_tri", "inherit")
	got = false
	for uid in main.cultivation_v1.state.instances:
		if str(main.cultivation_v1.state.instances[uid]["definition"]) == "bat_hoai_kim_than":
			got = true
	check(got, "nhận Bất Hoại Kim Thân Kinh (Trấn Phái)")

	# --- Thiên Mạch: bản thân trong gương
	d.dp_state.clear()
	info = await enter(d, "dp_thien_mach")
	ids = node_ids()
	check("dp_mirror" in ids and "dp_legacy" in ids, "Thiên Mạch: gương và pháp thân")
	var mirror: EncounterNode = find_node("dp_mirror")
	var st = main.cultivation_v1.state
	var cong_id := str(st.def_for("cong").get("id", ""))
	var mon_before: int = main.monsters.size()
	d._summon_mirror(mirror)
	check(main.monsters.size() == mon_before + 1, "soi gương: bản thân xuất hiện")
	var clone: Monster = d._run["clone"]
	check(clone != null and cong_id in (clone.get_meta("mirror_ids") as Array), "bản thân thuộc lòng chiêu Công đang trang bị")
	check(clone.get_meta("npc_skills").size() >= 1 and "skills" in clone.behaviors, "bản thân tung chiêu bằng hệ chiêu thức NPC")
	# chiêu thuộc lòng bị giảm sát thương
	var rt = main.cultivation_v1
	main.player.position = clone.position + Vector2(-60, 0)
	clone.hp = clone.max_hp
	rt._target_nodes[str(clone.get_instance_id())] = clone
	var ctx: Dictionary = rt.engine.context("cong", ["direct", "spell"])
	var hp_a: float = clone.hp
	rt._deal(clone, 100.0, ctx, false, false)
	var dealt_known: float = hp_a - clone.hp
	# chiêu lạ: đặt tạm một chiêu không có trong danh sách
	clone.set_meta("mirror_ids", ["__khong__"])
	clone.hp = clone.max_hp
	hp_a = clone.hp
	rt._deal(clone, 100.0, ctx, false, false)
	var dealt_other: float = hp_a - clone.hp
	check(dealt_known > 0.0 and dealt_other > dealt_known * 2.0, "chiêu thuộc lòng gây ít sát thương (%.0f so với %.0f)" % [dealt_known, dealt_other])
	check(not bool(d._run["done"]), "bản thân còn sống: truyền thừa chưa mở")
	clone.take_hit(9999999.0, main.player.position)
	d._tick_dong_phu(0.1)
	check(bool(d._run["done"]), "hạ bản thân: truyền thừa mở")
	var xp_before: float = main.cult.xp
	var step_before: int = main.cult.step_index()
	d.duyen = 50.0
	d._legacy("dp_thien_mach", "inherit")
	got = false
	for uid in st.instances:
		if str(st.instances[uid]["definition"]) == "thien_mach_quyet":
			got = true
	check(got, "nhận Thiên Mạch Chân Quyết")
	check(main.cult.xp > xp_before or main.cult.step_index() > step_before or main.cult.ready_breakthrough, "truyền thừa cho một phần tu vi (%.0f → %.0f)" % [xp_before, main.cult.xp])

	# --- cổng động phủ lộ ra ở đúng vùng khi đủ mảnh
	d.dp_state.clear()
	d.fragments.clear()
	d._run = {}
	for id in ["dp_kiem_trung", "dp_huyet_tri", "dp_thien_mach"]:
		var inf: Dictionary = d.dong_phu()[id]
		d.fragments[id] = int(inf["fragments"])
		var region := str(inf["region"])
		main.switch_map_now(region, Maps.DEFS[region]["entry"])
		await process_frame
		await process_frame
		d._spawn_gate_if_here()
		var gate := false
		for n in main.npcs:
			if n is EncounterNode and n.enc_id == "dp_gate" and str(n.data.get("dp", "")) == id:
				gate = true
		check(gate, "đủ mảnh: cổng %s lộ ra ở %s" % [id, Maps.map_name(region)])
		d.fragments.erase(id)

	print("DONG PHU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func CATALOG_DEF(id: String) -> Dictionary:
	return preload("res://scripts/v1/catalog.gd").definition(id)
