extends Node
class_name SwordSchool
## Kiếm phái: 4 skill (J, K, L, U), mở khoá theo cảnh giới, tiêu hao linh khí, hồi chiêu.
## Hoạt ảnh dùng kiếm vẽ riêng + vệt chém + nhân vật lao tới nên không cần khung hình mới cho thân nhân vật.

signal message(text: String)

const SKILLS := [
	{"id": "slash", "name": "Trảm", "key": "J", "cost": 5.0, "cd": 0.45, "need": 0, "desc": "Chém một nhát trước mặt"},
	{"id": "qi", "name": "Kiếm Khí", "key": "K", "cost": 16.0, "cd": 2.2, "need": 2, "desc": "Phóng kiếm khí xuyên thấu"},
	{"id": "fly", "name": "Phi Kiếm", "key": "L", "cost": 30.0, "cd": 6.0, "need": 5, "desc": "Ba phi kiếm lao vào kẻ địch"},
	{"id": "storm", "name": "Vạn Kiếm", "key": "U", "cost": 55.0, "cd": 14.0, "need": 9, "desc": "Vòng kiếm càn quét rồi nổ tung"},
]
# vị trí gốc chuôi, góc (độ), có nằm trước thân không
const SHEATH_POSE := {
	"north": [Vector2(3, -29), 126.0, true],
	"north-east": [Vector2(2, -29), 118.0, true],
	"north-west": [Vector2(5, -29), 134.0, true],
	"south": [Vector2(-4, -30), 50.0, false],
	"south-east": [Vector2(-5, -30), 55.0, false],
	"south-west": [Vector2(-2, -30), 45.0, false],
	"east": [Vector2(-6, -31), 108.0, false],
	"west": [Vector2(6, -31), 72.0, false],
}
const LAYER_NAMES := ["HairBack", "Body", "Clothes", "Shoes", "HairFront"]
const LAYER_BASE := Vector2(0, -29)   # trùng vị trí trong hd/base_character.tscn

var joined := false
var host: Node            # main: có biến `direction` (front/back/left/right)
var player: Node2D
var cult: Cultivation
var hud
var fx_layer: Node2D
var _cd := [0.0, 0.0, 0.0, 0.0]
var _hold: SwordVisual
var _sheath: SwordVisual
var _swing_dir := 1.0
var _combo := 0
var _last_slash := -10.0
var _flash_rect: ColorRect
var _hitstop_active := false
var _swinging := 0.0
var _pose_dir := Vector2.ZERO


func setup(p_host: Node, p_player: Node2D, p_cult: Cultivation, p_hud, p_fx: Node2D) -> void:
	host = p_host
	player = p_player
	cult = p_cult
	hud = p_hud
	fx_layer = p_fx
	_hold = SwordVisual.new()
	_hold.length = 32.0
	_hold.visible = false
	player.add_child(_hold)
	_sheath = SwordVisual.new()
	_sheath.length = 26.0
	_sheath.sheath = true
	_sheath.visible = false
	player.add_child(_sheath)
	hud.build_skillbar(SKILLS)


func step_unlocked(i: int) -> bool:
	return cult.step_index() >= int(SKILLS[i]["need"])


func _process(delta: float) -> void:
	for i in _cd.size():
		_cd[i] = maxf(0.0, float(_cd[i]) - delta)
	_swinging = maxf(0.0, _swinging - delta)
	_update_sheath()
	var infos: Array = []
	for i in SKILLS.size():
		infos.append({
			"cd": float(_cd[i]) / float(SKILLS[i]["cd"]),
			"unlocked": joined and step_unlocked(i),
			"afford": cult.qi >= float(SKILLS[i]["cost"]),
		})
	hud.update_skills(infos)


## Kiếm đeo sau lưng khi không chiến đấu.
func _update_sheath() -> void:
	player.set_meta("sword_drawn", _swinging > 0.0)   # BackSword (thoi trang) an khi kiem dang o tren tay
	_sheath.visible = joined and _swinging <= 0.0 and player.get_node_or_null("BackSword") == null
	if not _sheath.visible:
		return
	# Kiếm đeo chéo trên lưng, chuôi nhô qua vai phải, vỏ chạy xuống hông trái (toạ độ so với chân; vai ~ -28, hông ~ -14).
	# Nhìn từ phía bắc: thấy lưng nên kiếm nằm TRƯỚC thân; các hướng nam: kiếm nằm SAU thân (chỉ thấy chuôi và mũi vỏ).
	var dname := Dir.normalize(host.direction)
	var pose: Array = SHEATH_POSE.get(dname, SHEATH_POSE["south"])
	_sheath.position = pose[0]
	_sheath.rotation = deg_to_rad(float(pose[1]))
	if pose[2]:
		player.move_child(_sheath, player.get_child_count() - 1)
	else:
		player.move_child(_sheath, 0)

