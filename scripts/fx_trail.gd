extends Line2D
## Vệt đuôi bám theo `target`: lưu các vị trí gần đây, thon dần và mờ về phía đuôi.

var target: Node2D
var color_main := Color(0.6, 0.95, 1.0)
var base_width := 8.0
var life := 0.3
var _pts: Array[Vector2] = []
var _ts: Array[float] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	material = Fx.additive()
	width = base_width
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	round_precision = 6
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.7, 0.75))
	c.add_point(Vector2(1.0, 1.0))
	width_curve = c
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(color_main, 0.0), Color(color_main, 0.55), Color(1, 1, 1, 0.95)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient = g


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if is_instance_valid(target):
		_pts.append(target.global_position)
		_ts.append(now)
	while _ts.size() > 0 and now - _ts[0] > life:
		_pts.remove_at(0)
		_ts.remove_at(0)
	if _pts.size() < 2:
		if not is_instance_valid(target):
			queue_free()
		points = PackedVector2Array()
		return
	points = PackedVector2Array(_pts)
