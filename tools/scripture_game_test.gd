extends SceneTree
## Mini game Đọc kinh của Tham ngộ kinh thư: bội số theo điểm, Ngộ Tính chỉnh vùng/nhịp, luồng 5 câu, tính tu vi.
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
	main.cultivation_v1.confirm_origin(preload("res://scripts/v1/origin.gd").sample(), "kiem_tong")
	var g: ScriptureGame = main.scripture_game

	# --- bảng
	check(ScriptureGame.multiplier(0) == 0.0 and ScriptureGame.multiplier(1) == 0.0, "0-1 điểm: không được gì")
	check(ScriptureGame.multiplier(6) == 1.0, "6 điểm: đúng mức cũ (×1.0)")
	check(ScriptureGame.multiplier(10) > ScriptureGame.multiplier(8) and ScriptureGame.multiplier(8) > ScriptureGame.multiplier(6), "điểm cao hơn thì thưởng cao hơn")
	var prev := -1.0
	var mono := true
	for s in 11:
		mono = mono and ScriptureGame.multiplier(s) >= prev
		prev = ScriptureGame.multiplier(s)
	check(mono, "bội số tăng đơn điệu theo điểm")
	check(ScriptureGame.tier_name(0) == "Tâm tán" and ScriptureGame.tier_name(10) == "Đốn ngộ", "tên tầng")

	# --- Ngộ Tính
	var lo := ScriptureGame.params(30.0)
	var hi := ScriptureGame.params(70.0)
	check(float(hi.zone) > float(lo.zone), "Ngộ Tính cao: vùng ngộ rộng hơn")
	check(float(hi.speed) < float(lo.speed), "Ngộ Tính cao: nhịp quét chậm hơn")

	# --- luồng chơi: bấm đúng tâm 5 câu → hoàn hảo
	var res: Array = []
	g.finished.connect(func(x): res.append(x))
	g.begin({"insight": 50.0, "gain": 100.0, "seed": 5, "speed": 0.02})
	check(g.visible and g._state == "run", "mở game là vào chạy")
	for i in 5:
		g._phase = g._center       # dấu quét đúng tâm vùng ngộ (pha 0..1 = vị trí)
		g._press()
		for k in 120:
			if g._state == "run" or g._state == "result":
				break
			await process_frame
	check(g._state == "result" and g._score == 10, "5 câu hoàn hảo: 10 điểm")
	g._done()
	check(res.size() == 1 and is_equal_approx(float(res[0].mult), 2.2) and not g.visible, "kết quả trả bội số ×2.2")

	# --- bấm lệch hết
	g.begin({"insight": 50.0, "gain": 100.0, "seed": 6, "speed": 0.02})
	for i in 5:
		g._phase = fposmod(g._center + 0.5, 1.0) if absf(0.5 - g._center) < 0.3 else 0.0
		# chọn vị trí chắc chắn ngoài vùng: tâm lệch xa
		g._phase = 0.02 if g._center > 0.5 else 0.98
		g._press()
		for k in 120:
			if g._state == "run" or g._state == "result":
				break
			await process_frame
	check(g._state == "result" and g._score == 0, "bấm lệch hết: 0 điểm")
	g._done()
	check(res.size() == 2 and float(res[1].mult) == 0.0, "0 điểm: bội số 0")

	# --- bỏ giữa chừng
	g.begin({"insight": 50.0, "gain": 100.0, "seed": 7, "speed": 0.02})
	g._abandon()
	check(g._state == "result" and g._score == 0, "bỏ đọc: 0 điểm")
	g._done()

	# --- qua main: trả linh thạch, mở game, cộng tu vi theo bội số
	main.inv.stones = 5000
	var cost: int = main._scripture_cost()
	var xp0: float = main.cult.xp
	var gain: float = main._scripture_gain()
	main._study_scripture()
	check(g.visible and main.inv.stones == 5000 - cost and main._ui_blocked(), "mở game: đã trả linh thạch, chặn phím di chuyển")
	g.test_finish(6)
	check(main.cult.xp >= xp0 + gain * 0.99, "6 điểm: nhận đủ tu vi cơ bản")
	main.inv.stones = 5000
	xp0 = main.cult.xp
	main._study_scripture()
	g.test_finish(0)
	check(is_equal_approx(main.cult.xp, xp0), "0 điểm: không có tu vi (linh thạch đã mất)")
	main.inv.stones = 0
	main._study_scripture()
	check(not g.visible, "không đủ linh thạch thì không mở")

	print("SCRIPTURE GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
