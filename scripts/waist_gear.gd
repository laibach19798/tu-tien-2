extends Node2D
## Vật treo thắt lưng (slot "waist"): ngọc bội, chuông, hồ lô. Đung đưa như con lắc theo chuyển động của nhân vật.
## Chuông kêu khi lắc mạnh. Vẽ bằng ô vuông 1px, nằm trên thân/giày nhưng dưới tóc trước. Gốc ở chân nhân vật.

const HIP_Y := -20.0
const CORD := 5.0

var kind := "jade"
var col := Color(0.35, 0.8, 0.65)
var col2 := Color(0.95, 0.78, 0.3)
var _t := 0.0
var _last_gpos := Vector2.ZERO
var _theta := [0.0, 0.0]      # góc lắc của hai vật treo (mặt trước/ phải và trái)
var _omega := [0.0, 0.0]
var _ring_cd := 0.0


func _ready() -> void:
	_last_gpos = get_parent().global_position


## cfg: kind (jade | bell | gourd | both), col, col2
func configure(cfg: Dictionary) -> void:
	kind = str(cfg.get("kind", "jade"))
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
	if delta <= 0.0:
		return
	_t += delta
	_ring_cd = maxf(0.0, _ring_cd - delta)
	var parent := get_parent() as Node2D
	var gscale := maxf(absf(parent.global_scale.x), 0.001)
	var move := (parent.global_position - _last_gpos) / gscale
	_last_gpos = parent.global_position
	var speed := move.length() / delta
	# nằm trên thân và giày, dưới tóc trước
	var shoes := parent.get_node_or_null("Shoes")
	if shoes != null and get_index() < shoes.get_index():
		parent.move_child(self, shoes.get_index())
	for n in 2:
		var th: float = _theta[n]
		var om: float = _omega[n]
		om += (-70.0 * th - 5.5 * om) * delta
		om += -move.x * 0.9 + sin(_t * (6.0 + n * 1.3) + n) * (0.2 + 0.004 * speed) * delta * 6.0   # đẩy theo chuyển động + rung khi bước
		th = clampf(th + om * delta, -1.1, 1.1)
		_theta[n] = th
		_omega[n] = om
	if (kind == "bell" or kind == "both") and _ring_cd <= 0.0 and absf(float(_omega[0])) > 2.4:
		_ring_cd = 0.4
		Sfx.play("bell", randf_range(0.95, 1.1), -8.0)
	queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func _draw() -> void:
	var f := _facing()
	var side := absf(f.x) > 0.6 and absf(f.y) < 0.4
	var back := f.y < -0.3
	# điểm treo: nhìn thẳng thì ở hông phải/trái, nhìn ngang thì gần giữa thân
	var a0 := Vector2(7.0, HIP_Y)
	var a1 := Vector2(-7.0, HIP_Y)
	if side:
		a0 = Vector2(f.x * 1.0, HIP_Y)
		a1 = Vector2(f.x * 1.0 - 3.0, HIP_Y)
	elif absf(f.x) > 0.4:
		a0 = Vector2(f.x * 5.0 + 2.0, HIP_Y)
		a1 = Vector2(f.x * 5.0 - 4.0, HIP_Y)
	match kind:
		"jade":
			_draw_jade(a0, float(_theta[0]), back)
		"bell":
			_draw_bell(a0, float(_theta[0]), back)
		"gourd":
			_draw_gourd(a0, float(_theta[0]), back)
		"both":
			_draw_jade(a0, float(_theta[0]), back)
			_draw_bell(a1, float(_theta[1]), back)


func _end(anchor: Vector2, theta: float, length: float) -> Vector2:
	return anchor + Vector2(sin(theta), cos(theta)) * length


func _cord(anchor: Vector2, e: Vector2) -> void:
	draw_line(anchor.round(), e.round(), col2.darkened(0.25), 1.0)
	_px(anchor.x - 1.0, anchor.y - 1.0, 3.0, 2.0, col2)        # nút buộc vào đai


func _draw_jade(anchor: Vector2, th: float, back: bool) -> void:
	var e := _end(anchor, th, CORD)
	_cord(anchor, e)
	# đĩa ngọc có lỗ giữa
	var c := col
	_px(e.x - 2.0, e.y, 5.0, 5.0, c.darkened(0.45))
	_px(e.x - 1.0, e.y - 1.0, 3.0, 1.0, c.darkened(0.45))
	_px(e.x - 1.0, e.y + 5.0, 3.0, 1.0, c.darkened(0.45))
	_px(e.x - 1.0, e.y + 1.0, 3.0, 3.0, c)
	_px(e.x - 1.0, e.y + 1.0, 1.0, 1.0, c.lightened(0.5))      # điểm sáng
	_px(e.x, e.y + 2.0, 1.0, 1.0, Color(0.1, 0.12, 0.12))     # lỗ giữa
	# tua dưới ngọc, tung theo góc lắc
	for k in 3:
		var sway := sin(_t * 4.0 + k * 1.6) * 0.7 + th * 2.5
		for j in 4:
			_px(e.x - 1.0 + k + sway * float(j) / 4.0, e.y + 6.0 + j, 1.0, 1.0, col2 if j % 2 == 0 else col2.darkened(0.25))


func _draw_bell(anchor: Vector2, th: float, back: bool) -> void:
	var e := _end(anchor, th, CORD - 1.0)
	_cord(anchor, e)
	# thân chuông hình thang + miệng chuông
	var c := col2
	_px(e.x - 1.0, e.y, 3.0, 1.0, c.darkened(0.3))
	_px(e.x - 2.0, e.y + 1.0, 5.0, 3.0, c)
	_px(e.x - 3.0, e.y + 4.0, 7.0, 1.0, c.darkened(0.2))
	_px(e.x - 2.0, e.y + 1.0, 1.0, 2.0, c.lightened(0.45))    # bóng sáng
	var clap := clampf(float(_omega[0]) * 0.25, -1.5, 1.5)
	_px(e.x + clap, e.y + 5.0, 1.0, 1.0, c.darkened(0.45))   # quả lắc
	if absf(float(_omega[0])) > 2.4:   # đang rung: vẽ vài vạch tiếng ngân
		draw_line(Vector2(e.x - 5.0, e.y + 1.0), Vector2(e.x - 6.0, e.y + 3.0), Color(col2, 0.7), 1.0)
		draw_line(Vector2(e.x + 5.0, e.y + 1.0), Vector2(e.x + 6.0, e.y + 3.0), Color(col2, 0.7), 1.0)


func _draw_gourd(anchor: Vector2, th: float, back: bool) -> void:
	var e := _end(anchor, th, CORD - 1.0)
	_cord(anchor, e)
	var c := col
	_px(e.x - 1.0, e.y, 2.0, 1.0, c.darkened(0.4))              # nút gỗ
	_px(e.x - 2.0, e.y + 1.0, 4.0, 3.0, c)                      # bầu trên
	_px(e.x - 3.0, e.y + 4.0, 6.0, 4.0, c)                      # bầu dưới
	_px(e.x - 2.0, e.y + 8.0, 4.0, 1.0, c.darkened(0.3))
	_px(e.x - 2.0, e.y + 4.0, 1.0, 3.0, c.lightened(0.35))      # bóng sáng
	_px(e.x - 3.0, e.y + 3.0, 6.0, 1.0, col2)                   # dây buộc ngang eo hồ lô
