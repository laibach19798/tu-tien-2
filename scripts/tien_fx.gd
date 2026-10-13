extends Node2D
class_name TienFx
## Hiệu ứng tiên môn: đảo bay lơ lửng nhấp nhô, mây trôi, sương trên cao nguyên và linh quang bay lên.
## kind "sky": đặt trong layer_ground (sau vật thể) — đảo bay + mây nền; kind "mist": đặt trên cùng — sương và linh quang.

var kind := "sky"
var size := Vector2(3600, 2800)
var plateau := Rect2()           # vùng cao nguyên đi được (ngoài vùng này là biển mây)
var tint := Color(1, 1, 1)
var _t := randf() * 30.0
var _islands: Array = []         # {spr, base, amp, ph, sp}
var _clouds: Array = []          # {spr, speed}
var _cloud_tex: Array = []


func _ready() -> void:
	_cloud_tex = [_make_cloud(0), _make_cloud(1), _make_cloud(2)]
	if kind == "sky":
		_build_sky()
	else:
		_build_mist()


func add_island(tex: Texture2D, pos: Vector2, sc: float, amp: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * sc
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	var glow := _make_cloud(1)
	var g := Sprite2D.new()
	g.texture = glow
	g.position = Vector2(0, tex.get_height() * 0.45)
	g.modulate = Color(1, 1, 1, 0.55)
	g.scale = Vector2(1.6, 0.5)
	s.add_child(g)
	_islands.append({"spr": s, "base": pos, "amp": amp, "ph": randf() * TAU, "sp": randf_range(0.5, 0.9)})


func _build_sky() -> void:
	# mây trôi trong vùng trời (ngoài cao nguyên)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 46:
		var p := Vector2(rng.randf_range(-100, size.x + 100), rng.randf_range(-60, size.y + 60))
		if plateau.grow(40.0).has_point(p):
			continue
		var s := Sprite2D.new()
		s.texture = _cloud_tex[rng.randi() % 3]
		s.position = p
		s.scale = Vector2.ONE * rng.randf_range(1.2, 2.6)
		s.modulate = Color(tint, rng.randf_range(0.5, 0.85))
		add_child(s)
		_clouds.append({"spr": s, "speed": rng.randf_range(4.0, 12.0)})


func _build_mist() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	# dải sương mỏng trôi ngang cao nguyên
	for i in 22:
		var p := Vector2(rng.randf_range(plateau.position.x, plateau.end.x), rng.randf_range(plateau.position.y, plateau.end.y))
		var s := Sprite2D.new()
		s.texture = _cloud_tex[rng.randi() % 3]
		s.position = p
		s.scale = Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(0.9, 1.5))
		s.modulate = Color(tint.r, tint.g, tint.b, rng.randf_range(0.07, 0.14))
		s.z_index = 120
		add_child(s)
		_clouds.append({"spr": s, "speed": rng.randf_range(6.0, 14.0)})
	# linh quang bay lên toàn cao nguyên
	var motes := CPUParticles2D.new()
	motes.amount = 160
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.local_coords = true
	motes.position = plateau.get_center()
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = plateau.size * 0.5
	motes.direction = Vector2(0, -1)
	motes.spread = 40.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 26.0
	motes.scale_amount_min = 1.8
	motes.scale_amount_max = 3.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(tint, 0.0), Color(tint.lerp(Color.WHITE, 0.5), 0.9), Color(tint, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	motes.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = mat
	motes.z_index = 130
	add_child(motes)


func _process(delta: float) -> void:
	_t += delta
	for e in _islands:
		var s: Sprite2D = e["spr"]
		s.position = (e["base"] as Vector2) + Vector2(sin(_t * float(e["sp"]) * 0.6 + float(e["ph"])) * 6.0, sin(_t * float(e["sp"]) + float(e["ph"])) * float(e["amp"]))
	for c in _clouds:
		var s: Sprite2D = c["spr"]
		s.position.x += float(c["speed"]) * delta
		if s.position.x > size.x + 400.0:
			s.position.x = -400.0


## Đám mây mềm vẽ bằng nhiễu: nhiều chấm tròn mờ chồng lên nhau.
static func _make_cloud(seed_i: int) -> Texture2D:
	var w := 160
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + seed_i * 17
	var blobs: Array = []
	for i in 9:
		blobs.append([Vector2(rng.randf_range(34, w - 34), rng.randf_range(26, h - 22)), rng.randf_range(16, 30)])
	for y in h:
		for x in w:
			var a := 0.0
			for b in blobs:
				var d := Vector2(x, y).distance_to(b[0]) / float(b[1])
				a = maxf(a, 1.0 - smoothstep(0.35, 1.0, d))
			if a > 0.0:
				var shade := 1.0 - 0.12 * (float(y) / h)
				img.set_pixel(x, y, Color(shade, shade, 1.0 if y < h / 2 else 0.98, a * 0.9))
	return ImageTexture.create_from_image(img)
