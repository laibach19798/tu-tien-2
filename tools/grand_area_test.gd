extends SceneTree
## Đại chiêu: vùng trúng đòn khớp vùng hình ảnh (GrandFx.reach / impact_radius / mưa kiếm diện rộng).
const Origin = preload("res://scripts/v1/origin.gd")
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


func dummy_at(p: Vector2) -> TrainingDummy:
	var d := TrainingDummy.new()
	d.position = p
	main.world.add_child(d)
	return d


func clear_dummies() -> void:
	for t in get_nodes_in_group("targets"):
		if is_instance_valid(t) and t is TrainingDummy:
			t.remove_from_group("targets")
			t.queue_free()


func fire(rt, def: Dictionary, slot := "cong") -> void:
	GrandCast._busy_until = Time.get_ticks_msec() + 100000   # bỏ khung gồng lực, chỉ kiểm vùng trúng
	rt._execute({"definition": def, "context": rt.engine.context(slot, ["spell"])})


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var rt = main.cultivation_v1
	rt.confirm_origin(Origin.sample(), "kiem_tong")
	main.cult.qi = main.cult.qi_max()
	clear_dummies()
	var P: Vector2 = main.player.position

	# --- bảng vùng
	check(is_equal_approx(GrandFx.reach({"id": "the_quake", "range": 180}), 270.0), "Địa Chấn: tầm đánh 1,5 lần tầm gốc (270)")
	check(is_equal_approx(GrandFx.reach({"id": "kiem_cut", "range": 125}), 0.0), "chiêu thường: không đổi tầm")
	check(GrandFx.impact_radius({"id": "kiem_wave"}) > 0.0 and GrandFx.impact_radius({"id": "thien_mach_quyet"}) > 0.0, "Kiếm Khí / Thiên Mạch có bán kính nổ riêng")

	# --- Địa Chấn: vòng 180 → 270
	var def := {"id": "the_quake", "name": "Địa Chấn", "shape": "ring", "range": 180, "damage": 30.0, "element": "tho"}
	var inner := dummy_at(P + Vector2(150, 0))
	var mid := dummy_at(P + Vector2(0, 240))
	var outer := dummy_at(P + Vector2(-330, 0))
	await process_frame
	fire(rt, def)
	check(inner.hp < inner.max_hp, "Địa Chấn: mục tiêu trong tầm gốc bị trúng")
	check(mid.hp < mid.max_hp, "Địa Chấn: mục tiêu ở 240 (trong vùng hình ảnh, ngoài tầm gốc) bị trúng")
	check(outer.hp >= outer.max_hp, "Địa Chấn: mục tiêu ở 330 (ngoài vùng hình ảnh) không bị trúng")
	clear_dummies()

	# --- Thiên Mạch Quyết: nổ 170 quanh mục tiêu đầu (trước đây 110)
	def = {"id": "thien_mach_quyet", "name": "Thiên Mạch Quyết", "shape": "burst", "range": 300, "damage": 30.0, "element": "kim"}
	var a := dummy_at(P + Vector2(120, 0))
	var b := dummy_at(P + Vector2(120 + 150, 0))
	var c := dummy_at(P + Vector2(120 + 230, 0))
	await process_frame
	fire(rt, def)
	check(a.hp < a.max_hp and b.hp < b.max_hp, "Thiên Mạch: mục tiêu cách tâm nổ 150 bị trúng")
	check(c.hp >= c.max_hp, "Thiên Mạch: mục tiêu cách tâm nổ 230 không bị trúng")
	clear_dummies()

	# --- Kiếm Khí: tia + vùng nổ 210 quanh điểm rơi
	def = {"id": "kiem_wave", "name": "Kiếm Khí", "shape": "line", "range": 350, "damage": 30.0, "element": "kim"}
	var head := dummy_at(P + Vector2(200, 0))
	var side := dummy_at(P + Vector2(200, 150))
	var far := dummy_at(P + Vector2(200, 280))
	await process_frame
	fire(rt, def)
	check(head.hp < head.max_hp, "Kiếm Khí: mục tiêu đầu tia bị trúng")
	check(side.hp < side.max_hp, "Kiếm Khí: mục tiêu lệch 150 khỏi tia nhưng trong vùng nổ bị trúng")
	check(far.hp >= far.max_hp, "Kiếm Khí: mục tiêu lệch 280 không bị trúng")
	clear_dummies()

	# --- Phá Đao: nón 180 → 270
	def = {"id": "dao_break", "name": "Phá Đao", "shape": "cone", "range": 180, "damage": 30.0, "element": "kim"}
	var near := dummy_at(P + Vector2(120, 0))
	var long := dummy_at(P + Vector2(240, 0))
	var out := dummy_at(P + Vector2(330, 0))
	await process_frame
	main.direction = "east"
	fire(rt, def)
	check(near.hp < near.max_hp and long.hp < long.max_hp, "Phá Đao: vệt chém trúng tới 240 phía trước")
	check(out.hp >= out.max_hp, "Phá Đao: ngoài 270 không trúng")
	clear_dummies()

	# --- Cửu Kiếm: mưa kiếm diện rộng, mục tiêu thứ hai chịu một phần sát thương
	def = {"id": "nine_swords", "name": "Cửu Kiếm Hạp", "shape": "summon", "range": 330, "damage": 40.0, "duration": 5}
	var t1 := dummy_at(P + Vector2(100, 0))
	var t2 := dummy_at(P + Vector2(100, 120))
	await process_frame
	var ctx: Dictionary = rt.engine.context("artifact", ["summon", "artifact"])
	rt.summons.append({"context": ctx, "definition": def, "remaining": 5.0, "next": 0.0})
	main.cult.qi = main.cult.qi_max()
	rt._process(0.01)
	check(t1.hp < t1.max_hp and t2.hp < t2.max_hp, "Cửu Kiếm: cả hai mục tiêu trong vùng mưa kiếm bị trúng")
	var loss1: float = t1.max_hp - t1.hp
	var loss2: float = t2.max_hp - t2.hp
	check(loss2 > 0.0 and loss2 < loss1, "Cửu Kiếm: mục tiêu thứ hai nhận ít hơn (%.1f < %.1f)" % [loss2, loss1])

	print("GRAND AREA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
