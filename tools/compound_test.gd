extends SceneTree
## Tông môn: cổng duy nhất trong Tiểu Thế Giới, chức năng các điện của Kiếm Tông, tông địch (tông chủ, đặc điểm riêng).
## Chạy: godot --headless --path . --script res://tools/compound_test.gd
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 6:
		return false
	var ok := true
	main.war.reset()
	main.switch_map_now("overworld", Vector2(1280, 1100))
	# 1) Tiểu Thế Giới: mỗi tông đúng MỘT cổng vào, ngoài ra chỉ có cổng về làng; không còn nhà cửa trong căn cứ
	main.switch_map_now("tieu_gioi", Maps.DEFS["tieu_gioi"]["entry"])
	var to_sect := {}
	for g in main.gates:
		if str(g["to"]).begins_with("sect_"):
			to_sect[g["to"]] = int(to_sect.get(g["to"], 0)) + 1
	print("cổng trong Tiểu Thế Giới: ", to_sect, " | tổng ", main.gates.size())
	ok = ok and to_sect.size() == 5 and main.gates.size() == 6
	for k in to_sect:
		ok = ok and to_sect[k] == 1
	for n in main.npcs:
		ok = ok and not (n.npc_id in ["sect_head", "sect_keeper", "tailor"])   # NPC tông môn đã chuyển vào map riêng
	# 2) đi vào từng tông bằng chính cổng đó rồi ra lại đúng chỗ
	for sid in SectWar.SECTS:
		var hq: Vector2 = SectWar.SECTS[sid]["hq"]
		main.switch_map_now("tieu_gioi", hq + Vector2(0, 140))
		var gate: Dictionary = {}
		for g in main.gates:
			if g["to"] == "sect_" + sid:
				gate = g
		ok = ok and not gate.is_empty() and (gate["pos"] as Vector2).distance_to(hq) < 2.0
		main.switch_map_now("sect_" + sid, gate["to_pos"])
		var back: Dictionary = main.gates[0]
		ok = ok and main.current_map == "sect_" + sid and str(back["to"]) == "tieu_gioi" and (back["to_pos"] as Vector2).distance_to(hq) < 200.0
	print("vào/ra 5 tông môn: ", "OK" if ok else "LỖI")
	# 3) mỗi điện của Kiếm Tông có mặt và đúng vị trí
	main.switch_map_now("sect_kiem_tong", Maps.COMPOUND_ENTRY)
	var names := []
	for hall in Maps.COMPOUND_HALLS:
		names.append(hall["name"])
		ok = ok and ResourceLoader.exists("res://assets/props/%s.png" % hall["prop"])
	print("các điện: ", names)
	ok = ok and names.size() == 9
	# 4) Tàng Kinh Các: trả linh thạch, nhận tu vi
	main.inv.stones = 5000
	var xp0: float = main.cult.xp
	var cost: int = main._scripture_cost()
	main._study_scripture()
	print("tham ngộ: tốn ", 5000 - main.inv.stones, " (dự kiến ", cost, "), tu vi ", xp0, " -> ", main.cult.xp)
	ok = ok and main.inv.stones == 5000 - cost and main.cult.xp > xp0
	main.inv.stones = 0
	main._study_scripture()
	ok = ok and main.inv.stones == 0
	# 5) Trận Pháp Đường: có lựa chọn truyền tống tới các địa bàn đang giữ
	var opts: Array = main._menu_options("array_master")
	var tp := 0
	for o in opts:
		if str(o["text"]).begins_with("Truyền tống tới"):
			tp += 1
	print("lựa chọn truyền tống: ", tp)
	ok = ok and tp == main.war.owned_by_player().size()
	main._teleport_territory("t_linh_tuyen")
	print("bắt đầu truyền tống: traveling=", main.traveling)
	ok = ok and main.traveling
	# 6) Chiến Sự Đường: trưởng lão có menu xem chiến sự; nhiệm vụ chiến sự do trưởng lão này giao
	var wo: Array = main._menu_options("war_elder")
	ok = ok and wo.size() >= 3
	var q16: Dictionary = main.quests._find("q16")
	ok = ok and q16["giver"] == "war_elder"
	# 7) Linh Tuyền Thiền Viện: thiền ở đó hồi khí huyết
	main.switch_map_now("sect_kiem_tong", Maps.COMPOUND_ENTRY)
	main.vitals.hp = 20.0
	main.player.position = Vector2(520, 800)
	main.meditating = true
	main._physics_process(1.0)
	print("thiền ở linh tuyền: khí huyết 20 -> ", main.vitals.hp)
	ok = ok and main.vitals.hp > 25.0
	main.meditating = false
	# 8) tông địch: có tông chủ; hạ tông chủ thì tông đó suy yếu và mình nhận thưởng
	main.switch_map_now("sect_xich_viem", Maps.COMPOUND_ENTRY)
	var master = null
	for m in main.monsters:
		if m.kind_id == "sect_master":
			master = m
	ok = ok and master != null and master.sect_id == "xich_viem"
	var p_before: float = main.war.power("xich_viem")
	var stones0: int = main.inv.stones
	master.take_hit(99999.0, main.player.position)
	var p_after: float = main.war.power("xich_viem")
	print("hạ tông chủ: lực ", p_before, " -> ", p_after, ", linh thạch +", main.inv.stones - stones0)
	ok = ok and p_after < p_before and main.inv.stones > stones0 and main.war.weakened.has("xich_viem")
	# 9) đặc điểm riêng của từng tông: dữ liệu đủ, và tông hay tập kích (Độc Môn) xuất quân nhiều hơn tông thủ (Hàn Băng)
	for sid in SectWar.SECTS:
		ok = ok and not SectWar.trait_of(sid).is_empty() and str(SectWar.trait_of(sid).get("name", "")) != ""
	var w := SectWar.new()
	w.rng.seed = 11
	var counts := {}
	w.message.connect(func(t: String):
		for sid in SectWar.SECTS:
			if t.begins_with(SectWar.sect_name(sid)):
				counts[sid] = int(counts.get(sid, 0)) + 1)
	for i in 300:
		w.reset()
		w._ai_attack()
		w.under_attack.clear()
	print("số lần xuất quân sau 300 đợt: ", counts)
	ok = ok and int(counts.get("doc_mon", 0)) > int(counts.get("han_bang", 0)) * 1.5
	# 10) thu nhập của Kiếm Tông có hệ số riêng
	var got := [0, 0]
	main.war.income.connect(func(mm: int, ss: int):
		got[0] = mm
		got[1] = ss)
	main.war.reset()
	main.war._pay_income()
	print("thu nhập 2 địa bàn ban đầu: cống hiến ", got[0], ", linh thạch ", got[1])
	ok = ok and got[0] == int(round(4 * 1.25)) and got[1] == int(round(45 * 1.25))
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
	return true
