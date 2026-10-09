extends Node2D
## Kiếm Khí: lưỡi kiếm khí ba lớp màu bay thẳng, có vệt đuôi, bóng mờ phía sau, xuyên qua kẻ địch.

var school
var vel := Vector2.ZERO
var damage := 20.0
var life := 1.0
var hit_radius := 42.0
var _hit := {}
var _t := 0.0
var _ghost_timer := 0.0


func _ready() -> void:
	rotation = vel.angle()
	material = Fx.additive()
	Fx.trail(get_parent(), self, Color(0.5, 0.75, 1.0), 20.0, 0.34)
	Fx.trail(get_parent(), self, Color(0.85, 0.6, 1.0), 9.0, 0.5)
	var p := CPUParticles2D.new()
	p.amount = 34
	p.lifetime = 0.45
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(-1, 0)
	p.spread = 80.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.8
	p.scale_amount_max = 3.6
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(0.55, 0.85, 1.0, 0.65), Color(0.8, 0.6, 1.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = g
	add_child(p)
	# Chớp sáng lúc phóng ra
	Fx.glow(get_parent(), global_position, 20.0, 90.0, Color(0.6, 0.9, 1.0), 0.25)
	Fx.ring(get_parent(), global_position + Vector2(0, 30), 8.0, 60.0, Color(0.6, 0.85, 1.0), 0.35)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	position += vel * delta
	life -= delta
	_ghost_timer += delta
	if _ghost_timer > 0.05:
		_ghost_timer = 0.0
		Fx.glow(get_parent(), global_position, 22.0, 4.0, Color(0.6, 0.85, 1.0), 0.28)
	for t in get_tree().get_nodes_in_group("targets"):
		if _hit.has(t) or not t.alive:
			continue
		if t.hit_center().distance_to(global_position) < hit_radius:
			_hit[t] = true
			school.hit_target(t, damage, Color(0.6, 0.85, 1.0), true)
	if life < 0.2:
		modulate.a = maxf(0.0, life / 0.2)
	if life <= 0.0:
		Fx.burst(get_parent(), global_position, Color(0.6, 0.85, 1.0), 10, 80.0, 0.35)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(_t * 30.0)
	# đuôi sáng kéo dài
	draw_line(Vector2(-62, 0), Vector2(-6, 0), Color(0.5, 0.75, 1.0, 0.30), 9.0)
	draw_line(Vector2(-44, 0), Vector2(-6, 0), Color(0.85, 0.65, 1.0, 0.45), 5.0)
	draw_line(Vector2(-30, 0), Vector2(-6, 0), Color(1, 1, 1, 0.7), 2.0)
	# ba lớp lưỡi liềm: tím ngoài - xanh - trắng lõi
	draw_arc(Vector2(-12, 0), 36.0 * pulse, -1.05, 1.05, 22, Color(0.8, 0.55, 1.0, 0.35), 14.0)
	draw_arc(Vector2(-10, 0), 34.0 * pulse, -1.0, 1.0, 22, Color(0.5, 0.78, 1.0, 0.6), 9.0)
	draw_arc(Vector2(-8, 0), 32.0 * pulse, -0.95, 0.95, 22, Color(1, 1, 1, 0.95), 3.5)
	# hai cánh nhọn ở hai đầu lưỡi
	for s in [-1.0, 1.0]:
		var tip := Vector2(cos(0.95 * s), sin(0.95 * s)) * 32.0 + Vector2(-8, 0)
		draw_line(tip, tip + Vector2(-14, 8.0 * s), Color(0.8, 0.9, 1.0, 0.7), 2.0)
	draw_circle(Vector2(8, 0), 5.0, Color(1, 1, 1, 0.8))
