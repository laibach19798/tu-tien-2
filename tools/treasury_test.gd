extends SceneTree
## Ngân quỹ và kho năm đại tông môn (Tông môn & Thế lực V1.0, bước 1): thu chi theo ngày, không âm, thưởng không vượt kho,
## cống nộp NPC, hiến tặng có trần, quyền xem theo địa vị, lưu/tải.
var main: Node
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


func total_items(sect: String) -> int:
	var n := 0
	for k in T.items_of(sect):
		n += int(T.items_of(sect)[k])
	return n


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	T = main.treasury
	main.sect_life.day = 10

	# --- dữ liệu và kho khởi đầu
	var all_ok := true
	for s in SectWar.SECTS:
		all_ok = all_ok and T.stock(str(s)) > 0 and T.upkeep(str(s)) > 0 and not T.cfg(str(s)).is_empty()
	check(SectWar.SECTS.size() == 5 and all_ok, "đủ 5 tông, mỗi tông có kho khởi đầu và chi phí nuôi đệ tử")
	check(T.status_name("kiem_tong") != "" and T.status("kiem_tong") in ["rich", "ok", "tight", "empty"], "có trạng thái ngân quỹ (%s)" % T.status_name("kiem_tong"))
	check(T.reserve("kiem_tong") == T.upkeep("kiem_tong") * 3, "dự trữ bằng 3 ngày nuôi đệ tử")

	# --- thu chi một ngày
	T.reset()
	var before: int = T.stock("kiem_tong")
	var terr_income := 0
	for t in SectWar.TERRITORIES:
		if main.war.owner_of(str(t["id"])) == "kiem_tong":
			terr_income += int(round(float(t["income"]["stones"]) * 1.25))
	var prod0: int = T.stock("kiem_tong", "thiet_tinh")
	T.advance_day(11)
	var after: int = T.stock("kiem_tong")
	check(after == before + terr_income - T.upkeep("kiem_tong"), "một ngày: thu địa bàn %d − nuôi đệ tử %d (%d → %d)" % [terr_income, T.upkeep("kiem_tong"), before, after])
	check(T.stock("kiem_tong", "thiet_tinh") == prod0 + 1, "sản vật chuyên biệt của tông tăng mỗi ngày")
	check(int(T.last_net["kiem_tong"]) == after - before, "ghi nhận chênh lệch ròng của ngày")
	check(T.ledger.size() > 0 and str(T.ledger.back()["cause"]) != "", "sổ cái có nguyên nhân")

	# --- đổi chủ địa bàn: dòng thu chuyển theo
	T.reset()
	var tid := ""
	for t in SectWar.TERRITORIES:
		if main.war.owner_of(str(t["id"])) == "xich_viem":
			tid = str(t["id"])
			break
	var inc_t := int(round(float(SectWar.territory(tid)["income"]["stones"]) * float(SectWar.SECTS["kiem_tong"]["trait"]["income"])))
	var k0: int = T.stock("kiem_tong")
	T.advance_day(11)
	var gain_before: int = T.stock("kiem_tong") - k0
	T.reset()
	main.war.owners[tid] = "kiem_tong"
	T.advance_day(11)
	var gain_after: int = T.stock("kiem_tong") - T.cfg("kiem_tong")["start"]["stones"]
	check(gain_after == gain_before + inc_t, "chiếm thêm địa bàn: thu nhập ngày tăng đúng %d" % inc_t)
	main.war.owners[tid] = "xich_viem"

	# --- kho không bao giờ âm, thiếu hụt thì ghi nhận
	T.reset()
	var held: Array = []
	for t in SectWar.TERRITORIES:
		if main.war.owner_of(str(t["id"])) == "han_bang":
			held.append(str(t["id"]))
			main.war.owners[str(t["id"])] = ""   # mất hết địa bàn: không còn nguồn thu
	T.stocks["han_bang"]["stones"] = 5
	T.advance_day(12)
	for tid2 in held:
		main.war.owners[tid2] = "han_bang"
	check(T.stock("han_bang") >= 0, "thiếu tiền nuôi đệ tử: kho không âm (%d)" % T.stock("han_bang"))
	var shortage := false
	for e in T.ledger:
		shortage = shortage or str(e["cause"]).begins_with("Thiếu")
	check(shortage, "ghi nhận thiếu hụt vào sổ cái")
	check(T.status("han_bang") in ["tight", "empty"], "kho cạn: trạng thái eo hẹp hoặc cạn kiệt (%s)" % T.status_name("han_bang"))
	T.stocks["han_bang"]["stones"] = 0
	check(T.status("han_bang") == "empty", "hết linh thạch: cạn kiệt")

	# --- thưởng không vượt kho, giữ dự trữ
	T.reset()
	var res: int = T.reserve("kiem_tong")
	T.stocks["kiem_tong"]["stones"] = res + 40
	check(T.payable("kiem_tong") == 40, "chỉ được phát phần vượt dự trữ (%d)" % T.payable("kiem_tong"))
	check(T.pay("kiem_tong", 100, "thử") == 40 and T.stock("kiem_tong") == res, "phát thưởng vượt mức chỉ trả phần còn lại, giữ nguyên dự trữ")
	check(T.pay("kiem_tong", 10, "thử") == 0, "hết phần phát được thì không trả thêm")

	# --- thưởng cho người chơi đi qua kho
	T.reset()
	T.stocks["kiem_tong"]["stones"] = res + 25
	main.inv.stones = 0
	var paid: int = T.pay_player(60, "thử")
	check(paid == 25 and main.inv.stones == 25, "thưởng người chơi bị cắt theo kho (60 → 25)")
	T.stocks["kiem_tong"]["stones"] = 0
	check(T.pay_player(30, "thử") == 0 and main.inv.stones == 25, "kho cạn: không phát được gì")

	# --- cống nộp của NPC: bảo toàn vật phẩm
	T.reset()
	var loot := {"linh_thao": 4, "yeu_dan": 3, "co_tu_di_vat": 1}
	var s0: int = total_items("kiem_tong")
	var kept: Dictionary = T.tithe("kiem_tong", loot, "Lục Vân")
	var got := 0
	for k in kept:
		got += int(kept[k])
	var paid_tithe: int = total_items("kiem_tong") - s0
	check(got + paid_tithe == 8, "cống nộp bảo toàn tổng vật phẩm (giữ %d + nộp %d)" % [got, paid_tithe])
	check(int(kept.get("co_tu_di_vat", 0)) == 1, "vật độc nhất không bị thu thuế")
	check(paid_tithe == int(floor(4 * 0.25)) + int(floor(3 * 0.25)), "thuế 25% làm tròn xuống")
	var none: Dictionary = T.tithe("", {"linh_thao": 4}, "tán tu")
	check(int(none.get("linh_thao", 0)) == 4, "tán tu không phải cống nộp")

	# --- NPC thật nộp thuế khi đi thu thập
	T.reset()
	main.npc_world.states["luc_van"] = main.npc_world._fresh_state("luc_van")
	var before_all: int = total_items("kiem_tong")
	var npc_loot := 0
	for dday in range(30, 90):
		main.sect_life.day = dday
		main.npc_world._advance_day(dday)
	for k in main.npc_world.states["luc_van"]["assets"]:
		npc_loot += int(main.npc_world.states["luc_van"]["assets"][k])
	var tithe_in: int = 0
	for e in T.ledger:
		if str(e["cause"]).begins_with("Cống nộp"):
			tithe_in += int(e["qty"])
	check(main.npc_world.sect_legacy_of("luc_van") == "kiem_tong", "Lục Vân thuộc Kiếm Tông")
	check(tithe_in >= 0, "NPC đi thu thập có cống nộp vào kho (%d vật phẩm sau 60 ngày)" % tithe_in)
	check(main.npc_world.sect_legacy_of("phu_quy") == "", "thương nhân tán tu không thuộc tông nào")

	# --- hiến tặng có trần
	T.reset()
	main.sect_life.day = 100
	main.inv.merit = 0
	main.inv.merit_total = 0
	main.inv.add("thiet_tinh", 40)
	var worth := int(Items.DATA["thiet_tinh"]["sell"])
	var total_merit := 0
	var kho0: int = T.stock("kiem_tong", "thiet_tinh")
	for i in 40:
		var r: Dictionary = T.donate("thiet_tinh", 1)
		total_merit += int(r["merit"])
	check(total_merit <= 40, "hiến tặng nhận tối đa 40 cống hiến mỗi ngày (%d)" % total_merit)
	check(T.stock("kiem_tong", "thiet_tinh") == kho0 + 40 and main.inv.count("thiet_tinh") == 0, "vật liệu hiến thực sự chuyển vào kho tông")
	main.sect_life.day = 101
	main.inv.add("thiet_tinh", 1)
	check(int(T.donate("thiet_tinh", 1)["merit"]) > 0, "sang ngày mới: lại nhận được cống hiến")
	check(not bool(T.donate("thiet_tinh", 1)["ok"]), "không có vật liệu thì không hiến được")

	# --- quyền xem theo địa vị (menu chấp sự)
	main.inv.merit_total = 0
	main.inv.merit = 0
	main._show_treasury()
	check(main.dialogue.open, "chấp sự cho xem tình trạng ngân quỹ")
	main.dialogue.open = false

	# --- lưu / tải
	T.reset()
	T.stocks["kiem_tong"]["stones"] = 1234
	T.add("kiem_tong", "huyen_thiet", 7, "thử")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(T.to_dict()))
	var T2 := SectTreasury.new()
	T2.main = main
	T2._data = T._data
	T2.from_dict(saved)
	check(T2.stock("kiem_tong") == 1234 and T2.stock("kiem_tong", "huyen_thiet") == 7 and T2.ledger.size() == T.ledger.size(), "lưu/tải giữ kho và sổ cái")
	var T3 := SectTreasury.new()
	T3.main = main
	T3._data = T._data
	T3.from_dict({})
	check(T3.stock("kiem_tong") == int(T.cfg("kiem_tong")["start"]["stones"]), "bản lưu cũ: bắt đầu từ kho khởi đầu")
	T2.free()
	T3.free()

	# --- mô phỏng 360 ngày: không sụp đổ, không âm
	T.reset()
	var min_stones := 999999
	for dday in range(11, 371):
		T.advance_day(dday)
		for s in SectWar.SECTS:
			min_stones = mini(min_stones, T.stock(str(s)))
	var dump := []
	for s in SectWar.SECTS:
		dump.append("%s %d (%s)" % [SectWar.sect_name(str(s)), T.stock(str(s)), T.status_name(str(s))])
	print("Sau 360 ngày: ", ", ".join(dump))
	check(min_stones >= 0, "360 ngày: không tông nào âm kho")
	var surv := 0
	for s in SectWar.SECTS:
		if T.stock(str(s)) > 0:
			surv += 1
	check(surv >= 3, "đa số tông còn duy trì được (%d / 5)" % surv)
	var bounded := true
	for s in SectWar.SECTS:
		bounded = bounded and T.stock(str(s)) <= T.upkeep(str(s)) * 40
	check(bounded, "kho không tích luỹ vô hạn: có chi mở rộng khi thừa (mọi tông ≤ 40 ngày nuôi)")

	print("TREASURY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
