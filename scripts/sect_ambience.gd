extends Node2D
class_name SectAmbience
## Không khí tiên môn cho sân tông môn (thí điểm Kiếm Tông): lớp ngọc bạch phủ nền, kiếm trận phát sáng dưới sân,
## sương mây trôi sát mặt đất, tia sáng xuyên mây, cánh hoa bay, phi kiếm tuần tra trên trời.
## Dựng bằng code (pixel art giữ nguyên, thêm yếu tố huyền ảo). Gọi MapBuilder._compound khi sid == người chơi.

## Bản sắc từng tông: tiền tố tài nguyên (assets/props/<prefix>_*.png), bộ gạch sân, màu phủ nền, cột sáng, sương, hạt bay, binh khí tuần tra.
## Thiếu ảnh riêng của tông thì dùng ảnh Kiếm Tông (kt_*).
const STYLES := {
	"kiem_tong": {"prefix": "kt", "tiles": "jade", "wash": Color(0.56, 0.86, 0.80, 0.30), "shaft": Color(1.0, 0.98, 0.86), "bank": Color(0.95, 1.0, 1.0),
		"glow": Color(0.5, 0.9, 1.0), "blade": "kiem",
		"pond": {"deep": Color(0.09, 0.40, 0.68), "mid": Color(0.13, 0.49, 0.77), "shallow": Color(0.27, 0.64, 0.88), "shine": Color(0.62, 0.86, 0.97), "shore": Color(0.82, 0.75, 0.6), "rock": Color(0.55, 0.52, 0.5), "lily": true},
		"petal": {"ramp": [Color(1.0, 0.78, 0.86, 0.0), Color(1.0, 0.82, 0.9, 0.9), Color(1.0, 0.95, 0.97, 0.0)], "dir": Vector2(0.4, 1.0), "gravity": Vector2(6, 10), "v": Vector2(12, 30), "life": 11.0}},
	"xich_viem": {"prefix": "xv", "tiles": "xv", "wash": Color(0.95, 0.42, 0.18, 0.22), "shaft": Color(1.0, 0.68, 0.32), "bank": Color(1.0, 0.62, 0.5),
		"glow": Color(1.0, 0.5, 0.2), "blade": "dao",
		"pond": {"deep": Color(0.55, 0.10, 0.04), "mid": Color(0.85, 0.28, 0.06), "shallow": Color(1.0, 0.52, 0.12), "shine": Color(1.0, 0.85, 0.4), "shore": Color(0.18, 0.1, 0.09), "rock": Color(0.28, 0.2, 0.18), "lily": false},
		"petal": {"ramp": [Color(1.0, 0.45, 0.1, 0.0), Color(1.0, 0.65, 0.2, 0.95), Color(0.5, 0.1, 0.05, 0.0)], "dir": Vector2(0.15, -1.0), "gravity": Vector2(0, -14), "v": Vector2(18, 44), "life": 7.0}},
	"han_bang": {"prefix": "hb", "tiles": "hb", "wash": Color(0.70, 0.90, 1.0, 0.26), "shaft": Color(0.8, 0.95, 1.0), "bank": Color(0.85, 0.95, 1.0),
		"glow": Color(0.6, 0.9, 1.0), "blade": "thuong",
		"pond": {"deep": Color(0.42, 0.68, 0.86), "mid": Color(0.6, 0.82, 0.94), "shallow": Color(0.78, 0.92, 0.98), "shine": Color(1.0, 1.0, 1.0), "shore": Color(0.92, 0.96, 1.0), "rock": Color(0.7, 0.8, 0.88), "lily": false},
		"petal": {"ramp": [Color(0.9, 0.97, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.95), Color(0.75, 0.9, 1.0, 0.0)], "dir": Vector2(0.1, 1.0), "gravity": Vector2(4, 16), "v": Vector2(10, 26), "life": 12.0}},
	"doc_mon": {"prefix": "dm", "tiles": "dm", "wash": Color(0.42, 0.78, 0.28, 0.22), "shaft": Color(0.65, 1.0, 0.45), "bank": Color(0.62, 0.9, 0.5),
		"glow": Color(0.55, 0.95, 0.35), "blade": "liem",
		"pond": {"deep": Color(0.10, 0.28, 0.12), "mid": Color(0.22, 0.46, 0.14), "shallow": Color(0.42, 0.68, 0.2), "shine": Color(0.72, 0.95, 0.4), "shore": Color(0.3, 0.26, 0.14), "rock": Color(0.28, 0.3, 0.24), "lily": true},
		"petal": {"ramp": [Color(0.5, 1.0, 0.3, 0.0), Color(0.6, 1.0, 0.4, 0.85), Color(0.3, 0.7, 0.2, 0.0)], "dir": Vector2(0.2, -1.0), "gravity": Vector2(0, -6), "v": Vector2(6, 18), "life": 10.0}},
	"huyen_minh": {"prefix": "hm", "tiles": "hm", "wash": Color(0.55, 0.35, 0.85, 0.24), "shaft": Color(0.78, 0.58, 1.0), "bank": Color(0.72, 0.58, 0.92),
		"glow": Color(0.75, 0.5, 1.0), "blade": "xa",
		"pond": {"deep": Color(0.14, 0.06, 0.32), "mid": Color(0.28, 0.12, 0.52), "shallow": Color(0.46, 0.26, 0.74), "shine": Color(0.78, 0.6, 1.0), "shore": Color(0.2, 0.15, 0.3), "rock": Color(0.26, 0.22, 0.34), "lily": false},
		"petal": {"ramp": [Color(0.7, 0.45, 1.0, 0.0), Color(0.85, 0.65, 1.0, 0.9), Color(0.4, 0.2, 0.7, 0.0)], "dir": Vector2(0.3, -1.0), "gravity": Vector2(0, -8), "v": Vector2(8, 22), "life": 10.0}},
}

