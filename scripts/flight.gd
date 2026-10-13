extends Node
class_name Flight
## Phi hành (ngự không): mở khoá khi đạt Trúc Cơ, bay bằng linh khí.
##  - Phím X bay lên / hạ xuống. Bay nhanh hơn đi bộ, lướt qua cây, nhà, ao, vách; không qua được biên bản đồ.
##  - Tốn linh khí mỗi giây (Trúc Cơ tầng 1 đắt nhất, cảnh giới càng cao càng rẻ); đang bay không hồi linh khí, không thiền,
##    không ra chiêu, không tương tác. Hết linh khí thì rơi xuống: bị đẩy ra chỗ trống gần nhất và chịu một ít sát thương.
##  - Khi bay không có hiệu ứng dưới chân (không mây, không vệt); chỉ có gió phía sau lưng (BackWind).
##  - Cấm không trong sơn môn (map tông môn) và bản đồ chiến sự.
##  - Không lưu trạng thái: tải game hay qua cổng thì hạ xuống.

const UNLOCK_REALM := 2            # Cultivation.REALMS[2] = Trúc Cơ
const UNLOCK_STEP := 9             # step_index() của Trúc Cơ tầng 1
const SPEED_MULT := 1.9            # so với đi bộ
const RUN_MULT := 1.35             # giữ Shift
const LIFT := 26.0                 # nâng thân người lên bao nhiêu điểm ảnh
const BASE_COST := 8.0             # linh khí / giây ở Trúc Cơ tầng 1
const MIN_COST := 3.0
const COST_DROP_PER_STEP := 0.25
const TAKEOFF_QI := 40.0           # cần tối thiểu bao nhiêu linh khí mới cất cánh được
const WARN_FRACTION := 0.2
const FLY_Z := 40                  # thứ tự vẽ khi bay (trên mọi vật thể)
const FALL_DAMAGE := 0.08          # tỉ lệ khí huyết tối đa mất khi rơi vì hết linh khí
## Né đòn khi bay ("lướt gió"): thân nhẹ nên đòn có xác suất trượt, mỗi lần né tốn linh khí.
const EVADE_BASE := 0.30
const EVADE_AGILITY_K := 0.004     # mỗi điểm Linh Hoạt hơn/kém 50
const EVADE_MIN := 0.15
const EVADE_MAX := 0.50
const EVADE_QI := 4.0
const EVADE_COOLDOWN := 0.35       # giây, tránh né liên tiếp trong cùng một loạt đòn

signal changed(active: bool)

var main: Node
var active := false
var debug_unlock := false
var _lift := 0.0
var _warned := false
var _layers := ["HairBack", "Body", "Clothes", "Shoes", "HairFront"]
var evades := 0
var _back: BackWind                 # hiệu ứng gió phía sau lưng nhân vật
var evade_roll := -1.0             # >= 0: ép kết quả tung xúc xắc (dành cho test)
var _evade_cd := 0.0
var _t := 0.0
var _last_pos := Vector2.ZERO
var _whoosh_t := 0.0


func unlocked() -> bool:
	return debug_unlock or int(main.cult.realm) >= UNLOCK_REALM


## Linh khí tiêu mỗi giây theo cảnh giới hiện tại.
func qi_cost() -> float:
	var step: int = main.cult.step_index()
	return clampf(BASE_COST - COST_DROP_PER_STEP * float(step - UNLOCK_STEP), MIN_COST, BASE_COST)


func seconds_left() -> float:
	return float(main.cult.qi) / maxf(qi_cost(), 0.01)


## Cấm không: map tông môn (sect_*), bản đồ chiến sự.
func allowed_here() -> bool:
	var id := str(main.current_map)
	if id.begins_with("sect_") or bool(main.map_def.get("war", false)):
		return false
	return true


func speed(run: bool) -> float:
	return float(main.WALK_SPEED) * SPEED_MULT * (RUN_MULT if run else 1.0) * float(main.set_speed_mult)


func toggle() -> void:
	if active:
		land(false)
	else:
		takeoff()


func takeoff() -> bool:
	if active:
		return true
	if not unlocked():
		main.hud.toast("Chưa đủ cảnh giới: đạt Trúc Cơ mới ngự không được.")
		return false
	if not allowed_here():
		main.hud.toast("Nơi này cấm ngự không.")
		return false
	if main._ui_blocked() or main._dead or main.traveling:
		return false
	if float(main.cult.qi) < TAKEOFF_QI:
		main.hud.toast("Linh khí quá cạn (cần ít nhất %d) để ngự không." % int(TAKEOFF_QI))
		return false
	main.meditating = false
	active = true
	_warned = false
	_make_back()
	main.player.z_index = FLY_Z   # bay trên cây, nhà: luôn vẽ đè lên vật thể
	_last_pos = main.player.position
	var p: Vector2 = main.player.position
	Fx.ring(main.fx_layer, p, 6.0, 70.0, Color(0.7, 0.92, 1.0), 0.45, 0.55, 4.0)
	Sfx.play("fly")
	main.hud.toast("Ngự không! Tiêu %.1f linh khí mỗi giây." % qi_cost())
	changed.emit(true)
	return true


