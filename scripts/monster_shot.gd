extends Node2D
class_name MonsterShot
## Đạn của quái xạ thủ / du hồn: bay thẳng, không đuổi theo, vỡ khi chạm vật chắn hoặc hết thời gian.
## Trúng người chơi thì gây sát thương (qua Vitals.take nên né bằng Thân Pháp được) và có thể hút linh lực.

var host: Node
var vel := Vector2.ZERO
var damage := 10.0
var radius := 16.0
var drain := 0.0            # tỉ lệ linh lực tối đa bị hút khi trúng
var color := Color(0.9, 0.8, 0.5)
var _life := 2.6
var _t := 0.0


func _ready() -> void:
	z_index = 60


func _physics_process(delta: float) -> void:
	_t += delta
	_life -= delta
	if host == null or _life <= 0.0:
		queue_free()
		return
	position += vel * delta
	if host._is_blocked(Rect2(position.x - 6, position.y - 6, 12, 12)):
		_burst()
		return
	var p: Node2D = host.player
	if p != null and host.vitals.alive():
		var target := p.position + Vector2(0, -24)
		if position.distance_to(target) < radius + 14.0:
			if host.vitals.take(damage, global_position) and drain > 0.0:
				host.cult.qi = maxf(0.0, host.cult.qi - host.cult.qi_max() * drain)
				host.cult.changed.emit()
			_burst()
			return
	queue_redraw()


func _burst() -> void:
	if host != null and host.fx_layer != null:
		Fx.burst(host.fx_layer, global_position, color, 6, 70.0, 0.25, 2.4)
	queue_free()


func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(_t * 18.0)
	draw_circle(Vector2.ZERO, radius * 0.8 * pulse, Color(color, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(color, 0.18))
