extends Node2D
## Hào quang khi ngồi thiền: vòng sáng dưới chân + hạt linh khí bay lên.
## Đặt làm con đầu tiên của nhân vật để vẽ phía sau sprite.

var active := false:
	set(v):
		active = v
		if _particles:
			_particles.emitting = v
		queue_redraw()
var boosted := false
var _t := 0.0
var _particles: CPUParticles2D


func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.amount = 18
	_particles.lifetime = 1.6
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 13.0
	_particles.direction = Vector2(0, -1)
	_particles.spread = 12.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 9.0
	_particles.initial_velocity_max = 15.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 1.6
	_particles.position = Vector2(0, -4)
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.95, 1.0, 0.95))
	g.set_color(1, Color(0.6, 0.95, 1.0, 0.0))
	_particles.color_ramp = g
	add_child(_particles)


func _process(delta: float) -> void:
	if active:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var col := Color(1.0, 0.85, 0.4) if boosted else Color(0.5, 0.9, 1.0)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, 13.0 + pulse * 3.0, 0.0, TAU, 32, Color(col, 0.55), 1.2)
	draw_arc(Vector2.ZERO, 8.0 + pulse * 2.0, 0.0, TAU, 24, Color(col, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