var sect := "kiem_tong"   # id tông (khoá của STYLES)
var plateau := Rect2()
var map_size := Vector2(3600, 2800)
var color := Color(0.5, 0.85, 1.0)
var sites: Array = []        # [[tâm, bán kính]] các sân có kiếm trận
var _t := randf() * 40.0
var _banks: Array = []       # {spr, speed}
var _shafts: Array = []      # {node, base_alpha, ph}
var _swords: Array = []      # {node, c, rx, ry, sp, ph}
var _islands: Array = []     # {spr, base, ph, sp}
var _cranes: Array = []      # {spr, shadow, y, speed, dir, x, ph}


## Một kiếm trận nhìn từ trên (elip dẹt): vòng ngoài, vòng giữa, tám kiếm ấn quay chậm, sao tám cánh, bốn kiếm chữ thập.
class Disc extends Node2D:
	var r := 200.0
	var col := Color(0.5, 0.85, 1.0)
	var base := false   # true: lớp nền ngọc (vẽ thường); false: lớp phát sáng (cộng sáng)
	var phase := 0.0
	var _t := 0.0

	func _ready() -> void:
		if not base:
			material = Fx.additive()
		phase = randf() * TAU

	func _process(delta: float) -> void:
		_t += delta
		if not base:
			queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		if base:
			draw_circle(Vector2.ZERO, r * 1.04, Color(0.80, 0.96, 0.92, 0.24))
			draw_circle(Vector2.ZERO, r * 0.78, Color(0.88, 1.0, 0.96, 0.18))
			return
		var pulse := 0.65 + 0.35 * sin(_t * 1.7 + phase)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(col, 0.95 * pulse), 4.0)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 64, Color(col, 0.70 * pulse), 3.0)
		draw_arc(Vector2.ZERO, r * 0.40, 0.0, TAU, 40, Color(col, 0.85 * pulse), 3.0)
		# tám kiếm ấn quanh vòng, quay chậm
		for i in 8:
			var a := _t * 0.22 + phase + float(i) * TAU / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_line(d * r * 0.84, d * r * 0.99, Color(col.lerp(Color.WHITE, 0.4), 0.85 * pulse), 4.0)
			draw_circle(d * r * 0.9, 3.5, Color(1, 1, 1, 0.55 * pulse))
		# sao tám cánh quay ngược chiều
		var star := PackedVector2Array()
		for i in 16:
			var a2 := -_t * 0.35 + phase + float(i) * TAU / 16.0
			var rr := r * (0.34 if i % 2 == 0 else 0.14)
			star.append(Vector2(cos(a2), sin(a2)) * rr)
		star.append(star[0])
		draw_polyline(star, Color(col.lerp(Color.WHITE, 0.3), 1.0 * pulse), 3.0)
		# bốn thanh kiếm chữ thập nằm trên nền
		for k in 4:
			var ak := _t * 0.05 + phase + float(k) * PI / 2.0
			var dk := Vector2(cos(ak), sin(ak))
			draw_line(dk * r * 0.2, dk * r * 0.74, Color(col, 0.6 * pulse), 3.0)
			draw_line(dk * r * 0.7, dk * r * 0.78, Color(1, 1, 1, 0.5 * pulse), 4.0)


