extends Node2D
## Làng thử nghiệm: dựng toàn bộ map bằng code từ assets/props và assets/decor.
## Nền cỏ liền màu + cỏ/hoa rải rác, đường vẽ bằng Line2D uốn cong.
## Mọi prop đặt theo "chân" (giữa-đáy ảnh) để y-sort đúng với nhân vật.

const VILLAGE := Vector2(2560, 1792)   # làng gốc; các vùng mở rộng nằm ngoài khung này
const WORLD := Vector2(4096, 2816)
const PLAYER_SCALE := 1.0   # bản HD 64x64 đã to gấp đôi bản 32x32
const WALK_SPEED := 170.0
const RUN_SPEED := 300.0

const GRASS_COLOR := Color(0.42, 0.655, 0.42)
const PATH_FILL := Color(0.827, 0.718, 0.518)
const PATH_EDGE := Color(0.70, 0.575, 0.385)
const PATH_PEBBLE := Color(0.74, 0.63, 0.43)

# Chỉ giữ các mảnh cỏ/hoa đủ rõ nét (bỏ các mảnh vụn mờ tách từ ô nền)
const BLADES := [0, 2, 8, 11, 12, 17, 18, 22, 28, 31]
const FLOWERS := [7, 9, 10, 13, 21, 23, 27]

const CELL := 4   # kích thước 1 "pixel" của ảnh đường (px thế giới)
const CENTER := Vector2(1280, 900)
const PLAZA_R := 175.0
const ROAD_W := 96.0
const LANE_W := 56.0

var rng := RandomNumberGenerator.new()
var blockers: Array[Rect2] = []
var path_lines: Array = []   # [{pts: PackedVector2Array, w: float}]
var no_decor: Array[Rect2] = []
var world: Node2D
var layer_ground: Node2D
var player: Node2D
var camera: Camera2D
var direction := "south"
var atmo: Atmosphere
var layer_shadows: Node2D
var occluders: Array = []      # vật thể cao: mờ đi khi nhân vật đứng phía sau
var _med_light: PointLight2D
const FLAT_PROPS := ["field_a", "field_b", "lily", "water", "bridge"]
var pond_zone := Rect2()
var road_mask := PackedByteArray()
var road_gw := 0
var _lantern_spots: Array[Vector2] = []
var _tex_cache := {}


func _ready() -> void:
	rng.seed = 20260101
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atmo = Atmosphere.new()
	add_child(atmo)
	layer_ground = Node2D.new()
	add_child(layer_ground)
	layer_shadows = Node2D.new()
	add_child(layer_shadows)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	fx_layer = Node2D.new()   # hiệu ứng skill: vẽ phía trên vật thể
	add_child(fx_layer)
	_build_ground()
	_build_roads()
	_build_pond()
	_scatter_decor()
	_build_village()
	_build_forest()
	WorldExpansion.build(self)
	_spawn_player()
	_build_hud()
	_build_gameplay()


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


# ---------------------------------------------------------------- nền cỏ
func _build_ground() -> void:
	var base := ColorRect.new()
	base.color = GRASS_COLOR
	base.size = WORLD
	layer_ground.add_child(base)
	# Mảng cỏ đậm/nhạt nhẹ để nền không phẳng
	for i in 70:
		var c := Vector2(rng.randf_range(0, VILLAGE.x), rng.randf_range(0, VILLAGE.y))
		var r := rng.randf_range(90, 260)
		var shade := Color(0.25, 0.5, 0.3, 0.18) if i % 2 == 0 else Color(0.62, 0.8, 0.45, 0.14)
		layer_ground.add_child(_blob(c, r, r * rng.randf_range(0.55, 0.85), shade))


