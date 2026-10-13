extends SceneTree
## Godot --headless --path . --script res://tools/sect_life_test.gd
## Không ghi bản lưu thật; kiểm tra các nhánh, chuyển map, tương thích và phần thưởng.
var main: Node
var failures := 0

func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func dismiss() -> void:
	main.dialogue.open = false
	main.dialogue._panel.hide()

func fresh() -> void:
	if main.current_map != "overworld":
		main.switch_map_now("overworld", Vector2(1290, 2500))
	dismiss()
	main.inv.from_dict({})
	main.school.joined = true
	main.sect_life.from_dict({})

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var life = main.sect_life
	fresh()
	check(life.actors.size() == 4, "four social NPCs")
	for phase in [0.30, 0.55, 0.85]:
		main.atmo.t = phase
		life._update_schedule(true)
		for id in life.actors:
			check(not life.paths[id].is_empty(), "walkable schedule %s / %s" % [phase, id])
	life.open_board()
	check(main._ui_blocked(), "board blocks gameplay input")
	var key := InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	life._unhandled_input(key)
	check(not life.is_open(), "H closes board")
	life.socialize("han_phong")
	life.socialize("han_phong")
	check(life.bonds.han_phong == 5, "daily social action cannot be farmed")
	main.inv.add("dan_hoi_huyet", 2)
	life.give_gift("han_phong")
	life.give_gift("han_phong")
	check(main.inv.count("dan_hoi_huyet") == 1 and life.bonds.han_phong == 8, "one gift per person per day")
	life.bonds.han_phong = 34
	life.daily.clear()
	life.socialize("han_phong")
	check(life.bonds.han_phong == 35, "ordinary social actions capped below trust")
	life.last_clock = 0.99
	main.atmo.t = 0.01
	life._process(0.01)
	check(life.day == 2 and life.daily.is_empty(), "new day clears social limits")
	for branch in ["rescue", "together", "compete"]:
		fresh()
		life.mentor_task()
		for i in 10:
			main._on_dummy_hit(1.0)
		check(life.training_hits == 10, branch + " training hook")
		life.mentor_task()
		check(life.stage == "field" and not life.actors.luc_an.visible, branch + " starts expedition")
		main.switch_map_now("soi_linh", Vector2(250, 900))
		check(main.npcs.any(func(n): return n.npc_id == "luc_an"), branch + " rescue NPC in map")
		if branch == "together":
			life.choose_branch(branch)
			check(life.stage == "field", "cooperation requires respect")
			life.socialize("han_phong")
		life.choose_branch(branch)
		check(life.stage == branch, branch + " chosen")
		var before: int = life.field_kills
		life.on_kill("goblin")
		check(life.field_kills == before, "unrelated enemy ignored")
		var save: Dictionary = JSON.parse_string(JSON.stringify(main._collect_save()))
		main.switch_map_now("overworld", Vector2(1290, 2500))
		life.on_kill("wolf")
		check(life.field_kills == before, "wrong map kill ignored")
		main._apply_save(save, true)
		check(main.current_map == "soi_linh" and life.stage == branch, branch + " save restores active quest and map")
		for i in life.kill_goal():
			# Exercise actual combat → death → main hook, not only quest counters.
			var wolf := Monster.new()
			wolf.setup(main, "wolf", Vector2(850 + i * 70, 900))
			main.world.add_child(wolf)
			main.monsters.append(wolf)
			wolf.take_hit(10000.0, main.player.position)
		check(life.field_kills == life.kill_goal(), branch + " actual monster death counted")
		if branch != "compete":
			life.rescue_dialogue()
		check(life.stage == "report", branch + " field completed")
		main.switch_map_now("overworld", Vector2(1290, 2500))
		life.mentor_task()
		check(main.inv.merit_total == 100 and main.inv.sect_rank() == 0, "rank gated until exam")
		var total: int = main.inv.merit_total
		life.mentor_task()
		check(main.inv.merit_total == total, "report reward not duplicated")
		dismiss()
		life.start_exam()
		life.exam_left = 0.01
		life._process(0.1)
		check(life.exam_left == 0.0 and life.stage == "exam", "failed exam is retryable")
		life.start_exam()
		for i in 12:
			main._on_dummy_hit(1.0)
		check(life.stage == "done" and main.inv.sect_rank() == 1, "exam grants inner rank")
		var stones: int = main.inv.stones
		main.inv.pass_inner_exam()
		check(main.inv.stones == stones, "rank reward only once")
		life.accept_mentor()
		life.accept_mentor()
		check(life.mentor, "mentor accepted only once")
		var meds: int = main.inv.count("dan_hoi_huyet")
		life.gratitude()
		life.gratitude()
		check(main.inv.count("dan_hoi_huyet") == meds + (0 if branch == "compete" else 2), "branch gratitude only once")
		save = JSON.parse_string(JSON.stringify(main._collect_save()))
		main._apply_save(save, true)
		check(life.stage == "done" and main.inv.inner_exam_passed and life.mentor, "completed progress roundtrip")
		if branch == "compete":
			check(life.bonds.luc_an < 0, "abandonment has lasting consequence")
		else:
			var memory: String = life.memories.luc_an
			life.socialize("luc_an")
			check(life.memories.luc_an == memory, "small talk preserves major memory")
	main.inv.from_dict({"merit_total": 420, "stones": 50})
	check(main.inv.sect_rank() == 3 and main.inv.stones == 50, "old save keeps rank without duplicate rewards")
	main.inv.from_dict({"merit_total": 420, "inner_exam_passed": false})
	check(main.inv.sect_rank() == 0, "new save preserves exam requirement")
	print("SECT LIFE TEST: %d failures" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
