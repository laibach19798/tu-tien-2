extends Node2D
## Vòng sóng lan ra trên mặt đất (xem Fx.ring).

var r0 := 10.0
var r1 := 80.0
var color := Color(0.6, 0.95, 1.0)
var life := 0.45
var squash := 0.55
var width := 4.0
var _t := 0.0


func _ready() -> void:
	material = Fx.additive()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var e := 1.0 - pow(1.0 - k, 3.0)
	var r := lerpf(r0, r1, e)
	var a := 1.0 - k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(color, a * 0.85), width * (1.0 - k * 0.6))
	draw_arc(Vector2.ZERO, r * 0.93, 0.0, TAU, 72, Color(1, 1, 1, a * 0.45), width * 0.4)
	draw_arc(Vector2.ZERO, r * 1.06, 0.0, TAU, 72, Color(color, a * 0.25), width * 1.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
