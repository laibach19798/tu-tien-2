extends Node2D
## Vạn Kiếm Quy Tông (tuyệt kỹ), 4 giai đoạn:
##  1. Triệu hồi: vòng sáng nở ra dưới chân, 16 thanh kiếm xoáy bay lên từ người.
##  2. Kiếm trận: hai vòng kiếm xoay ngược chiều, mỗi nhịp gây sát thương và nổ vòng sáng.
##  3. Hội tụ: kiếm bay vút lên cao rồi thu về một điểm.
##  4. Mưa kiếm: kiếm giáng xuống từng đợt vào kẻ địch, kết thúc bằng sóng xung kích khổng lồ.

var school
var player: Node2D
var damage := 30.0
const T_SUMMON := 0.55
const T_ORBIT := 1.55
const T_GATHER := 0.5
const T_RAIN := 0.9
const INNER := 8
const OUTER := 8

var _t := 0.0
var _tick := 0.0
var _swords: Array = []     # {node, ring (0/1), idx}
var _rain_started := false
var _rain_count := 0
var _rain_timer := 0.0
var _final_done := false
var _gold := Color(1.0, 0.88, 0.5)
var _cyan := Color(0.55, 0.92, 1.0)


func _ready() -> void:
	material = Fx.additive()
	global_position = player.global_position + Vector2(0, -30)
	for ring_i in 2:
		var n := INNER if ring_i == 0 else OUTER
		for i in n:
			var s := SwordVisual.new()
			s.length = 34.0 if ring_i == 0 else 40.0
			s.glow = 0.9
			s.glow_color = _cyan if ring_i == 0 else _gold
			s.visible = false
			add_child(s)
			Fx.trail(get_parent(), s, s.glow_color, 7.0, 0.22)
			_swords.append({"node": s, "ring": ring_i, "idx": i})
	var foot := player.global_position
	Fx.ring(get_parent(), foot, 10.0, 150.0, _cyan, 0.7, 0.55, 5.0)
	Fx.ring(get_parent(), foot, 6.0, 110.0, _gold, 0.6, 0.55, 3.0)
	Fx.glow(get_parent(), foot + Vector2(0, -20), 30.0, 200.0, Color(0.6, 0.9, 1.0), 0.5)
	school.shake(4.0, 0.25)


func _total() -> float:
	return T_SUMMON + T_ORBIT + T_GATHER + T_RAIN + 0.6


func _process(delta: float) -> void:
	_t += delta
	var center := player.global_position + Vector2(0, -30)
	global_position = center
	var phase_t := _t
	var summon_end := T_SUMMON
	var orbit_end := summon_end + T_ORBIT
	var gather_end := orbit_end + T_GATHER
	var rain_end := gather_end + T_RAIN

	for e in _swords:
		var s: SwordVisual = e["node"]
		var ring_i: int = e["ring"]
		var idx: int = e["idx"]
		var n := INNER if ring_i == 0 else OUTER
		var dir := 1.0 if ring_i == 0 else -1.0
		var base_r := 58.0 if ring_i == 0 else 100.0
		var ang := dir * _t * (7.5 if ring_i == 0 else 5.5) + TAU * idx / n
		var r := base_r
		var lift := 0.0
		var vis := true
		if phase_t < summon_end:                                   # 1. bay xoáy lên từ người
			var k := phase_t / summon_end
			var e1 := 1.0 - pow(1.0 - k, 3.0)
			r = base_r * e1
			lift = -50.0 * (1.0 - e1)
			ang += (1.0 - k) * 4.0 * dir
		elif phase_t < orbit_end:                                  # 2. kiếm trận
			r = base_r * (1.0 + 0.06 * sin(_t * 9.0 + idx))
		elif phase_t < gather_end:                                 # 3. hội tụ vút lên cao
			var k2 := (phase_t - orbit_end) / T_GATHER
			var e2 := k2 * k2
			r = lerpf(base_r, 6.0, e2)
			lift = lerpf(0.0, -190.0, e2)
		else:                                                      # 4. kiếm đã rời đi để làm mưa kiếm
			vis = false
		s.visible = vis
		if vis:
			s.position = Vector2(cos(ang) * r, sin(ang) * r * 0.55 + lift)
			s.rotation = ang + PI / 2.0 if phase_t < orbit_end else (-PI / 2.0 if phase_t >= orbit_end else 0.0)
			s.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(ang))

	# nhịp sát thương và vòng sáng trong giai đoạn kiếm trận
	if phase_t >= summon_end and phase_t < orbit_end:
		_tick += delta
		if _tick >= 0.26:
			_tick = 0.0
			Fx.ring(get_parent(), player.global_position, 30.0, 135.0, _cyan, 0.4, 0.55, 3.0)
			for t in get_tree().get_nodes_in_group("targets"):
				if t.alive and t.hit_center().distance_to(center) < 150.0:
					school.hit_target(t, damage * 0.4, _cyan, false)
	# bắt đầu mưa kiếm
	if phase_t >= gather_end and not _rain_started:
		_rain_started = true
		Fx.glow(get_parent(), center + Vector2(0, -150), 20.0, 220.0, Color(1, 0.95, 0.8), 0.35)
		school.shake(3.0, 0.2)
	if _rain_started and phase_t < rain_end:
		_rain_timer += delta
		while _rain_timer >= 0.055:
			_rain_timer -= 0.055
			_drop_sword(center)
	if phase_t >= rain_end and not _final_done:
		_final_done = true
		_final_burst(center)
	queue_redraw()
	if _t >= _total():
		queue_free()


