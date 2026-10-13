extends Node2D
class_name TribulationStrike
## Một tia thiên kiếp: vòng báo trước (DELAY giây), sau đó sét giáng; ai còn đứng trong vòng thì nhận sát thương.
## Né bằng Thân Pháp cũng được: Vitals.take đi qua bộ lọc né của V1.

const DELAY := 1.0
const RADIUS := 56.0

var main: Node
var damage := 40.0
var _t := 0.0
var _struck := false


func _ready() -> void:
	z_index = 90
	Sfx.play("qi", 0.7)


func _process(delta: float) -> void:
	_t += delta
	if not _struck and _t >= DELAY:
		_struck = true
		_strike()
	if _t >= DELAY + 0.4:
		queue_free()
		return
	queue_redraw()


func _strike() -> void:
	Sfx.play("hit_big", 0.8)
	if main != null and main.fx_layer != null:
		Fx.ring(main.fx_layer, global_position, 8.0, RADIUS * 1.2, Color(0.8, 0.9, 1.0), 0.35, 0.55, 5.0)
		Fx.glow(main.fx_layer, global_position + Vector2(0, -40), 30.0, 130.0, Color(0.85, 0.92, 1.0), 0.3)
	if main != null and main.player != null and not main._dead:
		var d: float = main.player.position.distance_to(global_position)
		if d < RADIUS:
			main.vitals.take(damage, global_position)


func _draw() -> void:
	if not _struck:
		var k := clampf(_t / DELAY, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, RADIUS, Color(0.7, 0.8, 1.0, 0.10 + 0.25 * k))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(0.9, 0.95, 1.0, 0.5 + 0.5 * k), 2.0 + 2.0 * k)
		draw_arc(Vector2.ZERO, RADIUS * k, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0)
	else:
		var a := 1.0 - clampf((_t - DELAY) / 0.4, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(Vector2(0, -420), Vector2(0, 0), Color(0.9, 0.95, 1.0, a), 10.0 * a + 2.0)
		draw_line(Vector2(0, -420), Vector2(0, 0), Color(1, 1, 1, a), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, RADIUS * (1.0 + 0.2 * (1.0 - a)), Color(1.0, 1.0, 1.0, 0.5 * a))
