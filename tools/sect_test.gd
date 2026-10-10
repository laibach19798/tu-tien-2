extends SceneTree
## Kiem tra he thong cong hien Kiem Tong: NPC chap su, nhiem vu "since", chuc vi, tang bao cac, nop nguyen lieu, luu/tai.
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
	var inv: Inventory = main.inv
	var q: QuestLog = main.quests
	var ids := []
	for n in main.npcs:
		ids.append(n.npc_id)
	print("co sect_keeper: ", ids.has("sect_keeper"))
	# nhiem vu 'since': tien do tinh tu luc nhan
	q.states["q8"] = "done"
	q.sword_hits = 50
	print("q11 giver kha dung: ", q.available_for("sect_keeper").get("id", "-"))
	q.accept("q11")
	var q11: Dictionary = q._find("q11")
	print("q11 tien do sau khi nhan (ky vong 0/20): ", q.progress(q11))
	q.sword_hits += 20
	print("q11 sau 20 nhat (ky vong 20/20): ", q.progress(q11), " san sang: ", q.ready_for("sect_keeper").get("id", "-"))
	q.complete("q11")
	print("sau q11: cong hien=", inv.merit, " tong=", inv.merit_total, " chuc=", Sect.rank_name(inv.merit_total))
	# giet quai tinh cong hien
	main.switch_map_now("dam_lay", Maps.DEFS["dam_lay"]["entry"])
	for m in main.monsters:
		if m.kind_id == "goblin_elite":
			var before := inv.merit
			m.take_hit(99999.0, main.player.position)
			print("giet yeu tuong: cong hien ", before, " -> ", inv.merit)
			break
	# thang chuc
	var msgs: Array = []
	inv.message.connect(func(t): msgs.append(t))
	inv.add_merit(100)
	print("sau +100: chuc=", Sect.rank_name(inv.merit_total), " dan_tu_vi=", inv.count("dan_tu_vi"), " msg=", msgs)
	# cua hang
	main.sect_shop.open_shop()
	var hh0 := inv.count("dan_hoi_huyet")
	var m0 := inv.merit
	main.sect_shop._buy(Sect.SHOP[1])
	print("mua dan hoi huyet: ", hh0, " -> ", inv.count("dan_hoi_huyet"), "  cong hien ", m0, " -> ", inv.merit)
	var m1 := inv.merit
	main.sect_shop._buy(Sect.SHOP[9])   # tien_bao_tu_dien can chuc vi 3
	print("mua do can chuc vi 3 (phai tu choi): cong hien ", m1, " -> ", inv.merit)
	inv.add_merit(50)
	main.sect_shop._buy(Sect.SHOP[5])   # shoes_boot_gold, rank 1, 60
	print("mua giay vang: so huu=", main.wardrobe.is_owned("shoes_boot_gold"), " cong hien=", inv.merit)
	# nop nguyen lieu
	inv.add("yeu_dan", 2)
	var m2 := inv.merit
	main.sect_shop._give("yeu_dan", 2)
	print("nop 2 yeu dan: +", inv.merit - m2, " (ky vong 10), con yeu_dan=", inv.count("yeu_dan"))
	# luu / tai
	var d: Dictionary = main._collect_save()
	var tot := inv.merit_total
	inv.merit = 0
	inv.merit_total = 0
	q.base = {}
	main._apply_save(d, true)
	print("tai game: merit=", inv.merit, " tong=", inv.merit_total, " (truoc: ", tot, ") base q11=", q.base.get("q11", "-"))
	main.sect_shop.refresh()
	main.journal.open_ui("char")
	print("=== SECT TEST XONG ===")
	quit()
	return false
