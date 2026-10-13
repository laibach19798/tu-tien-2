extends SceneTree
## Chiến sự Tiểu Thế Giới: dữ liệu, chiếm địa bàn, tập kích / giữ / mất, thu nhập, bá chủ, lưu - tải, nhiệm vụ.
## Chạy: godot --headless --path . --script res://tools/war_test.gd
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _alive_guards(tid: String) -> int:
	var n := 0
	for m in main.monsters:
		if m.alive and m.territory_id == tid and not m.invader:
			n += 1
	return n


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 6:
		return false
	var ok := true
	main.switch_map_now("overworld", Vector2(1280, 1100))
	# 1) dữ liệu
	var w := SectWar.new()
	ok = ok and SectWar.TERRITORIES.size() == 12 and SectWar.SECTS.size() == 5
	print("địa bàn ban đầu: ", {"ta": w.count("kiem_tong"), "xich": w.count("xich_viem"), "vô chủ": w.count("")})
	ok = ok and w.count("kiem_tong") == 2 and w.count("") == 2
	var ids := {}
	for t in SectWar.TERRITORIES:
		ids[t["id"]] = true
		ok = ok and (t["pos"] as Vector2).x < 4480.0 and (t["pos"] as Vector2).y < 3200.0
	ok = ok and ids.size() == 12
	# 2) chiếm đến bá chủ
	var won := [false]
	w.victory.connect(func(): won[0] = true)
	for t in SectWar.TERRITORIES:
		if w.count("kiem_tong") < SectWar.WIN_COUNT:
			w.claim(t["id"])
	print("giữ ", w.count("kiem_tong"), " địa bàn -> bá chủ: ", won[0])
	ok = ok and won[0] and w.won and not w.claim(SectWar.TERRITORIES[0]["id"])
	# 3) lưu / tải
	var w2 := SectWar.new()
	w2.from_dict(w.to_dict())
	ok = ok and w2.count("kiem_tong") == w.count("kiem_tong") and w2.won
	# 4) AI tự giao tranh: nhiều đợt thì thế cục phải đổi và nhật ký ghi lại
	var w3 := SectWar.new()
	w3.rng.seed = 7
	var before := w3.owners.duplicate()
	for i in 40:
		w3._ai_attack()
		for tid in w3.under_attack.keys():
			w3.under_attack[tid]["left"] = 0.0
		w3._process(0.0)
	var changed := 0
	for tid in w3.owners:
		if w3.owners[tid] != before[tid]:
			changed += 1
	print("sau 40 đợt giao tranh: ", changed, " địa bàn đổi chủ, nhật ký ", w3.log.size(), " dòng")
	ok = ok and changed > 0 and w3.log.size() > 0
	var tot := 0
	for sid in SectWar.SECTS:
		tot += w3.count(sid)
	tot += w3.count("")
	ok = ok and tot == 12
	# 5) trong game: vào Tiểu Thế Giới, chiếm một địa bàn của Xích Viêm
	main.war.reset()
	main.switch_map_now("tieu_gioi", Maps.DEFS["tieu_gioi"]["entry"])
	var tid := "t_hoa_tinh"
	var flag: TerritoryFlag = main.territory_nodes[tid]["flag"]
	print("địa bàn ", tid, ": chủ=", main.war.owner_of(tid), " lính canh=", _alive_guards(tid))
	ok = ok and main.war.owner_of(tid) == "xich_viem" and _alive_guards(tid) == 4
	main._use_flag(tid)   # còn lính canh -> không chiếm được
	ok = ok and main.war.owner_of(tid) == "xich_viem"
	for m in main.monsters:
		if m.territory_id == tid:
			m.take_hit(99999.0, main.player.position)
	var merit0: int = main.inv.merit
	main._use_flag(tid)
	print("sau khi hạ lính canh và cắm cờ: chủ=", main.war.owner_of(tid), " cống hiến +", main.inv.merit - merit0, " đệ tử Kiếm Tông canh: ", main.territory_nodes[tid]["allies"].size())
	ok = ok and main.war.owner_of(tid) == "kiem_tong" and main.inv.merit > merit0 and main.territory_nodes[tid]["allies"].size() == 2
	ok = ok and main.quests.war_owned == 3
	# 6) tập kích địa bàn của ta: quân xâm lược xuất hiện, hạ hết thì giữ được
	var mine := "t_linh_tuyen"
	main.war.under_attack[mine] = {"by": "doc_mon", "left": 100.0}
	main.war.attack_started.emit(mine)
	var inv_n := 0
	for m in main.monsters:
		if m.invader and m.alive and m.territory_id == mine:
			inv_n += 1
	print("quân xâm lược ở ", mine, ": ", inv_n)
	ok = ok and inv_n == 5
	for m in main.monsters.duplicate():
		if m.invader and m.alive and m.territory_id == mine:
			m.take_hit(99999.0, main.player.position)
	print("sau khi đánh lui: còn bị tập kích=", main.war.under_attack.has(mine), " chủ=", main.war.owner_of(mine))
	ok = ok and not main.war.under_attack.has(mine) and main.war.owner_of(mine) == "kiem_tong"
	# 7) không giữ được thì mất, và lính địch canh địa bàn
	main.war.under_attack[mine] = {"by": "doc_mon", "left": 0.5}
	main.war.attack_started.emit(mine)
	main.war._process(1.0)
	print("hết giờ phòng thủ: chủ=", main.war.owner_of(mine), " lính canh=", _alive_guards(mine))
	ok = ok and main.war.owner_of(mine) == "doc_mon" and _alive_guards(mine) >= 1
	# 8) thu nhập
	var stones0: int = main.inv.stones
	main.war._pay_income()
	print("thu nhập: linh thạch ", stones0, " -> ", main.inv.stones)
	ok = ok and main.inv.stones > stones0
	# 9) lưu game có chiến sự; tải lại khôi phục
	var data: Dictionary = main._collect_save()
	ok = ok and data.has("war") and data["war"]["owners"][tid] == "kiem_tong" and data["war"]["owners"][mine] == "doc_mon"
	main.switch_map_now("overworld", Vector2(1280, 1100))
	main.war.reset()
	main._apply_save(data, true)
	print("tải: chủ ", tid, "=", main.war.owner_of(tid), " ", mine, "=", main.war.owner_of(mine), " map=", main.current_map)
	ok = ok and main.war.owner_of(tid) == "kiem_tong" and main.war.owner_of(mine) == "doc_mon"
	# 10) mở bảng chiến sự
	main.war_ui.open_ui()
	ok = ok and main.war_ui.is_open()
	main.war_ui.close_ui()
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
	return true
