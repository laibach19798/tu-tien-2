extends Node
class_name Atmosphere
## Bầu không khí 2.5D: chu kỳ ngày đêm, ánh sáng đèn/linh mạch, đom đóm, viền tối,
## shader gió lay cây và nước lấp lánh. Phím T: tua nhanh thời gian (để kiểm tra).

const DAY_SECONDS := 360.0
const NIGHT_TINT := Color(0.30, 0.37, 0.62)
const DUSK_TINT := Color(1.0, 0.74, 0.58)

var t := 0.35          # 0 = nửa đêm, 0.5 = chính ngọ
var darkness := 0.0    # 0 ban ngày .. 1 đêm sâu
var sun := 1.0
var modulate_node: CanvasModulate
var _lights: Array = []
var _light_tex: GradientTexture2D
var _fireflies: CPUParticles2D
var _sway_cache := {}
var _water_mat: ShaderMaterial


func _ready() -> void:
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	# Viền tối nhẹ quanh màn hình (nằm dưới HUD vì được thêm vào cây trước HUD)
	var vl := CanvasLayer.new()
	vl.layer = 1
	add_child(vl)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = dot(uv, uv);
	COLOR = vec4(0.0, 0.02, 0.07, smoothstep(0.13, 0.55, d) * 0.5);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	vl.add_child(rect)
	# Texture ánh sáng tròn mờ dần
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	_light_tex = GradientTexture2D.new()
	_light_tex.gradient = g
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	_light_tex.width = 256
	_light_tex.height = 256
	_apply()


## mode: "night" = chỉ sáng về đêm, "always" = luôn sáng, "manual" = do code ngoài điều khiển.
func add_light(pos: Vector2, color: Color, tex_scale: float, energy: float, mode := "night", parent: Node = null) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.texture_scale = tex_scale
	l.energy = energy if mode != "night" else 0.0
	l.position = pos
	(parent if parent else self).add_child(l)
	_lights.append({"node": l, "base": energy, "mode": mode})
	return l


func attach(camera: Camera2D) -> void:
	_fireflies = CPUParticles2D.new()
	_fireflies.emitting = false
	_fireflies.amount = 45
	_fireflies.lifetime = 6.0
	_fireflies.local_coords = false
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = Vector2(700, 400)
	_fireflies.direction = Vector2(0, -1)
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.initial_velocity_min = 4.0
	_fireflies.initial_velocity_max = 12.0
	_fireflies.scale_amount_min = 1.6
	_fireflies.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 0.6, 0), Color(1, 1, 0.6, 1), Color(1, 1, 0.6, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_fireflies.color_ramp = ramp
	camera.add_child(_fireflies)


func _process(delta: float) -> void:
	t = fposmod(t + delta / DAY_SECONDS, 1.0)
	_apply()
	for e in _lights:
		var n: PointLight2D = e["node"]
		if not is_instance_valid(n):
			continue
		if e["mode"] == "night":
			n.energy = float(e["base"]) * smoothstep(0.1, 0.7, darkness)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		t = fposmod(t + 0.08, 1.0)


func _apply() -> void:
	sun = 0.5 + 0.5 * cos((t - 0.5) * TAU)
	var col := Color.WHITE
	if sun < 0.25:
		col = NIGHT_TINT
	elif sun < 0.5:
		col = NIGHT_TINT.lerp(DUSK_TINT, (sun - 0.25) / 0.25)
	elif sun < 0.72:
		col = DUSK_TINT.lerp(Color.WHITE, (sun - 0.5) / 0.22)
	modulate_node.color = col
	darkness = 1.0 - smoothstep(0.2, 0.55, sun)
	if _fireflies:
		_fireflies.emitting = darkness > 0.35


func period_name() -> String:
	if sun > 0.72:
		return "Buổi sáng" if t < 0.5 else "Buổi chiều"
	if sun > 0.4:
		return "Bình minh" if t < 0.5 else "Hoàng hôn"
	return "Ban đêm"


## Shader gió: ngọn lay nhiều hơn gốc, pha dao động theo vị trí để các cây không lay đồng loạt.
func sway_material(amp: float) -> ShaderMaterial:
	if _sway_cache.has(amp):
		return _sway_cache[amp]
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amp = 2.0;
uniform float speed = 1.5;
void vertex() {
	float ph = MODEL_MATRIX[3].x * 0.011 + MODEL_MATRIX[3].y * 0.007;
	float w = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + ph) * amp * w * w;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amp", amp)
	_sway_cache[amp] = m
	return m


## Nước: các vệt sáng chạy chậm trên mặt nước.
func water_material() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5 && c.b > c.g + 0.12) {
		float w = sin(UV.x * 140.0 + TIME * 1.8 + sin(UV.y * 60.0 + TIME * 0.9) * 2.0);
		c.rgb += vec3(0.07, 0.09, 0.10) * step(0.85, w);
	}
	COLOR = c;
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = sh
	return _water_mat
