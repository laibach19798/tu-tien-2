extends SceneTree
## Hệ thống chiêu thức cho NPC (MonsterBehaviors: SECT_SKILLS / ROGUE_*): gán chiêu theo vai, gồng có dấu báo, hồi chiêu, sát thương theo hình dạng.
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


func spawn(kind: String, at: Vector2, sect := "") -> Monster:
	var m := Monster.new()
	m.sect_id = sect
	m.setup(main, kind, at)
	main.world.add_child(m)
	main.monsters.append(m)
	return m


func clear_monsters() -> void:
	for m in main.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	main.monsters.clear()


func skill_ids(m: Monster) -> Array:
	var out: Array = []
	for d in (m.get_meta("npc_skills", []) as Array):
		out.append(str(d["id"]))
	return out


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.debug_peaceful = true
	main.switch_map_now("dam_lay", Vector2(1200, 900))
	await process_frame
	clear_monsters()
	var p0: Vector2 = main.player.position
	main.vitals.invuln = 0.0

	# --- gán chiêu theo vai
	var dis := spawn("sect_disciple", p0 + Vector2(900, 0), "kiem_tong")
	var eld := spawn("sect_elder", p0 + Vector2(900, 100), "kiem_tong")
	var mas := spawn("sect_master", p0 + Vector2(900, 200), "huyen_minh")
	check(skill_ids(dis) == ["kiem_cut"], "đệ tử Kiếm Tông chỉ biết chiêu cơ bản (%s)" % str(skill_ids(dis)))
	check(skill_ids(eld).size() == 2 and "kiem_wave" in skill_ids(eld), "trưởng lão biết thêm Kiếm Khí (%s)" % str(skill_ids(eld)))
	check(skill_ids(mas).size() == 3, "tông chủ Huyền Minh biết đủ ba chiêu (%s)" % str(skill_ids(mas)))
	check("skills" in dis.behaviors, "NPC có chiêu được gắn hành vi 'skills'")
	var weak := spawn("rogue_weak", p0 + Vector2(900, 300))
	var boss := spawn("rogue_master", p0 + Vector2(900, 400))
	check(skill_ids(weak).size() == 1 and skill_ids(weak)[0] in MonsterBehaviors.ROGUE_BASIC, "tán tu yếu biết một chiêu cơ bản (%s)" % str(skill_ids(weak)))
	check(skill_ids(boss).size() == 3, "cao nhân tán tu biết ba chiêu mạnh (%s)" % str(skill_ids(boss)))
	var wolf := spawn("wolf", p0 + Vector2(900, 500))
	check(skill_ids(wolf).is_empty() and not ("skills" in wolf.behaviors), "thú không có chiêu thức")
	clear_monsters()

	# --- gồng chiêu có dấu báo, rồi tung gây sát thương
	var npc := spawn("sect_disciple", p0 + Vector2(70, 0), "kiem_tong")
	npc.state = "chase"
	var to_p := p0 - npc.position
	var d := to_p.length()
	var hp0: float = main.vitals.hp
	check(MonsterBehaviors.chase_hook(npc, to_p, d, 0.016) and npc.state == "cast", "đệ tử gồng chiêu khi đủ tầm")
	check(str(npc._bt.get("cast", "")) == "skill", "trạng thái gồng là chiêu thức")
	check(npc._tele != null and npc._tele.visible, "có dấu báo trước khi tung chiêu")
	check(not MonsterBehaviors._skill_hook(npc, to_p, d), "chiêu đang hồi thì không tung lại ngay")
	npc._timer = 0.0
	MonsterBehaviors.tick_state(npc, 0.016, to_p, d)
	check(npc.state == "recover", "tung xong thì vào hồi sức")
	check(main.vitals.hp < hp0, "chiêu quạt trúng người chơi đứng trước mặt gây sát thương")
	clear_monsters()

	# --- né được: đứng ngoài tầm hình quạt thì không trúng
	main.vitals.hp = main.vitals.max_hp
	main.vitals.invuln = 0.0
	var far := spawn("sect_disciple", p0 + Vector2(70, 0), "kiem_tong")
	far.state = "chase"
	far._bt["dir"] = Vector2.RIGHT
	far._bt["skill"] = far.get_meta("npc_skills")[0]
	var hp1: float = main.vitals.hp
	MonsterBehaviors._cast_skill(far)
	check(is_equal_approx(main.vitals.hp, hp1), "né ra khỏi hướng chiêu thì không trúng")
	clear_monsters()

	# --- vòng sóng quanh người (Chấn Địa Chưởng) và đạn đơn
	main.vitals.hp = main.vitals.max_hp
	main.vitals.invuln = 0.0
	var tx := spawn("sect_master", p0 + Vector2(90, 0), "han_bang")
	tx._bt["dir"] = Vector2.RIGHT
	for dd in (tx.get_meta("npc_skills") as Array):
		if str(dd["id"]) == "the_quake":
			tx._bt["skill"] = dd
	var hp2: float = main.vitals.hp
	MonsterBehaviors._cast_skill(tx)
	check(main.vitals.hp < hp2, "sóng vòng trúng người ở trong tầm")
	clear_monsters()

	var shooter := spawn("sect_master", p0 + Vector2(200, 0), "huyen_minh")
	for dd in (shooter.get_meta("npc_skills") as Array):
		if str(dd["id"]) == "hon_seal":
			shooter._bt["skill"] = dd
	shooter._bt["dir"] = Vector2.LEFT
	var before := 0
	for n in main.fx_layer.get_children():
		if n is MonsterShot:
			before += 1
	MonsterBehaviors._cast_skill(shooter)
	var after := 0
	for n in main.fx_layer.get_children():
		if n is MonsterShot:
			after += 1
	check(after == before + 1, "chiêu đơn mục tiêu bắn ra một viên đạn")
	clear_monsters()

	print("NPC SKILL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