## Hạ xuống. Nếu bên dưới là chỗ không đứng được thì không hạ (trừ khi bị buộc): phải bay tới chỗ trống.
func land(forced: bool, silent := false) -> bool:
	if not active:
		return true
	var p: Vector2 = main.player.position
	var blocked: bool = main._is_blocked(Rect2(p.x - 12, p.y - 8, 24, 10))
	if blocked and not forced:
		main.hud.toast("Dưới chân có vật cản, bay tới chỗ trống rồi hạ xuống.")
		return false
	if blocked:
		main.player.position = _nearest_free(p)
	active = false
	_remove_back()
	main.player.z_index = 0
	_apply_lift(0.0)
	_lift = 0.0
	if not silent:
		var q: Vector2 = main.player.position
		Fx.ring(main.fx_layer, q, 4.0, 46.0, Color(0.8, 0.9, 1.0), 0.3, 0.55, 3.0)
		Fx.burst(main.fx_layer, q + Vector2(0, -4), Color(0.85, 0.95, 1.0), 8, 70.0, 0.35, 2.4)
	changed.emit(false)
	return true


## Gọi mỗi khung hình vật lý: trừ linh khí, cảnh báo, rơi khi hết, nâng hạ thân người mượt.
func tick(delta: float) -> void:
	_t += delta
	_evade_cd = maxf(0.0, _evade_cd - delta)
	var target := LIFT if active else 0.0
	if not is_equal_approx(_lift, target):
		_lift = move_toward(_lift, target, 90.0 * delta)
		_apply_lift(_lift)
	if not active:
		return
	# nhân vật đứng yên trên không; gió và khí tuôn ra phía sau lưng, mạnh lên khi bay nhanh
	var moved: float = main.player.position.distance_to(_last_pos)
	_last_pos = main.player.position
	var fast := moved / maxf(delta, 0.0001) > 120.0
	if _back != null:
		_back.facing = Dir.to_vector(main.direction)
		_back.lift = _lift
		_back.intensity = move_toward(_back.intensity, 1.0 if fast else 0.3, delta * 4.0)
	_whoosh_t -= delta
	if fast and _whoosh_t <= 0.0:
		_whoosh_t = 1.1
		Sfx.play("fly", 1.0 + randf() * 0.1, -9.0)
	if main._dead or not allowed_here() or main.traveling:
		land(true, true)
		return
	main.cult.qi = maxf(0.0, float(main.cult.qi) - qi_cost() * delta)
	main.cult.changed.emit()
	var frac: float = float(main.cult.qi) / maxf(float(main.cult.qi_max()), 1.0)
	if frac <= WARN_FRACTION and not _warned:
		_warned = true
		main.hud.toast("Linh khí sắp cạn! Mau hạ xuống.")
	if float(main.cult.qi) <= 0.0:
		_fall()
		return


## Xác suất né mỗi đòn khi đang bay (theo Linh Hoạt).
func evade_chance() -> float:
	var agi := 50.0
	var rt = main.get("cultivation_v1")
	if rt != null and not (rt.state.origin as Dictionary).is_empty():
		agi = float(rt.state.origin.attributes.agility)
	return clampf(EVADE_BASE + (agi - 50.0) * EVADE_AGILITY_K, EVADE_MIN, EVADE_MAX)


## Gọi khi một đòn sắp trúng người chơi. Trả true nếu né được (đòn bị huỷ). `from`: nguồn đòn.
func try_evade(from: Vector2) -> bool:
	if not active or _evade_cd > 0.0 or float(main.cult.qi) < EVADE_QI:
		return false
	var roll := evade_roll if evade_roll >= 0.0 else randf()
	if roll >= evade_chance():
		return false
	_evade_cd = EVADE_COOLDOWN
	evades += 1
	main.cult.qi = maxf(0.0, float(main.cult.qi) - EVADE_QI)
	main.cult.changed.emit()
	var p: Vector2 = main.player.position
	var away: Vector2 = (p - from).normalized() if from.distance_to(p) > 1.0 else Vector2.ZERO
	SkillFx.afterimage(main, Color(1.0, 1.0, 1.0), 0.75, 0.4)
	Fx.ring(main.fx_layer, p, 6.0, 58.0, Color(0.85, 0.97, 1.0), 0.35, 0.55, 3.0)
	Fx.cross(main.fx_layer, p + Vector2(0, -34) - away * 14.0, Color(0.9, 0.98, 1.0), 38.0)
	Fx.burst(main.fx_layer, p + Vector2(0, -30), Color(0.75, 0.93, 1.0), 10, 150.0, 0.35, 2.2)
	main.float_text(p + Vector2(0, -92), "Lướt gió!", Color(0.8, 0.95, 1.0))
	Sfx.play("fly", 1.25)
	# trượt nhẹ sang bên một đoạn như thật sự tránh đòn
	if away != Vector2.ZERO:
		var tw: Tween = main.player.create_tween()
		var dest: Vector2 = main.player.position + away * 26.0
		dest = dest.clamp(Vector2(20, 20), main.map_size - Vector2(20, 10))
		tw.tween_property(main.player, "position", dest, 0.12).set_ease(Tween.EASE_OUT)
	return true