func _blob(c: Vector2, rx: float, ry: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 20
	for i in n:
		var a := TAU * i / n
		var k := rng.randf_range(0.88, 1.08)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	poly.polygon = pts
	poly.color = color
	return poly


# ---------------------------------------------------------------- đường
func _smooth(pts: Array, jitter := 2.5) -> PackedVector2Array:
	var p: Array = [pts[0]] + pts + [pts[pts.size() - 1]]
	var out := PackedVector2Array()
	for i in range(1, p.size() - 2):
		var p0: Vector2 = p[i - 1]
		var p1: Vector2 = p[i]
		var p2: Vector2 = p[i + 1]
		var p3: Vector2 = p[i + 2]
		var steps := maxi(4, int(p1.distance_to(p2) / 16.0))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			out.append(q + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	out.append(p[p.size() - 2])
	return out


func _road(pts: Array, w: float) -> void:
	path_lines.append({"pts": _smooth(pts, 0.0), "w": w})


## Vẽ cả mạng đường vào MỘT ảnh pixel (mỗi ô CELL px): ruột đường, viền đất sẫm,
## mép gồ ghề và cỏ lấn ra ở rìa -> không bị viền chồng nhau giữa các đoạn.
func _paint_roads() -> void:
	var gw := int(WORLD.x) / CELL
	var gh := int(WORLD.y) / CELL
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.13
	var nz := PackedFloat32Array()
	nz.resize(gw * gh)
	for y in gh:
		for x in gw:
			nz[y * gw + x] = noise.get_noise_2d(x, y)
	var mask := PackedByteArray()
	mask.resize(gw * gh)
	for line in path_lines:
		var pts: PackedVector2Array = line.pts
		var r: float = float(line.w) * 0.5 / CELL
		if pts.size() == 1:
			var c := pts[0] / CELL
			var rx := PLAZA_R / CELL
			var ry := rx * 0.82
			for y in range(maxi(0, int(c.y - ry) - 4), mini(gh, int(c.y + ry) + 5)):
				for x in range(maxi(0, int(c.x - rx) - 4), mini(gw, int(c.x + rx) + 5)):
					var d := Vector2((x - c.x) / rx, (y - c.y) / ry).length() * rx
					if d < rx + nz[y * gw + x] * 4.0:
						mask[y * gw + x] = 1
			continue
		for p in pts:
			var c := p / CELL
			var ri := int(r) + 4
			for y in range(maxi(0, int(c.y) - ri), mini(gh, int(c.y) + ri + 1)):
				for x in range(maxi(0, int(c.x) - ri), mini(gw, int(c.x) + ri + 1)):
					if Vector2(x - c.x, y - c.y).length() < r + nz[y * gw + x] * 2.2:
						mask[y * gw + x] = 1
	var data := PackedByteArray()
	data.resize(gw * gh * 4)
	var fill_a := PATH_FILL
	var fill_b := PATH_FILL.darkened(0.06)
	var grass_dark := Color(0.30, 0.53, 0.33)
	var grass_light := Color(0.52, 0.76, 0.46)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var col := Color(0, 0, 0, 0)
			var h := float(((x * 73856093) ^ (y * 19349663)) & 255) / 255.0
			if mask[i] == 1:
				var rim := _cell(mask, gw, gh, x - 1, y) == 0 or _cell(mask, gw, gh, x + 1, y) == 0 \
					or _cell(mask, gw, gh, x, y - 1) == 0 or _cell(mask, gw, gh, x, y + 1) == 0
				col = PATH_EDGE if rim else (fill_b if nz[i] > 0.25 and h > 0.5 else fill_a)
				if not rim and h < 0.025:
					col = PATH_PEBBLE
			else:
				var near1 := _cell(mask, gw, gh, x - 1, y) == 1 or _cell(mask, gw, gh, x + 1, y) == 1 \
					or _cell(mask, gw, gh, x, y - 1) == 1 or _cell(mask, gw, gh, x, y + 1) == 1
				if near1:
					if h < 0.7:
						col = grass_dark
				else:
					var near2 := _cell(mask, gw, gh, x - 2, y) == 1 or _cell(mask, gw, gh, x + 2, y) == 1 \
						or _cell(mask, gw, gh, x, y - 2) == 1 or _cell(mask, gw, gh, x, y + 2) == 1
					if near2 and h < 0.3:
						col = grass_light
			data[i * 4] = int(col.r * 255.0)
			data[i * 4 + 1] = int(col.g * 255.0)
			data[i * 4 + 2] = int(col.b * 255.0)
			data[i * 4 + 3] = int(col.a * 255.0)
	var img := Image.create_from_data(gw, gh, false, Image.FORMAT_RGBA8, data)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.scale = Vector2.ONE * CELL
	layer_ground.add_child(s)
	road_mask = mask
	road_gw = gw


func _cell(mask: PackedByteArray, gw: int, gh: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return 0
	return mask[y * gw + x]


func _build_roads() -> void:
	path_lines.append({"pts": PackedVector2Array([CENTER]), "w": PLAZA_R * 2.0})
	# Trục chính Bắc - Nam, Đông - Tây
	_road([Vector2(1110, -40), Vector2(1190, 220), Vector2(1090, 440), Vector2(1230, 640), CENTER], ROAD_W)
	_road([CENTER, Vector2(1340, 1080), Vector2(1240, 1320), Vector2(1350, 1560), Vector2(1290, 1840)], ROAD_W)
	_road([CENTER, Vector2(1560, 880), Vector2(1860, 820), Vector2(2150, 870), Vector2(2420, 800), Vector2(2610, 830)], ROAD_W)
	_road([CENTER, Vector2(1000, 940), Vector2(700, 880), Vector2(400, 950), Vector2(-50, 900)], ROAD_W)
	# Lối vào từng nhà
	_road([Vector2(820, 615), Vector2(830, 740), Vector2(710, 885)], LANE_W)
	_road([Vector2(1640, 615), Vector2(1610, 740), Vector2(1560, 878)], LANE_W)
	_road([Vector2(2150, 680), Vector2(2170, 770), Vector2(2150, 868)], LANE_W)
	_road([Vector2(500, 1215), Vector2(470, 1090), Vector2(410, 950)], LANE_W)
	_road([Vector2(1850, 1435), Vector2(1700, 1400), Vector2(1330, 1450)], LANE_W)
	WorldExpansion.add_roads(self)
	_paint_roads()
	_build_lanterns()


## Đèn lồng đặt dọc mép đường chính, xen kẽ hai bên.
func _build_lanterns() -> void:
	var side := 1.0
	for k in range(1, 5):
		var line: Dictionary = path_lines[k]
		var pts: PackedVector2Array = line.pts
		var i := 14
		while i < pts.size() - 3:
			var dir := (pts[i + 2] - pts[i - 2]).normalized()
			var p := pts[i] + Vector2(-dir.y, dir.x) * side * (ROAD_W * 0.5 + 34.0)
			if _dist_to_roads(p) > 24.0 and p.x > 60 and p.x < WORLD.x - 60 and p.y > 90 and p.y < WORLD.y - 60:
				_lantern_spots.append(p)
				side = -side
			i += 22
	for p in _lantern_spots:
		_prop("lantern", p, Vector2(24, 14))
		atmo.add_light(p + Vector2(20, -60), Color(1.0, 0.75, 0.4), 1.5, 0.95)


func _dist_to_roads(p: Vector2) -> float:
	var best := INF
	for line in path_lines:
		var pts: PackedVector2Array = line.pts
		var half: float = float(line.w) * 0.5
		if pts.size() == 1:
			best = minf(best, p.distance_to(pts[0]) * 0.9 - half)
			continue
		for i in pts.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			best = minf(best, p.distance_to(cp) - half)
	return best


# ---------------------------------------------------------------- ao
func _build_pond() -> void:
	# Ao vẽ vào một ảnh pixel: nước 3 độ sâu, gợn sóng, bờ đất, vành cỏ lấn ra.
	var center := Vector2(2110, 250)
	var rx := 250.0 / CELL
	var ry := 160.0 / CELL
	var origin := Vector2(1780, 40)
	var gw := 160
	var gh := 112
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	var ripple := FastNoiseLite.new()
	ripple.seed = 9
	ripple.frequency = 0.35
	var cc := (center - origin) / CELL
	var water := PackedByteArray()
	water.resize(gw * gh)
	var depth := PackedFloat32Array()
	depth.resize(gw * gh)
	for y in gh:
		for x in gw:
			var d := Vector2((x - cc.x) / rx, (y - cc.y) / ry).length() + noise.get_noise_2d(x, y) * 0.16
			depth[y * gw + x] = d
			if d < 1.0:
				water[y * gw + x] = 1
	var deep := Color(0.09, 0.40, 0.68)
	var mid := Color(0.13, 0.49, 0.77)
	var shallow := Color(0.27, 0.64, 0.88)
	var shine := Color(0.62, 0.86, 0.97)
	var bank := Color(0.72, 0.62, 0.42)
	var bank_dark := Color(0.50, 0.42, 0.30)
	var grass_dark := Color(0.30, 0.53, 0.33)
	var grass_light := Color(0.52, 0.76, 0.46)
	var data := PackedByteArray()
	data.resize(gw * gh * 4)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var col := Color(0, 0, 0, 0)
			var h := float(((x * 73856093) ^ (y * 19349663)) & 255) / 255.0
			if water[i] == 1:
				var edge := _cell(water, gw, gh, x - 1, y) == 0 or _cell(water, gw, gh, x + 1, y) == 0 \
					or _cell(water, gw, gh, x, y - 1) == 0 or _cell(water, gw, gh, x, y + 1) == 0
				var d: float = depth[i]
				if edge:
					col = shallow.lightened(0.15)
				else:
					col = deep if d < 0.5 else (mid if d < 0.78 else shallow)
					if ripple.get_noise_2d(x * 0.6, y * 2.2) > 0.5 and d < 0.9 and h < 0.9:
						col = shine
			else:
				var n1 := _cell(water, gw, gh, x - 1, y) == 1 or _cell(water, gw, gh, x + 1, y) == 1 \
					or _cell(water, gw, gh, x, y - 1) == 1 or _cell(water, gw, gh, x, y + 1) == 1
				var n2 := _cell(water, gw, gh, x - 2, y) == 1 or _cell(water, gw, gh, x + 2, y) == 1 \
					or _cell(water, gw, gh, x, y - 2) == 1 or _cell(water, gw, gh, x, y + 2) == 1
				var n3 := _cell(water, gw, gh, x - 3, y) == 1 or _cell(water, gw, gh, x + 3, y) == 1 \
					or _cell(water, gw, gh, x, y - 3) == 1 or _cell(water, gw, gh, x, y + 3) == 1
				if n1:
					col = bank_dark
				elif n2:
					col = bank if h < 0.85 else bank_dark
				elif n3:
					if h < 0.7:
						col = grass_dark
			data[i * 4] = int(col.r * 255.0)
			data[i * 4 + 1] = int(col.g * 255.0)
			data[i * 4 + 2] = int(col.b * 255.0)
			data[i * 4 + 3] = int(col.a * 255.0)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_RGBA8, data))
	s.centered = false
	s.scale = Vector2.ONE * CELL
	s.position = origin
	s.material = atmo.water_material()
	layer_ground.add_child(s)
	pond_zone = Rect2(origin, Vector2(gw, gh) * CELL)
	no_decor.append(pond_zone.grow(30))
	# Vùng chặn: quét từng dải 32px theo hình dạng ao (chừa 1 ô bờ cho người đi sát mép)
	for by in range(0, gh, 8):
		var minx := gw
		var maxx := -1
		for y in range(by, mini(by + 8, gh)):
			for x in gw:
				if water[y * gw + x] == 1:
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
		if maxx >= 0:
			blockers.append(Rect2(origin + Vector2(minx + 2, by) * CELL, Vector2(maxx - minx - 3, 8) * CELL))
	# Sen, đá và hoa ven bờ
	for p in [Vector2(2000, 240), Vector2(2200, 310), Vector2(2120, 180), Vector2(2260, 230)]:
		var l := Sprite2D.new()
		l.texture = _tex("res://assets/props/lily.png")
		l.scale = Vector2.ONE * 1.3
		l.position = p
		layer_ground.add_child(l)
	var shore_props := ["rock_a", "rock_b", "bush_a", "flower_white", "flower_pink", "rock_b", "bush_c"]
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)
		var pp := center + Vector2(cos(a) * (rx * CELL + 38.0), sin(a) * (ry * CELL + 34.0))
		var shore: String = shore_props[rng.randi() % shore_props.size()]
		if _dist_to_roads(pp) > 80.0 and pp.y > 120.0:
			_prop(shore, pp, Vector2(30, 16) if shore.begins_with("rock") or shore.begins_with("bush") else Vector2.ZERO, 1.0, rng.randf() < 0.5)


