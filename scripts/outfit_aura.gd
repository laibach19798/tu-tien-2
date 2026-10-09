extends Node2D
## Hào quang rực rỡ của trang phục: quầng sáng sau lưng, vòng pháp trận dưới chân, linh khí bay lên,
## tia lấp lánh, vệt sáng khi di chuyển, và viền phát sáng trên lớp áo (shader outfit_glow).
## Wardrobe.apply tạo node này khi bộ đồ có trường "aura" và đặt nó làm con đầu tiên (vẽ phía sau sprite).
## Toạ độ theo ô 64px của nhân vật, gốc ở chân.

const GLOW_SHADER := preload("res://scripts/outfit_glow.gdshader")
const BODY_CENTER := Vector2(0, -24)

var color := Color(0.6, 0.9, 1.0)
var color2 := Color(1.0, 0.95, 0.7)
var _t := 0.0
var _clothes: AnimatedSprite2D
var _rise: CPUParticles2D
var _sparks: CPUParticles2D
var _trail: CPUParticles2D
var _last_pos := Vector2.ZERO
var _speed := 0.0
var _trail_on := true
var _canvas_mod: CanvasModulate
var _light: PointLight2D
var _find_timer := 0.0


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_rise = _make_emitter(36, 1.5, Vector2(0, -1), 14.0, 28.0, 1.0, 2.0)
	_rise.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rise.emission_rect_extents = Vector2(12, 14)
	_rise.position = BODY_CENTER
	_sparks = _make_emitter(8, 1.0, Vector2(0, -1), 4.0, 12.0, 2.0, 3.2)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 20.0
	_sparks.position = BODY_CENTER
	_sparks.spread = 180.0
	_trail = _make_emitter(18, 0.6, Vector2(0, 0), 0.0, 3.0, 2.0, 3.5)
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 7.0
	_trail.position = Vector2(0, -6)
	_trail.local_coords = false   # hạt ở lại thế giới, tạo thành vệt
	_trail.emitting = false
	_last_pos = global_position
	_light = PointLight2D.new()
	_light.texture = _make_light_texture()
	_light.position = BODY_CENTER
	_light.texture_scale = 0.9
	_light.energy = 0.0
	add_child(_light)
	_apply_colors()


func _make_light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


## Độ "đêm" 0..1 và hệ số bù màu, đọc từ CanvasModulate của cảnh (Atmosphere).
func _night_state() -> Array:
	if not is_instance_valid(_canvas_mod):
		_canvas_mod = null
		if _find_timer <= 0.0 and is_inside_tree():
			_find_timer = 1.0
			var found := get_tree().root.find_children("*", "CanvasModulate", true, false)
			if not found.is_empty():
				_canvas_mod = found[0]
	if _canvas_mod == null:
		return [0.0, Color.WHITE]
	var c := _canvas_mod.color
	var lum := (c.r + c.g + c.b) / 3.0
	var boost := Color(minf(1.0 / maxf(c.r, 0.2), 3.5), minf(1.0 / maxf(c.g, 0.2), 3.5), minf(1.0 / maxf(c.b, 0.2), 3.5))
	return [clampf((1.0 - lum) / 0.5, 0.0, 1.0), boost]


## cfg: color, color2, outline (độ dày viền, 0 = tắt), rise (có linh khí không), trail (có vệt khi chạy không)
func configure(cfg: Dictionary, clothes_layer: AnimatedSprite2D) -> void:
	color = cfg.get("color", color)
	color2 = cfg.get("color2", color2)
	_trail_on = bool(cfg.get("trail", true))
	_clothes = clothes_layer
	var width: float = cfg.get("outline", 1.0)
	if width > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("glow_color", color)
		mat.set_shader_parameter("outline_width", width)
		_clothes.material = mat
	else:
		_clothes.material = null
	if _rise != null:
		_rise.visible = bool(cfg.get("rise", true))
		_apply_colors()
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_clothes):
		_clothes.material = null


func _apply_colors() -> void:
	for p in [_rise, _sparks, _trail]:
		var g := Gradient.new()
		g.set_color(0, Color(color2, 0.95))
		g.add_point(0.45, Color(color, 0.7))
		g.set_color(g.get_point_count() - 1, Color(color, 0.0))
		(p as CPUParticles2D).color_ramp = g


func _make_emitter(amount: int, life: float, dir: Vector2, vmin: float, vmax: float, smin: float, smax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = 15.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.emitting = true
	p.use_parent_material = true   # cộng sáng như node cha
	add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), 0.2)
	_trail.emitting = _trail_on and _speed > 25.0
	_find_timer -= delta
	var st := _night_state()
	var night: float = st[0]
	var boost: Color = st[1]
	self_modulate = boost   # bù màu đêm: hào quang giữ nguyên màu thật thay vì bị tối đi
	for p in [_rise, _sparks, _trail]:
		(p as CPUParticles2D).self_modulate = boost
	_light.color = color
	_light.energy = (0.35 + 0.9 * night) * (0.85 + 0.15 * sin(_t * 2.6))   # đêm: soi sáng cả mặt đất quanh người
	if is_instance_valid(_clothes) and _clothes.material is ShaderMaterial:
		var m := _clothes.material as ShaderMaterial
		m.set_shader_parameter("glow_color", color)
		m.set_shader_parameter("boost", Vector3(boost.r, boost.g, boost.b) * (1.0 + 0.5 * night))
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.6)
	# quầng sáng mềm sau lưng
	for i in 5:
		var r := 30.0 - i * 4.5
		draw_circle(BODY_CENTER, r, Color(color, 0.035 + 0.01 * pulse))
	# vòng pháp trận dưới chân (elip dẹt)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, 17.0 + pulse * 2.0, 0.0, TAU, 40, Color(color, 0.7), 1.2)
	draw_arc(Vector2.ZERO, 11.0 - pulse, 0.0, TAU, 32, Color(color2, 0.5), 1.0)
	for i in 8:
		var a := _t * 1.2 + i * TAU / 8.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * 17.0, dir * 21.0, Color(color2, 0.8), 1.4)
	for i in 3:
		var a2 := -_t * 0.8 + i * TAU / 3.0
		draw_circle(Vector2(cos(a2), sin(a2)) * 11.0, 1.4, Color(color2, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
