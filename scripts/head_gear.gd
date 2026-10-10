extends Node2D
## Phụ kiện đầu (slot "head"): khăn buộc trán, trâm, kim quan, hoa cài tóc, mặt nạ nửa mặt, vòng đạo quang.
## Vẽ bằng ô vuông 1px theo từng hướng nhìn, luôn nằm trên cùng (trên cả tóc trước). Gốc ở chân nhân vật.

const HEAD_TOP := -50.0
const BROW := -44.0

var gear := "band"
var col := Color.WHITE
var col2 := Color(0.95, 0.8, 0.3)
var _t := 0.0
var _last_gpos := Vector2.ZERO
var _sway := 0.0       # độ lệch dải khăn theo chuyển động


func _ready() -> void:
	_last_gpos = get_parent().global_position


func configure(cfg: Dictionary) -> void:
	gear = str(cfg.get("gear", "band"))
	col = cfg.get("col", col)
	col2 = cfg.get("col2", col2)
	queue_redraw()


func _facing() -> Vector2:
	var p := get_parent()
	var i := Dir.ALL.find(str(p.get("facing")) if p.get("facing") != null else "south")
	if i < 0:
		return Vector2(0, 1)
	var table := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
	return (table[i] as Vector2).normalized()


func _process(delta: float) -> void:
	_t += delta
	var parent := get_parent() as Node2D
	var gscale := maxf(absf(parent.global_scale.x), 0.001)
	var move := (parent.global_position - _last_gpos) / gscale
	_last_gpos = parent.global_position
	_sway = lerpf(_sway, clampf(-move.x * 0.6, -3.0, 3.0), 0.2)
	# luôn trên cùng (kể cả trên hào quang, áo choàng linh khí và kiếm đeo)
	var count := parent.get_child_count()
	if get_index() != count - 1:
		parent.move_child(self, count - 1)
	queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func _draw() -> void:
	var f := _facing()
	var off := roundf(f.x * 1.5)            # đầu hơi lệch về hướng nhìn khi nhìn ngang
	var hw := 8.0 + 1.5 * absf(f.y)         # nửa bề rộng đầu
	var back := f.y < -0.3                  # quay lưng
	var side := absf(f.x) > 0.6 and absf(f.y) < 0.4
	var dark := Color(0.12, 0.1, 0.14)
	match gear:
		"band":
			_px(off - hw, -43.0, hw * 2.0, 3.0, col)
			_px(off - hw, -43.0, hw * 2.0, 1.0, col.lightened(0.25))
			_px(off - hw, -41.0, hw * 2.0, 1.0, col.darkened(0.35))
			# đuôi khăn: nhìn thẳng thì rủ hai bên đầu, nhìn ngang/chéo thì sau gáy, quay lưng thì giữa lưng
			var roots: Array = []
			if side:
				roots = [off - f.x * (hw - 1.0)]
			elif back:
				roots = [off - 2.0, off + 2.0]
			elif absf(f.x) > 0.4:
				roots = [off - f.x * (hw + 1.0)]
			else:
				roots = [off - hw - 1.0, off + hw]
			for k in roots.size():
				var rx: float = roots[k]
				var wob := sin(_t * 3.0 + k * 1.7) * 1.2 + _sway - f.x * 1.2
				var tail_len := 9 if (back or side) else 7
				for j in tail_len:
					var jj := float(j)
					_px(rx + wob * jj / float(tail_len) - f.x * jj * 0.4, -41.0 + jj, 1.0 if j > 3 else 2.0, 1.0, col if j % 3 != 2 else col.darkened(0.2))
		"pin":
			var y := -49.0
			if side:
				var dx := -f.x
				for j in 9:
					_px(off + dx * (3.0 + j), y + j * 0.55, 1.0, 1.0, col2)
				_px(off + dx * 12.0, y + 5.0, 2.0, 2.0, col)
			else:
				_px(off - 8.0, y, 16.0, 1.0, col2)
				_px(off + 8.0, y - 1.0, 2.0, 3.0, col)
				_px(off - 10.0, y - 1.0, 2.0, 3.0, col)
				_px(off + 9.0, y + 2.0, 1.0, 3.0 + sin(_t * 3.0) * 0.9, col.lightened(0.3))   # tua rủ
		"crown":
			_px(off - 5.0, -56.0, 10.0, 4.0, col2)
			_px(off - 5.0, -56.0, 10.0, 1.0, col2.lightened(0.35))
			_px(off - 5.0, -53.0, 10.0, 1.0, col2.darkened(0.25))
			_px(off - 6.0, -59.0, 2.0, 3.0, col2)
			_px(off + 4.0, -59.0, 2.0, 3.0, col2)
			_px(off - 1.0, -61.0, 2.0, 5.0, col2)
			_px(off - 1.0, -60.0, 2.0, 2.0, col)         # ngọc đỉnh
			_px(off - 2.0, -55.0, 1.0, 2.0, col)
			_px(off + 1.0, -55.0, 1.0, 2.0, col)
			_px(off - 8.0, -52.0, 16.0, 1.0, col2.darkened(0.15))   # trâm cài ngang
		"flower":
			var fx := off + (6.0 if not side else -f.x * 2.0)
			var fy := -47.0
			_px(fx - 1.0, fy - 2.0, 3.0, 1.0, col)
			_px(fx - 1.0, fy + 2.0, 3.0, 1.0, col)
			_px(fx - 2.0, fy - 1.0, 1.0, 3.0, col)
			_px(fx + 2.0, fy - 1.0, 1.0, 3.0, col)
			_px(fx - 1.0, fy - 1.0, 3.0, 3.0, col.lightened(0.25))
			_px(fx, fy, 1.0, 1.0, col2)
			_px(fx - 1.0, fy + 3.0, 1.0, 2.0, Color(0.3, 0.6, 0.3))   # lá
		"mask":
			if not back:
				var mx0 := off - 7.0
				var mw := 14.0
				if side:
					mx0 = off + f.x * 2.0 - (0.0 if f.x > 0 else 6.0)
					mw = 6.0
				_px(mx0, -43.0, mw, 6.0, col)
				_px(mx0, -43.0, mw, 1.0, col.lightened(0.2))
				_px(mx0, -38.0, mw, 1.0, col.darkened(0.3))
				if not side:
					_px(off - 4.0, -41.0, 2.0, 1.0, dark)    # khe mắt
					_px(off + 3.0, -41.0, 2.0, 1.0, dark)
					_px(off - 1.0, -43.0, 2.0, 2.0, col2)     # nốt đỏ giữa trán
					_px(off - 6.0, -39.0, 1.0, 2.0, col2)
					_px(off + 6.0, -39.0, 1.0, 2.0, col2)
				else:
					_px(mx0 + (3.0 if f.x > 0 else 2.0), -41.0, 1.0, 1.0, dark)
				_px(off - hw, -42.0, 2.0, 1.0, col2.darkened(0.2))   # dây buộc
				_px(off + hw - 2.0, -42.0, 2.0, 1.0, col2.darkened(0.2))
		"halo":
			var bob := sin(_t * 2.0) * 1.0
			draw_set_transform(Vector2(off, -56.0 + bob), 0.0, Vector2(1.0, 0.32))
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 28, Color(col, 0.28), 4.0)
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 28, Color(col, 0.95), 1.6)
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, Color(col2, 0.6), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
