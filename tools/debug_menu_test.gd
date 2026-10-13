extends SceneTree
## Menu thử nghiệm (F1): mọi nút mới dựng được và chạy không lỗi.
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

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var dm = main.debug_menu
	dm.open_menu()
	check(dm._grid_box.get_child_count() > 20, "menu dựng đủ các mục (%d)" % dm._grid_box.get_child_count())
	dm.close_menu()
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	var base: int = main.cultivation_v1.state.instances.size()
	dm._v1_all()
	check(main.cultivation_v1.state.instances.size() >= base + 30, "nhận mọi bí tịch (%d)" % main.cultivation_v1.state.instances.size())
	dm._v1_reset()
	check(float(main.cultivation_v1.engine.cooldowns.cong) == 0.0, "xoá hồi chiêu")
	var kinds: Array = dm._kind_buttons()
	check(kinds.size() == Monster.KINDS.size(), "có nút cho mọi loài quái (%d)" % kinds.size())
	var before: int = main.monsters.size()
	dm._spawn("wolf")
	dm._spawn("rogue_master")
	check(main.monsters.size() == before + 2, "tạo quái")
	dm._spawn_elite("goblin")
	var any_elite := false
	for m in main.monsters:
		if m.elite:
			any_elite = true
	check(any_elite, "tạo được tinh anh")
	dm._status_on_monsters()
	check(main.cultivation_v1.engine.statuses.size() > 0, "gắn trạng thái lên quái")
	dm._buffs_self()
	check(main.cultivation_v1.engine.has_status("player", "guard"), "gắn buff lên mình")
	var fx: Array = dm._fx_buttons()
	check(fx.size() >= 13, "có nút xem hiệu ứng cho mọi chiêu (%d)" % fx.size())
	for b in fx:
		(b[1] as Callable).call()
	await process_frame
	var sects: Array = dm._sect_buttons()
	check(sects.size() == SectWar.SECTS.size() * 3, "nút NPC tông môn (%d)" % sects.size())
	before = main.monsters.size()
	for b in sects:
		(b[1] as Callable).call()
	check(main.monsters.size() == before + sects.size(), "tạo NPC tông môn có chiêu")
	var npcs: Array = dm._npc_duel_buttons()
	check(npcs.size() == main.npc_world.agent_ids().size() and npcs.size() >= 20, "nút giao đấu thử cho mọi NPC có tên (%d)" % npcs.size())
	before = main.monsters.size()
	(npcs[0][1] as Callable).call()
	check(main.monsters.size() == before + 1 and main.npc_world._duels.size() == 1, "bấm nút NPC: dựng trận giao đấu")
	var duelist = main.npc_world._duels.values()[0]
	var rel0: int = int(main.npc_world.states[duelist.get_meta("npc_id")]["rel"])
	duelist.set_meta("npc_defense", {})   # tránh né ngẫu nhiên làm test chập chờn
	duelist.take_hit(duelist.max_hp * 5.0, main.player.position)
	check(main.npc_world._duels.is_empty() and int(main.npc_world.states[duelist.get_meta("npc_id")]["rel"]) == rel0 and str(main.npc_world.states[duelist.get_meta("npc_id")]["status"]) == "ok", "trận thử không để lại hậu quả cho NPC")
	var dest: Array = dm._destiny_buttons()
	check(dest.size() > 3, "nút cơ duyên (%d)" % dest.size())
	for b in dest:
		(b[1] as Callable).call()
	var dps: Array = dm._dong_phu_buttons()
	check(dps.size() >= 1, "nút động phủ (%d)" % dps.size())
	for b in dps:
		(b[1] as Callable).call()
	await process_frame
	print("DEBUG MENU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