## Di chuyển khi bay: chỉ bị giới hạn bởi biên bản đồ (bay qua mọi vật cản).
func move(step: Vector2) -> void:
	var np: Vector2 = main.player.position + step
	main.player.position = np.clamp(Vector2(20, 20), main.map_size - Vector2(20, 10))


func _fall() -> void:
	main.hud.toast("Hết linh khí, rơi xuống!")
	land(true)
	var dmg: float = float(main.vitals.max_hp) * FALL_DAMAGE
	main.vitals.take(maxf(dmg, 1.0), main.player.position)


## Chỗ trống gần nhất quanh p (xoắn ốc).
func _nearest_free(p: Vector2) -> Vector2:
	for r in range(16, 520, 16):
		for i in 16:
			var q: Vector2 = p + Vector2.from_angle(TAU * float(i) / 16.0) * float(r)
			q = q.clamp(Vector2(20, 20), main.map_size - Vector2(20, 10))
			if not main._is_blocked(Rect2(q.x - 12, q.y - 8, 24, 10)):
				return q
	return p


## Nâng toàn bộ phần thân người lên v: các lớp sprite (offset), phụ trang / hào quang / áo choàng (vị trí), kiếm đeo lưng (meta);
## bóng dưới chân nhỏ và nhạt dần. Áo choàng linh khí và kiếm đeo lưng luôn gắn theo thân người khi bay.
func _apply_lift(v: float) -> void:
	var pl: Node2D = main.player
	for n in _layers:
		var s := pl.get_node_or_null(n) as AnimatedSprite2D
		if s != null:
			s.offset = Vector2(s.offset.x, -v)
	for n in ["OutfitAura", "HeadGear", "WaistGear"]:
		var node := pl.get_node_or_null(n) as Node2D
		if node != null:
			node.position.y = -v
	var cape := pl.get_node_or_null("QiCape") as Node2D
	if cape != null:
		cape.position.y = -v   # áo choàng linh khí theo thân người lên cao, vẫn buông sau vai
	pl.set_meta("fly_lift", v)
	var sh := pl.get_node_or_null("PlayerShadow") as Node2D
	if sh != null:
		var k := clampf(v / LIFT, 0.0, 1.0)
		sh.scale = Vector2.ONE * lerpf(1.0, 0.65, k)
		sh.modulate.a = lerpf(1.0, 0.55, k)


func _make_back() -> void:
	_remove_back()
	_back = BackWind.new()
	main.player.add_child(_back)


func _remove_back() -> void:
	if _back != null and is_instance_valid(_back):
		_back.queue_free()
	_back = null


## Gió tuôn ra phía sau lưng (ngược hướng nhân vật đang quay): chỉ có vệt gió cuộn, không quầng sáng, không hạt sáng.
## Nhân vật không đổi dáng (đứng yên trên không); toàn bộ chuyển động nằm ở hiệu ứng này.
class BackWind extends Node2D:
	var facing := Vector2.DOWN
	var lift := 0.0
	var intensity := 0.3
	var _t := 0.0

	func _ready() -> void:
		material = Fx.additive()

	func _process(delta: float) -> void:
		_t += delta * (1.0 + 2.0 * intensity)
		# nhìn xuống / ngang thì phía sau lưng nằm sau thân người; nhìn lên thì phía sau lưng nằm trước thân (vẽ đè lên)
		z_index = -1 if facing.y >= -0.2 else 2
		queue_redraw()

	func _draw() -> void:
		var back := -facing
		if back == Vector2.ZERO:
			back = Vector2.UP
		var side := Vector2(-back.y, back.x)
		var origin := Vector2(0, -30.0 - lift) + back * 12.0
		var a := 0.25 + 0.45 * intensity
		# vệt gió cuộn: các đoạn trôi dần ra xa rồi mờ đi
		for i in 6:
			var off := (float(i) - 2.5) * 6.5
			var phase := fposmod(_t * 1.1 + float(i) * 0.37, 1.0)
			var len := (16.0 + 34.0 * intensity) * (0.6 + 0.4 * sin(float(i) * 1.7 + 1.0))
			var start := origin + side * off + back * (6.0 + phase * 38.0 * (0.5 + intensity))
			var fade := (1.0 - phase) * a
			var col := Color(0.8, 0.95, 1.0, clampf(fade, 0.0, 1.0))
			draw_line(start, start + back * len, col, 2.0 if i % 2 == 0 else 1.0)
			draw_line(start + back * len, start + back * len * 1.6 + side * sin(_t * 6.0 + float(i)) * 3.0, Color(col, col.a * 0.5), 1.0)
