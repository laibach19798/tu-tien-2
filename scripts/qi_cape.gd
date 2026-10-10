extends Node2D
## Áo choàng linh khí của tiên bào: vài dải ánh sáng dài từ vai, bay theo chuyển động nhân vật rồi nhạt dần.
## Không phải vải thật nên không có đường cắt/rách; cộng sáng như hào quang và được bù màu đêm.
## Wardrobe._set_aura tạo node này khi aura có "qi_cape": true. Toạ độ theo ô 64px của nhân vật, gốc ở chân.

const STRANDS := 6
const POINTS := 13
const SEG := 3.6
const SHOULDER := Vector2(0, -30)
const STIFF := 70.0
const DAMP := 8.5

var color := Color(0.6, 0.9, 1.0)
var color2 := Color(1.0, 0.95, 0.7)
var _pos: Array = []      # STRANDS x POINTS
var _vel: Array = []
var _last_gpos := Vector2.ZERO
var _t := 0.0
var _canvas_mod: CanvasModulate
var _find_timer := 0.0
var _alpha := 1.0       # dải ở trước thân (hướng bắc) thì mờ hơn để không che người


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	for s in STRANDS:
		_pos.append([])
		_vel.append([])
		for i in POINTS:
			_pos[s].append(Vector2.ZERO)
			_vel[s].append(Vector2.ZERO)
	_last_gpos = get_parent().global_position
	_snap()


func configure(cfg: Dictionary) -> void:
	color = cfg.get("color", color)
	color2 = cfg.get("color2", color2)
	queue_redraw()


func _facing_vec() -> Vector2:
	var f := str(get_parent().get("facing")) if get_parent().get("facing") != null else "south"
	var i := Dir.ALL.find(f)
	if i < 0:
		return Vector2(0, 1)
	var table := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
	return (table[i] as Vector2).normalized()


## Điểm neo của dải s (trải đều ngang vai; nhìn ngang thì dồn lại) và hướng buông xuống của nó.
func _anchor(s: int, f: Vector2) -> Vector2:
	var u := (float(s) / float(STRANDS - 1)) * 2.0 - 1.0       # -1 .. 1
	var half := 2.5 + 6.5 * absf(f.y)
	return SHOULDER + Vector2(u * half - f.x * 3.0, 0.0)


func _rest(s: int, i: int, f: Vector2) -> Vector2:
	var u := (float(s) / float(STRANDS - 1)) * 2.0 - 1.0
	var t := float(i) / float(POINTS - 1)
	var a := _anchor(s, f)
	# buông xuống và hơi xoè ra ngoài; nhìn ngang thì buông về phía sau lưng
	var spread := Vector2(u * 9.0 * absf(f.y) * t, 0.0)
	var back := Vector2(-f.x * 11.0 * t, 0.0)
	return a + Vector2(0.0, i * SEG * 0.85) + spread + back


func _snap() -> void:
	var f := _facing_vec()
	for s in STRANDS:
		for i in POINTS:
			_pos[s][i] = _rest(s, i, f)


func _night_boost() -> Color:
	if not is_instance_valid(_canvas_mod):
		_canvas_mod = null
		if _find_timer <= 0.0 and is_inside_tree():
			_find_timer = 1.0
			var found := get_tree().root.find_children("*", "CanvasModulate", true, false)
			if not found.is_empty():
				_canvas_mod = found[0]
	if _canvas_mod == null:
		return Color.WHITE
	var c := _canvas_mod.color
	return Color(minf(1.0 / maxf(c.r, 0.2), 3.5), minf(1.0 / maxf(c.g, 0.2), 3.5), minf(1.0 / maxf(c.b, 0.2), 3.5))


func _process(delta: float) -> void:
	if delta <= 0.0 or _pos.is_empty():
		return
	_t += delta
	_find_timer -= delta
	self_modulate = _night_boost()
	var parent := get_parent() as Node2D
	var gscale := maxf(absf(parent.global_scale.x), 0.001)
	var gmove := (parent.global_position - _last_gpos) / gscale
	_last_gpos = parent.global_position
	var f := _facing_vec()
	for s in STRANDS:
		for i in POINTS:
			var rest := _rest(s, i, f)
			if i == 0:
				_pos[s][0] = rest
				continue
			var t := float(i) / float(POINTS - 1)
			var lag := pow(t, 1.1)
			var p: Vector2 = _pos[s][i]
			var v: Vector2 = _vel[s][i]
			p -= gmove * lag * 1.15                                                  # quán tính: chạy thì dải bay ra sau
			var wave := Vector2(sin(_t * 2.2 + s * 1.3 + i * 0.55) * 1.6, cos(_t * 1.7 + s + i * 0.4) * 0.8) * t   # lượn nhẹ
			var acc := (rest + wave - p) * STIFF - v * DAMP
			v += acc * delta
			p += v * delta
			var up: Vector2 = _pos[s][i - 1]
			var d := p - up
			if d.length() > SEG * 1.5:
				p = up + d.normalized() * SEG * 1.5
			_pos[s][i] = p
			_vel[s][i] = v
	_order()
	queue_redraw()


## Hướng bắc: dải buông phía trước thân (vẽ trên cùng); còn lại ở sau (sau cả hào quang).
func _order() -> void:
	var parent := get_parent()
	var north := (str(parent.get("facing")) if parent.get("facing") != null else "south").begins_with("north")
	var aura := parent.get_node_or_null("OutfitAura")
	if north:   # trên tóc trước nhưng không giành chỗ cuối cùng với phụ kiện đầu
		var hair_front := parent.get_node_or_null("HairFront")
		if hair_front != null and get_index() < hair_front.get_index():
			parent.move_child(self, parent.get_child_count() - 1)
	else:
		var want: int = (aura.get_index() + 1) if aura != null else 0
		if get_index() != want:
			parent.move_child(self, want)
	var pw := clampf((float(parent.get_meta("aura_power", 1.0)) - 0.4) / 0.5, 0.0, 1.0)   # cảnh giới thấp: chưa có áo choàng linh khí
	_alpha = (0.5 if north else 1.0) * pw


func _draw() -> void:
	if _pos.is_empty():
		return
	for s in STRANDS:
		for i in range(POINTS - 1):
			var t := float(i) / float(POINTS - 1)
			var fade := pow(1.0 - t, 1.15)
			var c := color.lerp(color2, 0.4 * (1.0 - t))   # gần vai hơi sáng, càng xa càng về màu linh khí
			var a: Vector2 = (_pos[s][i] as Vector2).round()
			var b: Vector2 = (_pos[s][i + 1] as Vector2).round()
			var w := roundf(lerpf(3.5, 1.0, t))
			draw_line(a, b, Color(c, 0.14 * fade * _alpha), w + 3.0)       # quầng mờ
			draw_line(a, b, Color(c, 0.72 * fade * _alpha), w)             # lõi
			if i % 3 == 0:
				draw_circle(b, 0.9, Color(color2, 0.9 * fade * _alpha * (0.6 + 0.4 * sin(_t * 6.0 + s + i))))   # điểm sáng lấp lánh