# ---------------------------------------------------------------- cỏ, hoa
func _clear_spot(p: Vector2, margin := 14.0) -> bool:
	if p.x < 0 or p.y < 0 or p.x > WORLD.x or p.y > WORLD.y:
		return false
	if _dist_to_roads(p) < margin:
		return false
	for r in no_decor:
		if r.has_point(p):
			return false
	return true


func _decor(idx: int, p: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _tex("res://assets/decor/tuft_%02d.png" % idx)
	s.position = p
	s.flip_h = rng.randf() < 0.5
	layer_ground.add_child(s)


func _scatter_decor() -> void:
	for i in 1100:
		var p := Vector2(rng.randf_range(0, VILLAGE.x), rng.randf_range(0, VILLAGE.y))
		if _clear_spot(p):
			_decor(BLADES[rng.randi() % BLADES.size()], p)
	# Cụm hoa
	for i in 55:
		var c := Vector2(rng.randf_range(80, VILLAGE.x - 80), rng.randf_range(80, VILLAGE.y - 80))
		for j in rng.randi_range(3, 8):
			var p := c + Vector2(rng.randf_range(-70, 70), rng.randf_range(-45, 45))
			if _clear_spot(p, 20.0):
				_decor(FLOWERS[rng.randi() % FLOWERS.size()], p)


# ---------------------------------------------------------------- prop
## foot = vị trí chân (giữa-đáy); block = vùng chặn từ chân lên (0 = không chặn).
func _prop(pname: String, foot: Vector2, block := Vector2.ZERO, sc := 1.0, flip := false, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	var t := _tex("res://assets/props/%s.png" % pname)
	s.texture = t
	s.centered = false
	s.scale = Vector2.ONE * sc
	s.flip_h = flip
	s.modulate = tint
	var size := t.get_size()
	s.offset = Vector2(-size.x / 2.0, -size.y)
	s.position = foot
	world.add_child(s)
	var w := size.x * sc
	var h := size.y * sc
	prop_log.append({"n": pname, "p": foot, "w": w, "h": h})
	# Bóng đổ dưới chân (lệch nhẹ sang phải như nắng chiếu từ trái)
	if not FLAT_PROPS.has(pname):
		var is_house := pname.begins_with("house")
		var k := 0.62 if pname.begins_with("tree") else (0.82 if is_house else 0.7)
		var shadow := Shadow.make(w * k * 0.5, w * k * 0.5 * (0.17 if is_house else 0.3))
		shadow.position = foot + Vector2(w * 0.07, -1.0)
		layer_shadows.add_child(shadow)
	# Gió lay cây cối
	if pname.begins_with("tree"):
		s.material = atmo.sway_material(2.6)
	elif pname.begins_with("bamboo"):
		s.material = atmo.sway_material(3.0)
	elif pname.begins_with("bush"):
		s.material = atmo.sway_material(1.4)
	elif pname.begins_with("flower"):
		s.material = atmo.sway_material(1.2)
	# Vật cao: mờ đi khi nhân vật đi phía sau
	if h >= 90.0 and not pname.begins_with("lantern") and not pname.begins_with("fence"):
		occluders.append({"s": s, "rect": Rect2(foot.x - w * 0.32, foot.y - h, w * 0.64, h - 28.0)})
	if block != Vector2.ZERO:
		blockers.append(Rect2(foot.x - block.x / 2.0, foot.y - block.y, block.x, block.y))
	no_decor.append(Rect2(foot.x - size.x * sc / 2.0, foot.y - size.y * sc * 0.5, size.x * sc, size.y * sc * 0.5 + 10))
	return s


func _house(pname: String, foot: Vector2, flip := false, tint := Color.WHITE) -> void:
	_prop(pname, foot, Vector2(230, 110), 1.0, flip, tint)
	atmo.add_light(foot + Vector2(0, -60), Color(1.0, 0.8, 0.5), 1.8, 0.7)   # cửa sổ sáng đèn về đêm
	# Bụi hai bên cửa
	_prop("bush_a", foot + Vector2(-150, 8), Vector2(30, 14))
	_prop("flower_white" if foot.x < CENTER.x else "flower_pink", foot + Vector2(145, 10))


func _fence_line(from: Vector2, count: int, step := 95.0) -> void:
	var names := ["fence_a", "fence_b", "fence_c", "fence_d"]
	for i in count:
		_prop(names[i % names.size()], from + Vector2(i * step, 0), Vector2(90, 22))


func _build_village() -> void:
	# Nhà
	_house("house_blue", Vector2(820, 600))
	_house("house_red", Vector2(1640, 600))
	_house("house_blue", Vector2(2150, 660), true, Color(0.95, 0.9, 1.0))
	_house("house_red", Vector2(500, 1200), true, Color(1.0, 0.95, 0.9))
	_house("house_blue", Vector2(1850, 1420), false, Color(1.0, 0.92, 0.92))
	# Quảng trường: giếng ở giữa, biển chỉ đường
	_prop("well", CENTER + Vector2(0, 50), Vector2(110, 50))
	_prop("sign", CENTER + Vector2(-110, -60), Vector2(30, 14))
	# Chợ phía đông nam quảng trường
	_prop("stall", Vector2(1530, 1130), Vector2(110, 50))
	_prop("stall", Vector2(1700, 1130), Vector2(110, 50), 1.0, true)
	_prop("table", Vector2(1620, 1215), Vector2(110, 40))
	_prop("barrel_a", Vector2(1450, 1150), Vector2(40, 24))
	_prop("barrel_b", Vector2(1780, 1150), Vector2(44, 24))
	_prop("barrel_c", Vector2(1815, 1165), Vector2(40, 24))
	# Ruộng rau tây nam
	for i in 3:
		for j in 2:
			_prop("field_a" if (i + j) % 2 == 0 else "field_b", Vector2(240 + i * 100, 1480 + j * 92))
	_fence_line(Vector2(190, 1700), 4)
	_fence_line(Vector2(190, 1370), 4)
	# Hàng rào dọc đường lên Bắc
	_fence_line(Vector2(700, 700), 3)
	_fence_line(Vector2(1900, 720), 3)
	# Khu tre phía đông bắc
	for i in 6:
		_prop("bamboo_a" if i % 2 == 0 else "bamboo_b", Vector2(1480 + i * 55 + rng.randf_range(-12, 12), 330 + rng.randf_range(-40, 40)), Vector2(30, 16))
	# Đá, bụi, hoa lớn rải rác
	var deco := ["bush_a", "bush_b", "bush_c", "bush_d", "flower_white", "flower_pink", "rock_a", "rock_b"]
	for i in 80:
		var p := Vector2(rng.randf_range(120, VILLAGE.x - 120), rng.randf_range(260, VILLAGE.y - 100))
		if not _clear_spot(p, 70.0):
			continue
		var n: String = deco[rng.randi() % deco.size()]
		var solid := n.begins_with("rock") or n.begins_with("bush")
		_prop(n, p, Vector2(34, 18) if solid else Vector2.ZERO, 1.0, rng.randf() < 0.5)


# ---------------------------------------------------------------- rừng
func _build_forest() -> void:
	var names := ["tree_big", "tree_a", "tree_b", "tree_c"]
	var trunk := Vector2(44, 30)
	# Viền rừng hai lớp, chừa chỗ cho các con đường.
	# Hàng trên đặt chân đủ thấp (>=170) để tán cây không bị camera cắt ở mép map.
	for layer in 2:
		for x in range(80 + layer * 70, int(VILLAGE.x) - 60, 150):
			for y in [175.0 + layer * 75.0, VILLAGE.y - 10.0 - layer * 60.0]:
				var p := Vector2(x + rng.randf_range(-30, 30), y + rng.randf_range(-10, 10))
				if _dist_to_roads(p) > 90.0 and not pond_zone.has_point(p):
					_prop(names[rng.randi() % names.size()], p, trunk)
		for y in range(330 + layer * 80, int(VILLAGE.y) - 100, 170):
			for x in [80.0 + layer * 60.0, VILLAGE.x - 80.0 - layer * 60.0]:
				var p := Vector2(x + rng.randf_range(-15, 15), y + rng.randf_range(-30, 30))
				if _dist_to_roads(p) > 90.0 and not pond_zone.has_point(p):
					_prop(names[rng.randi() % names.size()], p, trunk)
	# Cụm rừng nhỏ trong làng
	for c in [Vector2(300, 520), Vector2(1000, 330), Vector2(2330, 1250), Vector2(1000, 1560), Vector2(2250, 1620), Vector2(700, 1180)]:
		for i in rng.randi_range(4, 7):
			var p: Vector2 = c + Vector2(rng.randf_range(-130, 130), rng.randf_range(-90, 90))
			if _dist_to_roads(p) > 80.0 and not _is_blocked(Rect2(p.x - 60, p.y - 60, 120, 70)):
				_prop(names[rng.randi() % names.size()], p, trunk)


func _is_blocked(r: Rect2) -> bool:
	for b in blockers:
		if b.intersects(r):
			return true
	return false


# ---------------------------------------------------------------- người chơi
func _spawn_player() -> void:
	player = load("res://character/hd/base_character.tscn").instantiate()
	player.scale = Vector2.ONE * PLAYER_SCALE
	player.position = CENTER + Vector2(0, 200)
	var pshadow := Shadow.make(16.0, 6.4, 0.34)
	pshadow.position = Vector2(2, 0)
	player.add_child(pshadow)
	player.move_child(pshadow, 0)
	world.add_child(player)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD.x)
	camera.limit_bottom = int(WORLD.y)
	camera.position = player.position
	add_child(camera)


const SAVE_PATH := "user://save.json"
# Linh mạch: nơi linh khí dày đặc, tu luyện nhanh hơn
const QI_ZONES := [
	{"pos": Vector2(1900, 480), "r": 120.0, "density": 3.0},   # bờ ao sen
	{"pos": Vector2(1560, 430), "r": 130.0, "density": 3.0},   # rừng tre
	{"pos": Vector2(2330, 1250), "r": 140.0, "density": 3.0},  # góc đông nam
] + WorldExpansion.NEW_QI_ZONES

var cult := Cultivation.new()
var _last_realm := 1
var set_speed_mult := 1.0   # thưởng bộ trang phục
var _active_sets: Array = []
var _sets_ready := false   # sau khi nạp xong mới báo "kích hoạt bộ"
var vitals := Vitals.new()
var monsters: Array = []
var alchemy: CanvasLayer
var furnace: Furnace
var _dead := false
const SAFE_R := 330.0   # quanh quảng trường: yêu thú không vào, người chơi an toàn
var inv := Inventory.new()
var quests := QuestLog.new()
var dialogue: CanvasLayer
var shop: CanvasLayer
var bag: CanvasLayer
var fashion: CanvasLayer
var wardrobe := Wardrobe.new()
var school: SwordSchool
var fx_layer: Node2D
var _pending_school := {}
var npcs: Array = []
var herbs: Array = []
var hud: CanvasLayer
var aura: Node2D
var meditating := false
const QI_SQUASH := 0.62   # phải trùng SQUASH trong qi_zone.gd
var _zone_nodes: Array = []
var _save_timer := 0.0


func _build_hud() -> void:
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	add_child(cult)
	add_child(vitals)
	add_child(inv)
	add_child(quests)
	add_child(wardrobe)
	quests.setup(inv, cult)
	vitals.setup(cult)
	inv.vitals = vitals
	vitals.changed.connect(func(): hud.update_hp(vitals.hp, vitals.max_hp))
	vitals.hurt.connect(_on_player_hurt)
	Sfx.setup(self)
	vitals.died.connect(_on_player_died)
	wardrobe.changed.connect(func():
		Wardrobe.apply(player, wardrobe.equipped)
		_apply_set_bonus(true))
	cult.message.connect(hud.toast)
	inv.message.connect(hud.toast)
	quests.message.connect(hud.toast)
	quests.outfits_unlocked.connect(_on_outfits_unlocked)
	quests.changed.connect(_grant_quest_outfits)
	_load_game()
	hud.update_status(cult, false, 1.0)
	hud.update_hp(vitals.hp, vitals.max_hp)
	cult.changed.connect(func(): hud.update_status(cult, meditating, _density_at(player.position)))
	quests.changed.connect(_refresh_quest_ui)
	inv.changed.connect(_refresh_quest_ui)
	_refresh_quest_ui()
	Wardrobe.apply(player, wardrobe.equipped)
	_last_realm = cult.realm
	_sync_aura_power()
	_apply_set_bonus(false)
	_sets_ready = true
	cult.changed.connect(_sync_aura_power)
	# Hào quang thiền định (con đầu tiên của nhân vật để vẽ phía sau)
	aura = preload("res://scripts/aura.gd").new()
	player.add_child(aura)
	player.move_child(aura, 0)
	atmo.attach(camera)
	aura.scale = Vector2.ONE * 2.0   # aura.gd vẽ theo tỉ lệ nhân vật 32px
	_med_light = atmo.add_light(Vector2(0, -16), Color(0.6, 0.9, 1.0), 1.2, 0.0, "manual", player)
	# Vầng sáng linh mạch trên nền (+ phát sáng về đêm)
	for z in QI_ZONES:
		atmo.add_light(z.pos, Color(0.5, 0.9, 1.0), z.r / 128.0 * 1.3, 0.8)
	_build_qi_zones()


## Mỗi linh mạch: quầng sáng + đốm sáng trên nền, và tia sáng/sương/hạt linh khí phía trên.
func _build_qi_zones() -> void:
	for z in QI_ZONES:
		var g: Node2D = preload("res://scripts/qi_zone.gd").new()
		g.setup("ground", z.r)
		g.position = z.pos
		layer_ground.add_child(g)
		var f: Node2D = preload("res://scripts/qi_zone.gd").new()
		f.setup("fx", z.r)
		f.position = z.pos
		add_child(f)   # sau world -> vẽ phía trên vật thể
		_zone_nodes.append({"z": z, "nodes": [g, f]})


func _in_zone(p: Vector2, z: Dictionary, grow := 1.0) -> bool:
	return Vector2((p.x - z.pos.x) / (z.r * grow), (p.y - z.pos.y) / (z.r * QI_SQUASH * grow)).length() < 1.0


func _density_at(p: Vector2) -> float:
	for z in QI_ZONES:
		if _in_zone(p, z):
			return z.density
	return 1.0


func _ui_blocked() -> bool:
	return _dead or (pause_menu != null and pause_menu.is_open()) or (journal != null and journal.is_open()) or (minimap != null and minimap.is_full_open()) or (debug_menu != null and debug_menu.is_open()) or dialogue.open or shop.is_open() or (sect_shop != null and sect_shop.is_open()) or bag.is_open() or fashion.is_open() or (alchemy != null and alchemy.is_open())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _ui_blocked():
			return
		if event.keycode == KEY_ESCAPE:
			meditating = false
			pause_menu.open_menu()
		elif event.keycode == KEY_M:
			minimap.toggle_full()
		elif event.keycode == KEY_F1:
			meditating = false
			debug_menu.open_menu()
		elif event.keycode == KEY_P or event.keycode == KEY_Q:
			meditating = false
			journal.open_ui("char" if event.keycode == KEY_P else "quest")
		elif event.keycode == KEY_F:
			meditating = not meditating
			if meditating:
				hud.toast("Ngồi thiền, hấp thụ linh khí...")
		elif event.keycode == KEY_B:
			cult.try_breakthrough()
		elif event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_I:
			meditating = false
			bag.toggle()
		elif event.keycode == KEY_C:
			meditating = false
			fashion.open_ui("closet")
		elif event.keycode in [KEY_J, KEY_K, KEY_L, KEY_U]:
			meditating = false
			school.cast([KEY_J, KEY_K, KEY_L, KEY_U].find(event.keycode))


func _process(delta: float) -> void:
	# Linh mạch: sáng hơn khi đứng trong, rực nhất khi đang thiền; về đêm tăng độ sáng để vẫn nổi bật
	var boost := 1.0 + 2.2 * atmo.darkness
	fx_layer.modulate = Color(boost, boost, boost, 1.0)   # hiệu ứng skill luôn rực rỡ, kể cả ban đêm
	for e in _zone_nodes:
		var tgt := 0.7
		if _in_zone(player.position, e["z"]):
			tgt = 1.5 if meditating else 0.95
		for n in e["nodes"]:
			n.target = tgt
			n.modulate = Color(boost, boost, boost, 1.0)
	# 2.5D: bóng nhạt dần về đêm, vật cao mờ đi khi nhân vật đứng sau
	layer_shadows.modulate.a = 1.0 - 0.65 * atmo.darkness
	_med_light.energy = lerpf(_med_light.energy, 0.7 if meditating else 0.0, minf(1.0, delta * 4.0))
	var pp := player.position
	for o in occluders:
		var spr: Sprite2D = o["s"]
		var behind: bool = (o["rect"] as Rect2).has_point(pp)
		spr.modulate.a = move_toward(spr.modulate.a, 0.45 if behind else 1.0, delta * 4.0)
	hud.set_time(atmo.period_name())
	playtime += delta
	_save_timer += delta
	if _save_timer > 15.0:
		_save_timer = 0.0
		_save_game()


var slot_paths := ["user://save.json", "user://save_1.json", "user://save_2.json", "user://save_3.json"]   # ô 0 = tự động lưu
var playtime := 0.0
var pause_menu: CanvasLayer
var journal: CanvasLayer
var minimap: Minimap
var prop_log: Array = []   # {n, p, w, h} của mọi vật thể đặt trên bản đồ (để vẽ bản đồ nhỏ)
var debug_menu: CanvasLayer
var debug_inf_qi := false
var debug_peaceful := false
var debug_speed := 1.0


func _collect_save() -> Dictionary:
	var d := {
		"cult": cult.to_dict(), "vitals": vitals.to_dict(), "inv": inv.to_dict(), "quests": quests.to_dict(), "wardrobe": wardrobe.to_dict(),
		"school": school.to_dict() if school else {},
		"pos": [player.position.x, player.position.y], "time": atmo.t, "playtime": playtime,
	}
	var now := Time.get_datetime_dict_from_system()
	d["meta"] = {
		"realm": cult.realm_name(), "stones": inv.stones, "playtime": playtime,
		"when": "%02d/%02d %02d:%02d" % [now["day"], now["month"], now["hour"], now["minute"]],
	}
	return d


func _save_game() -> void:
	save_to_slot(0, true)


## Ghi game vào ô i (0 = tự động). quiet: không hiện thông báo.
func save_to_slot(i: int, quiet := false) -> bool:
	if OS.has_environment("TUTIEN_NO_SAVE"):   # bài kiểm tra tự động không được ghi đè file lưu thật
		return false
	var f := FileAccess.open(slot_paths[i], FileAccess.WRITE)
	if f == null:
		if not quiet:
			hud.toast("Không lưu được game!")
		return false
	f.store_string(JSON.stringify(_collect_save()))
	f.close()
	if not quiet:
		hud.toast("Đã lưu vào ô %d" % i)
	return true


## Thông tin hiển thị của một ô lưu ({} nếu trống).
func slot_info(i: int) -> Dictionary:
	if not FileAccess.file_exists(slot_paths[i]):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_paths[i]))
	if data is Dictionary and data.has("cult"):
		var m: Dictionary = data.get("meta", {})
		if m.is_empty():   # file lưu cũ chưa có meta
			var c := Cultivation.new()
			c.from_dict(data["cult"])
			m = {"realm": c.realm_name(), "stones": int(data.get("inv", {}).get("stones", 0)), "playtime": float(data.get("playtime", 0.0)), "when": "(bản cũ)"}
			c.free()
		return m
	return {}


