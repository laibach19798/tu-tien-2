extends SceneTree
const Origin = preload("res://scripts/v1/origin.gd")
const Data = preload("res://scripts/v1/catalog.gd")
var main: Node
var failures := 0
var count := 0

func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE","1")
	OS.set_environment("TUTIEN_FRESH_GAME","1")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)

func clean_equip(id: String) -> String:
	var state = main.cultivation_v1.state
	var uid: String = state.acquire(id,"test")
	state.instances[uid].affixes = []
	state.learn(uid)
	state.equip(uid)
	return uid

func near_npc(id: String) -> void:
	for npc in main.npcs:
		if npc.get("npc_id") == id:
			main.player.position = npc.position + Vector2(0,30)
			return

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var rt = main.cultivation_v1
	check(rt.active(),"runtime initialized in real main scene")
	check(not rt.state.origin.confirmed,"fresh game needs origin confirmation")
	rt.confirm_origin(Origin.sample(),"kiem_tong")
	check(rt.state.sect == "kiem_tong" and rt.state.instances.size() == 6,"creation equips exactly 3 books + 3 items")
	for uid in rt.state.instances:
		rt.state.instances[uid].affixes = []
	for element in rt.state.origin.roots:
		rt.state.origin.roots[element] = 20
	main.player.position = Vector2(1050,1190)
	main.cult.qi = main.cult.qi_max()
	var dummy = main.get_tree().get_nodes_in_group("targets").filter(func(t): return t is TrainingDummy)[1]
	var old_hp: float = dummy.hp
	rt.cast("cong")
	check(dummy.hp < old_hp,"J active technique damages actual training target")
	check(main.quests.sword_hits > 0,"legacy quest hit adapter still works")
	main.vitals.invuln = 0
	main.cult.qi = main.cult.qi_max()
	rt.cast("than")
	var hp: float = main.vitals.hp
	main.vitals.take(20,main.player.position + Vector2(0,20))
	check(main.vitals.hp == hp and rt.engine.has_status("player","discount"),"real incoming attack triggers perfect dodge before damage")
	rt.dash_left = 0
	rt.engine.cooldowns.than = 5
	Data.definition("kiem_wave").cost = 45   # ví dụ bắt buộc của tài liệu: 45 → 36 thực trả
	clean_equip("kiem_wave")
	rt.engine.cooldowns.cong = 0
	main.cult.qi = 100
	rt.cast("cong")
	check(is_equal_approx(main.cult.qi,64) and rt.engine.cooldowns.than == 5,"real cast: 45→36, pearl not triggered")
	rt.pending.clear()
	rt.engine.clear_transient()
	main.player.position = Vector2(1040,1150)
	main.direction = "east"
	main.blockers.append(Rect2(1058,1100,10,120))
	rt.cast("than")
	rt.move_dash(0.2)
	check(main.player.position.x < 1058,"dash cannot tunnel through collision at low FPS")
	main.blockers.pop_back()
	rt.dash_left = 0
	rt.engine.clear_transient()
	main.player.position = Vector2(1050,1190)
	main.cult.qi = main.cult.qi_max()
	clean_equip("nine_swords")
	rt.combat_left = 0
	rt.choose_primary("artifact")
	rt.cast()
	check(rt.summons.size() == 1,"artifact main input creates summon")
	var mana: float = main.cult.qi
	rt._process(0.05)
	check(main.cult.qi < mana,"summon pays actual upkeep")
	main.cult.qi = 0
	rt._process(1)
	check(rt.summons.is_empty(),"summon ends when unable to maintain")
	rt.combat_left = 0
	rt.choose_primary("cong")
	main.inv.add_stones(5000)
	main.player.position = Vector2(30,30)
	check(rt.access_reason(Data.definition("hon_heart"),"market") != "","cannot buy remotely")
	near_npc("merchant")
	var owned: int = rt.state.instances.size()
	rt.acquire_from("hon_heart","market")
	check(rt.state.instances.size() == owned + 1,"foreign book acquired through merchant")
	var foreign_uid: String = rt.state.instances.keys().back()
	check(rt.state.learn(foreign_uid) and rt.state.equip(foreign_uid),"foreign book learned and equipped in live game")
	near_npc("v1_librarian")
	main.inv.add_merit(400)
	check(rt.access_reason(Data.definition("kiem_wave"),"sect") != "","inner books respect existing exam gate")
	main.inv.pass_inner_exam()
	check(rt.access_reason(Data.definition("kiem_wave"),"sect") == "","inner exam unlocks library access")
	owned = rt.state.instances.size()
	rt.acquire_from("kiem_wave","sect")
	check(rt.state.instances.size() == owned + 1,"merit buys sect scripture")
	main.sect_life.bonds.thanh_dao = 20
	near_npc("thanh_dao")
	owned = rt.state.instances.size()
	rt.acquire_from("dao_blood","npc")
	rt.acquire_from("dao_blood","npc")
	check(rt.state.instances.size() == owned + 1,"NPC grants foreign book once")
	var fake := Monster.new()
	fake.kind_id = "wolf"
	main.current_map = "linh_mach_dong"
	owned = rt.state.instances.size()
	for i in int(Data.balance("ruin_kills")):
		rt.on_killed(fake)
	check(rt.state.instances.size() == owned + 1,"ruin produces repeatable fragment without random progression lock")
	main.current_map = "overworld"
	fake.free()
	var tip: String = rt.ui.tooltip(rt.state.item_for("cong"))
	check(tip.contains("Linh lực gốc") and tip.contains("thực tế") and tip.contains("Nguồn:") and tip.contains("Kiếm Ấn"),"T13 tooltip shows provenance, costs and effect conditions")
	for page in ["origin","loadout","books","gear","acquire","log"]:
		rt.ui.open_ui(page)
		await process_frame
		check(rt.ui.body.get_child_count() > 0,"UI page " + page)
	rt.ui.hide()
	var before: Dictionary = JSON.parse_string(JSON.stringify(rt.state.to_dict()))
	main.slot_paths = ["res://tools/v1_test_save.json"]
	OS.unset_environment("TUTIEN_NO_SAVE")
	check(main.save_to_slot(0,true),"disk save writes V1 schema")
	OS.set_environment("TUTIEN_NO_SAVE","1")
	check(main.load_from_slot(0),"disk save reloads")
	var after: Dictionary = JSON.parse_string(JSON.stringify(rt.state.to_dict()))
	check(JSON.stringify(before) == JSON.stringify(after),"disk load preserves every V1 instance and origin")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tools/v1_test_save.json"))
	check(Sect.RANKS.size() == 5,"five rank definitions")
	print("V1 INTEGRATION: %d checks, %d failures" % [count,failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
