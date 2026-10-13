extends Node2D
class_name MonsterTelegraph
## Dấu báo trước của quái: "arrow" (hướng lao), "circle" (vùng nổ/gọi), "line" (hướng bắn).
## Nằm dưới chân quái, hiện trong lúc gồng và biến mất khi ra đòn.

var mode := ""
var dir := Vector2.RIGHT
var radius := 90.0
var length := 300.0
var color := Color(1.0, 0.3, 0.25)
var dur := 1.0
var _t := 0.0


func show_arrow(p_dir: Vector2, p_len: float, p_dur: float, p_color := Color(1.0, 0.3, 0.25)) -> void:
	mode = "arrow"
	dir = p_dir.normalized()
	length = p_len
	dur = maxf(p_dur, 0.05)
	color = p_color
	_t = 0.0
	visible = true
	z_index = -1
	queue_redraw()


func show_circle(p_radius: float, p_dur: float, p_color := Color(1.0, 0.45, 0.2)) -> void:
	mode = "circle"
	radius = p_radius
	dur = maxf(p_dur, 0.05)
	color = p_color
	_t = 0.0
	visible = true
	z_index = -1
	queue_redraw()


func hide_now() -> void:
	mode = ""
	visible = false
	position = Vector2.ZERO


func _process(delta: float) -> void:
	if mode == "":
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / dur, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	match mode:
		"circle":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.10 + 0.25 * k))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.9), 2.0 + 2.0 * k)
			draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
		"arrow":
			var tip := dir * length
			var side := dir.orthogonal() * 18.0
			draw_colored_polygon(PackedVector2Array([side * 0.6, tip + side * 0.6, tip - side * 0.6, -side * 0.6]), Color(color, 0.10 + 0.25 * k))
			draw_line(Vector2.ZERO, tip, Color(color, 0.9), 2.0 + 2.0 * k)
			draw_line(tip, tip - dir * 22.0 + side * 0.8, Color(color, 0.9), 3.0)
			draw_line(tip, tip - dir * 22.0 - side * 0.8, Color(color, 0.9), 3.0)