func load_from_slot(i: int) -> bool:
	if not FileAccess.file_exists(slot_paths[i]):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_paths[i]))
	if not (data is Dictionary):
		hud.toast("File lưu bị hỏng!")
		return false
	_apply_save(data, true)
	hud.toast("Đã tải game")
	return true


func _load_game() -> void:
	if not FileAccess.file_exists(slot_paths[0]):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_paths[0]))
	if data is Dictionary:
		_apply_save(data, false)


## runtime = true: đang chơi (đã dựng xong thế giới) nên phải đặt lại quái, đồ rơi và giao diện.
func _apply_save(data: Dictionary, runtime: bool) -> void:
	cult.from_dict(data.get("cult", {}))
	vitals.from_dict(data.get("vitals", {}))
	inv.from_dict(data.get("inv", {}))
	quests.from_dict(data.get("quests", {}))
	wardrobe.from_dict(data.get("wardrobe", {}))
	playtime = float(data.get("playtime", 0.0))
	atmo.t = float(data.get("time", atmo.t))
	var p = data.get("pos", null)
	if p is Array and p.size() == 2:
		player.position = Vector2(p[0], p[1])
	if school != null:
		school.from_dict(data.get("school", {}))
	else:
		_pending_school = data.get("school", {})
	if runtime:
		meditating = false
		_dead = false
		camera.position = player.position
		for m in monsters:
			m.reset_to_home()
		for c in world.get_children():
			if c is Loot:
				c.queue_free()
		Wardrobe.apply(player, wardrobe.equipped)
		hud.update_hp(vitals.hp, vitals.max_hp)
		hud.hide_death()
		_refresh_quest_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player:
		_save_game()