func _style() -> Dictionary:
	return STYLES.get(sect, STYLES["kiem_tong"])


func _ready() -> void:
	z_index = 0
	_build_wash()
	_build_discs()
	_build_shafts()
	_build_banks()
	_build_petals()
	_build_swords()
	_build_islands()
	_build_cranes()


# ------------------------------------------------------------------ dựng
## Lớp ngọc bạch phủ nhẹ lên nền đá xám để mặt sân không còn là một tấm gạch xám đồng nhất.
func _build_wash() -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([plateau.position, Vector2(plateau.end.x, plateau.position.y), plateau.end, Vector2(plateau.position.x, plateau.end.y)])
	p.color = _style().wash
	p.z_index = 0
	add_child(p)


func _build_discs() -> void:
	for s in sites:
		var c: Vector2 = s[0]
		var rad: float = float(s[1])
		for is_base in [true, false]:
			var d := Disc.new()
			d.r = rad
			d.col = color
			d.base = is_base
			d.position = c
			d.z_index = 0
			add_child(d)


func _build_shafts() -> void:
	# những cột sáng nghiêng xuyên mây từ trên cao rọi xuống sân
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 7:
		var x := rng.randf_range(plateau.position.x + 200.0, plateau.end.x - 200.0)
		var w := rng.randf_range(90.0, 170.0)
		var h := rng.randf_range(900.0, 1500.0)
		var p := Polygon2D.new()
		var slant := 260.0
		p.polygon = PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, h), Vector2(x - slant, h)])
		var sc: Color = _style().shaft
		var top := Color(sc, 0.0)
		var mid := Color(sc, 0.28)
		p.vertex_colors = PackedColorArray([top, top, mid, mid])
		p.material = Fx.additive()
		p.position = Vector2(0, plateau.position.y - 200.0 + rng.randf_range(0.0, 500.0))
		p.z_index = 125
		add_child(p)
		_shafts.append({"node": p, "ph": rng.randf() * TAU, "sp": rng.randf_range(0.2, 0.5)})


func _build_banks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 9:
		var s := Sprite2D.new()
		s.texture = TienFx._make_cloud(i % 3)
		s.position = Vector2(rng.randf_range(plateau.position.x - 200.0, plateau.end.x), rng.randf_range(plateau.position.y + 100.0, plateau.end.y - 100.0))
		s.scale = Vector2(rng.randf_range(6.5, 10.0), rng.randf_range(2.2, 3.4))
		s.modulate = Color(_style().bank, rng.randf_range(0.18, 0.28))
		s.z_index = 118
		add_child(s)
		_banks.append({"spr": s, "speed": rng.randf_range(5.0, 11.0)})