## Hướng ngắm: tự nhắm vào mục tiêu gần nhất trong tầm, nếu không thì theo hướng nhìn.
func _aim() -> Vector2:
	var best: Node2D = null
	var best_d := 340.0
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var d: float = t.hit_center().distance_to(player.global_position + Vector2(0, -30))
		if d < best_d:
			best_d = d
			best = t
	if best:
		return (best.hit_center() - (player.global_position + Vector2(0, -30))).normalized()
	return Dir.to_vector(host.direction)


func _face(aim: Vector2) -> void:
	host.direction = Dir.from_vector(aim, host.direction)


func cast(i: int) -> void:
	if not joined:
		message.emit("Hãy bái sư ở Kiếm sư để học kiếm.")
		return
	if not step_unlocked(i):
		message.emit("%s chưa mở khoá (cần cảnh giới cao hơn)." % SKILLS[i]["name"])
		return
	if float(_cd[i]) > 0.0:
		return
	var cost: float = SKILLS[i]["cost"]
	if cult.qi < cost:
		message.emit("Linh khí không đủ.")
		return
	cult.qi -= cost
	_cd[i] = SKILLS[i]["cd"]
	var aim := _aim()
	_face(aim)
	Sfx.play(str(SKILLS[i]["id"]))
	match SKILLS[i]["id"]:
		"slash": _do_slash(aim)
		"qi": _do_qi(aim)
		"fly": _do_fly(aim)
		"storm": _do_storm()


func _power(base: float) -> float:
	return base * (1.0 + 0.12 * cult.step_index())


func hit_target(t: Node, dmg: float, col := Color(0.6, 0.95, 1.0), big := false) -> void:
	if t.take_hit(dmg, player.global_position):
		Sfx.play("hit_big" if big else "hit", randf_range(0.92, 1.08))
		impact(t.hit_center(), col, big)
		if big:
			shake(5.0, 0.15)
			hitstop(0.045)
		else:
			shake(2.0, 0.08)


## Hiệu ứng trúng đòn: dấu X, vòng sóng, quầng sáng, tia lửa.
func impact(pos: Vector2, col: Color, big := false) -> void:
	Fx.cross(fx_layer, pos, col, 42.0 if big else 30.0)
	Fx.ring(fx_layer, pos + Vector2(0, 28), 4.0, 58.0 if big else 38.0, col, 0.3, 0.55, 3.0)
	Fx.glow(fx_layer, pos, 14.0, 92.0 if big else 60.0, Color(1, 1, 1), 0.2)
	Fx.burst(fx_layer, pos, col, 18 if big else 12, 150.0 if big else 110.0, 0.4)


func spark(pos: Vector2) -> void:
	Fx.burst(fx_layer, pos, Color(0.55, 0.92, 1.0), 12, 130.0, 0.35)


## Rung màn hình, giảm dần về 0.
func shake(strength: float, dur: float) -> void:
	if host == null or host.camera == null:
		return
	var tw := create_tween()
	tw.tween_method(_apply_shake.bind(strength), 1.0, 0.0, dur)


func _apply_shake(k: float, strength: float) -> void:
	host.camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k


