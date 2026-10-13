extends SceneTree
## Mini game Ngộ đạo của Tham ngộ: tầng ngộ, áp kết quả lên bí tịch, chuỗi tất định, luồng chơi đủ 5 vòng, sai thì dừng, bỏ cuộc.
const Origin = preload("res://scripts/v1/origin.gd")
const Progression = preload("res://scripts/v1/progression.gd")
var main: Node
var rt
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


func fresh_book(id := "kiem_wave", fragment := false) -> String:
	var uid: String = rt.state.acquire(id, "test", "huyen", fragment)
	return uid


## Chơi game: chờ tới lượt nhập rồi bấm đúng/sai theo chuỗi.
func play(game: StudyGame, rounds_right: int, make_wrong := false) -> void:
	var done := 0
	while game.visible and game._state != "result" and done < 20:
		var guard := 0
		while game._state != "input" and game._state != "result" and guard < 600:
			await process_frame
			guard += 1
		if game._state == "result":
			return
		if done >= rounds_right:
			if make_wrong:
				var wrong := (int(game._seq[0]) + 1) % 5
				game._press(wrong)
			return
		var seq: Array = game._seq.duplicate()
		for i in seq:
			game._press(int(i))
		done += 1
		var g2 := 0
		while game._state == "input" and g2 < 5:
			await process_frame
			g2 += 1


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	rt = main.cultivation_v1
	rt.confirm_origin(Origin.sample(), "kiem_tong")
	var st = rt.state

	# --- tầng ngộ
	check(Progression.study_tier(0) == "fail" and Progression.study_tier(1) == "fail", "0-1 vòng: tâm loạn")
	check(Progression.study_tier(2) == "ok" and Progression.study_tier(3) == "ok", "2-3 vòng: ngộ thường")
	check(Progression.study_tier(4) == "good" and Progression.study_tier(5) == "perfect", "4 vòng: ngộ sâu · 5 vòng: đốn ngộ")

	# --- áp kết quả lên bí tịch
	var uid := fresh_book()
	var item: Dictionary = st.instances[uid]
	var before: Array = item.affixes.duplicate()
	var hidden0: String = item.hidden_affix
	var r: Dictionary = st.resolve_study(uid, "fail")
	check(not r.ok and item.affixes == before and int(item.tries) == 1, "hỏng: dòng phụ không đổi, ghi một lần thử")
	r = st.resolve_study(uid, "ok")
	var changed_n := 0
	for i in before.size():
		if item.affixes[i] != before[i]:
			changed_n += 1
	check(r.ok and changed_n == 1 and r.new == hidden0 and item.affixes.has(hidden0), "thường: đúng một dòng bị thay bằng dòng tiềm ẩn")
	before = item.affixes.duplicate()
	hidden0 = item.hidden_affix
	r = st.resolve_study(uid, "good", 0)
	check(item.affixes[0] == hidden0 and r.old == before[0], "sâu: thay đúng dòng người chơi chọn")
	before = item.affixes.duplicate()
	r = st.resolve_study(uid, "perfect", -2)
	check(r.ok and r.kept and item.affixes == before, "đốn ngộ: được giữ nguyên")
	r = st.resolve_study(uid, "ok", -2)
	check(r.ok and not r.get("kept", false), "-2 chỉ có tác dụng ở tầng đốn ngộ")
	var frag := fresh_book("dao_break", true)
	r = st.resolve_study(frag, "fail")
	check(st.instances[frag].fragment, "tàn quyển: hỏng thì chưa bổ khuyết")
	r = st.resolve_study(frag, "ok")
	check(r.get("repaired", false) and not st.instances[frag].fragment, "tàn quyển: từ 2 vòng là bổ khuyết được")
	var s1: int = st.study_seed(uid)
	st.instances[uid].tries = int(st.instances[uid].tries) + 1
	check(st.study_seed(uid) != s1, "mỗi lần thử có chuỗi khác")

	# --- luồng game
	var game: StudyGame = rt.study_game
	var uid2 := fresh_book("dao_cut")
	var res: Array = []
	var cfg := {"name": "Thử", "seed": 77, "insight": 56.0, "fragment": false, "speed": 0.02,
		"affixes": [{"name": "A", "desc": "a"}, {"name": "B", "desc": "b"}], "hidden": {"name": "H", "desc": "h"}}
	game.finished.connect(func(x): res.append(x))
	game.begin(cfg)
	check(game.visible and game._peeks == 2, "Ngộ Tính 56 cho 2 lần xem lại")
	await play(game, 5)
	check(game._state == "result", "đủ 5 vòng đúng: sang màn kết quả")
	check(game._cleared == 5, "vượt đủ 5 vòng")
	game._done("perfect", 1)
	check(res.size() == 1 and res[0].tier == "perfect" and res[0].replace == 1 and not game.visible, "đốn ngộ trả kết quả và đóng bảng")

	game.begin(cfg)
	await play(game, 2, true)
	await create_timer(0.1).timeout
	for i in 60:
		if game._state == "result":
			break
		await process_frame
	check(game._state == "result" and game._cleared == 2, "sai ở vòng 3: dừng với 2 vòng")
	game._done("ok", -1)
	check(res.size() == 2 and res[1].tier == "ok", "2 vòng: ngộ thường")

	game.begin(cfg)
	await process_frame
	game._abandon()
	check(game._state == "result" and game._cleared == 0, "bỏ ngộ: coi như tâm loạn")
	game._done("fail", -1)


	# --- Ngộ Tính ảnh hưởng mini game
	var lo: Dictionary = Progression.study_params(30.0)
	var mid: Dictionary = Progression.study_params(50.0)
	var hi: Dictionary = Progression.study_params(70.0)
	check(int(lo.peeks) <= int(mid.peeks) and int(mid.peeks) <= int(hi.peeks) and int(hi.peeks) == 3, "Ngộ Tính cao: nhiều lần xem lại hơn")
	check(int(lo.mistakes) == 0 and int(hi.mistakes) == 2, "Ngộ Tính cao tha lỗi (0 → 2 lần)")
	check(int(lo.len_delta) == 1 and int(mid.len_delta) == 0 and int(hi.len_delta) == -1, "Ngộ Tính thấp: chuỗi dài hơn · rất cao: ngắn hơn")
	check(float(lo.hint_delay) == 0.0 and float(hi.hint_delay) > 0.0 and float(hi.hint_delay) <= float(mid.hint_delay), "Ngộ Tính từ 50 mới có gợi ý, càng cao gợi ý càng sớm")
	check(float(hi.flash) >= float(lo.flash) and bool(hi.reveal_good) and not bool(mid.reveal_good), "Ngộ Tính cao: ký hiệu sáng lâu hơn; từ 60 ngộ sâu cũng thấy dòng tiềm ẩn")
	var cfg_hi := cfg.duplicate()
	cfg_hi["insight"] = 70.0
	game.begin(cfg_hi)
	for i in 600:
		if game._state == "input":
			break
		await process_frame
	check(game._seq.size() == 2 or game._seq.size() == 3, "Ngộ Tính 70: chuỗi vòng 1 ngắn hơn một ký hiệu")
	var wrong := (int(game._seq[0]) + 1) % 5
	game._press(wrong)
	game._press(wrong)
	check(game._state == "input" and game._mistakes == 0, "Ngộ Tính 70: tha hai lần bấm sai, vẫn tiếp tục")
	game._press(wrong)
	check(game._state == "wrong", "lần sai thứ ba mới dừng")
	game._abandon()
	game._done("fail", -1)

	# --- qua runtime: tốn linh thạch, mở game, áp kết quả
	main.inv.stones = 5000
	var stones0: int = main.inv.stones
	var cost: int = st.study_cost()
	var res2: Array = []
	rt.study(uid2)
	check(main.inv.stones == stones0 - cost and rt.study_game.visible, "Tham ngộ trả linh thạch rồi mở mini game")
	check(rt.is_open(), "đang chơi thì coi như giao diện đang mở (chặn phím di chuyển)")
	rt.study_game._abandon()
	rt.study_game._done("fail", -1)
	check(not rt.study_game.visible and int(st.instances[uid2].tries) == 1, "kết thúc: áp kết quả (một lần thử)")
	main.inv.stones = 0
	rt.study(uid2)
	check(not rt.study_game.visible, "không đủ linh thạch thì không mở")

	print("STUDY GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
