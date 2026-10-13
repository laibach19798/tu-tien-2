extends SceneTree
## Hiệu ứng pixel-art (assets/vfx): tài nguyên nạp được, mỗi chiêu đặc trưng sinh ra Clip, Clip tự xoá.
const NAMES := ["slash_kiem", "slash_dao", "lance", "fireball", "water_jet", "quake", "sigil", "summon", "bell", "swords", "orb_green", "orb_arcane", "impact_ring", "hit", "crit"]
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


func count_clips() -> int:
	var n := 0
	for c in main.fx_layer.get_children():
		if c is Vfx.Clip:
			n += 1
	return n


func run() -> void:
	for n in NAMES:
		check(Vfx.has(n), "hiệu ứng %s nạp được" % n)
	check(not Vfx.has("khong_ton_tai") and Vfx.play(null, "khong_ton_tai", Vector2.ZERO) == null, "hiệu ứng không tồn tại trả về null")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var books: Array = preload("res://scripts/v1/catalog.gd").data().books.duplicate()
	var eq = preload("res://scripts/v1/catalog.gd").data().equipment
	books.append_array(eq if eq is Array else eq.values())
	var with_vfx := ["kiem_cut", "kiem_wave", "dao_cut", "dao_break", "the_fist", "ngu_fire", "ngu_water", "the_quake", "hon_seal", "hon_clone", "soul_bell", "qi_pearl", "nine_swords"]
	for id in with_vfx:
		var def: Dictionary = {}
		for b in books:
			if str(b.get("id", "")) == id:
				def = b
		var before := count_clips()
		GrandCast._busy_until = Time.get_ticks_msec() + 100000   # bỏ khung đại chiêu: kiểm hiệu ứng nhỏ
		SkillFx.cast(main, def, Vector2.RIGHT, [])
		check(count_clips() > before, "chiêu %s phát hiệu ứng pixel-art" % id)
	# đại chiêu quy mô lớn (GrandFx): dựng ra nhiều nút hiệu ứng
	GrandCast._busy_until = 0
	for id in GrandFx.IDS:
		var n0: int = main.fx_layer.get_child_count()
		GrandFx.release(main, {"id": id, "name": id, "range": 125}, main.player.position, Vector2.RIGHT, [main.player.position + Vector2(120, 0)])
		check(main.fx_layer.get_child_count() > n0, "đại chiêu %s dựng hiệu ứng quy mô lớn" % id)
	# dư chấn: vết trên đất + quái bị hất văng
	var scars0: int = main.layer_shadows.get_child_count()
	var dummy := Node2D.new()
	var gs := GDScript.new()
	gs.source_code = "extends Node2D
var alive := true
var _knock := Vector2.ZERO
"
	gs.reload()
	dummy.set_script(gs)
	dummy.add_to_group("targets")
	dummy.position = main.player.position + Vector2(90, 0)
	main.add_child(dummy)
	GrandFx.release(main, {"id": "the_quake", "name": "x", "range": 125}, main.player.position, Vector2.RIGHT, [])
	check(main.layer_shadows.get_child_count() > scars0, "đại chiêu để lại vết dư chấn trên mặt đất")
	check(dummy._knock.length() > 50.0 and dummy._knock.x > 0.0, "quái gần tâm bị hất văng ra xa")
	dummy.queue_free()
	GrandCast._busy_until = 0
	check(SkillFx.is_grand({"id": "x", "cooldown": 3.0}) and not SkillFx.is_grand({"id": "kiem_cut", "cooldown": 0.55}), "chỉ chiêu hồi lâu/bí truyền mới là đại chiêu")
	var c0 := count_clips()
	SkillFx.hit(main, main.player.position, {}, false)
	SkillFx.hit(main, main.player.position, {}, true)
	check(count_clips() == c0 + 2, "trúng đòn / chí mạng phát hiệu ứng")
	# nút tự xoá khi hết khung hình
	await create_timer(2.5).timeout
	await process_frame
	check(count_clips() == 0, "mọi hiệu ứng tự xoá sau khi phát xong (còn %d)" % count_clips())
	print("VFX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
