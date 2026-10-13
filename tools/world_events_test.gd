extends SceneTree
## Sự kiện thế giới: vòng đời (dấu hiệu → diễn ra → giải quyết → hậu quả), 6 mẫu, giới hạn đồng thời, NPC tham gia, lưu/tải.
var main: Node
var ev: WorldEvents
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


func advance(n: int, with_npcs := true) -> void:
	for i in n:
		main.sect_life.day += 1
		ev._daily(int(main.sect_life.day))
		ev._last_day = int(main.sect_life.day)
		if with_npcs:
			main.npc_world._advance_day(int(main.sect_life.day))
		main.npc_world._last_day = int(main.sect_life.day)


## Đưa mọi NPC (trừ những ai nêu) về làng để chúng không can thiệp vào ca thử.
func park_npcs(except: Array = []) -> void:
	for id in main.npc_world.states:
		if not except.has(id):
			main.npc_world.states[id]["loc"] = "van_khe"
			main.npc_world.states[id]["status"] = "ok"
			main.npc_world.states[id]["act"] = "rest"
			main.npc_world.states[id]["until"] = int(main.sect_life.day) + 999


func reset_events() -> void:
	for e in ev.events.duplicate():
		ev.resolve(e, "ended", "test")
	ev.cooldown.clear()
	ev.history.clear()
	ev.traces.clear()