func _physics_process(delta: float) -> void:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_key_pressed(KEY_D): v.x += 1.0
	if Input.is_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_key_pressed(KEY_S): v.y += 1.0
	v = v.limit_length(1.0)
	if _ui_blocked() or (player.has_method("is_busy") and player.is_busy()):
		v = Vector2.ZERO
	if meditating and v != Vector2.ZERO:
		meditating = false
	var density := _density_at(player.position)
	if meditating:
		cult.meditate(delta, density)
		quests.add_meditate(delta)
	else:
		cult.qi = minf(cult.qi_max(), cult.qi + 3.0 * delta)   # hồi linh khí chậm khi không thiền
	if debug_inf_qi:
		cult.qi = cult.qi_max()
	_check_regions()
	_theme_timer -= delta
	if _theme_timer <= 0.0:
		_theme_timer = 0.5
		Sfx.set_theme(music_theme_at(player.position))
	_update_prompt()
	aura.active = meditating
	aura.boosted = density > 1.0
	hud.update_status(cult, meditating, density)
	var action := "idle"
	if v != Vector2.ZERO:
		var run := Input.is_key_pressed(KEY_SHIFT)
		action = "run" if run else "walk"
		direction = Dir.from_vector(v, direction)
		var step := v * (RUN_SPEED if run else WALK_SPEED) * set_speed_mult * delta
		var before := player.position
		_move_axis(Vector2(step.x, 0.0))
		_move_axis(Vector2(0.0, step.y))
		_step_dist += player.position.distance_to(before)
		if _step_dist >= (62.0 if run else 50.0):
			_step_dist = 0.0
			Sfx.step(surface_at(player.position), run)
	player.set_motion(action, direction)
	camera.position = player.position


