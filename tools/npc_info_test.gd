extends SceneTree
## NPC thông minh V1 bước 5: ba mức hiểu biết (chưa biết / nghe đồn / bằng chứng), nhân chứng, lan truyền, báo lên tông, phân trần, cướp.
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


func reset_all() -> void:
	for id in W.agent_ids():
		W.states[str(id)] = W._fresh_state(str(id))
		W.states[str(id)]["status"] = "ok"
		W.states[str(id)]["loc"] = "far_" + str(id)   # mỗi người một nơi: không ai thấy ai
	W.deeds.clear()
	W.next_deed = 1
	main.cultivation_v1.state.wanted.clear()
	main.cultivation_v1.state.relations.clear()


func place(id: String, loc: String) -> void:
	W.states[id]["loc"] = loc


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	main.sect_life.day = 100

	# --- việc bí mật: không nhân chứng, nạn nhân không phải NPC
	reset_all()
	var d0: Dictionary = W.report_deed("theft", "sect:xich_viem", "soi_linh", "")
	var anyone := false
	for id in W.agent_ids():
		anyone = anyone or W.know_level(str(id), str(d0["id"])) > 0
	check(not anyone, "không nhân chứng, nạn nhân là cả tông: không ai biết")
	check(main.cultivation_v1.state.wanted.get("dao_mon", 0) == 0, "không bị bắt gặp: tông chưa ghi vào sổ truy nã")
	for dday in range(101, 130):
		W._spread_deeds(dday)
	anyone = false
	for id in W.agent_ids():
		anyone = anyone or W.know_level(str(id), str(d0["id"])) > 0
	check(not anyone, "việc bí mật không tự lan ra")

	# --- nhân chứng: người cùng chỗ biết chắc, người ở xa không biết
	reset_all()
	place("luc_van", "van_khe")
	place("phu_quy", "van_khe")
	place("ha_kiem", "soi_linh")
	var d1: Dictionary = W.report_deed("robbery", "ngo_thanh", "van_khe", "")
	check(W.know_level("ngo_thanh", str(d1["id"])) == 2, "nạn nhân biết chắc")
	check(W.know_level("luc_van", str(d1["id"])) == 2 and W.know_level("phu_quy", str(d1["id"])) == 2, "người chứng kiến có mặt tại chỗ biết chắc")
	check(W.know_level("ha_kiem", str(d1["id"])) == 0, "người ở nơi khác chưa biết")
	check(int(W.bond("luc_van").trust) < 0, "chứng kiến chuyện xấu: mất tín nhiệm với người chơi")

	# --- ảnh hưởng: nghe đồn nhẹ hơn có bằng chứng
	reset_all()
	W.record("luc_van", "known_wrong")
	W.record("ngo_thanh", "heard_wrong")
	check(int(W.bond("luc_van").trust) < int(W.bond("ngo_thanh").trust) and int(W.bond("luc_van").affinity) < int(W.bond("ngo_thanh").affinity), "nghe đồn nhẹ hơn có bằng chứng")

	# --- lan truyền: chỉ qua người cùng địa điểm, bằng chứng chỉ nguyên vẹn trong cùng tông
	reset_all()
	place("luc_van", "van_khe")     # Kiếm Tông (nhân chứng)
	place("ha_kiem", "van_khe")     # Kiếm Tông
	place("phu_quy", "van_khe")     # tán tu
	place("bach_tam", "xa")
	var d2: Dictionary = W.report_deed("robbery", "ngo_thanh", "van_khe", "")
	for id in ["luc_van", "ha_kiem", "phu_quy"]:
		W.states[id]["know"].erase(str(d2["id"]))   # chỉ để xem lan truyền: giả sử ba người chưa biết
	W._learn("luc_van", d2, 2, true)
	var d_found := {"ha_kiem": 0, "phu_quy": 0}
	for dday in range(101, 125):
		W._spread_deeds(dday)
	d_found["ha_kiem"] = W.know_level("ha_kiem", str(d2["id"]))
	d_found["phu_quy"] = W.know_level("phu_quy", str(d2["id"]))
	check(int(d_found["ha_kiem"]) == 2, "đồng môn cùng tông nghe báo cáo: có bằng chứng (mức 2)")
	check(int(d_found["phu_quy"]) == 1, "người ngoài tông chỉ nghe đồn (mức 1)")
	check(W.know_level("bach_tam", str(d2["id"])) == 0, "người ở nơi khác không biết")

	# --- báo lên tông: truy nã
	check(main.cultivation_v1.state.wanted.get("kiem_tong", 0) >= 1 and str(main.cultivation_v1.state.relations.get("kiem_tong", "")) == "hostile", "đệ tử có bằng chứng báo lên: tông ghi truy nã và coi là thù địch")
	var wanted_n: int = int(main.cultivation_v1.state.wanted.get("kiem_tong", 0))
	for dday in range(160, 170):
		W._spread_deeds(dday)
	check(int(main.cultivation_v1.state.wanted.get("kiem_tong", 0)) == wanted_n, "mỗi việc chỉ báo tông một lần")

	for dday in range(125, 160):
		W._spread_deeds(dday)
	# --- tin đồn phai, việc cũ bị quên
	check(W.know_level("phu_quy", str(d2["id"])) == 0 or W.deed_by_id(str(d2["id"])).is_empty(), "tin đồn phai sau một thời gian")
	for dday in range(170, 260):
		W._spread_deeds(dday)
	check(W.deed_by_id(str(d2["id"])).is_empty(), "việc quá cũ không còn được nhắc")

	# --- việc tốt cũng lan, hiệu ứng tích cực
	reset_all()
	place("luc_van", "van_khe")
	var aff0: int = int(W.bond("luc_van").affinity)
	var dg: Dictionary = W.report_deed("rescue", "tran_hoai", "van_khe", "")
	check(W.know_level("luc_van", str(dg["id"])) == 2 and int(W.bond("luc_van").affinity) > aff0, "việc tốt có nhân chứng: thiện cảm tăng")
	check(main.cultivation_v1.state.wanted.get("kiem_tong", 0) == 0, "việc tốt không gây truy nã")

	# --- tiếng xấu
	reset_all()
	var n0: float = W.notoriety()
	place("luc_van", "van_khe")
	place("phu_quy", "van_khe")
	W.report_deed("robbery", "ngo_thanh", "van_khe", "")
	check(W.notoriety() > n0, "tiếng xấu tăng khi nhiều người biết chuyện xấu")

	# --- phân trần
	reset_all()
	var dd: Dictionary = W.report_deed("robbery", "ngo_thanh", "xa", "")
	W._learn("luc_van", dd, 1, true)
	check(W.suspicion_of("luc_van") == 1, "nghe đồn: đang nghi ngờ")
	W.states["luc_van"]["rel"] = 80
	W.bond("luc_van")["trust"] = 80
	var cleared := false
	for dday in range(101, 140):
		main.sect_life.day = dday
		W._learn("luc_van", dd, 1, true) if W.know_level("luc_van", str(dd["id"])) == 0 else null
		W._explain("luc_van")
		main.dialogue.open = false
		if W.suspicion_of("luc_van") == 0:
			cleared = true
			break
	check(cleared, "tin tưởng cao: phân trần xoá được nghi ngờ")
	main.sect_life.day = 100

	# --- cướp hành trang
	reset_all()
	W.states["ngo_thanh"]["assets"] = {"linh_thao": 4, "yeu_dan": 2}
	W.states["ngo_thanh"]["step"] = 0
	main.cult.realm = 3
	main.cult.layer = 5
	place("ngo_thanh", "van_khe")
	place("luc_an", "van_khe")
	var inv0: int = main.inv.count("linh_thao") + main.inv.count("yeu_dan")
	var res := {"ok": false}
	for dday in range(100, 200):
		main.sect_life.day = dday
		W.states["ngo_thanh"]["assets"] = {"linh_thao": 4, "yeu_dan": 2}
		res = W.rob("ngo_thanh")
		main.dialogue.open = false
		if bool(res["ok"]):
			break
	check(bool(res["ok"]) and main.inv.count("linh_thao") + main.inv.count("yeu_dan") > inv0, "cướp thành công: hành trang chuyển sang người chơi")
	check(int(W.bond("ngo_thanh").hate) > 0 and int(W.bond("ngo_thanh").trust) < 0, "nạn nhân căm hận và mất tin")
	check(W.know_level("luc_an", str(W.deeds.back()["id"])) == 2, "người chứng kiến cướp có bằng chứng")
	var chance_low := 0.5 + float(0 - 40) * 0.06
	check(clampf(chance_low, 0.1, 0.9) == 0.1, "kẻ mạnh hơn nhiều: khả năng cướp thấp (đáy 10%)")

	# --- lưu / tải
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	check(W2.deeds.size() == W.deeds.size() and W2.next_deed == W.next_deed and W2.know_level("luc_an", str(W.deeds.back()["id"])) == 2, "lưu/tải giữ việc đã làm và hiểu biết của từng NPC")
	var old: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	old.erase("deeds")
	old.erase("next_deed")
	for id in old["states"]:
		(old["states"][id] as Dictionary).erase("know")
	var W3 := NpcWorld.new()
	W3.main = main
	W3._data = W._data
	W3.from_dict(old)
	check(W3.deeds.is_empty() and W3.suspicion_of("luc_van") == 0 and W3.notoriety() == 0.0, "bản lưu cũ: bắt đầu sạch")
	W2.free()
	W3.free()

	print("NPC INFO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
