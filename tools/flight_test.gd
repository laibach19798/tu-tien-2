extends SceneTree
## Phi hành: mở khoá ở Trúc Cơ, tốn linh khí, bay qua vật cản, hết linh khí thì rơi, cấm ở sơn môn, không ra chiêu / tương tác khi bay.
var main: Node
var F: Flight
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
	main.dialogue.open = false
	F = main.flight
	main.player.position = Vector2(1300, 1500)   # đất trống ngoài làng

	# --- mở khoá theo cảnh giới
	main.cult.realm = 1
	main.cult.layer = 9
	check(not F.unlocked(), "Luyện Khí: chưa ngự không được")
	check(not F.takeoff() and not F.active, "chưa mở khoá thì không cất cánh")
	main.cult.realm = 2
	main.cult.layer = 1
	check(F.unlocked(), "Trúc Cơ: mở khoá phi hành")
	check(Cultivation.REALMS[Flight.UNLOCK_REALM] == "Trúc Cơ" and main.cult.step_index() == Flight.UNLOCK_STEP, "mốc mở khoá đúng Trúc Cơ tầng 1")

	# --- cất cánh cần linh khí
	main.cult.qi = 10.0
	check(not F.takeoff(), "linh khí quá cạn: không cất cánh")
	main.cult.qi = main.cult.qi_max()
	check(F.takeoff() and F.active, "đủ linh khí: cất cánh")

	# --- tốn linh khí, không hồi khi bay
	var q0: float = main.cult.qi
	for i in 60:
		await physics_frame
	check(main.cult.qi < q0, "bay tiêu hao linh khí (%.0f → %.0f)" % [q0, main.cult.qi])
	var cost_low: float = F.qi_cost()
	main.cult.realm = 3
	main.cult.layer = 9
	check(F.qi_cost() < cost_low and F.qi_cost() >= Flight.MIN_COST, "cảnh giới càng cao bay càng rẻ (%.1f → %.1f)" % [cost_low, F.qi_cost()])
	main.cult.realm = 2
	main.cult.layer = 1
	check(is_equal_approx(F.qi_cost(), Flight.BASE_COST), "Trúc Cơ tầng 1 đắt nhất (%.1f/giây)" % F.qi_cost())

	# --- bay qua vật cản; đi bộ thì bị chặn
	var obstacle := Vector2.ZERO
	var found := false
	for x in range(300, 3000, 40):
		for y in range(300, 2200, 40):
			if main._is_blocked(Rect2(x - 12, y - 8, 24, 10)):
				obstacle = Vector2(x, y)
				found = true
				break
		if found:
			break
	check(found, "tìm được một vật cản trên bản đồ (%s)" % str(obstacle))
	main.cult.qi = main.cult.qi_max()
	main.player.position = obstacle - Vector2(60, 0)
	F.move(Vector2(60, 0))
	check(main.player.position.distance_to(obstacle) < 1.0, "bay xuyên được vật cản (bước thẳng vào ô bị chặn)")
	check(not F.land(false), "đang ở trên vật cản: không hạ xuống được")
	check(F.active, "vẫn đang bay")
	# biên bản đồ
	main.player.position = Vector2(30, 30)
	F.move(Vector2(-500, -500))
	check(main.player.position.x >= 20.0 and main.player.position.y >= 20.0, "không bay ra ngoài biên bản đồ")

	# --- hạ xuống nơi trống
	main.player.position = Vector2(1300, 1500)
	check(F.land(false) and not F.active, "hạ xuống nơi trống thành công")

	# --- hết linh khí: rơi, mất khí huyết
	main.player.position = Vector2(1300, 1500)
	main.cult.qi = 60.0
	check(F.takeoff(), "cất cánh lại")
	main.vitals.hp = main.vitals.max_hp
	main.vitals.invuln = 0
	var hp0: float = main.vitals.hp
	main.cult.qi = 0.5
	for i in 30:
		await physics_frame
		if not F.active:
			break
	check(not F.active and main.vitals.hp < hp0, "hết linh khí: rơi xuống và mất khí huyết (%.0f → %.0f)" % [hp0, main.vitals.hp])
	var p := main.player.position as Vector2
	check(not main._is_blocked(Rect2(p.x - 12, p.y - 8, 24, 10)), "rơi xong đứng ở chỗ đi được")

	# --- rơi trên vật cản: bị đẩy ra chỗ trống
	main.cult.qi = main.cult.qi_max()
	main.player.position = obstacle
	F.active = true
	F.land(true)
	var q := main.player.position as Vector2
	check(not F.active and not main._is_blocked(Rect2(q.x - 12, q.y - 8, 24, 10)), "bị buộc hạ trên vật cản: đẩy ra chỗ trống gần nhất")

	# --- cấm không và hạn chế
	main.cult.qi = main.cult.qi_max()
	var saved_map: String = str(main.current_map)
	main.current_map = "sect_kiem_tong"
	check(not F.allowed_here() and not F.takeoff(), "sơn môn: cấm ngự không")
	main.current_map = saved_map
	main.player.position = Vector2(1300, 1500)
	check(F.takeoff(), "cất cánh lại ở nơi cho phép")
	var key := InputEventKey.new()
	key.keycode = KEY_J
	key.pressed = true
	main._unhandled_input(key)
	check(F.active, "đang bay ra chiêu bị từ chối (vẫn bay)")
	main.meditating = true
	var fk := InputEventKey.new()
	fk.keycode = KEY_F
	fk.pressed = true
	main._unhandled_input(fk)
	check(F.active and main.meditating == true, "đang bay không ngồi thiền được")
	main.meditating = false

	# --- né đòn khi bay
	main.cult.qi = main.cult.qi_max()
	var ch: float = F.evade_chance()
	check(ch >= Flight.EVADE_MIN and ch <= Flight.EVADE_MAX, "xác suất né khi bay trong giới hạn (%.0f%%)" % (ch * 100.0))
	var agi0 = main.cultivation_v1.state.origin.attributes.agility
	main.cultivation_v1.state.origin.attributes.agility = 75
	var ch_hi: float = F.evade_chance()
	main.cultivation_v1.state.origin.attributes.agility = 30
	var ch_lo: float = F.evade_chance()
	main.cultivation_v1.state.origin.attributes.agility = agi0
	check(ch_hi > ch_lo, "Linh Hoạt cao né tốt hơn (%.0f%% > %.0f%%)" % [ch_hi * 100.0, ch_lo * 100.0])
	F.evade_roll = 0.0
	var qi_e: float = main.cult.qi
	var ev0: int = F.evades
	var out: float = main.cultivation_v1.filter_damage(30.0, main.player.position + Vector2(40, 0))
	check(out < 0.0 and F.evades == ev0 + 1 and main.cult.qi < qi_e, "đòn bị né khi đang bay: huỷ đòn và tốn linh khí (%.0f → %.0f)" % [qi_e, main.cult.qi])
	var out2: float = main.cultivation_v1.filter_damage(30.0, main.player.position + Vector2(40, 0))
	check(out2 >= 0.0, "né liên tiếp trong 0,35 giây bị chặn (hồi né)")
	F._evade_cd = 0.0
	F.evade_roll = 0.999
	var out3: float = main.cultivation_v1.filter_damage(30.0, main.player.position + Vector2(40, 0))
	check(out3 >= 0.0, "xúc xắc xấu: đòn vẫn trúng")
	F._evade_cd = 0.0
	F.evade_roll = 0.0
	main.cult.qi = 1.0
	check(not F.try_evade(main.player.position + Vector2(30, 0)), "hết linh khí để né thì không né được")
	main.cult.qi = main.cult.qi_max()
	F.land(true, true)
	check(not F.try_evade(main.player.position + Vector2(30, 0)), "đứng dưới đất thì không có né của phi hành")
	F.evade_roll = -1.0
	main.player.position = Vector2(1300, 1500)
	F.takeoff()

	# --- hiệu ứng khi bay
	check(main.fx_layer.get_children().filter(func(c): return c is Line2D).is_empty(), "không còn vệt gió dưới chân khi bay")
	check(main.player.get_node_or_null("FlightCloud") == null and F._back != null, "không có mây dưới chân, chỉ có gió sau lưng")
	var x0: float = main.player.position.x
	Input.action_press("ui_right")
	for i in 30:
		await physics_frame
	Input.action_release("ui_right")
	check(main.player.position.x > x0 + 50.0, "bay sang phải bằng phím di chuyển (%.0f → %.0f)" % [x0, main.player.position.x])
	check(str(main.player.body.animation).begins_with("idle"), "đang bay vẫn đứng yên trên không (hoạt ảnh %s)" % str(main.player.body.animation))
	check(F._back != null and is_instance_valid(F._back), "có hiệu ứng gió sau lưng nhân vật")
	check(F._back.intensity > 0.9, "bay nhanh: hiệu ứng sau lưng mạnh lên (%.2f)" % F._back.intensity)
	check(F._back.facing.x > 0.5 and F._back.z_index == -1, "quay sang phải: gió tuôn ra phía sau (bên trái), vẽ sau thân người")
	main.direction = "north"
	await physics_frame
	await physics_frame
	check(F._back.facing.y < -0.5 and F._back.z_index > 0, "quay lên trên: phía sau lưng hướng về camera nên vẽ đè lên thân")
	for i in 40:
		await physics_frame
	check(F._back.intensity < 0.5, "đứng yên trên không: hiệu ứng dịu lại (%.2f)" % F._back.intensity)
	var shadow := main.player.get_node("PlayerShadow") as Node2D
	check(shadow.scale.x < 1.0, "bóng dưới chân nhỏ lại khi lên cao")
	F.land(true, true)
	check(shadow.scale.is_equal_approx(Vector2.ONE) and F._back == null, "hạ xuống: gỡ hiệu ứng, bóng trở lại bình thường")

	# --- mặc tiên bào (có áo choàng linh khí, hào quang, kiếm đeo lưng): khi bay mọi thứ nâng lên cùng thân, áo choàng ẩn
	Wardrobe.apply(main.player, {"hair": "hair_topknot_black", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black"})
	var cape := main.player.get_node_or_null("QiCape") as Node2D
	var aura := main.player.get_node_or_null("OutfitAura") as Node2D
	check(cape != null and aura != null, "tiên bào có áo choàng linh khí và hào quang")
	main.player.position = Vector2(1300, 1500)
	main.cult.qi = main.cult.qi_max()
	F.takeoff()
	for i in 40:
		await physics_frame
	check(cape.visible and absf(cape.position.y + Flight.LIFT) < 0.5, "đang bay: áo choàng linh khí gắn theo thân người, nâng lên cùng (%.1f)" % cape.position.y)
	check(absf(aura.position.y + Flight.LIFT) < 0.5, "hào quang nâng lên cùng thân người (%.1f)" % aura.position.y)
	check(aura.scale.is_equal_approx(Vector2.ONE), "hào quang không bị co lại như bóng")
	var body_off: float = (main.player.get_node("Body") as AnimatedSprite2D).offset.y
	check(absf(body_off + Flight.LIFT) < 0.5, "thân người nâng lên đúng độ cao (%.1f)" % body_off)
	F.land(true, true)
	check(cape.visible and absf(cape.position.y) < 0.5 and absf(aura.position.y) < 0.5 and absf((main.player.get_node("Body") as AnimatedSprite2D).offset.y) < 0.5, "hạ xuống: áo choàng và mọi lớp về chỗ cũ")

	# --- kiếm của Kiếm Tông đeo sau lưng (SwordSchool): cũng lên cao cùng thân người
	Wardrobe.apply(main.player, {"hair": "hair_topknot_black", "clothes": "outfit_xam", "shoes": "shoes_boot_black"})
	main.school.joined = true
	main.player.position = Vector2(1300, 1500)
	main.direction = "east"
	for i in 5:
		await process_frame
	var sheath: Node2D = main.school._sheath
	check(sheath.visible and main.player.get_node_or_null("BackSword") == null, "đệ tử Kiếm Tông có kiếm đeo lưng của môn phái")
	var sy0: float = sheath.position.y
	main.cult.qi = main.cult.qi_max()
	F.takeoff()
	for i in 40:
		await physics_frame
	check(absf((sheath.position.y - sy0) + Flight.LIFT) < 0.5, "đang bay: kiếm môn phái đeo lưng nâng lên cùng thân (%.1f → %.1f)" % [sy0, sheath.position.y])
	F.land(true, true)
	for i in 3:
		await physics_frame
	check(absf(sheath.position.y - sy0) < 0.5, "hạ xuống: kiếm môn phái về chỗ cũ")
	main.school.joined = false

	# --- kiếm đeo lưng: gắn theo thân người khi bay
	Wardrobe.apply(main.player, {"hair": "hair_topknot_black", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black", "sword": "sword_crystal"})
	var bsword := main.player.get_node_or_null("BackSword") as Node2D
	check(bsword != null, "có kiếm đeo lưng")
	for i in 5:
		await process_frame
	var y_ground: float = bsword.position.y
	main.player.position = Vector2(1300, 1500)
	main.cult.qi = main.cult.qi_max()
	F.takeoff()
	for i in 40:
		await physics_frame
	check(absf((bsword.position.y - y_ground) + Flight.LIFT) < 0.5, "đang bay: kiếm đeo lưng nâng lên cùng thân (%.1f → %.1f)" % [y_ground, bsword.position.y])
	var cape2 := main.player.get_node_or_null("QiCape") as Node2D
	check(cape2 != null and cape2.visible and absf(cape2.position.y + Flight.LIFT) < 0.5, "áo choàng và kiếm cùng lên cao")
	F.land(true, true)
	await physics_frame
	await physics_frame
	check(absf(bsword.position.y - y_ground) < 0.5, "hạ xuống: kiếm về chỗ cũ")
	Wardrobe.apply(main.player, main.wardrobe.equipped)
	main.player.position = Vector2(1300, 1500)
	main.cult.qi = main.cult.qi_max()
	F.takeoff()
	main.player.position = Vector2(1300, 1500)
	F.takeoff()

	# --- đổi map thì hạ xuống
	main.switch_map_now("overworld", Vector2(1300, 1500))
	check(not F.active, "đổi bản đồ / qua cổng: tự hạ xuống")

	# --- lượng linh khí và quãng bay ở Trúc Cơ tầng 1 (hợp lý, không vô hạn)
	main.cult.realm = 2
	main.cult.layer = 1
	main.cult.qi = main.cult.qi_max()
	var secs: float = F.seconds_left()
	var dist: float = secs * F.speed(false)
	print("Trúc Cơ tầng 1: %.0f giây bay, %.0f điểm ảnh (bản đồ làng %.0f × %.0f)" % [secs, dist, main.map_size.x, main.map_size.y])
	check(secs > 20.0 and secs < 200.0 and dist > main.map_size.x * 0.8, "một bình linh khí đầy đủ để vượt cả bản đồ nhưng không vô hạn (%.0f giây)" % secs)

	print("FLIGHT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