func _build_petals() -> void:
	var st: Dictionary = _style().petal
	var up: bool = (st.dir as Vector2).y < 0.0   # hạt bay lên (tàn lửa, bào tử, hồn) hay rơi xuống (cánh hoa, tuyết)
	var pet := CPUParticles2D.new()
	pet.amount = 70
	pet.lifetime = float(st.life)
	pet.preprocess = float(st.life)
	pet.position = plateau.get_center() + Vector2(0, plateau.size.y * (0.3 if up else -0.25))
	pet.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pet.emission_rect_extents = Vector2(plateau.size.x * 0.5, 60.0)
	pet.direction = st.dir
	pet.spread = 25.0
	pet.gravity = st.gravity
	pet.initial_velocity_min = (st.v as Vector2).x
	pet.initial_velocity_max = (st.v as Vector2).y
	pet.angular_velocity_min = -90.0
	pet.angular_velocity_max = 90.0
	pet.scale_amount_min = 2.4
	pet.scale_amount_max = 4.4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(st.ramp)
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	pet.color_ramp = ramp
	pet.z_index = 135
	add_child(pet)


func _build_swords() -> void:
	# phi kiếm tuần tra cao trên sân, mỗi thanh một quỹ đạo elip và vệt sáng
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var routes := [
		[Vector2(1800, 1050), 1100.0, 220.0], [Vector2(1800, 1900), 1250.0, 260.0],
		[Vector2(900, 1200), 420.0, 150.0], [Vector2(2700, 1200), 420.0, 150.0],
		[Vector2(1800, 600), 700.0, 120.0],
	]
	for r in routes:
		for k in 2:
			var s := SwordVisual.new()
			s.shape = str(_style().blade)
			s.length = 44.0 if s.shape == "kiem" else SwordVisual.length_of(s.shape) + 14.0
			s.glow = 1.0
			s.glow_color = color
			s.z_index = 140
			add_child(s)
			Fx.trail(self, s, color, 13.0, 0.9)
			_swords.append({"node": s, "c": r[0], "rx": float(r[1]), "ry": float(r[2]),
				"sp": rng.randf_range(0.18, 0.32) * (1.0 if k == 0 else -1.0), "ph": rng.randf() * TAU + float(k) * PI})


## Ảnh riêng của tông (<prefix>_<name>), thiếu thì dùng ảnh Kiếm Tông (kt_<name>).
func _tex(name: String) -> Texture2D:
	for pre in [str(_style().prefix), "kt"]:
		var path := "res://assets/props/%s_%s.png" % [pre, name]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Khung hình chim tuần (<prefix>_bird_0..8); tông chưa có thì dùng tiên hạc kt_crane_0..8.
func _bird_frames() -> Array:
	var out: Array = []
	var own := ResourceLoader.exists("res://assets/props/%s_bird_0.png" % str(_style().prefix))
	for k in 9:
		var path := ("res://assets/props/%s_bird_%d.png" % [str(_style().prefix), k]) if own else ("res://assets/props/kt_crane_%d.png" % k)
		var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
		if tex != null:
			out.append(tex)
	return out


## Núi đảo lớn lơ lửng ở ngoài cao nguyên (biển mây), nhấp nhô chậm: tạo quy mô tiên cảnh cho hậu cảnh.
func _build_islands() -> void:
	var tex := _tex("island")
	if tex == null:
		return
	var spots := [[Vector2(560, 150), 1.5, 0.0], [Vector2(1650, 90), 1.15, 1.0], [Vector2(2950, 160), 1.6, 0.0],
		[Vector2(100, 1420), 1.2, 1.0], [Vector2(3500, 1250), 1.3, 0.0], [Vector2(130, 2400), 1.1, 0.0], [Vector2(3480, 2450), 1.2, 1.0]]
	for sp in spots:
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(float(sp[1]) * (-1.0 if float(sp[2]) > 0.5 else 1.0), float(sp[1]))
		s.position = sp[0]
		s.z_index = 2
		add_child(s)
		var glow := Sprite2D.new()   # quầng sáng trắng dưới đáy đảo
		glow.texture = TienFx._make_cloud(1)
		glow.modulate = Color(1, 1, 1, 0.5)
		glow.scale = Vector2(2.4, 0.9)
		glow.position = Vector2(0, tex.get_height() * 0.45)
		s.add_child(glow)
		_islands.append({"spr": s, "base": sp[0], "ph": randf() * TAU, "sp": randf_range(0.35, 0.6)})


