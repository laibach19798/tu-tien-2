extends SceneTree
## Nhiệm vụ tông môn sinh từ nhu cầu kho (Tông môn & Thế lực V1.0, bước 2).
var main: Node
var M: SectMissions
var T: SectTreasury
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


func fresh() -> void:
	M.missions.clear()
	M.kills.clear()
	M.next_id = 1
	T.reset()
	main.war.reset()
	main.events.events.clear()


func kinds_open(sect: String) -> Array:
	var out: Array = []
	for m in M.open_for(sect):
		out.append(str(m["kind"]))
	return out


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	M = main.missions
	T = main.treasury
	main.sect_life.day = 20
	main.player.position = Vector2(1300, 1500)
	var P := SectWar.PLAYER

	# --- thu thập: sinh khi kho thiếu vật liệu tông cần
	fresh()
	T.stocks[P]["linh_thao"] = 0
	M.generate(P, 20)
	var collect: Dictionary = {}
	for m in M.open_for(P):
		if str(m["kind"]) == "collect":
			collect = m
	check(not collect.is_empty() and str(collect["item"]) == "linh_thao", "kho thiếu linh thảo → sinh nhiệm vụ thu thập (%s)" % str(collect.get("text", "")))
	var n0 := M.missions.size()
	M.generate(P, 21)
	var collects := 0
	for m in M.missions:
		if str(m["kind"]) == "collect" and str(m["item"]) == "linh_thao":
			collects += 1
	check(M.missions.size() >= n0 and collects == 1, "không sinh trùng nhiệm vụ cho cùng một nhu cầu")
	fresh()
	for it in ["linh_thao", "thiet_tinh", "yeu_dan", "da_yeu", "soi_nanh", "han_thuy_thach", "hoang_tho_tinh", "xich_hoa_thach", "linh_mach_tinh"]:
		T.stocks[P][it] = 50
	M.generate(P, 21)
	check("collect" not in kinds_open(P), "kho đầy đủ: không sinh nhiệm vụ thu thập")

	# --- nhận, giao vật liệu, thưởng từ kho
	fresh()
	T.stocks[P]["linh_thao"] = 0
	T.stocks[P]["stones"] = T.reserve(P) + 500
	M.generate(P, 20)
	var mc := M.open_for(P)[0] as Dictionary
	check(M.accept(str(mc["id"])) and str(mc["status"]) == "taken" and str(mc["by"]) == "player", "nhận nhiệm vụ")
	main.inv.add("linh_thao", int(mc["qty"]))
	var merit0: int = main.inv.merit
	var stones0: int = main.inv.stones
	var kho0: int = T.stock(P, "linh_thao")
	var st0: int = T.stock(P)
	check(M.turn_in(str(mc["id"])), "giao đủ vật liệu")
	check(str(mc["status"]) == "done" and T.stock(P, "linh_thao") == kho0 + int(mc["qty"]), "vật liệu chuyển vào kho tông")
	check(main.inv.merit == merit0 + int(mc["merit"]), "nhận cống hiến (+%d)" % int(mc["merit"]))
	check(main.inv.stones == stones0 + int(mc["stones"]) and T.stock(P) == st0 - int(mc["stones"]), "linh thạch thưởng lấy từ ngân quỹ (%d)" % int(mc["stones"]))

	# --- thưởng bị cắt theo kho
	fresh()
	T.stocks[P]["linh_thao"] = 0
	M.generate(P, 20)
	var mp := M.open_for(P)[0] as Dictionary
	M.accept(str(mp["id"]))
	T.stocks[P]["stones"] = T.reserve(P) + 3
	main.inv.add("linh_thao", int(mp["qty"]))
	var s1: int = main.inv.stones
	M.turn_in(str(mp["id"]))
	check(main.inv.stones - s1 == 3, "kho eo hẹp: thưởng linh thạch bị cắt còn 3 (cống hiến vẫn nhận)")

	# --- NPC giải quyết trước
	fresh()
	T.stocks[P]["linh_thao"] = 0
	M.generate(P, 20)
	var ms := M.open_for(P)[0] as Dictionary
	M.accept(str(ms["id"]))
	T.add(P, "linh_thao", int(ms["qty"]) + 5, "NPC nộp")
	main.inv.add("linh_thao", int(ms["qty"]))
	var inv_before: int = main.inv.count("linh_thao")
	M.advance_day(22)
	check(str(ms["status"]) == "solved", "NPC đã nộp đủ: nhiệm vụ chuyển 'đã được giải quyết'")
	check(not M.turn_in(str(ms["id"])) and main.inv.count("linh_thao") == inv_before, "nhiệm vụ đã giải quyết: không còn thu vật liệu của người chơi")

	# --- trấn thủ khi địa bàn bị tấn công + tính hạ quái
	fresh()
	var tid := ""
	for t in SectWar.TERRITORIES:
		if main.war.owner_of(str(t["id"])) == P:
			tid = str(t["id"])
			break
	main.war.under_attack[tid] = {"by": "xich_viem", "left": 100.0}
	for it in ["linh_thao", "thiet_tinh", "yeu_dan"]:
		T.stocks[P][it] = 50
	M.generate(P, 23)
	var guard: Dictionary = {}
	for m in M.open_for(P):
		if str(m["kind"]) == "guard":
			guard = m
	check(not guard.is_empty() and str(guard["tid"]) == tid, "địa bàn bị tấn công → nhiệm vụ trấn thủ")
	M.accept(str(guard["id"]))
	var m0: int = main.inv.merit
	for i in int(guard["need"]):
		M.on_kill("goblin", "overworld")
	check(str(guard["status"]) == "done" and main.inv.merit == m0 + int(guard["merit"]), "hạ đủ kẻ xâm lấn: hoàn thành và nhận cống hiến")
	main.war.under_attack.erase(tid)

	# --- điều tra: dị tượng; tới nơi thì hoàn thành
	fresh()
	for it in ["linh_thao", "thiet_tinh", "yeu_dan"]:
		T.stocks[P][it] = 50
	for it in ["linh_thao", "thiet_tinh", "yeu_dan"]:
		T.stocks[P][it] = 14   # vừa đủ: không thiếu, không dư để hộ tống
	var ev: Dictionary = main.events.spawn("linh_mach_bien_dong", 20, "soi_linh")
	M.generate(P, 24)
	var inv_m: Dictionary = {}
	for m in M.open_for(P):
		if str(m["kind"]) == "investigate":
			inv_m = m
	check(not inv_m.is_empty() and str(inv_m["loc"]) == "soi_linh", "có sự kiện dị tượng → nhiệm vụ điều tra")
	M.accept(str(inv_m["id"]))
	M.check_arrivals()
	check(str(inv_m["status"]) == "taken", "chưa tới nơi: chưa hoàn thành")
	main.player.position = Vector2(300, 900)
	main.switch_map_now("soi_linh", Vector2(300, 900))
	await process_frame
	M.check_arrivals()
	check(str(inv_m["status"]) == "done", "tới nơi: hoàn thành")
	main.switch_map_now("overworld", Vector2(1300, 1500))
	await process_frame
	main.events.events.clear()

	# --- hộ tống: kho dư vật liệu → nhiệm vụ, bán hàng thành tiền cho kho
	fresh()
	T.stocks[P]["thiet_tinh"] = 40
	for it in ["linh_thao", "yeu_dan"]:
		T.stocks[P][it] = 50
	M.generate(P, 25)
	var esc: Dictionary = {}
	for m in M.open_for(P):
		if str(m["kind"]) == "escort":
			esc = m
	check(not esc.is_empty() and int(esc["cargo"]) == 40 - SectMissions.TARGET_STOCK, "kho dư thiết tinh → nhiệm vụ hộ tống đi bán (%d)" % int(esc.get("cargo", 0)))
	M.accept(str(esc["id"]))
	var kho_t: int = T.stock(P, "thiet_tinh")
	var kho_s: int = T.stock(P)
	main.player.position = Vector2(1280, 900)
	M.check_arrivals()
	check(str(esc["status"]) == "done" and T.stock(P, "thiet_tinh") == kho_t - int(esc["cargo"]), "hộ tống xong: bớt vật liệu dư khỏi kho")
	check(T.stock(P) > kho_s - int(esc["stones"]), "bán hàng đem lại linh thạch cho kho tông")

	# --- ngoại giao và truy bắt sinh định kỳ
	fresh()
	for it in ["linh_thao", "thiet_tinh", "yeu_dan"]:
		T.stocks[P][it] = 50
	for it in ["linh_thao", "thiet_tinh", "yeu_dan"]:
		T.stocks[P][it] = 14
	M.generate(P, 30)
	check("envoy" in kinds_open(P), "ngày 30: sinh nhiệm vụ ngoại giao (gửi thư tới tông khác)")
	M.generate(P, 36)
	check("hunt" in kinds_open(P), "ngày 36: sinh nhiệm vụ truy bắt tán tu")
	var hunt: Dictionary = {}
	for m in M.open_for(P):
		if str(m["kind"]) == "hunt":
			hunt = m
	M.accept(str(hunt["id"]))
	M.on_kill("wolf", "overworld")
	check(int(hunt["progress"]) == 0, "giết sai loại (sói) không tính cho truy bắt tán tu")
	M.on_kill("rogue_weak", "overworld")
	M.on_kill("rogue_master", "overworld")
	check(str(hunt["status"]) == "done", "hạ đủ 2 tán tu: hoàn thành")

	# --- giới hạn và quá hạn
	fresh()
	for it in ["linh_thao", "thiet_tinh", "yeu_dan", "da_yeu", "soi_nanh", "han_thuy_thach", "hoang_tho_tinh", "xich_hoa_thach", "linh_mach_tinh"]:
		T.stocks[P][it] = 0
	for d in range(20, 40):
		M.generate(P, d)
	check(M.open_for(P).size() <= SectMissions.MAX_OPEN_PER_SECT, "mỗi tông tối đa %d việc mở" % SectMissions.MAX_OPEN_PER_SECT)
	var some := M.open_for(P)[0] as Dictionary
	M.accept(str(some["id"]))
	var rep0: int = main.cultivation_v1.state.reputation
	main.cultivation_v1.state.reputation = 5
	M.advance_day(int(some["deadline"]) + 1)
	check(str(some["status"]) == "expired" and main.cultivation_v1.state.reputation == 4, "việc đã nhận mà quá hạn: hết hạn và mất 1 uy tín")
	main.cultivation_v1.state.reputation = rep0

	# --- người chơi không thể nhận việc của tông khác; giới hạn số việc đang làm
	fresh()
	for it in ["linh_thao"]:
		T.stocks["xich_viem"][it] = 0
	M.generate("xich_viem", 20)
	var foreign := M.open_for("xich_viem")
	check(not foreign.is_empty() and not M.accept(str(foreign[0]["id"])), "việc của tông khác: người chơi không nhận được")
	fresh()
	for i in 4:
		M._post(P, "hunt", "thử %d" % i, {"need": 1, "merit": 1, "stones": 0, "kinds": ["x"]})
	var taken := 0
	for m in M.open_for(P):
		if M.accept(str(m["id"])):
			taken += 1
	main.dialogue.open = false
	check(taken == SectMissions.MAX_TAKEN, "tối đa %d việc cùng lúc (%d)" % [SectMissions.MAX_TAKEN, taken])

	# --- NPC của tông tự giải quyết việc của tông mình
	fresh()
	T.stocks["han_bang"]["linh_thao"] = 50
	var npc_m: Dictionary = M._post("han_bang", "envoy", "thư", {"loc": "van_khe", "to": "kiem_tong", "merit": 5, "stones": 0})
	main.npc_world.states["tuyet_lan"]["loc"] = "van_khe"
	main.npc_world.states["tuyet_lan"]["status"] = "ok"
	M.advance_day(int(npc_m["posted"]) + 1)
	check(str(npc_m["status"]) == "solved", "NPC cùng tông (Tuyết Lan) đã tới nơi: việc được giải quyết")

	# --- lưu / tải
	fresh()
	T.stocks[P]["linh_thao"] = 0
	M.generate(P, 20)
	var mv := M.open_for(P)[0] as Dictionary
	M.accept(str(mv["id"]))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(M.to_dict()))
	var M2 := SectMissions.new()
	M2.main = main
	M2.from_dict(saved)
	check(M2.missions.size() == M.missions.size() and M2.next_id == M.next_id and M2.get_mission(str(mv["id"]))["status"] == "taken", "lưu/tải giữ nhiệm vụ và trạng thái")
	var M3 := SectMissions.new()
	M3.main = main
	M3.from_dict({})
	check(M3.missions.is_empty() and M3.next_id == 1, "bản lưu cũ: bắt đầu trống")
	M2.free()
	M3.free()

	# --- mô phỏng 90 ngày: số nhiệm vụ hợp lý, không trùng, kho không âm
	fresh()
	for d in range(21, 111):
		main.sect_life.day = d
		T.advance_day(d)
		M.advance_day(d)
	var posted := {}
	for m in M.missions:
		posted[str(m["sect"])] = int(posted.get(str(m["sect"]), 0)) + 1
	var by_kind := {}
	for m in M.missions:
		by_kind[str(m["kind"])] = int(by_kind.get(str(m["kind"]), 0)) + 1
	print("90 ngày: ", str(posted), " | ", str(by_kind))
	var ok_open := true
	for s in SectWar.SECTS:
		ok_open = ok_open and M.open_for(str(s)).size() <= SectMissions.MAX_OPEN_PER_SECT and T.stock(str(s)) >= 0
	check(ok_open, "90 ngày: mọi tông luôn ≤ %d việc mở, kho không âm" % SectMissions.MAX_OPEN_PER_SECT)
	check(M.missions.size() >= 10 and by_kind.size() >= 3, "có nhiều kiểu nhiệm vụ được sinh (%d việc, %d kiểu)" % [M.missions.size(), by_kind.size()])

	print("SECT MISSIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