var sect_shop: CanvasLayer
var _step_dist := 0.0
var _theme_timer := 0.0


## Loại mặt đất dưới chân (cho tiếng bước chân): rock = trong hang, stone = sân lát đá, còn lại là cỏ.
func surface_at(p: Vector2) -> String:
	if p.distance_to(WorldExpansion.CAVE) < 330.0:
		return "rock"
	if p.distance_to(Vector2(1280, 900)) < 330.0 or p.distance_to(WorldExpansion.SECT_C) < 330.0:
		return "stone"
	for c in [Vector2(1050, 1220), Vector2(1620, 1160), WorldExpansion.SECT_GATE]:
		if p.distance_to(c) < 190.0:
			return "stone"
	return "grass"


## Bản nhạc theo khu vực: hang, Kiếm Tông, Hắc Lâm (phía đông), còn lại là làng.
func music_theme_at(p: Vector2) -> String:
	if p.distance_to(WorldExpansion.CAVE) < 420.0:
		return "cave"
	if p.distance_to(WorldExpansion.SECT_C) < 520.0 or p.distance_to(WorldExpansion.SECT_GATE) < 260.0:
		return "sect"
	if p.x > 2640.0:
		return "forest"
	return "village"


func _move_axis(step: Vector2) -> void:
	var np := player.position + step
	np = np.clamp(Vector2(20, 20), WORLD - Vector2(20, 10))
	if not _is_blocked(Rect2(np.x - 12, np.y - 8, 24, 10)):
		player.position = np


