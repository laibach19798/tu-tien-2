extends SceneTree
## Độ khó địa ngục: đường cong tu vi, đột phá thành chuỗi, thiên kiếp, quái co giãn, tử vong, kháng dược.
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
	# --- đường cong
	var prev := 0.0
	var mono := true
	for r in range(1, 6):
		for l in range(1, 10):
			var need := Hell.xp_needed(r, l)
			mono = mono and need > prev
			prev = need
	check(mono, "tu vi cần tăng đơn điệu qua cả 45 bậc")
	var targets := [3.0, 9.0, 27.0, 81.0, 243.0]
	for r in range(1, 6):
		var total := 0.0
		for l in range(1, 10):
			total += Hell.xp_needed(r, l)
		var hours := total / (12.0 * 3600.0)   # thiền ở linh mạch: 4 × mật độ 3 = 12 tu vi/giây
		check(absf(hours - float(targets[r - 1])) / float(targets[r - 1]) < 0.06, "cảnh giới %d cần ~%d giờ thiền ở linh mạch (đo %.1f)" % [r, int(targets[r - 1]), hours])
	check(Hell.fatigue_factor(600.0) == 1.0 and is_equal_approx(Hell.fatigue_factor(2400.0), Hell.FATIGUE_FLOOR), "mệt mỏi khi thiền quá lâu")
	check(Hell.time_factor(0.0) > Hell.time_factor(1.0), "ban ngày hấp thụ nhanh hơn đêm khuya")
	check(Hell.reward_factor(20, 5) < 0.2 and Hell.reward_factor(0, 10) > 1.0, "vượt cấp thì thưởng giảm mạnh, khu cao hơn thì nhỉnh lên")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var cult: Cultivation = main.cult
	var bt: Breakthrough = main.breakthrough

	# --- thất bại đột phá: giữ 30% tu vi, trọng thương làm chậm hấp thụ
	cult.realm = 1
	cult.layer = 9
	cult.xp = cult.xp_needed()
	cult.ready_breakthrough = true
	cult.fail_breakthrough()
	check(is_equal_approx(cult.xp, Hell.xp_needed(1, 9) * Hell.FAIL_KEEP) and cult.injury > 0.0, "đột phá thất bại: giữ 30%% tu vi và trọng thương")
	cult.qi = 500.0
	cult.env_mult = 1.0
	var before := cult.xp
	cult.meditate(1.0, 1.0)
	var injured_gain := cult.xp - before
	cult.injury = 0.0
	cult.qi = 500.0
	before = cult.xp
	cult.meditate(1.0, 1.0)
	check(injured_gain < (cult.xp - before) * 0.6, "trọng thương: hấp thụ chỉ còn khoảng một nửa")

	# --- chuỗi đột phá: tâm ma (Luyện Khí → Trúc Cơ)
	cult.realm = 1
	cult.layer = 9
	cult.xp = cult.xp_needed()
	cult.ready_breakthrough = true
	var results: Array = []
	bt.finished.connect(func(ok): results.append(ok))
	bt.start()
	check(main.dialogue.open, "bấm B mở hộp thoại chuẩn bị đột phá")
	main.dialogue.hide()
	main.dialogue.open = false   # đóng hộp thoại như khi người chơi đã chọn xong
	bt._prepared(0.0, "")
	check(bt.active and bt._rounds_left == Breakthrough.DEMON_ROUNDS, "tâm ma có 3 câu hỏi")
	for i in Breakthrough.DEMON_ROUNDS:
		bt._answer(true)
	check(not bt.active and results.size() == 1, "trả lời xong tâm ma thì ra kết quả")
	check(is_equal_approx(bt._trial_bonus, Breakthrough.DEMON_GOOD * 3.0), "trả lời đúng cả 3 câu: cộng đủ thưởng thử thách")
	# trả lời sai tốn khí huyết
	cult.realm = 1
	cult.layer = 9
	cult.xp = cult.xp_needed()
	cult.ready_breakthrough = true
	main.vitals.hp = main.vitals.max_hp
	bt._prepared(0.0, "")
	var hp_before: float = main.vitals.hp
	bt._answer(false)
	check(main.vitals.hp < hp_before, "trả lời sai tâm ma mất khí huyết")
	bt._answer(true)
	bt._answer(true)

	# --- thiên kiếp (Trúc Cơ → Kim Đan)
	cult.realm = 2
	cult.layer = 9
	cult.xp = cult.xp_needed()
	cult.ready_breakthrough = true
	main.vitals.hp = main.vitals.max_hp
	bt._prepared(0.0, "")
	check(bt.active and bt._trib_left > 0.0, "thiên kiếp bắt đầu với thời gian đếm ngược")
	var strike := TribulationStrike.new()
	strike.main = main
	strike.damage = 50.0
	strike.position = main.player.position
	main.world.add_child(strike)
	main.vitals.invuln = 0.0
	var hp0: float = main.vitals.hp
	main.dialogue.open = false   # các câu hỏi tâm ma trước đó mở hộp thoại; người chơi thật đã đóng khi chọn
	strike._t = TribulationStrike.DELAY
	strike._process(0.016)
	check(main.vitals.hp < hp0, "tia sét trúng người chơi đứng trong vòng thì gây sát thương")
	var count := results.size()
	bt._trib_left = 0.01
	bt._process(0.05)
	check(not bt.active and results.size() == count + 1, "trụ hết thời gian thiên kiếp thì ra kết quả")
	# chết trong thiên kiếp = thất bại
	cult.realm = 2
	cult.layer = 9
	cult.xp = cult.xp_needed()
	cult.ready_breakthrough = true
	bt._prepared(0.0, "")
	bt._on_died()
	check(not bt.active and not cult.ready_breakthrough and cult.injury > 0.0, "chết trong thiên kiếp: đột phá thất bại và trọng thương")

	# --- kháng dược
	cult.realm = 1
	cult.layer = 1
	cult.xp = 0.0
	main.inv.items.clear()
	main.inv.tolerance.clear()
	main.inv.add("dan_tu_vi", 3)
	var need := cult.xp_needed()
	main.inv.use("dan_tu_vi", cult)
	var g1 := cult.xp
	main.inv.use("dan_tu_vi", cult)
	var g2 := cult.xp - g1
	check(is_equal_approx(g1, need * 0.03) and g2 < g1 * 0.6, "đan dược theo tỉ lệ tu vi tầng và bị kháng khi dùng liên tiếp")

	# --- quái co giãn theo tầng nguy hiểm của khu
	var zone := "soi_linh"
	check(zone != "", "có khu tầng nguy hiểm 2")
	main.switch_map_now(zone, (Maps.DEFS[zone]["entry"] as Vector2))
	await process_frame
	var wolf: Monster = null
	for m in main.monsters:
		if m.kind_id == "wolf":
			wolf = m
			break
	if wolf != null:
		check(is_equal_approx(wolf.max_hp, Hell.monster_hp(70.0, 2)) and wolf.max_hp > 70.0 * 1.6, "sói ở khu tầng 2 có máu đã co giãn (%.0f)" % wolf.max_hp)
		check(is_equal_approx(wolf.damage, Hell.monster_dmg(9.0, 2)), "sát thương quái đã co giãn")

	# --- tử vong
	main.switch_map_now("overworld", main.CENTER + Vector2(0, 200))
	await process_frame
	main.inv.add_stones(1000 - main.inv.stones)
	cult.realm = 1
	cult.layer = 3
	cult.xp = 1000.0
	main.inv.items.clear()
	main.inv.add("linh_thao", 10)
	main._on_player_died()
	check(main.inv.stones == 1000 - int(1000 * Hell.DEATH_STONES), "chết mất %d%% linh thạch" % roundi(Hell.DEATH_STONES * 100.0))
	check(is_equal_approx(cult.xp, 1000.0 * (1.0 - Hell.DEATH_XP)) and cult.layer == 3, "chết mất tu vi trong tầng, không tụt tầng")
	check(main.inv.count("linh_thao") == 5, "chết rơi mất một nửa một loại nguyên liệu đang mang")

	print("HELL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