## Tiên hạc bay ngang cao nguyên: vỗ cánh nhẹ, có bóng đổ xuống sân, quay đầu khi bay ngược chiều.
func _build_cranes() -> void:
	var frames: Array = _bird_frames()
	if frames.is_empty():
		return
	var tex: Texture2D = frames[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var lanes := [[760.0, 34.0], [1560.0, 26.0], [2240.0, 40.0], [1180.0, 30.0]]
	for i in lanes.size():
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * 1.5
		s.z_index = 145
		add_child(s)
		var sh := Sprite2D.new()
		sh.texture = tex
		sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sh.modulate = Color(0, 0, 0, 0.22)
		sh.scale = Vector2(1.3, 0.55)
		sh.z_index = 1
		add_child(sh)
		var dir := 1.0 if i % 2 == 0 else -1.0
		_cranes.append({"spr": s, "shadow": sh, "y": float(lanes[i][0]), "speed": float(lanes[i][1]), "dir": dir,
			"x": rng.randf_range(plateau.position.x, plateau.end.x), "ph": rng.randf() * TAU,
			"frames": frames, "fps": rng.randf_range(8.0, 11.0), "k": 96.0 / float(tex.get_width())})

# ------------------------------------------------------------------ chuyển động
func _process(delta: float) -> void:
	_t += delta
	for b in _banks:
		var s: Sprite2D = b["spr"]
		s.position.x += float(b["speed"]) * delta
		if s.position.x > plateau.end.x + 700.0:
			s.position.x = plateau.position.x - 700.0
	for e in _shafts:
		var n: Polygon2D = e["node"]
		n.modulate.a = 0.55 + 0.45 * sin(_t * float(e["sp"]) + float(e["ph"]))
	for e in _islands:
		var isl: Sprite2D = e["spr"]
		var b: Vector2 = e["base"]
		isl.position = b + Vector2(sin(_t * float(e["sp"]) * 0.6 + float(e["ph"])) * 5.0, sin(_t * float(e["sp"]) + float(e["ph"])) * 9.0)
	for c in _cranes:
		var cx: float = float(c["x"]) + float(c["speed"]) * float(c["dir"]) * delta * 3.0
		if cx > plateau.end.x + 200.0:
			cx = plateau.position.x - 200.0
		elif cx < plateau.position.x - 200.0:
			cx = plateau.end.x + 200.0
		c["x"] = cx
		var cy: float = float(c["y"]) + sin(_t * 0.7 + float(c["ph"])) * 18.0
		var fr: Array = c["frames"]
		var fi := int(_t * float(c["fps"]) + float(c["ph"]) * 3.0) % fr.size()   # vỗ cánh thật: đổi khung hình
		var cs: Sprite2D = c["spr"]
		cs.texture = fr[fi]
		cs.position = Vector2(cx, cy)
		var k: float = float(c["k"])
		cs.scale = Vector2(1.5 * k * float(c["dir"]) * -1.0, 1.5 * k)
		var shd: Sprite2D = c["shadow"]
		shd.texture = fr[fi]
		shd.position = Vector2(cx, cy + 150.0)
		shd.scale = Vector2(1.3 * k * float(c["dir"]) * -1.0, 0.55 * k)
	for e in _swords:
		var a: float = _t * float(e["sp"]) + float(e["ph"])
		var c: Vector2 = e["c"]
		var p := c + Vector2(cos(a) * float(e["rx"]), sin(a) * float(e["ry"]))
		var s: SwordVisual = e["node"]
		var tangent := Vector2(-sin(a) * float(e["rx"]), cos(a) * float(e["ry"])) * signf(float(e["sp"]))
		s.position = p + Vector2(0, sin(_t * 1.3 + float(e["ph"])) * 6.0)
		s.rotation = tangent.angle()
