extends Node2D
class_name SwordVisual
## Thanh kiếm vẽ bằng code, mũi kiếm hướng +X. Dùng cho kiếm cầm tay, kiếm sau lưng và phi kiếm.

const BLADE := Color(0.86, 0.92, 1.0)
const EDGE := Color(1, 1, 1)
const LINE := Color(0.22, 0.28, 0.40)
const GOLD := Color(0.95, 0.78, 0.30)
const HILT := Color(0.45, 0.28, 0.20)
const SCABBARD := Color(0.30, 0.20, 0.15)
const SCABBARD_EDGE := Color(0.52, 0.38, 0.28)

var length := 30.0:
	set(v):
		length = v
		queue_redraw()
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()
var glow_color := Color(0.6, 0.9, 1.0)
var sheath := false:   # true: vẽ vỏ kiếm nâu (kiếm đeo lưng) thay vì lưỡi kiếm trần
	set(v):
		sheath = v
		queue_redraw()


func _draw() -> void:
	var l := length
	if glow > 0.0:
		draw_line(Vector2(0, 0), Vector2(l, 0), Color(glow_color, 0.18 * glow), 13.0)
		draw_line(Vector2(2, 0), Vector2(l, 0), Color(glow_color, 0.38 * glow), 7.0)
	var hw := 2.3 if sheath else 2.6
	var pts := PackedVector2Array([Vector2(4, -hw), Vector2(l - 7, -hw), Vector2(l, 0), Vector2(l - 7, hw), Vector2(4, hw)])
	draw_colored_polygon(pts, SCABBARD if sheath else BLADE)
	draw_line(Vector2(4, -0.6), Vector2(l - 5, -0.6), SCABBARD_EDGE if sheath else EDGE, 1.2)
	if sheath:
		draw_rect(Rect2(l - 9.0, -hw - 0.6, 3.0, hw * 2.0 + 1.2), GOLD)   # khoen vàng trên vỏ
		draw_rect(Rect2(8.0, -hw - 0.6, 2.0, hw * 2.0 + 1.2), GOLD)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), LINE, 1.0)
	draw_rect(Rect2(1.0, -6.0, 3.0, 12.0), GOLD)
	draw_rect(Rect2(-9.0, -1.5, 10.0, 3.0), HILT)
	draw_circle(Vector2(-10, 0), 2.2, GOLD)
