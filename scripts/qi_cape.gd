extends Node2D
## Áo choàng linh khí của tiên bào: vài dải ánh sáng dài từ vai, bay theo chuyển động nhân vật rồi nhạt dần.
## Không phải vải thật nên không có đường cắt/rách; cộng sáng như hào quang và được bù màu đêm.
## Wardrobe._set_aura tạo node này khi aura có "qi_cape": true. Toạ độ theo ô 64px của nhân vật, gốc ở chân.

const STRANDS := 5
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
var _glow: Node2D
var _alpha := 1.0       # dải ở trước thân (hướng bắc) thì mờ hơn để không che người


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()   # lớp cộng sáng: quầng và điểm lấp lánh; thân dải vẽ thường để rõ nét
	_glow.material = add
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
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
	var half := 3.0 + 8.0 * absf(f.y)
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
	var boost := _night_boost()
	self_modulate = boost
	_glow.self_modulate = boost
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
	_glow.queue_redraw()


## Hướng bắc: dải buông phía trước thân (vẽ trên cùng); còn lại ở sau (sau cả hào quang).
func _order() -> void:
	var parent := get_parent()
	var north := (str(parent.get("facing")) if parent.get("facing") != null else "south").begins_with("north")
	var aura := parent.get_node_or_null("OutfitAura")
	var want: int = parent.get_child_count() - 1 if north else ((aura.get_index() + 1) if aura != null else 0)
	if get_index() != want:
		parent.move_child(self, want)
	_alpha = 0.5 if north else 1.0


func _draw() -> void:
	if _pos.is_empty():
		return
	var zero := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for s in STRANDS:
		var outer := s == 0 or s == STRANDS - 1
		var wmax := 4.8 if outer else (3.6 if s % 2 == 0 else 2.8)
		for i in range(POINTS - 1):
			var t0 := float(i) / float(POINTS - 1)
			var t1 := float(i + 1) / float(POINTS - 1)
			var f0 := pow(1.0 - t0, 0.9) * _alpha
			var f1 := pow(1.0 - t1, 0.9) * _alpha
			var a: Vector2 = (_pos[s][i] as Vector2).round()
			var b: Vector2 = (_pos[s][i + 1] as Vector2).round()
			var dir := b - a
			if dir.length() < 0.01:
				continue
			var n := dir.orthogonal().normalized()
			var w0 := lerpf(wmax, 0.5, pow(t0, 0.85))
			var w1 := lerpf(wmax, 0.5, pow(t1, 0.85))
			var c0 := color.lerp(color2, 0.25 * (1.0 - t0))
			var c1 := color.lerp(color2, 0.25 * (1.0 - t1))
			# thân dải
			draw_primitive(PackedVector2Array([a + n * w0, b + n * w1, b - n * w1, a - n * w0]),
				PackedColorArray([Color(c0, 0.8 * f0), Color(c1, 0.8 * f1), Color(c1, 0.8 * f1), Color(c0, 0.8 * f0)]), zero)
			# lõi sáng mảnh ở giữa
			draw_primitive(PackedVector2Array([a + n * w0 * 0.3, b + n * w1 * 0.3, b - n * w1 * 0.3, a - n * w0 * 0.3]),
				PackedColorArray([Color(color2, 0.9 * f0), Color(color2, 0.9 * f1), Color(color2, 0.9 * f1), Color(color2, 0.9 * f0)]), zero)
			# viền đậm hai mép cho nét rõ
			draw_line(a + n * w0, b + n * w1, Color(c0.darkened(0.4), 0.95 * f0), 1.0)
			draw_line(a - n * w0, b - n * w1, Color(c0.darkened(0.4), 0.95 * f0), 1.0)
			# vạch ngang như nếp vải khí
			if i % 3 == 1:
				draw_line(a + n * w0 * 0.9, a - n * w0 * 0.9, Color(color2, 0.75 * f0), 1.0)
	# móc cài ngọc ở cổ
	draw_circle(SHOULDER + Vector2(0, -1), 2.2, Color(color.darkened(0.4), _alpha))
	draw_circle(SHOULDER + Vector2(0, -1), 1.4, Color(color2, _alpha))


## Quầng sáng quanh dải và điểm lấp lánh (vẽ cộng sáng).
func _draw_glow() -> void:
	if _pos.is_empty():
		return
	for s in STRANDS:
		for i in range(POINTS - 1):
			var t := float(i) / float(POINTS - 1)
			var fade := pow(1.0 - t, 1.0) * _alpha
			var a: Vector2 = (_pos[s][i] as Vector2).round()
			var b: Vector2 = (_pos[s][i + 1] as Vector2).round()
			_glow.draw_line(a, b, Color(color, 0.12 * fade), 8.0)
			_glow.draw_line(a, b, Color(color2, 0.10 * fade), 4.0)
			if i % 3 == 0:
				_glow.draw_circle(b, 1.0, Color(color2, 0.9 * fade * (0.6 + 0.4 * sin(_t * 6.0 + s + i))))