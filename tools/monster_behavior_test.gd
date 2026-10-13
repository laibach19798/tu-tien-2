extends SceneTree
## Hành vi quái mới (docs/QUAI_VAT.md): hú gọi, lao thẳng, nổ, bắn, hỗ trợ, triệu hồi, trọng giáp, hút linh; tinh anh; đồ hiếm; cao nhân tán tu.
const KNOWN := ["howler", "charger", "bomber", "thrower", "support", "summoner", "armored", "drainer", "enrage"]
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


func spawn(kind: String, at: Vector2) -> Monster:
	var m := Monster.new()
	m.setup(main, kind, at)
	main.world.add_child(m)
	main.monsters.append(m)
	return m


func clear_monsters() -> void:
	for m in main.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	main.monsters.clear()


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.debug_peaceful = true

	# --- dữ liệu
	var data_ok := true
	for id in Monster.KINDS:
		var k: Dictionary = Monster.KINDS[id]
		for b in k.get("behaviors", []):
			data_ok = data_ok and str(b) in KNOWN
		if bool(k.get("humanoid", false)) and not k.has("outfits") and not ["sect_disciple", "sect_elder", "sect_master"].has(id):
			data_ok = false
	check(data_ok, "mọi hành vi trong dữ liệu quái đều được hỗ trợ")
	var groups_ok := true
	for id in Maps.DEFS:
		for g in (Maps.DEFS[id] as Dictionary).get("groups", []):
			groups_ok = groups_ok and Monster.KINDS.has(str(g[0]))
	check(groups_ok, "mọi nhóm quái trong bản đồ đều có định nghĩa")
	check(Monster.KINDS.size() >= 18, "đã mở rộng số loài (%d)" % Monster.KINDS.size())

	main.switch_map_now("dam_lay", Vector2(1200, 900))
	await process_frame
	clear_monsters()
	var p0: Vector2 = main.player.position
	main.vitals.invuln = 0.0

	# --- bầy hú gọi
	var w1 := spawn("wolf", p0 + Vector2(300, 0))
	var w2 := spawn("wolf", p0 + Vector2(380, 40))
	w2.state = "idle"
	MonsterBehaviors._call_pack(w1)
	check(w2.state == "chase", "sói hú: đồng bọn gần đó vào trạng thái đuổi")
	clear_monsters()

	# --- lao thẳng
	var c := spawn("wolf_charger", p0 + Vector2(220, 0))
	c.state = "chase"
	var to_p := p0 - c.position
	var handled := MonsterBehaviors.chase_hook(c, to_p, to_p.length(), 0.016)
	check(handled and c.state == "charge_tele", "cuồng lang gồng có dấu báo trước khi lao")
	c._timer = 0.0
	MonsterBehaviors.tick_state(c, 0.016, to_p, to_p.length())
	check(c.state == "charging", "hết gồng thì lao")
	var before := c.position
	MonsterBehaviors.tick_state(c, 0.1, to_p, to_p.length())
	check(c.position.distance_to(before) > 20.0, "đang lao thì di chuyển nhanh theo hướng đã khóa")
	main.blockers.append(Rect2(c.position.x - 200, c.position.y - 200, 400, 400))
	main.blockers.append(Rect2(c.position.x - 50, c.position.y - 50, 100, 100))
	c.position = c.position
	var blocked_before := c.position
	MonsterBehaviors.tick_state(c, 0.1, to_p, to_p.length())
	check(c.state == "stunned" or c.position.distance_to(blocked_before) < 5.0, "đâm vào vật cản thì choáng")
	main.blockers.pop_back()
	main.blockers.pop_back()
	clear_monsters()

	# --- nổ
	var b := spawn("goblin_bomber", p0 + Vector2(60, 0))
	b.state = "chase"
	var hp0: float = main.vitals.hp
	var d := (p0 - b.position).length()
	check(MonsterBehaviors.chase_hook(b, p0 - b.position, d, 0.016) and b.state == "fuse", "yêu quái nổ: tới gần thì châm ngòi")
	b._timer = 0.0
	MonsterBehaviors.tick_state(b, 0.016, p0 - b.position, d)
	check(not b.alive and main.vitals.hp < hp0, "nổ: tự chết và gây sát thương vùng")
	clear_monsters()
	main.vitals.hp = main.vitals.max_hp
	main.vitals.invuln = 0.0

	# --- xạ thủ
	var t := spawn("goblin_thrower", p0 + Vector2(240, 0))
	t.state = "chase"
	d = 240.0
	var fired_before: int = main.fx_layer.get_child_count()
	check(MonsterBehaviors.chase_hook(t, p0 - t.position, d, 0.016) and t.state == "cast", "xạ thủ gồng có dấu báo rồi mới bắn")
	t._timer = 0.0
	MonsterBehaviors.tick_state(t, 0.016, p0 - t.position, d)
	var shots := 0
	for n in main.fx_layer.get_children():
		if n is MonsterShot:
			shots += 1
	check(shots >= 1 and main.fx_layer.get_child_count() > fired_before, "bắn ra một viên đạn")
	clear_monsters()

	# --- hỗ trợ
	var alpha := spawn("wolf_alpha", p0 + Vector2(300, 0))
	var pup := spawn("wolf", p0 + Vector2(340, 20))
	MonsterBehaviors._buff_allies(alpha)
	check(pup._buff_until > MonsterBehaviors.now() and pup.dyn_speed() > 1.2 and pup.dmg_mult() > 1.2, "Lang tăng gầm: đồng bọn nhanh và mạnh hơn")
	clear_monsters()

	# --- triệu hồi + quái triệu hồi không có phần thưởng
	var sh := spawn("goblin_shaman", p0 + Vector2(260, 0))
	sh._bt["cast"] = "summon"
	MonsterBehaviors._summon(sh)
	var minions := 0
	var mon: Monster = null
	for m in main.monsters:
		if m.minion:
			minions += 1
			mon = m
	check(minions == 2, "pháp sư triệu hồi hai con")
	var stones: int = main.inv.stones
	var xp0: float = main.cult.xp
	mon.hp = 1.0
	mon.take_hit(500.0, p0)
	check(main.inv.stones == stones and is_equal_approx(main.cult.xp, xp0), "quái triệu hồi hạ xuống không cho thưởng")
	clear_monsters()

	# --- trọng giáp
	var sg := spawn("goblin_shield", p0 + Vector2(300, 0))
	check(is_equal_approx(MonsterBehaviors.incoming(sg, 100.0), 100.0 * MonsterBehaviors.ARMOR_MULT), "trọng giáp giảm sát thương nhận vào")
	main.cultivation_v1.engine.statuses[str(sg.get_instance_id())] = {"armor_break": {"stacks": 1, "remaining": 5.0, "tick": 1.0, "source": {}}}
	check(is_equal_approx(MonsterBehaviors.incoming(sg, 100.0), 100.0), "bị Phá Giáp thì nhận trọn sát thương")
	main.cultivation_v1.engine.statuses.clear()
	clear_monsters()

	# --- hút linh
	var wisp := spawn("soul_wisp", p0 + Vector2(40, 0))
	main.cult.qi = main.cult.qi_max()
	var q0: float = main.cult.qi
	wisp.hp = wisp.max_hp * 0.5
	MonsterBehaviors.on_strike_hit(wisp)
	check(main.cult.qi < q0 and wisp.hp > wisp.max_hp * 0.5, "du hồn hút linh lực và tự hồi")
	clear_monsters()

	# --- tinh anh
	var elites := 0
	var total := 300
	for i in total:
		var e := Monster.new()
		e.setup(main, "goblin", Vector2(500, 500))
		if e.elite:
			elites += 1
		e.free()
	var ratio := float(elites) / float(total)
	check(ratio > 0.02 and ratio < 0.18, "tinh anh ở khu tầng 7 chiếm ~8%% (đo %.1f%%)" % (ratio * 100.0))
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	var e2 := Monster.new()
	e2.setup(main, "goblin", Vector2(500, 500))
	check(not e2.elite, "khu tầng thấp không có tinh anh")
	e2.free()

	# --- đồ hiếm siêu hiếm
	main.switch_map_now("dam_lay", Vector2(1200, 900))
	await process_frame
	clear_monsters()
	var normal := spawn("goblin", p0 + Vector2(500, 0))
	normal.elite = false   # tầng ≥ 7 có ~8% sinh ra tinh anh: ép thường để phép đo tỉ lệ ổn định
	var master := spawn("rogue_master", p0 + Vector2(500, 200))
	main.rng.seed = 12345
	var base_inst: int = main.cultivation_v1.state.instances.size()
	for i in 3000:
		main._rare_drop(normal, 1.0)
	var normal_drops: int = main.cultivation_v1.state.instances.size() - base_inst
	check(normal_drops >= 1 and normal_drops <= 20, "quái thường: rơi tàn quyển siêu hiếm (%d / 3000)" % normal_drops)
	base_inst = main.cultivation_v1.state.instances.size()
	for i in 300:
		main._rare_drop(master, 1.0)
	var master_drops: int = main.cultivation_v1.state.instances.size() - base_inst
	check(master_drops > 40 and master_drops < 160, "cao nhân tán tu: rơi nhiều hơn rất nhiều (%d / 300)" % master_drops)
	var huyen := 0
	for uid in main.cultivation_v1.state.instances:
		if str(main.cultivation_v1.state.instances[uid]["source"]) == "loot" and str(main.cultivation_v1.state.instances[uid]["quality"]) == "huyen":
			huyen += 1
	check(huyen > 0 and huyen < master_drops, "phẩm Huyền chỉ là một phần nhỏ trong đồ rơi")
	clear_monsters()

	# --- cao nhân tán tu: hiếm
	var d_map: Dictionary = Maps.DEFS["dam_lay"]
	var spawned := 0
	for i in 600:
		var before_n: int = main.monsters.size()
		MapBuilder._maybe_master(main, d_map)
		if main.monsters.size() > before_n:
			spawned += 1
			clear_monsters()
	var mr := float(spawned) / 600.0
	check(mr > 0.01 and mr < 0.07, "cao nhân tán tu xuất hiện hiếm, ~3%% mỗi lần ghé (đo %.1f%%)" % (mr * 100.0))
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	var n_before: int = main.monsters.size()
	for i in 200:
		MapBuilder._maybe_master(main, Maps.DEFS["soi_linh"])
	check(main.monsters.size() == n_before, "khu đầu (tầng 2) không có cao nhân tán tu")

	print("MONSTER BEHAVIOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