# ---------------------------------------------------------------- NPC, nhiệm vụ, thảo dược
func _build_gameplay() -> void:
	dialogue = preload("res://scripts/dialogue.gd").new()
	add_child(dialogue)
	shop = preload("res://scripts/shop.gd").new()
	shop.inv = inv
	add_child(shop)
	sect_shop = preload("res://scripts/sect_shop.gd").new()
	sect_shop.inv = inv
	sect_shop.wardrobe = wardrobe
	add_child(sect_shop)
	bag = preload("res://scripts/bag.gd").new()
	bag.inv = inv
	bag.cult = cult
	add_child(bag)
	inv.changed.connect(func():
		shop.refresh()
		sect_shop.refresh()
		bag.refresh())
	fashion = preload("res://scripts/fashion_ui.gd").new()
	fashion.wardrobe = wardrobe
	fashion.inv = inv
	add_child(fashion)
	inv.changed.connect(func(): fashion.refresh())
	debug_menu = preload("res://scripts/debug_menu.gd").new()
	debug_menu.main = self
	add_child(debug_menu)
	journal = preload("res://scripts/journal.gd").new()
	journal.main = self
	add_child(journal)
	pause_menu = preload("res://scripts/pause_menu.gd").new()
	pause_menu.main = self
	add_child(pause_menu)
	alchemy = preload("res://scripts/alchemy_ui.gd").new()
	alchemy.inv = inv
	alchemy.cult = cult
	add_child(alchemy)
	inv.changed.connect(func(): alchemy.refresh())
	alchemy.crafted.connect(func(_id, ok):
		quests.add_craft()
		if ok:
			cult.add_xp(3.0))
	_spawn_npc("elder", "Trưởng lão Vân Hạc", {"hair": "hair_long_silver", "clothes": "outfit_plain", "shoes": "shoes_cloth_white", "head": "head_crown_gold"}, CENTER + Vector2(190, 80))
	_spawn_npc("merchant", "Thương nhân Lý Tam", {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown", "waist": "waist_bell_copper"}, Vector2(1615, 1150))
	# Tiệm may phía tây nam quảng trường
	_prop("stall", Vector2(840, 1085), Vector2(110, 50))
	_prop("barrel_a", Vector2(770, 1095), Vector2(40, 24))
	_spawn_npc("tailor", "Thợ may Tô Nương", {"hair": "hair_ponytail_brown", "clothes": "outfit_lam", "dye": "dye_green", "shoes": "shoes_boot_black"}, Vector2(930, 1090))
	_spawn_herbs()
	WorldExpansion.extra_herbs(self)
	WorldExpansion.spawn_npcs(self)
	# Kiếm phái: kiếm sư + sân luyện kiếm với mộc nhân
	school = SwordSchool.new()
	add_child(school)
	school.setup(self, player, cult, hud, fx_layer)
	_apply_set_bonus(false)
	school.from_dict(_pending_school)
	school.message.connect(hud.toast)
	_spawn_npc("swordmaster", "Kiếm sư Lăng Tiêu", {"hair": "hair_topknot_silver", "clothes": "outfit_plain", "shoes": "shoes_boot_black", "sword": "sword_black"}, Vector2(1050, 1150))
	for p in [Vector2(955, 1215), Vector2(1050, 1250), Vector2(1145, 1218)]:
		var d: TrainingDummy = preload("res://scripts/dummy.gd").new()
		d.position = p
		world.add_child(d)
		blockers.append(Rect2(p.x - 18, p.y - 14, 36, 16))
		d.got_hit.connect(_on_dummy_hit)
	_spawn_furnace()
	_spawn_monsters()
	minimap = Minimap.new()
	minimap.main = self
	add_child(minimap)
	minimap.build()
	_refresh_quest_ui()
	if quests.states.is_empty():
		hud.toast("Hãy gặp Trưởng lão ở quảng trường (dấu !)")


func _spawn_npc(id: String, display: String, outfit: Dictionary, foot: Vector2) -> void:
	var n: Node2D = preload("res://scripts/npc.gd").new()
	n.setup(id, display, outfit)
	n.position = foot
	world.add_child(n)
	npcs.append(n)
	blockers.append(Rect2(foot.x - 22, foot.y - 16, 44, 18))


func _spawn_herbs() -> void:
	var count := 0
	var tries := 0
	while count < 26 and tries < 1500:
		tries += 1
		var p: Vector2
		if count < 9:
			var z: Dictionary = QI_ZONES[count % QI_ZONES.size()]
			p = z["pos"] + Vector2(rng.randf_range(-1.0, 1.0) * z["r"], rng.randf_range(-0.7, 0.7) * z["r"])
		else:
			p = Vector2(rng.randf_range(150, VILLAGE.x - 150), rng.randf_range(300, VILLAGE.y - 120))
		if not _clear_spot(p, 40.0) or _is_blocked(Rect2(p.x - 30, p.y - 30, 60, 40)):
			continue
		var h: Node2D = preload("res://scripts/herb.gd").new()
		h.position = p
		world.add_child(h)
		herbs.append(h)
		count += 1


func _refresh_quest_ui() -> void:
	if hud == null:
		return
	hud.set_quest(quests.tracker_text())
	hud.set_stones(inv.stones)
	for n in npcs:
		var mark := ""
		if not quests.ready_for(n.npc_id).is_empty():
			mark = "?"
		elif not quests.available_for(n.npc_id).is_empty() and not (n.npc_id == "swordmaster" and school != null and not school.joined):
			mark = "!"
		elif n.npc_id == "swordmaster" and school != null and not school.joined:
			mark = "!"
		n.set_marker(mark)


func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in npcs:
		var d := player.position.distance_to(n.position)
		if d < 110.0 and d < best_d:
			best = n
			best_d = d
	for h in herbs:
		if not h.available:
			continue
		var d := player.position.distance_to(h.position)
		if d < 70.0 and d < best_d:
			best = h
			best_d = d
	if furnace != null:
		var fd := player.position.distance_to(furnace.position)
		if fd < 90.0 and fd < best_d:
			best = furnace
			best_d = fd
	return best


func _update_prompt() -> void:
	if _ui_blocked():
		hud.set_prompt("")
		return
	var t := _nearest_target()
	if t == null:
		hud.set_prompt("")
	elif t in herbs:
		hud.set_prompt("E: Hái Linh thảo")
	elif t == furnace:
		hud.set_prompt("E: Luyện đan")
	else:
		hud.set_prompt("E: Trò chuyện với %s" % t.display_name)


func _interact() -> void:
	var t := _nearest_target()
	if t == null:
		return
	meditating = false
	if t == furnace:
		alchemy.open_ui()
	elif t in herbs:
		t.pick()
		inv.add("linh_thao", 1)
		hud.toast("+1 Linh thảo")
	else:
		_talk(t)


func _on_dummy_hit(_dmg: float) -> void:
	quests.add_hit()
	cult.add_xp(0.4)   # luyện kiếm cũng tích luỹ chút tu vi


func _join_sword_school() -> void:
	school.joined = true
	hud.toast("Gia nhập Kiếm Tông! Phím J/K/L/U để ra chiêu.")
	_refresh_quest_ui()


func _talk_swordmaster(nm: String) -> void:
	dialogue.say(nm, [
		"Ngươi muốn học kiếm? Kiếm đạo không chỉ là chém giết, mà là dùng linh khí ngự kiếm, kiếm theo ý động.",
		"Ta là Lăng Tiêu, trưởng lão Kiếm Tông. Bái ta làm sư, ta truyền bốn chiêu: Trảm, Kiếm Khí, Phi Kiếm, Vạn Kiếm.",
		"Cảnh giới càng cao, chiêu mở càng nhiều: Kiếm Khí từ Luyện Khí tầng 3, Phi Kiếm từ tầng 6, Vạn Kiếm từ tầng 10 (Trúc Cơ).",
	], func():
		dialogue.choose(nm, "Ngươi có bằng lòng bái sư không?", [
			{"text": "Bái sư, gia nhập Kiếm Tông", "call": _join_sword_school},
			{"text": "Để ta suy nghĩ thêm", "call": Callable()},
		]))


func _talk(npc: Node2D) -> void:
	var id: String = npc.npc_id
	var nm: String = npc.display_name
	if id == "swordmaster" and not school.joined:
		_talk_swordmaster(nm)
		return
	var q := quests.ready_for(id)
	if not q.is_empty():
		dialogue.say(nm, q["ready"], quests.complete.bind(q["id"]))
		return
	q = quests.available_for(id)
	if not q.is_empty():
		dialogue.say(nm, q["intro"], quests.accept.bind(q["id"]))
		return
	q = quests.active_for(id)
	var greeting := "Có chuyện gì nữa không?"
	if not q.is_empty():
		greeting = q["remind"]
	elif id == "merchant":
		greeting = "Khách quan cần gì nào?"
	elif id == "sect_keeper":
		greeting = "Cống hiến của ngươi hiện là %d, chức vị %s. Cần đổi gì không?" % [inv.merit, Sect.rank_name(inv.merit_total)]
	elif id == "tailor":
		greeting = "Khách muốn may áo mới, đổi kiểu tóc hay sắm đôi giày chăng?"
	dialogue.choose(nm, greeting, _menu_options(id))


func _menu_options(id: String) -> Array:
	var bye := {"text": "Tạm biệt", "call": Callable()}
	if id == "tailor":
		return [
			{"text": "Xem tiệm may (mua / mặc thử)", "call": Callable(fashion, "open_ui").bind("shop")},
			{"text": "Trò chuyện", "call": _lore.bind(id)},
			bye,
		]
	if id == "sect_keeper":
		return [
			{"text": "Tàng Bảo Các (đổi đồ / nộp nguyên liệu)", "call": Callable(sect_shop, "open_shop")},
			{"text": "Hỏi về chức vị và cống hiến", "call": _lore.bind("sect_rank")},
			{"text": "Trò chuyện", "call": _lore.bind(id)},
			bye,
		]
	if id == "merchant":
		return [
			{"text": "Xem hàng (mua / bán)", "call": Callable(shop, "open_shop")},
			{"text": "Trò chuyện", "call": _lore.bind(id)},
			bye,
		]
	return [{"text": "Hỏi về con đường tu tiên", "call": _lore.bind(id)}, bye]


func _lore(id: String) -> void:
	if id == "elder":
		dialogue.say("Trưởng lão Vân Hạc", [
			"Tu tiên là nghịch thiên mà đi. Luyện Khí, Trúc Cơ, Kim Đan, Nguyên Anh, Hóa Thần: mỗi cảnh giới là một cửa ải.",
			"Linh khí có ở khắp nơi, nhưng linh mạch mới là chỗ tu luyện nhanh nhất. Đừng quên thiền ở đó.",
		])
	elif id == "swordmaster":
		dialogue.say("Kiếm sư Lăng Tiêu", [
			"Trảm (J) là gốc, dùng mọi lúc. Kiếm Khí (K) phóng xa, xuyên thấu. Phi Kiếm (L) ngự ba thanh kiếm tự tìm địch.",
			"Vạn Kiếm (U) là tuyệt kỹ của Kiếm Tông: vạn kiếm quy tông, càn quét một vùng. Mỗi chiêu đều tốn linh khí, hết thì thiền để hồi.",
		])
	elif id == "sect_head":
		dialogue.say("Chưởng môn Thanh Huyền", [
			"Kiếm Tông không phải nơi dạy ngươi giết chóc, mà dạy ngươi giữ lòng tĩnh khi kiếm trong tay.",
			"Thung lũng này có linh mạch sau chính điện, thiền ở đó nhanh gấp ba. Bù nhìn trong sân dùng thoải mái để luyện kiếm.",
			"Phía đông là Hắc Lâm, phía đông nam là Hang Linh Mạch. Cả hai đều nguy hiểm, nhưng cơ duyên cũng ở đó.",
		])
	elif id == "sect_keeper":
		dialogue.say("Chấp sự Mộ Dung", [
			"Tàng Bảo Các là kho báu của tông môn. Đan dược, trang phục, đều đổi bằng điểm cống hiến, không dùng linh thạch.",
			"Muốn có điểm thì nhận việc của ta, hạ yêu tướng, hạ Hắc Lang Vương, hoặc nộp nguyên liệu như yêu đan, nanh yêu.",
		])
	elif id == "sect_rank":
		var lines: Array[String] = ["Chức vị tính theo tổng cống hiến đã nhận, không mất đi khi ngươi đổi đồ. Mỗi lần thăng chức, tông môn thưởng thêm."]
		for rk in Sect.RANKS:
			lines.append("%s: từ %d cống hiến." % [rk["name"], int(rk["need"])])
		lines.append("Hiện ngươi là %s, tổng đã nhận %d cống hiến." % [Sect.rank_name(inv.merit_total), inv.merit_total])
		dialogue.say("Chấp sự Mộ Dung", lines)
	elif id == "hermit":
		dialogue.say("Ẩn sĩ Mặc Thạch", [
			"Rừng này ngày xưa lành lắm. Từ khi Hắc Lang Vương tu thành yêu, đàn sói đổi hẳn tính nết.",
			"Trại ta có lửa suốt đêm, yêu thú không dám lại gần. Ngươi cứ nghỉ chân thoải mái.",
			"Muốn tới hang ổ của nó thì đi theo đường lớn về phía đông bắc. Nhớ mang nhiều đan hồi huyết.",
		])
	elif id == "tailor":
		dialogue.say("Thợ may Tô Nương", [
			"Người tu tiên cũng cần vẻ ngoài chỉn chu. Đạo bào, tóc tai, giày hài, ta đều lo được hết.",
			"Muốn mặc cho ra dáng cao nhân thì tích đủ linh thạch rồi quay lại nhé. Bạch y tay rộng là món đắt khách nhất.",
			"Mua rồi cứ nhấn phím C để thay đồ bất cứ lúc nào.",
		])
	else:
		dialogue.say("Thương nhân Lý Tam", [
			"Ta buôn bán khắp nơi, chuyện gì cũng nghe qua một ít. Đan dược thì ta có đủ loại.",
			"Linh thảo ngươi hái được cứ đem bán cho ta, giá công bằng.",
		])


# ---------------------------------------------------------------- yêu thú, khí huyết, lò đan
func is_safe(p: Vector2) -> bool:
	if p.distance_to(CENTER) < SAFE_R:
		return true
	for z in WorldExpansion.SAFE_ZONES:
		if p.distance_to(z[0]) < float(z[1]):
			return true
	return false


func _spawn_furnace() -> void:
	furnace = Furnace.new()
	furnace.position = Vector2(1130, 1010)
	world.add_child(furnace)
	blockers.append(Rect2(furnace.position.x - 24, furnace.position.y - 16, 48, 18))


## Mỗi nhóm: [kind, tâm vùng, số con]. Đều nằm ngoài vùng an toàn quanh quảng trường.
const MONSTER_GROUPS := [
	["wolf", Vector2(330, 760), 3],
	["wolf", Vector2(1450, 1620), 3],
	["goblin", Vector2(2250, 980), 2],
	["goblin", Vector2(520, 430), 2],
] + WorldExpansion.NEW_MONSTER_GROUPS


func _spawn_monsters() -> void:
	for g in MONSTER_GROUPS:
		var made := 0
		var tries := 0
		while made < int(g[2]) and tries < 200:
			tries += 1
			var p: Vector2 = g[1] + Vector2(rng.randf_range(-170, 170), rng.randf_range(-110, 110))
			if is_safe(p) or pond_zone.has_point(p) or _is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)):
				continue
			var m := Monster.new()
			m.setup(self, g[0], p)
			world.add_child(m)
			monsters.append(m)
			made += 1