func _drop_sword(center: Vector2) -> void:
	# ưu tiên rơi vào kẻ địch, nếu không có thì rơi quanh người chơi
	var targets: Array = []
	for t in get_tree().get_nodes_in_group("targets"):
		if t.alive and t.hit_center().distance_to(center) < 260.0:
			targets.append(t)
	var land: Vector2
	if not targets.is_empty() and _rain_count % 2 == 0:
		var tg: Node2D = targets[randi() % targets.size()]
		land = tg.global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-6.0, 6.0))
	else:
		var a := randf() * TAU
		land = player.global_position + Vector2(cos(a), sin(a) * 0.55) * randf_range(40.0, 170.0)
	_rain_count += 1
	var sword := SwordVisual.new()
	sword.length = 46.0
	sword.glow = 1.0
	sword.glow_color = _gold if _rain_count % 3 == 0 else _cyan
	sword.rotation = PI / 2.0
	sword.material = Fx.additive()
	sword.global_position = land + Vector2(randf_range(-6.0, 6.0), -330.0)
	get_parent().add_child(sword)
	Fx.trail(get_parent(), sword, sword.glow_color, 9.0, 0.2)
	var col := sword.glow_color
	var tw := sword.create_tween()
	tw.tween_property(sword, "global_position", land + Vector2(0, -6), 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): _land(land, col))
	tw.tween_interval(0.25)
	tw.tween_property(sword, "modulate:a", 0.0, 0.2)
	tw.tween_callback(sword.queue_free)


func _land(pos: Vector2, col: Color) -> void:
	Fx.ring(get_parent(), pos, 4.0, 46.0, col, 0.3, 0.55, 3.0)
	Fx.burst(get_parent(), pos + Vector2(0, -6), col, 10, 110.0, 0.35, 3.0)
	Fx.glow(get_parent(), pos + Vector2(0, -10), 10.0, 56.0, Color(1, 1, 1), 0.2)
	for t in get_tree().get_nodes_in_group("targets"):
		if t.alive and t.global_position.distance_to(pos) < 60.0:
			school.hit_target(t, damage * 0.55, col, false)


func _final_burst(center: Vector2) -> void:
	var foot := player.global_position
	Fx.ring(get_parent(), foot, 20.0, 260.0, _cyan, 0.7, 0.55, 7.0)
	Fx.ring(get_parent(), foot, 10.0, 200.0, _gold, 0.6, 0.55, 5.0)
	Fx.ring(get_parent(), foot, 4.0, 140.0, Color(1, 1, 1), 0.5, 0.55, 3.0)
	Fx.glow(get_parent(), center, 40.0, 330.0, Color(0.85, 0.95, 1.0), 0.5)
	Fx.burst(get_parent(), center, _gold, 40, 260.0, 0.7, 4.0)
	school.shake(10.0, 0.45)
	school.flash(Color(0.85, 0.95, 1.0), 0.45, 0.35)
	school.hitstop(0.08)
	for t in get_tree().get_nodes_in_group("targets"):
		if t.alive and t.hit_center().distance_to(center) < 230.0:
			school.hit_target(t, damage * 1.5, _gold, true)


func _draw() -> void:
	# vòng sáng nhẹ dưới chân trong lúc kiếm trận xoay
	var summon_end := T_SUMMON
	var orbit_end := summon_end + T_ORBIT
	if _t < summon_end or _t > orbit_end + T_GATHER:
		return
	var k := 1.0
	if _t < summon_end + 0.2:
		k = (_t - summon_end + 0.2) / 0.4
	elif _t > orbit_end:
		k = 1.0 - (_t - orbit_end) / T_GATHER
	k = clampf(k, 0.0, 1.0)
	draw_set_transform(Vector2(0, 30), 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, 104.0, 0.0, TAU, 72, Color(_cyan, 0.35 * k), 3.0)
	draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 56, Color(_gold, 0.30 * k), 2.0)
	draw_circle(Vector2.ZERO, 62.0, Color(_cyan, 0.06 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
