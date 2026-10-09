extends Node2D
## Linh mạch kiểu tự nhiên: quầng sáng mềm + đốm sáng lấp lánh trên cỏ (mode "ground"),
## tia sáng, sương, hạt linh khí và các quả cầu sáng mờ trôi lên (mode "fx").
## Mỗi linh mạch dùng 2 node: "ground" nằm dưới vật thể, "fx" nằm trên cùng. Cả hai nhận cùng `target`.

const SQUASH := 0.62   # ép chiều dọc để quầng sáng nằm "phẳng" trên mặt đất (góc nhìn 2.5D)
const CYAN := Color(0.5, 0.92, 1.0)
const MINT := Color(0.62, 1.0, 0.85)
const VIOLET := Color(0.78, 0.66, 1.0)

var mode := "ground"
var radius := 120.0
var target := 0.7            # 0.7 bình thường, ~0.95 khi đứng trong vùng, ~1.5 khi đang thiền
var _k := 0.7
var _t := randf() * 20.0
var _sparkles: Array = []    # {pos, phase, speed, size}
var _shafts: Array = []      # {node, phase, speed}
var _motes: CPUParticles2D
var _mist: CPUParticles2D
var _orbs: CPUParticles2D
var _soft_tex: GradientTexture2D


func setup(p_mode: String, p_radius: float) -> void:
	mode = p_mode
	radius = p_radius


func _ready() -> void:
	material = _additive()
	if mode == "ground":
		for i in 46:
			var a := randf() * TAU
			var d := sqrt(randf()) * radius * 0.95
			_sparkles.append({
				"pos": Vector2(cos(a) * d, sin(a) * d * SQUASH),
				"phase": randf() * TAU,
				"speed": randf_range(1.2, 3.0),
				"size": randf_range(1.0, 2.2),
			})
		return
	_soft_tex = _make_soft_texture()
	for i in 6:
		var shaft := Polygon2D.new()
		var x := randf_range(-0.6, 0.6) * radius
		var w := randf_range(8.0, 22.0)
		var hgt := randf_range(170.0, 260.0)
		var lean := randf_range(-18.0, 18.0)
		shaft.polygon = PackedVector2Array([Vector2(x - w, 0), Vector2(x + w, 0), Vector2(x + w * 0.5 + lean, -hgt), Vector2(x - w * 0.5 + lean, -hgt)])
		shaft.vertex_colors = PackedColorArray([Color(MINT, 0.22), Color(MINT, 0.22), Color(MINT, 0.0), Color(MINT, 0.0)])
		add_child(shaft)
		_shafts.append({"node": shaft, "phase": randf() * TAU, "speed": randf_range(0.5, 1.1)})
	_mist = _make_mist()
	add_child(_mist)
	_orbs = _make_orbs()
	add_child(_orbs)
	_motes = _make_motes()
	add_child(_motes)


func _make_soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _make_motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_tex
	p.amount = 40
	p.lifetime = 4.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.8
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(MINT, 0.0), Color(1, 1, 1, 0.95), Color(CYAN, 0.6), Color(CYAN, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.65, 1.0])
	p.color_ramp = g
	p.position = Vector2(0, -6)
	p.material = _additive()
	return p


func _make_mist() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_tex
	p.amount = 14
	p.lifetime = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.8
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 1.8
	p.scale_amount_max = 3.4
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(MINT, 0.0), Color(MINT, 0.12), Color(CYAN, 0.08), Color(CYAN, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	p.color_ramp = g
	p.material = _additive()
	return p


## Những quả cầu sáng lớn, mờ, trôi chậm (như linh khí kết tụ).
func _make_orbs() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _soft_tex
	p.amount = 7
	p.lifetime = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.7
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.9
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(VIOLET, 0.0), Color(MINT, 0.3), Color(CYAN, 0.22), Color(VIOLET, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	p.color_ramp = g
	p.position = Vector2(0, -10)
	p.material = _additive()
	return p


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _process(delta: float) -> void:
	_t += delta
	_k = lerpf(_k, target, minf(1.0, delta * 2.5))
	if mode == "fx":
		for s in _shafts:
			var n: Polygon2D = s["node"]
			var a := 0.5 + 0.5 * sin(_t * float(s["speed"]) + float(s["phase"]))
			n.modulate.a = clampf(_k * (0.35 + 0.65 * a), 0.0, 1.0)
			n.position.x = sin(_t * 0.3 + float(s["phase"])) * 6.0
		_motes.speed_scale = 0.8 + _k * 0.8
		_motes.modulate.a = clampf(0.55 + _k * 0.35, 0.0, 1.0)
		_mist.modulate.a = clampf(0.6 + _k * 0.3, 0.0, 1.0)
		_orbs.modulate.a = clampf(0.5 + _k * 0.4, 0.0, 1.0)
	else:
		queue_redraw()


func _draw() -> void:
	if mode != "ground":
		return
	var k := clampf(_k, 0.3, 1.6)
	var breath := 0.85 + 0.15 * sin(_t * 1.2)
	# Quầng sáng mềm: nhiều lớp elip chồng nhau, đậm dần về tâm
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	var steps := 14
	for i in steps:
		var f := float(i) / steps
		draw_circle(Vector2.ZERO, radius * (1.1 - 0.95 * f), Color(MINT, 0.028 * k * breath))
	draw_circle(Vector2.ZERO, radius * 0.18, Color(1, 1, 1, 0.05 * k * breath))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Đốm sáng lấp lánh trên cỏ
	for s in _sparkles:
		var tw := sin(_t * float(s["speed"]) + float(s["phase"]))
		if tw <= 0.2:
			continue
		var a := (tw - 0.2) / 0.8 * clampf(k, 0.4, 1.3)
		var p: Vector2 = s["pos"]
		var sz: float = s["size"]
		draw_circle(p, sz * 2.2, Color(CYAN, a * 0.12))
		draw_circle(p, sz, Color(0.9, 1.0, 1.0, a * 0.85))
		draw_line(p + Vector2(-sz * 2.2, 0), p + Vector2(sz * 2.2, 0), Color(1, 1, 1, a * 0.4), 1.0)
		draw_line(p + Vector2(0, -sz * 2.2), p + Vector2(0, sz * 2.2), Color(1, 1, 1, a * 0.4), 1.0)