func on_monster_killed(m: Monster) -> void:
	var k: Dictionary = m.kind
	cult.add_xp(float(k["xp"]))
	quests.add_kill(m.kind_id)
	var mk := int(Sect.KILL_MERIT.get(m.kind_id, 0))
	if mk > 0 and quests.states.get("q8", "") == "done":   # chỉ tính cho người đã vào Kiếm Tông
		inv.add_merit(mk)
		float_text(m.position + Vector2(0, -92), "+%d cống hiến" % mk, Color(1.0, 0.82, 0.35))
	var st: Array = k["stones"]
	_drop("stone", rng.randi_range(int(st[0]), int(st[1])), m.position)
	var drops: Dictionary = k["drops"]
	for id in drops:
		if rng.randf() < float(drops[id]):
			_drop(str(id), 1, m.position)
	for od in Wardrobe.items_dropped_by(m.kind_id):   # trang phục hiếm rơi từ quái (chỉ khi chưa có)
		if not wardrobe.is_owned(str(od["id"])) and rng.randf() < float(od["chance"]):
			_drop(str(od["id"]), 1, m.position + Vector2(rng.randf_range(-14.0, 14.0), 6.0))
	float_text(m.position + Vector2(0, -70), "+%d tu vi" % int(k["xp"]), UIKit.XP_GOLD)


func _drop(id: String, n: int, at: Vector2) -> void:
	var l := Loot.new()
	l.setup(self, id, n, at)
	world.add_child(l)


## Chữ nổi (nhặt đồ, tu vi, sát thương nhận vào).
func float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 220
	world.add_child(l)
	l.global_position = pos - Vector2(40, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


func _on_player_hurt(dmg: float, from: Vector2) -> void:
	meditating = false
	hud.flash_hurt()
	if school != null:
		school.shake(4.0, 0.15)
	float_text(player.position + Vector2(0, -64), "-%d" % int(dmg), UIKit.RED)
	var away := (player.position - from).normalized()
	for i in 4:
		_move_axis(away * 5.0)
	var tw := create_tween()
	tw.tween_property(player, "modulate", Color(1.8, 0.5, 0.5), 0.05)
	tw.tween_property(player, "modulate", Color.WHITE, 0.25)


func _on_player_died() -> void:
	_dead = true
	meditating = false
	var lost := int(inv.stones * 0.1)
	if lost > 0:
		inv.spend_stones(lost)
	hud.show_death("TRỌNG THƯƠNG", "Mất %d linh thạch. Được người trong làng đưa về quảng trường..." % lost)
	await get_tree().create_timer(2.6).timeout
	player.position = CENTER + Vector2(0, 200)
	camera.position = player.position
	for m in monsters:
		if m.alive and m.state in ["chase", "windup", "recover", "hurt"]:
			m.state = "return"
	vitals.revive(0.5)
	hud.hide_death()
	_dead = false


## Ghi nhận người chơi đã tới các khu vực (cho nhiệm vụ "đến nơi").
func _check_regions() -> void:
	var p := player.position
	if p.distance_to(WorldExpansion.SECT_C) < 300.0:
		quests.add_visit("sect")
	if p.distance_to(WorldExpansion.CAVE) < 200.0:
		quests.add_visit("cave")
	if p.distance_to(WorldExpansion.CAMP) < 200.0:
		quests.add_visit("camp")
	var boss: Monster = null
	for m in monsters:
		if m.alive and bool(m.kind.get("boss", false)) and m.position.distance_to(p) < 620.0:
			boss = m
			break
	if boss != null:
		hud.set_boss(str(boss.kind["name"]), boss.hp, boss.max_hp)
	else:
		hud.set_boss("", 0.0, 1.0)

## Hào quang trang phục mạnh dần theo cảnh giới; đột phá thành công thì bùng một vòng sáng.
func _sync_aura_power() -> void:
	player.set_meta("aura_power", cult.aura_power())
	if cult.realm > _last_realm:
		var a := player.get_node_or_null("OutfitAura")
		if a != null:
			a.burst()
	_last_realm = cult.realm

## Thưởng bộ trang phục: áp lên tu vi, khí huyết, sát thương và tốc độ; báo khi vừa kích hoạt một bộ.
func _apply_set_bonus(announce: bool) -> void:
	var b := Wardrobe.total_bonus(wardrobe.equipped)
	cult.xp_mult = 1.0 + float(b["xp"])
	vitals.set_hp_bonus(float(b["hp"]))
	set_speed_mult = 1.0 + float(b["speed"])
	if school != null:
		school.dmg_mult = 1.0 + float(b["dmg"])
	var now: Array = []
	for st in Wardrobe.set_status(wardrobe.equipped):
		if not (st["bonus"] as Dictionary).is_empty():
			now.append(str(st["id"]))
			if announce and _sets_ready and not _active_sets.has(str(st["id"])):
				hud.toast("Bộ %s (%d/%d): %s" % [st["name"], st["count"], st["total"], Wardrobe.bonus_text(st["bonus"])])
	_active_sets = now

## Trang phục mở khóa khi hoàn thành nhiệm vụ: thêm vào kho và báo người chơi.
func _on_outfits_unlocked(ids: Array) -> void:
	for id in ids:
		if wardrobe.grant(str(id)):
			hud.toast("Mở khóa trang phục: %s" % Wardrobe.ITEMS[id]["name"])

## Cấp lại trang phục của các nhiệm vụ đã xong (save cũ, hoặc nhiệm vụ làm xong trước khi có tính năng).
func _grant_quest_outfits() -> void:
	for q in QuestLog.QUESTS:
		if quests.states.get(q["id"], "") == "done":
			for id in Wardrobe.items_unlocked_by(str(q["id"])):
				wardrobe.grant(id)
