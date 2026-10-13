extends CanvasLayer
class_name GrandCast
## Khung "đại chiêu": gồng lực (khựng hình, màn hình tối viền, vòng linh khí co về, tên chiêu hiện) rồi bùng nổ (loé sáng, rung mạnh, sóng xung kích).
## Chạy theo giờ thật (Time.get_ticks_msec) vì lúc gồng Engine.time_scale bị hạ gần 0.
## Chỉ dành cho nhóm chiêu hiếm / hồi lâu / bí truyền, xem SkillFx.is_grand.

const WIND := 0.24     # giây gồng lực
const TOTAL := 1.15    # tổng thời gian khung

static var _busy_until := 0

var main: Node
var col := Color.WHITE
var acc := Color.WHITE
var world_pos := Vector2.ZERO
var skill_name := ""
var skill_def: Dictionary = {}
var aim := Vector2.RIGHT
var targets: Array = []

var _t0 := 0
var _released := false
var _vig: TextureRect
var _banner: Label
var _ring: Control


## Dựng khung nếu chưa có khung nào đang chạy.
static func play(p_main: Node, def: Dictionary, at: Vector2, p_aim := Vector2.RIGHT, p_targets: Array = []) -> bool:
	var now := Time.get_ticks_msec()
	if now < _busy_until or p_main == null:
		return false
	_busy_until = now + int(TOTAL * 1000.0)
	var g := GrandCast.new()
	g.main = p_main
	var c: Array = SkillFx.palette(def)
	g.col = c[0]
	g.acc = c[1]
	g.world_pos = at
	g.skill_name = str(def.get("name", ""))
	g.skill_def = def
	g.aim = p_aim
	for t in p_targets.slice(0, 6):
		g.targets.append((t as Node2D).position + Vector2(0, -24))
	p_main.add_child(g)
	return true


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vig = TextureRect.new()
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tint := Color(col.r * 0.12, col.g * 0.12, col.b * 0.2 + 0.04)
	grad.colors = PackedColorArray([Color(tint, 0.12), Color(tint, 0.3), Color(tint, 0.95)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_vig.texture = tex
	_vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.modulate.a = 0.0
	root.add_child(_vig)
	_ring = Ring.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_ring as Ring).col = col
	(_ring as Ring).acc = acc
	root.add_child(_ring)
	_banner = Label.new()
	_banner.text = skill_name
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 108.0
	_banner.offset_bottom = 170.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.45))
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	if main.get("school") != null:
		main.school.hitstop(WIND * 0.9)


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec() - _t0) / 1000.0
	if not is_instance_valid(main):
		queue_free()
		return
	var center := Vector2.ZERO
	if main.fx_layer != null:
		center = main.fx_layer.get_global_transform_with_canvas() * world_pos
	var ring := _ring as Ring
	ring.center = center
	_banner.pivot_offset = _banner.size * 0.5
	if t < WIND:
		var k := clampf(t / WIND, 0.0, 1.0)
		_vig.modulate.a = k
		ring.radius = lerpf(190.0, 18.0, k * k)
		ring.alpha = 0.35 + 0.65 * k
		ring.mode = 0
		_banner.modulate.a = k
		_banner.scale = Vector2.ONE * lerpf(1.35, 1.0, k)
	else:
		if not _released:
			_release()
		var u := clampf((t - WIND) / (TOTAL - WIND), 0.0, 1.0)
		_vig.modulate.a = (1.0 - u) * (1.0 - u)
		ring.mode = 1
		ring.radius = 18.0 + 260.0 * (1.0 - pow(1.0 - u, 3.0))
		ring.alpha = 1.0 - u
		_banner.modulate.a = 1.0 if u < 0.45 else 1.0 - (u - 0.45) / 0.55
		_banner.scale = Vector2.ONE
	if t >= TOTAL:
		queue_free()


func _release() -> void:
	_released = true
	var school: Node = main.get("school")
	if school != null:
		school.flash(col.lerp(Color.WHITE, 0.6), 0.3, 0.28)
		school.shake(8.0, 0.4)
	var parent: Node2D = main.fx_layer
	if parent != null:
		var foot := world_pos + Vector2(0, 30)
		Fx.ring(parent, foot, 12.0, 230.0, col, 0.55, 0.6, 8.0)
		Fx.ring(parent, foot, 6.0, 150.0, acc, 0.4, 0.6, 4.0)
		Fx.glow(parent, world_pos, 24.0, 160.0, col, 0.35)
		Fx.burst(parent, world_pos, acc, 22, 220.0, 0.5, 3.4)
		if GrandFx.has(str(skill_def.get("id", ""))):
			GrandFx.release(main, skill_def, world_pos, aim, targets)


## Vòng linh khí vẽ trên màn hình quanh người tung chiêu: mode 0 co lại, mode 1 toả ra.
class Ring extends Control:
	var center := Vector2.ZERO
	var radius := 100.0
	var alpha := 1.0
	var mode := 0
	var col := Color.WHITE
	var acc := Color.WHITE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := 6.0 if mode == 0 else 4.0
		draw_arc(center, radius, 0.0, TAU, 56, Color(col, alpha * 0.9), w)
		draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(acc, alpha * 0.6), 3.0)
		# tia linh khí hội tụ / toả ra
		var n := 12
		for i in n:
			var a := TAU * float(i) / float(n) + (0.0 if mode == 0 else 0.26)
			var d := Vector2(cos(a), sin(a))
			var r0 := radius * (1.0 if mode == 0 else 0.8)
			var r1 := radius * (1.45 if mode == 0 else 1.12)
			draw_line(center + d * r0, center + d * r1, Color(acc, alpha * 0.55), 2.0)
