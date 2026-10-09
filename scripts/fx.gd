extends RefCounted
class_name Fx
## Bộ hiệu ứng dùng chung cho skill: vòng sóng, quầng sáng, vết chém chéo, vệt đuôi, tia lửa.
## Mọi hiệu ứng tự huỷ khi hết thời gian và dùng trộn màu cộng (additive).

static var _soft: Texture2D


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


## Vòng sóng nằm phẳng trên mặt đất (ép dẹt) lan từ bán kính r0 ra r1.
static func ring(parent: Node, pos: Vector2, r0: float, r1: float, color: Color, life := 0.45, squash := 0.55, width := 4.0) -> void:
	var n: Node2D = preload("res://scripts/fx_ring.gd").new()
	n.r0 = r0
	n.r1 = r1
	n.color = color
	n.life = life
	n.squash = squash
	n.width = width
	n.position = pos
	parent.add_child(n)


## Quầng sáng mềm nở ra rồi tắt.
static func glow(parent: Node, pos: Vector2, size_from: float, size_to: float, color: Color, life := 0.3) -> void:
	var s := Sprite2D.new()
	s.texture = soft_texture()
	s.material = additive()
	s.modulate = Color(color, 0.95)
	s.position = pos
	s.scale = Vector2.ONE * (size_from / 32.0)
	parent.add_child(s)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (size_to / 32.0), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.chain().tween_callback(s.queue_free)


## Hai vệt chém chéo nhau (dấu "X") nổ ra tại điểm trúng.
static func cross(parent: Node, pos: Vector2, color: Color, size := 34.0, angle := -1.0) -> void:
	var n: Node2D = preload("res://scripts/fx_cross.gd").new()
	n.color = color
	n.size = size
	n.rotation = angle if angle >= 0.0 else randf() * PI
	n.position = pos
	parent.add_child(n)


## Tia lửa bắn toả ra.
static func burst(parent: Node, pos: Vector2, color: Color, count := 14, speed := 130.0, life := 0.4, size := 3.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 40)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(color, 0.8), Color(color, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = g
	p.material = additive()
	p.position = pos
	parent.add_child(p)
	p.finished.connect(p.queue_free)


## Vệt đuôi uốn lượn bám theo một node, thon dần về phía sau.
static func trail(parent: Node, target: Node2D, color: Color, width := 8.0, life := 0.3) -> Line2D:
	var t: Line2D = preload("res://scripts/fx_trail.gd").new()
	t.target = target
	t.color_main = color
	t.base_width = width
	t.life = life
	parent.add_child(t)
	return t
