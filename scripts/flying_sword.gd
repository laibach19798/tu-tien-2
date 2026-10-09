extends Node2D
## Phi Kiếm: kiếm phát sáng bay lượn quanh người (có vệt đuôi) rồi lao vào mục tiêu, cắm xuống và tan thành ánh sáng.

var school
var player: Node2D
var phase_angle := 0.0
var damage := 18.0
var target: Node2D = null
var aim := Vector2.RIGHT
var orbit_time := 0.55
var tint := Color(0.6, 0.9, 1.0)
var _state := "orbit"
var _t := 0.0
var _dash_t := 0.0
var _dest := Vector2.ZERO
var _sword: SwordVisual
var _ghost_t := 0.0


func _ready() -> void:
	_sword = SwordVisual.new()
	_sword.length = 28.0
	_sword.glow_color = tint
	_sword.glow = 0.4
	add_child(_sword)
	global_position = player.global_position + Vector2(0, -40)
	Fx.trail(get_parent(), self, tint, 11.0, 0.45)
	Fx.glow(get_parent(), global_position, 10.0, 46.0, tint, 0.3)


func _process(delta: float) -> void:
	if _state == "orbit":
		_t += delta
		var k := clampf(_t / orbit_time, 0.0, 1.0)
		var ang := phase_angle + _t * 10.0
		var r := 52.0 * minf(1.0, _t / 0.18) * (1.0 + 0.25 * k)
		global_position = player.global_position + Vector2(cos(ang) * r, sin(ang) * r * 0.55 - 44.0 - 7.0 * sin(_t * 12.0))
		_sword.rotation = ang + PI / 2.0
		_sword.glow = 0.4 + 0.6 * k
		_ghost_t += delta
		if _ghost_t > 0.04:
			_ghost_t = 0.0
			Fx.glow(get_parent(), global_position, 16.0, 3.0, tint, 0.22)
		if _t >= orbit_time:
			_state = "dash"
			_dest = player.global_position + aim * 340.0 + Vector2(0, -30)
			Fx.glow(get_parent(), global_position, 20.0, 90.0, Color(1, 1, 1), 0.2)
			Fx.ring(get_parent(), global_position, 6.0, 40.0, tint, 0.25, 1.0, 3.0)
	elif _state == "dash":
		_dash_t += delta
		if is_instance_valid(target) and target.alive:
			_dest = target.hit_center()
		var to := _dest - global_position
		_sword.rotation = to.angle()
		_sword.glow = 1.0
		_ghost_t += delta
		if _ghost_t > 0.025:
			_ghost_t = 0.0
			Fx.glow(get_parent(), global_position, 20.0, 4.0, tint, 0.25)
		if to.length() < 28.0 or _dash_t > 0.9:
			if is_instance_valid(target) and target.alive:
				school.hit_target(target, damage, tint, false)
			else:
				school.impact(global_position, tint, false)
			_state = "fade"
			# kiếm cắm lại một thoáng rồi tan thành ánh sáng
			var tw := create_tween()
			tw.tween_interval(0.18)
			tw.tween_callback(func(): Fx.burst(get_parent(), global_position, tint, 16, 100.0, 0.5, 3.4))
			tw.tween_property(self, "modulate:a", 0.0, 0.22)
			tw.tween_callback(queue_free)
		else:
			global_position += to.normalized() * minf(1100.0 * delta, to.length())
