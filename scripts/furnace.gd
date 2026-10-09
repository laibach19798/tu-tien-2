extends Node2D
class_name Furnace
## Lò luyện đan trong làng: vẽ bằng điểm ảnh, có lửa nhấp nháy, khói bay lên và ánh sáng ấm.

const BODY := [
	"....kkkkkkkk....",
	"...kmmmmmmmmk...",
	"..kmllmmmmmddk..",
	".kmllmmmmmmmddk.",
	".kmmmmmmmmmmmdk.",
	".kmmmmmmmmmmmdk.",
	".kddddddddddddk.",
	".kmmmkkkkkkmmdk.",
	".kmmmkffffkmmdk.",
	".kmmmkffwfkmmdk.",
	".kmmmkkkkkkmmdk.",
	"..kmmmmmmmmmdk..",
	"..kkkkkkkkkkkk..",
	"..kk........kk..",
	"..kk........kk..",
	"................",
]

var _t := 0.0
var _light: PointLight2D
var _smoke: Array = []


func _ready() -> void:
	var sh := Shadow.make(26.0, 9.0, 0.38)
	sh.position = Vector2(0, 2)
	add_child(sh)
	for i in 5:
		_smoke.append(randf())


func hit_center() -> Vector2:
	return global_position + Vector2(0, -30)


func _process(delta: float) -> void:
	_t += delta
	for i in _smoke.size():
		_smoke[i] = fmod(_smoke[i] + delta * 0.35, 1.0)
	queue_redraw()


func _draw() -> void:
	var fire_a := Color(1.0, 0.55, 0.15) if int(_t * 6.0) % 2 == 0 else Color(1.0, 0.75, 0.25)
	var fire_b := Color(1.0, 0.9, 0.5) if int(_t * 7.0) % 2 == 0 else Color(1.0, 0.7, 0.3)
	var pal := {"k": UIKit.BLACK, "m": Color(0.72, 0.45, 0.22), "l": Color(0.92, 0.66, 0.36), "d": Color(0.45, 0.26, 0.14), "f": fire_a, "w": fire_b}
	UIKit.bitmap(self, Vector2(-32, -60), BODY, pal, 4.0)
	# khói
	for i in _smoke.size():
		var p: float = _smoke[i]
		var s := 4.0 + p * 10.0
		var x := -4.0 + sin(p * 6.0 + i) * 8.0 + (i - 2) * 3.0
		draw_rect(Rect2(x - s * 0.5, -66.0 - p * 40.0, s, s), Color(0.8, 0.8, 0.85, (1.0 - p) * 0.45))
