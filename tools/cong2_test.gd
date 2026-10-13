extends SceneTree
## Ô Công Pháp phụ (U) và ô thứ hai K (Pháp Bảo / Công Pháp còn lại).
const Origin = preload("res://scripts/v1/origin.gd")
var main: Node
var failures := 0
var count := 0

func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)

func learn_book(id: String) -> String:
	var state = main.cultivation_v1.state
	var uid: String = state.acquire(id, "test")
	state.instances[uid].affixes = []
	state.learn(uid)
	return uid

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var rt = main.cultivation_v1
	rt.confirm_origin(Origin.sample(), "kiem_tong")
	var st = rt.state
	var a: String = str(st.equipped.cong)
	var b := learn_book("dao_cut")
	check(a != "" and st.equipped.cong2 == "", "ban đầu chỉ có ô Công chính")
	st.equip(b, "cong2")
	check(st.equipped.cong2 == b and st.equipped.cong == a, "trang bị vào ô phụ không đè ô chính")
	st.equip(a, "cong2")
	check(st.equipped.cong2 == a and st.equipped.cong == "", "một bản không đứng ở cả hai ô (chuyển qua ô phụ)")
	st.equip(a)
	check(st.equipped.cong == a and st.equipped.cong2 == "", "đưa về ô chính thì rời ô phụ")
	st.equip(b, "cong2")
	check(rt.other_slot() == "artifact", "K là Pháp Bảo khi J dùng Công Pháp")
	st.primary = "artifact"
	check(rt.other_slot() == "cong", "K là Công Pháp khi J dùng Pháp Bảo (Bảo Tu)")
	st.primary = "cong"
	check(str(st.to_dict()["equipped"]["cong2"]) == b, "Công phụ được lưu")

	# cast độc lập, hồi chiêu riêng
	main.player.position = Vector2(1050, 1190)
	main.vitals.invuln = 0.0
	main.cult.qi = main.cult.qi_max()
	var dummy = main.get_tree().get_nodes_in_group("targets").filter(func(t): return t is TrainingDummy)[1]
	var hp0: float = dummy.hp
	rt.cast("cong2")
	check(dummy.hp < hp0, "U (Công phụ) gây sát thương lên mục tiêu")
	check(float(rt.engine.cooldowns.cong2) > 0.0 and float(rt.engine.cooldowns.cong) == 0.0, "Công phụ hồi chiêu riêng, không khóa Công chính")
	check(rt.engine.cost("cong2").actual > 0.0, "Công phụ tốn linh lực như Công Pháp")
	print("CONG2: %d checks, %d failures" % [count, failures])
	quit(1 if failures else 0)
