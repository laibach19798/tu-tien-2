extends Node2D
## Dấu "X": hai vệt chém chéo nhau bật ra rồi mờ đi (hiệu ứng trúng đòn).

var color := Color(0.6, 0.95, 1.0)
var size := 34.0
var _t := 0.0
const LIFE := 0.28


func _ready() -> void:
	material = Fx.additive()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var pop := 0.35 + 0.65 * (1.0 - pow(1.0 - minf(1.0, k * 3.0), 3.0))
	var a := 1.0 - k
	var l := size * pop
	var w := 3.2 * (1.0 - k * 0.5)
	for ang in [0.0, PI * 0.5 + 0.18]:
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x)
		var poly := PackedVector2Array([-d * l, n * w, d * l, -n * w])
		draw_colored_polygon(poly, Color(color, a * 0.85))
		var core := PackedVector2Array([-d * l * 0.7, n * w * 0.4, d * l * 0.7, -n * w * 0.4])
		draw_colored_polygon(core, Color(1, 1, 1, a))
	draw_circle(Vector2.ZERO, size * 0.28 * (1.0 - k), Color(1, 1, 1, a * 0.7))
