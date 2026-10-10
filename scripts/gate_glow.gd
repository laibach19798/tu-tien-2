extends Node2D
class_name GateGlow
## Điểm sáng tròn nhỏ đánh dấu cổng dịch chuyển: lõi sáng và quầng mờ nhấp nháy nhẹ, cộng sáng (additive).

var tint := Color(0.7, 0.9, 1.0)
var _t := randf() * 10.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 2.6)
	for i in 7:
		var k := float(i) / 6.0
		draw_circle(Vector2.ZERO, lerpf(46.0, 9.0, k) * pulse, Color(tint, 0.05 + 0.07 * k))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color(1, 1, 1, 0.9))