func state_of(e: Dictionary) -> String:
	return str(e.get("state", ""))


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	main.sect_life.day = 5
	ev = main.events
	ev._last_day = 5
	ev.next_spawn = 99999   # tự sinh bị khoá trong test; mỗi ca tự gọi spawn()

	# --- dữ liệu
	var tpl_ok := true
	for id in ev.templates():
		for z in ev.tpl(str(id)).get("zones", []):
			tpl_ok = tpl_ok and main.province.locations().has(str(z))
	check(ev.templates().size() == 6 and tpl_ok, "6 mẫu sự kiện, khu vực hợp lệ")

	# --- vòng đời chung (yêu thú tinh anh: sign 1 ngày, active 4 ngày)
	# NPC giờ tự quyết định có chạy theo sự kiện hay không: ca này cần "không ai xử lý", nên cho mọi NPC bế quan tạm thời
	var saved_status := {}
	for nid in main.npc_world.states:
		saved_status[nid] = [main.npc_world.states[nid]["status"], main.npc_world.states[nid]["status_until"]]
		main.npc_world.states[nid]["status"] = "seclusion"
		main.npc_world.states[nid]["status_until"] = 9999
	var e: Dictionary = ev.spawn("yeu_thu_tinh_anh", 5, "soi_linh")
	check(not e.is_empty() and state_of(e) == "sign" and str(e["id"]).begins_with("ev_"), "tạo lượt mới ở trạng thái dấu hiệu, có ID riêng")
	check(int(e["active_from"]) == 6 and int(e["deadline"]) == 10, "mốc thời gian: bắt đầu 6, hạn 10")
	check(main.province.log.size() >= 1, "dấu hiệu có tin tức")
	check(ev.danger_of("soi_linh", 1) == 1, "chưa diễn ra: nguy hiểm chưa tăng")
	advance(1)
	check(state_of(e) == "active" and ev.danger_of("soi_linh", 1) == 2, "sang pha diễn ra: nguy hiểm tuyến đường +1")
	advance(5)
	check(not ev.events.has(e) and str(e["outcome"]) == "retreated", "quá hạn không ai xử lý: yêu thú rút lui")
	for nid in saved_status:
		main.npc_world.states[nid]["status"] = saved_status[nid][0]
		main.npc_world.states[nid]["status_until"] = saved_status[nid][1]
	check(ev.history.size() == 1 and ev.traces_at("soi_linh").size() >= 1, "kết thúc để lại lịch sử và dấu vết")
	check(ev.danger_of("soi_linh", 1) == 1, "hậu quả: nguy hiểm trở lại bình thường")
	check(int(ev.cooldown.get("yeu_thu_tinh_anh", 0)) > int(main.sect_life.day), "mẫu có thời gian chờ trước khi lặp lại")

	# --- giới hạn đồng thời
	reset_events()
	ev.spawn("linh_thao_quy", int(main.sect_life.day), "soi_linh")
	ev.spawn("linh_mach_bien_dong", int(main.sect_life.day), "linh_mach_dong")
	var n_before := ev.events.size()
	ev._try_spawn(int(main.sect_life.day))
	check(ev.events.size() == n_before, "đang đủ 2 sự kiện thì không sinh thêm (%d)" % ev.events.size())
	reset_events()

	# --- 1. động phủ cổ tu: bỏ qua → NPC giành
	var dp_before: Dictionary = main.destiny.dp_state.duplicate(true)
	var e1: Dictionary = ev.spawn("co_tu_dong_phu", int(main.sect_life.day))
	check(not e1.is_empty() and main.province.state_of(str(e1["data"]["dp"])) != World.UNKNOWN, "động phủ cổ tu: dấu hiệu thành tin đồn về động phủ")
	var dp := str(e1["data"]["dp"])
	advance(1)
	check(state_of(e1) == "active" and int(main.destiny.fragments.get(dp, 0)) >= 3, "cửa động phủ mở trong hạn")
	var hunter_moved := false
	for id in e1["participants"]:
		hunter_moved = hunter_moved or str(main.npc_world.states[id]["loc"]) == str(e1["loc"])
	check(hunter_moved, "kẻ tầm bảo kéo tới khu vực")
	advance(3)
	check(str(e1["outcome"]) == "npc_took" and str(main.destiny.dp_state[dp]["state"]) == "destroyed", "người chơi chậm chân: NPC giành, động phủ mất")
	var uid: String = main.npc_world.legacy_uid(dp)
	check(main.npc_world.owner_of(uid).begins_with("npc:"), "truyền thừa chuyển sang NPC, động phủ không còn bản gốc")
	main.destiny.dp_state = dp_before
	main.destiny.fragments.clear()
	reset_events()
	# nhánh người chơi vào kịp
	var e1b: Dictionary = ev.spawn("co_tu_dong_phu", int(main.sect_life.day))
	var dp2 := str(e1b["data"]["dp"])
	advance(1)
	main.destiny.dp_state[dp2] = {"state": "open", "regen_day": 0}
	advance(1)
	check(str(e1b["outcome"]) == "player_entered", "người chơi vào kịp: sự kiện ghi nhận người chơi vào")
	main.destiny.dp_state = dp_before
	main.destiny.fragments.clear()
	reset_events()

	# --- 2. thương đội gặp nạn
	main.sect_life.day += 1
	var e2: Dictionary = ev.spawn("thuong_doi_nan", int(main.sect_life.day), "soi_linh")
	check(state_of(e2) == "active" and "phu_quy" in e2["participants"], "thương đội: diễn ra ngay, Phú Quý có mặt")
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	ev._sync_scene()
	var door: EncounterNode = null
	for n in main.npcs:
		if n is EncounterNode and n.enc_id == "wev_" + str(e2["id"]):
			door = n
	check(door != null, "thương đội xuất hiện trong scene để tương tác")
	ev._caravan_rescue(str(e2["id"]))
	var rt: Dictionary = ev._runtime[str(e2["id"])]
	check(bool(e2["data"]["started"]) and (rt["guards"] as Array).size() == 3, "ra tay cứu: 3 yêu thú ập tới")
	var stones0: int = main.inv.stones
	var rel0: int = int(main.npc_world.states["phu_quy"]["rel"])
	for g in (rt["guards"] as Array).duplicate():
		g.take_hit(999999.0, main.player.position)
	check(str(e2["outcome"]) == "rescued" and main.inv.stones > stones0 and int(main.npc_world.states["phu_quy"]["rel"]) > rel0, "hạ hết yêu thú: thương đội được cứu, có thưởng và quan hệ tăng")
	reset_events()
	# nhánh cướp
	var e2b: Dictionary = ev.spawn("thuong_doi_nan", int(main.sect_life.day), "soi_linh")
	var duyen0: float = main.destiny.duyen
	var rel1: int = int(main.npc_world.states["phu_quy"]["rel"])
	ev._caravan_loot(str(e2b["id"]))
	check(str(e2b["outcome"]) == "looted" and main.destiny.duyen < duyen0 and int(main.npc_world.states["phu_quy"]["rel"]) < rel1, "cướp thương đội: được hàng, duyên và quan hệ giảm")
	reset_events()
	# nhánh bỏ mặc
	var e2c: Dictionary = ev.spawn("thuong_doi_nan", int(main.sect_life.day), "soi_linh")
	main.npc_world.states["phu_quy"]["assets"] = {"soi_nanh": 3}
	park_npcs(["phu_quy"])
	advance(4, false)
	check(str(e2c["outcome"]) == "lost" and main.npc_world.states["phu_quy"]["assets"].is_empty() and str(main.npc_world.states["phu_quy"]["status"]) == "injured", "bỏ mặc: thương đội mất hàng, Phú Quý bị thương")
	reset_events()
	main.npc_world.states["phu_quy"]["status"] = "ok"
	# nhánh NPC cứu
	var e2d: Dictionary = ev.spawn("thuong_doi_nan", int(main.sect_life.day), "soi_linh")
	main.npc_world.states["ha_kiem"]["loc"] = "soi_linh"
	main.npc_world.states["ha_kiem"]["status"] = "ok"
	var tries := 0
	while ev.events.has(e2d) and tries < 3:
		main.npc_world.states["ha_kiem"]["loc"] = "soi_linh"
		advance(1)
		tries += 1
	check(str(e2d["outcome"]) in ["npc_rescued", "lost"], "NPC đủ mạnh có mặt có thể cứu hoặc hết hạn (%s)" % str(e2d["outcome"]))
	reset_events()

	# --- 3. linh thảo quý
	var e3: Dictionary = ev.spawn("linh_thao_quy", int(main.sect_life.day), "soi_linh")
	check(state_of(e3) == "sign", "linh thảo quý: có dấu hiệu trước")
	advance(1)
	var nid := str(e3["data"]["node_id"])
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	ev._sync_scene()
	var found := false
	for h in main.herbs:
		found = found or (is_instance_valid(h) and h.node_id == nid)
	check(found and main.resources.kinds().has("linh_thao_quy"), "linh thảo quý xuất hiện đúng ID khi diễn ra")
	var held: int = main.inv.count("ngan_nien_thao")
	for h in main.herbs:
		if is_instance_valid(h) and h.node_id == nid:
			main.resources.take(h, "player")
	ev._poll()
	check(str(e3["outcome"]) == "claimed" and str(e3["by"]) == "player", "người chơi hái: sự kiện giải quyết")
	reset_events()
	# nhánh NPC hái
	var e3b: Dictionary = ev.spawn("linh_thao_quy", int(main.sect_life.day), "soi_linh")
	advance(1)
	var nid2 := str(e3b["data"]["node_id"])
	var got: Dictionary = main.resources.npc_take(nid2, "ngo_thanh")
	check(not got.is_empty(), "NPC hái được linh thảo quý")
	ev._poll()
	check(str(e3b["outcome"]) == "claimed" and str(e3b["by"]).begins_with("npc:"), "NPC hái: ghi kết cục và người hái")
	reset_events()
	# nhánh héo
	var e3c: Dictionary = ev.spawn("linh_thao_quy", int(main.sect_life.day), "soi_linh")
	park_npcs()
	advance(6, false)
	check(str(e3c["outcome"]) == "withered" and main.resources.states[str(e3c["data"]["node_id"])]["gone"] == true, "không ai hái: linh thảo héo, mất hẳn")
	reset_events()

	# --- 4. yêu thú tinh anh trong scene
	var e4: Dictionary = ev.spawn("yeu_thu_tinh_anh", int(main.sect_life.day), "soi_linh")
	advance(1)
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	ev._sync_scene()
	var elite: Monster = null
	for m in main.monsters:
		if is_instance_valid(m) and m.has_meta("world_event"):
			elite = m
	check(elite != null and elite.elite, "yêu thú tinh anh xuất hiện trong map khi sự kiện diễn ra")
	var yd: int = main.inv.count("yeu_dan")
	elite.take_hit(9999999.0, main.player.position)
	check(str(e4["outcome"]) == "player_killed" and main.inv.count("yeu_dan") >= yd + 2, "người chơi hạ: sự kiện giải quyết, có vật liệu")
	reset_events()

	# --- 5. xung đột giữa đệ tử
	main.sect_life.day += 1
	var e5: Dictionary = ev.spawn("xung_dot_de_tu", int(main.sect_life.day), "van_khe")
	var a := str(e5["data"]["a"])
	var b := str(e5["data"]["b"])
	check(state_of(e5) == "active" and str(main.npc_world.states[a]["loc"]) == "van_khe" and str(main.npc_world.states[b]["loc"]) == "van_khe", "hai đệ tử khác phái gặp nhau ở làng")
	var ra: int = int(main.npc_world.states[a]["rel"])
	ev._dispute_mediate(str(e5["id"]))
	check(str(e5["outcome"]) == "mediated" and int(main.npc_world.states[a]["rel"]) == ra + 3, "hoà giải: quan hệ hai bên tăng")
	reset_events()
	var e5b: Dictionary = ev.spawn("xung_dot_de_tu", int(main.sect_life.day), "van_khe")
	var a2 := str(e5b["data"]["a"])
	var b2 := str(e5b["data"]["b"])
	ev._dispute_side(str(e5b["id"]), "side_a")
	check(str(e5b["outcome"]) == "side_a" and int(main.npc_world.states[a2]["rel"]) > int(main.npc_world.states[b2]["rel"]), "đứng về một phía: bên thắng quý mến, bên thua oán")
	reset_events()
	var e5c: Dictionary = ev.spawn("xung_dot_de_tu", int(main.sect_life.day), "van_khe")
	advance(3)
	var a3 := str(e5c["data"]["a"])
	check(str(e5c["outcome"]) == "fought" and str(main.npc_world.states[a3]["status"]) == "injured", "mặc kệ: hai bên đánh nhau trọng thương")
	reset_events()
	for id in main.npc_world.states:
		main.npc_world.states[id]["status"] = "ok"

	# --- 6. linh mạch biến động
	var e6: Dictionary = ev.spawn("linh_mach_bien_dong", int(main.sect_life.day), "linh_mach_dong")
	advance(1)
	var mod: int = ev.qi_mod("linh_mach_dong")
	check(state_of(e6) == "active" and mod != 0, "linh mạch biến động: linh khí lệch %+d" % mod)
	var expect_mult := 0.5 if mod > 0 else 2.0
	check(is_equal_approx(ev.regrow_mult("linh_mach_dong"), expect_mult), "điều kiện khai thác thay đổi: hệ số tái sinh %.1f" % expect_mult)
	var rumors_before: int = main.province.count(World.RUMOR)
	ev._surge_observe(str(e6["id"]))
	check(str(e6["outcome"]) == "observed" and main.province.count(World.RUMOR) > rumors_before, "quan sát: sinh manh mối (tin đồn mới)")
	check(is_equal_approx(ev.regrow_mult("linh_mach_dong"), 1.0), "kết thúc: điều kiện khai thác trở lại bình thường")
	reset_events()

	# --- lưu / tải giữa chừng
	var e7: Dictionary = ev.spawn("linh_thao_quy", int(main.sect_life.day), "soi_linh")
	ev.spawn("thuong_doi_nan", int(main.sect_life.day), "dam_lay")
	var saved: Dictionary = ev.to_dict()
	var ev2 := WorldEvents.new()
	ev2.main = main
	ev2._data = ev._data
	ev2.from_dict(saved)
	check(ev2.events.size() == 2 and ev2.next_id == ev.next_id and ev2.history.size() == ev.history.size(), "lưu/tải giữ các lượt đang diễn ra, ID và lịch sử")
	var same := true
	for i in ev.events.size():
		same = same and str(ev.events[i]["id"]) == str(ev2.events[i]["id"]) and str(ev.events[i]["state"]) == str(ev2.events[i]["state"])
	check(same, "trạng thái từng lượt giống nhau sau tải")
	var ev3 := WorldEvents.new()
	ev3.main = main
	ev3._data = ev._data
	ev3.from_dict({})
	check(ev3.events.is_empty() and ev3.next_id == 1, "bản lưu cũ không có khóa: tải được")
	ev2.free()
	ev3.free()
	reset_events()

	# --- tự sinh theo thời gian: tần suất, đa dạng, không quá 2 sự kiện đồng thời
	reset_events()
	ev.history.clear()
	ev.next_spawn = 0
	main.sect_life.day = 20
	ev._last_day = 20
	var max_seen := 0
	var kinds_seen := {}
	for i in 240:
		advance(1)
		max_seen = maxi(max_seen, ev.events.size())
		for e8 in ev.events:
			kinds_seen[str(e8["tpl"])] = true
		for h in ev.history:
			kinds_seen[str(h["tpl"])] = true
	var total := ev.history.size() + ev.events.size()
	print("240 ngày: %d sự kiện, %d mẫu khác nhau, đồng thời tối đa %d" % [total, kinds_seen.size(), max_seen])
	check(total >= 15 and total <= 70, "240 ngày game có %d sự kiện (khoảng 1 sự kiện mỗi 4–16 ngày)" % total)
	check(kinds_seen.size() >= 5, "đủ đa dạng: %d/6 mẫu xuất hiện" % kinds_seen.size())
	check(max_seen <= 2, "không bao giờ quá 2 sự kiện cùng lúc (cao nhất %d)" % max_seen)
	var bad := false
	for h in ev.history:
		bad = bad or str(h["outcome"]) == ""
	check(not bad, "mọi sự kiện đã kết thúc đều có kết cục")

	print("WORLD EVENTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