## Loé sáng toàn màn hình rồi tắt.
func flash(col: Color, alpha: float, dur: float) -> void:
	if _flash_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 15
		add_child(layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.color = Color(1, 1, 1, 0)
		layer.add_child(_flash_rect)
	_flash_rect.color = Color(col, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)


## Khựng hình một thoáng khi trúng đòn mạnh.
func hitstop(dur: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	get_tree().create_timer(dur, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	Engine.time_scale = float(host.debug_speed) if host != null else 1.0
	_hitstop_active = false

# ------------------------------------------------------------------ nhân vật lao tới khi ra chiêu
func _lunge(dir: Vector2, amount: float) -> void:
	_pose_dir = dir
	var tw := create_tween()
	tw.tween_method(_set_pose, 0.0, amount, 0.07)
	tw.tween_method(_set_pose, amount, 0.0, 0.14)


func _set_pose(v: float) -> void:
	for n in LAYER_NAMES:
		var node := player.get_node_or_null(n) as Node2D
		if node:
			node.position = LAYER_BASE + _pose_dir * v
			node.rotation = signf(_pose_dir.x) * 0.012 * v


func _swing_sword(aim: Vector2, big := false) -> void:
	_swinging = 0.3
	_hold.visible = true
	_hold.glow = 0.9 if big else 0.5
	_hold.position = Vector2(aim.x * 8.0, -34.0 + aim.y * 4.0)
	var base := aim.angle()
	var s := _swing_dir
	_swing_dir = -_swing_dir
	_hold.rotation = base - 1.4 * s
	var tw := create_tween()
	tw.tween_property(_hold, "rotation", base + 1.4 * s, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _hold.visible = false)


# ------------------------------------------------------------------ các skill
func _cast_flash(col: Color) -> void:
	var c := player.global_position
	Fx.ring(fx_layer, c, 6.0, 44.0, col, 0.3, 0.55, 3.0)
	Fx.glow(fx_layer, c + Vector2(0, -34), 10.0, 58.0, col, 0.22)


func _slash_layer(center: Vector2, aim: Vector2, radius: float, col: Color, delay: float, thick: float, flip: bool) -> void:
	var fx := preload("res://scripts/fx_slash.gd").new()
	fx.position = center + aim * 14.0
	fx.rotation = aim.angle()
	fx.radius = radius
	fx.color = col
	fx.thickness = thick
	if flip:
		fx.a0 = 1.25
		fx.a1 = -1.25
	if delay <= 0.0:
		fx_layer.add_child(fx)
		fx.play(0.28)
	else:
		get_tree().create_timer(delay).timeout.connect(func():
			fx_layer.add_child(fx)
			fx.play(0.28))


## Tia lửa bắn rải dọc theo cung chém.
func _arc_sparks(center: Vector2, aim: Vector2, radius: float, flip: bool, col: Color) -> void:
	var s := -1.0 if flip else 1.0
	for i in 8:
		var f := float(i) / 7.0
		var ang := aim.angle() + lerpf(-1.15, 1.15, f) * s
		var pos := center + aim * 14.0 + Vector2(cos(ang), sin(ang)) * radius
		get_tree().create_timer(0.022 * i).timeout.connect(Fx.burst.bind(fx_layer, pos, col, 5, 100.0, 0.28, 2.6))


## Chờ animation thân đạt khung `frame_target` rồi gọi cb (đồng bộ hiệu ứng với động tác). Có đồng hồ dự phòng.
func _at_frame(frame_target: int, cb: Callable) -> void:
	var body := player.get_node("Body") as AnimatedSprite2D
	var st := {"done": false, "h": Callable()}
	st["h"] = func():
		if st["done"] or body.frame < frame_target:
			return
		st["done"] = true
		if body.frame_changed.is_connected(st["h"]):
			body.frame_changed.disconnect(st["h"])
		cb.call()
	body.frame_changed.connect(st["h"])
	get_tree().create_timer(0.9).timeout.connect(func():
		if not st["done"]:
			st["done"] = true
			if body.frame_changed.is_connected(st["h"]):
				body.frame_changed.disconnect(st["h"])
			cb.call())


## Trảm: chuỗi 3 nhát. Nhát thứ 3 là đòn chém chéo chữ X, rộng hơn và có sóng xung kích.
## Nếu nhân vật có animation "slash" cho hướng này thì phát nó và chờ đến khung trúng đòn (khung 3, khung có vệt chém) mới bung hiệu ứng.
func _do_slash(aim: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_combo = (_combo + 1) % 3 if now - _last_slash < 0.9 else 0
	_last_slash = now
	var big := _combo == 2
	var used := false
	if player.has_method("play_oneshot"):
		used = player.play_oneshot("slash", host.direction, 1.0)
	if used:
		_swing_dir = -_swing_dir
		var flip_a := _swing_dir > 0.0
		_swinging = 0.6          # ẩn kiếm đeo lưng; kiếm đang nằm trong animation thân
		_hold.visible = false
		_at_frame(3, func(): _slash_effects(aim, big, flip_a))
	else:
		_lunge(aim, 12.0 if big else 8.0)
		_swing_sword(aim, big)
		_slash_effects(aim, big, _swing_dir > 0.0)   # _swing_sword vừa đảo hướng nên ngược với chiều kiếm vừa quét


func _slash_effects(aim: Vector2, big: bool, flip: bool) -> void:
	var center := player.global_position + Vector2(0, -30)
	var rad := 84.0 if big else 66.0
	_slash_layer(center, aim, rad, Color(0.55, 0.9, 1.0), 0.0, 0.46, flip)
	_slash_layer(center, aim, rad * 0.86, Color(1, 1, 1), 0.02, 0.30, flip)
	_slash_layer(center, aim, rad * 1.18, Color(0.6, 0.7, 1.0), 0.05, 0.22, flip)
	if big:
		_slash_layer(center, aim, rad * 1.05, Color(1.0, 0.9, 0.6), 0.07, 0.40, not flip)
		Fx.ring(fx_layer, player.global_position, 10.0, 125.0, Color(0.6, 0.9, 1.0), 0.4, 0.55, 5.0)
		shake(5.0, 0.18)
	_cast_flash(Color(0.6, 0.9, 1.0))
	_arc_sparks(center, aim, rad, flip, Color(0.7, 0.95, 1.0))
	var reach := 125.0 if big else 100.0
	var half := 1.6 if big else 1.25
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var v: Vector2 = t.hit_center() - center
		if v.length() < reach and absf(angle_difference(v.angle(), aim.angle())) < half:
			hit_target(t, _power(24.0 if big else 14.0), Color(0.6, 0.95, 1.0), big)

## Dùng chung animation vung kiếm "slash" cho mọi chiêu: phát animation, đến khung `hit_frame` thì gọi cb. Trả về false nếu không có animation cho hướng này.
func _swing_then(speed: float, hit_frame: int, cb: Callable) -> bool:
	if not player.has_method("play_oneshot"):
		return false
	if not player.play_oneshot("slash", host.direction, speed):
		return false
	_swinging = 0.7
	_hold.visible = false
	_at_frame(hit_frame, cb)
	return true


func _do_qi(aim: Vector2) -> void:
	var spawn := func():
		_cast_flash(Color(0.7, 0.75, 1.0))
		var p := preload("res://scripts/skill_projectile.gd").new()
		p.school = self
		p.damage = _power(26.0)
		p.vel = aim * 600.0
		p.position = player.global_position + Vector2(0, -30) + aim * 34.0
		fx_layer.add_child(p)
	if not _swing_then(1.0, 3, spawn):
		_lunge(aim, 9.0)
		_swing_sword(aim, true)
		spawn.call()


func _do_fly(aim: Vector2) -> void:
	var spawn := func():
		_cast_flash(Color(1.0, 0.9, 0.55))
		Fx.ring(fx_layer, player.global_position, 8.0, 95.0, Color(1.0, 0.88, 0.5), 0.5, 0.55, 4.0)
		var tints := [Color(0.6, 0.9, 1.0), Color(1.0, 0.88, 0.5), Color(0.82, 0.65, 1.0)]
		var targets: Array = []
		for t in get_tree().get_nodes_in_group("targets"):
			if t.alive and t.hit_center().distance_to(player.global_position) < 420.0:
				targets.append(t)
		targets.sort_custom(func(a, b): return a.hit_center().distance_to(player.global_position) < b.hit_center().distance_to(player.global_position))
		for i in 3:
			var s := preload("res://scripts/flying_sword.gd").new()
			s.school = self
			s.player = player
			s.phase_angle = TAU * i / 3.0
			s.damage = _power(18.0)
			s.aim = aim
			s.tint = tints[i]
			s.orbit_time = 0.5 + 0.1 * i
			if not targets.is_empty():
				s.target = targets[i % targets.size()]
			fx_layer.add_child(s)
	if not _swing_then(0.8, 2, spawn):
		_lunge(-aim, 3.0)
		spawn.call()


func _do_storm() -> void:
	var spawn := func():
		var s := preload("res://scripts/sword_storm.gd").new()
		s.school = self
		s.player = player
		s.damage = _power(30.0)
		fx_layer.add_child(s)
	if not _swing_then(0.7, 2, spawn):
		_lunge(Vector2.UP, 5.0)
		_swing_sword(Vector2.UP, true)
		spawn.call()

func to_dict() -> Dictionary:
	return {"joined": joined}


func from_dict(d: Dictionary) -> void:
	joined = bool(d.get("joined", false))
