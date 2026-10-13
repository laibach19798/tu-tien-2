extends SceneTree
## Di chuyển đại vực có thời gian: tìm tuyến (chính/tắt, nhãn, dấu hiệu), tuyến tắt phải được phát hiện, tốn ngày game,
## biến cố trên đường (chặn đường: trả tiền / thắng / thua quay về, gặp người, phát hiện), tới nơi, lưu/tải trạng thái tuyến.
var main: Node
var J: Journey
var P: World
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


func quiet() -> void:
	var tr: Dictionary = P._data["travel"]
	tr["incident_base"] = {"main": 0.0, "shortcut": 0.0}
	tr["incident_per_risk"] = {"main": 0.0, "shortcut": 0.0}


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	J = main.journey
	P = main.province

	for id in ["soi_linh", "hac_lam", "dam_lay", "tuyet_coc", "hang_linh_mach", "linh_mach_dong", "tieu_gioi"]:
		P.discover(id, "thử")
	main.player.position = Vector2(1280, 900)
	check(J.here() == "van_khe", "đang đứng ở Làng Vân Khê")
	check(J.blocked_reason() == "", "có thể xuất phát")

	# --- đích hợp lệ
	check(J.can_travel_to("soi_linh") and J.can_travel_to("van_khe"), "nơi đã phát hiện là đích hợp lệ")
	check(not J.can_travel_to("dp_vo_danh") and not J.can_travel_to("sect_xich_viem"), "động phủ và sơn môn đối địch không phải đích đi thẳng")
	P.discover("sect_kiem_tong", "thử")
	check(J.can_travel_to("sect_kiem_tong"), "tổng bộ Kiếm Tông của người chơi là đích hợp lệ")

	# --- tìm tuyến: đường tắt chưa biết thì chưa dùng được
	var before: Array = J.plan("kiem_tong_ngoai", "dam_lay")
	check(before.size() == 1 and int(before[0]["shortcuts"]) == 0 and str(before[0]["label"]) == "Đường an toàn", "chưa biết đường tắt: chỉ có tuyến chính vòng (%d ngày)" % int(before[0]["days"]))
	P.discover_route("kiem_tong_ngoai", "dam_lay", "thử")
	var after: Array = J.plan("kiem_tong_ngoai", "dam_lay")
	check(after.size() >= 2, "đã phát hiện đường tắt: có hai lựa chọn tuyến")
	var safe: Dictionary = after[0]
	var fast: Dictionary = after[after.size() - 1]
	check(int(fast["days"]) < int(safe["days"]) and int(fast["score"]) > int(safe["score"]), "đường tắt nhanh hơn nhưng rủi ro cao hơn (%d ngày / %d ngày)" % [int(fast["days"]), int(safe["days"])])
	check(int(fast["shortcuts"]) == 1 and not (fast["signs"] as Array).is_empty(), "đường tắt có dấu hiệu nguy hiểm báo trước")
	check(str(safe["label"]) == "Đường an toàn" and str(fast["label"]) == "Đường nhanh", "nhãn tuyến: an toàn / nhanh")
	var hac_tuyet: Array = J.plan("hac_lam", "tuyet_coc")
	P.discover_route("hac_lam", "tuyet_coc", "thử")
	hac_tuyet = J.plan("hac_lam", "tuyet_coc")
	check(hac_tuyet.size() == 2 and int(hac_tuyet[0]["days"]) == 3 and int(hac_tuyet[1]["days"]) == 1, "Hắc Lâm → Hắc Lang Cốc: 3 ngày an toàn hoặc 1 ngày liều (người chơi chọn)")

	# --- phát hiện đường tắt theo ngày và qua NPC
	P.routes_found.clear()
	check(P._reveal_shortcut(1.0), "mỗi ngày có cơ hội lộ một đường tắt giữa hai nơi đã phát hiện")
	check(P.routes_found.size() == 1, "đường tắt lộ ra được ghi nhớ")
	check(P.reveal_shortcut_from_npc("Lục Vân"), "NPC chỉ thêm một đường tắt khi hỏi thăm")
	check(P.routes_found.size() == 2, "hai đường tắt đã biết")

	# --- thực hiện chuyến đi (không biến cố)
	quiet()
	P.routes_found.clear()
	var day0: int = int(main.sect_life.day)
	var opts: Array = J.plan("van_khe", "soi_linh")
	check(opts.size() == 1 and int(opts[0]["days"]) == 1, "Làng → Sói Lĩnh một đường chính 1 ngày")
	check(J.begin(opts[0], "van_khe"), "bắt đầu chuyến đi")
	check(J.active and J.blocked_reason() != "", "đang đi thì không bắt đầu chuyến khác")
	main.dialogue.open = false
	J._run_day()
	check(int(main.sect_life.day) == day0 + 1, "một chặng 1 ngày tốn đúng 1 ngày game")
	check(not J.active, "tới nơi sau chặng cuối")
	main.dialogue.open = false
	J._finish_arrival("soi_linh", Vector2(300, 900))
	await process_frame
	await process_frame
	check(str(main.current_map) == "soi_linh" or main.traveling, "tới nơi: chuyển sang map đích")
	for i in 60:
		if not main.traveling:
			break
		await process_frame
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame

	# --- chuyến đi nhiều chặng tốn tổng số ngày
	var long_opts: Array = J.plan("van_khe", "hang_linh_mach")
	var main_opt: Dictionary = long_opts[0]
	check(int(main_opt["days"]) == 2 and int(main_opt["shortcuts"]) == 0 or int(main_opt["days"]) == 4, "Làng → Hang Linh Mạch: tuyến chính nhiều chặng (%d ngày)" % int(main_opt["days"]))
	var d1: int = int(main.sect_life.day)
	main.player.position = Vector2(1280, 900)
	J.begin(main_opt, "van_khe")
	main.dialogue.open = false
	var guard := 0
	while J.active and guard < 20:
		J._run_day()
		main.dialogue.open = false
		guard += 1
	check(int(main.sect_life.day) - d1 == int(main_opt["days"]), "tổng ngày trôi = tổng ngày các chặng (%d)" % int(main_opt["days"]))
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame
	check(P.state_of("hac_lam") == World.DISCOVERED, "đi qua nơi nào thì nơi đó đã phát hiện")

	# --- biến cố: chặn đường
	main.player.position = Vector2(1280, 900)
	var route: Dictionary = {"a": "van_khe", "b": "hac_lam", "kind": "main", "days": 2, "risk": 2, "note": "thử"}
	J._path = [{"from": "van_khe", "to": "hac_lam", "route": route}]
	J._leg = 0
	J._day_in_leg = 0
	J._start = "van_khe"
	J._dest = "hac_lam"
	J.active = true
	main.inv.add_stones(500)
	var s0: int = main.inv.stones
	J._ambush_pay(30)
	check(main.inv.stones == s0 - 30 and J.active, "trả tiền mua đường: mất 30 linh thạch, chuyến đi tiếp tục")
	main.dialogue.open = false
	# thua: quay lại, mất máu và tiền
	main.vitals.hp = main.vitals.max_hp
	var hp0: float = main.vitals.hp
	var s1: int = main.inv.stones
	J._path[0]["route"]["risk"] = 3
	# tìm hạt giống thua chắc chắn
	var lost_seed := -1
	main.cult.realm = 1
	main.cult.layer = 1
	for sd in 400:
		var rr := RandomNumberGenerator.new()
		rr.seed = sd
		if rr.randf() >= clampf(0.5 + 0.04 * float((main.cult.step_index() + 6) - ((5 + 3) * 4 + 4)), 0.1, 0.9):
			lost_seed = sd
			break
	J._ambush_fight(3, 5, lost_seed)
	check(not J.active and main.vitals.hp < hp0 and main.inv.stones < s1, "thua: bị đánh lui, mất khí huyết và linh thạch, huỷ chuyến đi")
	main.dialogue.open = false
	check(main.vitals.hp >= 1.0, "không bị đánh chết (khí huyết tối thiểu 1)")
	# thắng
	J.active = true
	var won_seed := -1
	main.cult.realm = 3
	main.cult.layer = 9
	for sd in 400:
		var r2 := RandomNumberGenerator.new()
		r2.seed = sd
		if r2.randf() < clampf(0.5 + 0.04 * float((main.cult.step_index() + 6) - ((1 + 1) * 4 + 4)), 0.1, 0.9):
			won_seed = sd
			break
	var yeu0: int = main.inv.count("da_yeu")
	J._ambush_fight(1, 1, won_seed)
	check(J.active and main.inv.count("da_yeu") > yeu0, "thắng: nhặt được đồ và đi tiếp")
	main.dialogue.open = false
	J.active = false

	# --- biến cố: phát hiện và gặp người
	J.active = true
	var rrf := RandomNumberGenerator.new()
	rrf.seed = 5
	var frag0: int = 0
	for k in main.destiny.fragments:
		frag0 += int(main.destiny.fragments[k])
	var inv0 := 0
	for it in ["linh_thao", "truc_linh", "thiet_tinh", "han_thuy_thach", "hoang_tho_tinh"]:
		inv0 += main.inv.count(it)
	J._incident_find({"opportunity": 0.1, "kind": "shortcut"}, rrf, false)
	var inv1 := 0
	for it in ["linh_thao", "truc_linh", "thiet_tinh", "han_thuy_thach", "hoang_tho_tinh"]:
		inv1 += main.inv.count(it)
	check(inv1 == inv0 + 1, "phát hiện trên đường: nhặt thêm một vật liệu")
	main.dialogue.open = false
	J._incident_wanderer({"kind": "main"}, rrf)
	check(main.dialogue.open, "gặp người đi đường: mở hội thoại để hỏi thăm")
	main.dialogue.open = false
	J.active = false

	# --- lưu / tải trạng thái tuyến
	P.routes_found.clear()
	P.discover_route("hac_lam", "tuyet_coc", "thử")
	var saved: Dictionary = P.to_dict()
	var w2 := World.new()
	w2._load_data()
	w2.from_dict(saved)
	check(w2.routes_found.has(w2.route_key("hac_lam", "tuyet_coc")), "lưu/tải giữ trạng thái phát hiện của từng tuyến")
	var w3 := World.new()
	w3._load_data()
	w3.from_dict({})
	check(w3.routes_found.is_empty(), "bản lưu cũ không có khóa: tải được, chưa lộ đường tắt nào")
	w2.free()
	w3.free()

	print("JOURNEY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
