extends RefCounted
class_name WorldExpansion
## Mở rộng thế giới: Hắc Lâm (đông), Thung lũng Kiếm Tông (nam) và Hang Linh Mạch (đông nam).
## Dùng rng riêng nên làng cũ giữ nguyên bố cục. Mọi vật thể đặt qua các hàm của main (_prop, _road, _blob...).

const VILLAGE := Vector2(2560, 1792)
const SECT_GATE := Vector2(1290, 2250)
const SECT_C := Vector2(1290, 2500)
const CAMP := Vector2(2980, 820)
const LAIR := Vector2(3650, 560)
const CAVE := Vector2(3520, 2350)

# vùng an toàn: [tâm, bán kính]
const SAFE_ZONES := [[Vector2(1290, 2500), 330.0], [Vector2(2980, 820), 170.0]]

const NEW_QI_ZONES := [
	{"pos": Vector2(3300, 1250), "r": 150.0, "density": 4.0},   # suối linh trong Hắc Lâm
	{"pos": Vector2(3520, 2350), "r": 190.0, "density": 6.0},   # Hang Linh Mạch
	{"pos": Vector2(1530, 2610), "r": 130.0, "density": 3.0},   # góc sân Kiếm Tông
]

static func has_prop(n: String) -> bool:
	return ResourceLoader.exists("res://assets/props/%s.png" % n)


# ---------------------------------------------------------------- đường
static func add_roads(m: Node) -> void:
	# Nam: kéo dài đường chính xuống cổng và sân Kiếm Tông
	m._road([Vector2(1290, 1840), Vector2(1300, 2000), Vector2(1270, 2150), SECT_GATE, Vector2(1290, 2380), SECT_C], m.ROAD_W)
	m.path_lines.append({"pts": PackedVector2Array([SECT_C]), "w": m.PLAZA_R * 2.0})
	m._road([SECT_C, Vector2(1100, 2480), Vector2(930, 2450), Vector2(860, 2410)], m.LANE_W)
	m._road([SECT_C, Vector2(1480, 2480), Vector2(1650, 2450), Vector2(1720, 2410)], m.LANE_W)
	m._road([SECT_C, Vector2(1290, 2620), Vector2(1290, 2700)], m.LANE_W)
	# Đông nam: đường đến Hang Linh Mạch
	m._road([SECT_C + Vector2(150, 0), Vector2(1750, 2520), Vector2(2150, 2480), Vector2(2550, 2400), Vector2(2950, 2330), Vector2(3300, 2340), CAVE + Vector2(-190, 0)], m.ROAD_W)
	# Đông: kéo dài vào Hắc Lâm
	m._road([Vector2(2420, 800), Vector2(2610, 830), Vector2(2800, 850), CAMP, Vector2(3200, 770), Vector2(3420, 650), Vector2(3560, 590), LAIR], m.ROAD_W)
	m.path_lines.append({"pts": PackedVector2Array([CAMP]), "w": m.PLAZA_R * 2.0})
	m._road([Vector2(3200, 770), Vector2(3260, 1000), Vector2(3300, 1250)], m.LANE_W)


# ---------------------------------------------------------------- địa hình và vật thể
static func build(m: Node) -> void:
	var xr := RandomNumberGenerator.new()
	xr.seed = 777
	_ground(m, xr)
	_outer_ring(m, xr)
	_dark_forest(m, xr)
	_sect(m, xr)
	_camp_and_lair(m, xr)
	_cave(m, xr)


static func _blob(m: Node, xr: RandomNumberGenerator, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var k := xr.randf_range(0.88, 1.08)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	poly.polygon = pts
	poly.color = col
	m.layer_ground.add_child(poly)


static func _ground(m: Node, xr: RandomNumberGenerator) -> void:
	# mảng cỏ nhạt/đậm trên toàn vùng mới (ngoài làng)
	for i in 90:
		var c := Vector2(xr.randf_range(0, m.WORLD.x), xr.randf_range(0, m.WORLD.y))
		if c.x < VILLAGE.x - 100 and c.y < VILLAGE.y - 100:
			continue
		var r := xr.randf_range(90, 260)
		var shade := Color(0.25, 0.5, 0.3, 0.18) if i % 2 == 0 else Color(0.62, 0.8, 0.45, 0.14)
		_blob(m, xr, c, r, r * xr.randf_range(0.55, 0.85), shade)
	# Hắc Lâm: ngả tối, hơi xanh lạnh
	for i in 46:
		var c := Vector2(xr.randf_range(2640, 4040), xr.randf_range(120, 1720))
		var r := xr.randf_range(140, 320)
		_blob(m, xr, c, r, r * 0.7, Color(0.04, 0.12, 0.16, 0.20))
	# Thung lũng Kiếm Tông: sáng và xanh dịu hơn
	for i in 26:
		var c := Vector2(xr.randf_range(300, 2300), xr.randf_range(1950, 2720))
		var r := xr.randf_range(120, 260)
		_blob(m, xr, c, r, r * 0.7, Color(0.55, 0.85, 0.75, 0.10))
	# cỏ lác đác ở vùng mới
	for i in 1500:
		var p := Vector2(xr.randf_range(0, m.WORLD.x), xr.randf_range(0, m.WORLD.y))
		if p.x < VILLAGE.x and p.y < VILLAGE.y:
			continue
		if m._clear_spot(p):
			m._decor(m.BLADES[xr.randi() % m.BLADES.size()], p)


## Viền rừng ở rìa bản đồ mới (rìa cũ của làng giữ nguyên làm dải rừng ngăn cách, chừa lối cho đường đi).
static func _outer_ring(m: Node, xr: RandomNumberGenerator) -> void:
	var names := ["tree_big", "tree_a", "tree_b", "tree_c"]
	var trunk := Vector2(44, 30)
	var W: Vector2 = m.WORLD
	for layer in 2:
		for x in range(80 + layer * 70, int(W.x) - 60, 150):
			for y in [175.0 + layer * 75.0, W.y - 10.0 - layer * 60.0]:
				if y < 600.0 and x < VILLAGE.x:
					continue   # rìa trên của làng đã có
				var p := Vector2(x + xr.randf_range(-30, 30), y + xr.randf_range(-10, 10))
				if m._dist_to_roads(p) > 90.0:
					m._prop(names[xr.randi() % names.size()], p, trunk)
		for y in range(330 + layer * 80, int(W.y) - 100, 170):
			for x in [80.0 + layer * 60.0, W.x - 80.0 - layer * 60.0]:
				if x < 400.0 and y < VILLAGE.y:
					continue   # rìa trái của làng đã có
				var p := Vector2(x + xr.randf_range(-15, 15), y + xr.randf_range(-30, 30))
				if m._dist_to_roads(p) > 90.0:
					m._prop(names[xr.randi() % names.size()], p, trunk)
	# dải rừng ngăn cách làng với hai vùng mới (rìa đông và rìa nam của làng)
	for y in range(260, int(VILLAGE.y) - 60, 120):
		for dx in [0.0, 70.0]:
			var p := Vector2(VILLAGE.x - 40.0 + dx + xr.randf_range(-12, 12), y + xr.randf_range(-20, 20))
			if m._dist_to_roads(p) > 100.0 and not m.pond_zone.has_point(p):
				m._prop(names[xr.randi() % names.size()], p, trunk)
	for x in range(100, int(VILLAGE.x) - 60, 130):
		for dy in [0.0, 70.0]:
			var p := Vector2(x + xr.randf_range(-20, 20), VILLAGE.y - 40.0 + dy + xr.randf_range(-12, 12))
			if m._dist_to_roads(p) > 100.0:
				m._prop(names[xr.randi() % names.size()], p, trunk)


static func _dark_forest(m: Node, xr: RandomNumberGenerator) -> void:
	var names := ["tree_c", "tree_a", "tree_big", "tree_b", "tree_c"]
	var dark := Color(0.52, 0.62, 0.68)
	var placed := 0
	var tries := 0
	while placed < 230 and tries < 2500:
		tries += 1
		var p := Vector2(xr.randf_range(2680, 4040), xr.randf_range(240, 1700))
		if m._dist_to_roads(p) < 85.0 or p.distance_to(CAMP) < 200.0 or p.distance_to(LAIR) < 230.0 or m.pond_zone.has_point(p):
			continue
		if p.distance_to(Vector2(3300, 1250)) < 160.0:
			continue
		var n: String = names[xr.randi() % names.size()]
		if has_prop("dead_tree") and xr.randf() < 0.22:
			m._prop("dead_tree", p, Vector2(36, 26), 1.0, xr.randf() < 0.5)
		else:
			m._prop(n, p, Vector2(44, 30), xr.randf_range(0.9, 1.15), xr.randf() < 0.5, dark)
		placed += 1
	# đá, bụi và tre rải rác
	for i in 70:
		var p := Vector2(xr.randf_range(2680, 4040), xr.randf_range(240, 1700))
		if m._dist_to_roads(p) < 70.0 or p.distance_to(CAMP) < 190.0 or p.distance_to(LAIR) < 220.0:
			continue
		var n: String = ["rock_a", "rock_b", "bush_b", "bush_c", "bamboo_a", "bamboo_b"][xr.randi() % 6]
		m._prop(n, p, Vector2(34, 18) if not n.begins_with("bamboo") else Vector2(30, 16), 1.0, xr.randf() < 0.5, Color(0.6, 0.7, 0.75))


static func _sect(m: Node, xr: RandomNumberGenerator) -> void:
	# thông hai bên đường vào
	for y in range(1930, 2230, 90):
		for sx in [-1.0, 1.0]:
			var p := Vector2(1290 + sx * 105.0 + xr.randf_range(-10, 10), y + xr.randf_range(-8, 8))
			m._prop("tree_b", p, Vector2(36, 26), 1.0, sx < 0.0, Color(0.74, 0.92, 0.96))
	# đèn lồng dọc đường
	for y in range(1960, 2400, 120):
		for sx in [-1.0, 1.0]:
			var p := Vector2(1290 + sx * 92.0, y + (60.0 if sx > 0.0 else 0.0))
			m._prop("lantern", p, Vector2(24, 14))
			m.atmo.add_light(p + Vector2(20, -60), Color(1.0, 0.75, 0.4), 1.5, 0.95)
	# cổng
	if has_prop("sect_gate"):
		m._prop("sect_gate", SECT_GATE + Vector2(0, 40), Vector2.ZERO)
		for sx in [-1.0, 1.0]:
			m.blockers.append(Rect2(SECT_GATE.x + sx * 98.0 - 18.0, SECT_GATE.y + 14.0, 36.0, 28.0))
		m.atmo.add_light(SECT_GATE + Vector2(0, -40), Color(1.0, 0.7, 0.4), 2.4, 0.8)
	else:
		for sx in [-1.0, 1.0]:
			m._prop("lantern", SECT_GATE + Vector2(sx * 90.0, 30), Vector2(24, 14), 1.4)
			m._prop("fence_e", SECT_GATE + Vector2(sx * 170.0, 28), Vector2(60, 22))
	m._prop("sign", SECT_GATE + Vector2(130, 70), Vector2(30, 14))
	# hai bên cổng: hàng rào đá/rào gỗ
	for sx in [-1.0, 1.0]:
		for i in 4:
			m._prop(["fence_a", "fence_b", "fence_c", "fence_d"][i % 4], SECT_GATE + Vector2(sx * (200.0 + i * 92.0), 30), Vector2(90, 22), 1.0, sx < 0.0)
	# các điện
	m._prop("house_red", Vector2(860, 2430), Vector2(230, 110), 1.0, true, Color(1.0, 0.92, 0.72))
	m._prop("house_blue", Vector2(1720, 2430), Vector2(230, 110), 1.0, false, Color(0.82, 0.94, 1.0))
	m._prop("house_red", Vector2(1290, 2790), Vector2(240, 110), 1.0, false, Color(1.0, 0.88, 0.62))
	m.atmo.add_light(Vector2(860, 2370), Color(1.0, 0.8, 0.5), 1.8, 0.7)
	m.atmo.add_light(Vector2(1720, 2370), Color(1.0, 0.8, 0.5), 1.8, 0.7)
	m.atmo.add_light(Vector2(1290, 2730), Color(1.0, 0.8, 0.5), 2.2, 0.8)
	# bụi, hoa quanh sân
	for i in 36:
		var p := Vector2(xr.randf_range(400, 2200), xr.randf_range(2000, 2780))
		if m._clear_spot(p, 80.0) and p.distance_to(SECT_C) > 230.0 and not m._is_blocked(Rect2(p.x - 40, p.y - 40, 80, 50)):
			var n: String = ["bush_a", "bush_b", "flower_white", "flower_pink", "rock_a"][xr.randi() % 5]
			m._prop(n, p, Vector2(34, 18) if n.begins_with("bush") or n.begins_with("rock") else Vector2.ZERO, 1.0, xr.randf() < 0.5)
	# cụm cây ở góc thung lũng
	for c in [Vector2(380, 2050), Vector2(2150, 2080), Vector2(450, 2640), Vector2(2200, 2680)]:
		for i in xr.randi_range(5, 8):
			var p: Vector2 = c + Vector2(xr.randf_range(-160, 160), xr.randf_range(-110, 110))
			if m._dist_to_roads(p) > 90.0:
				m._prop(["tree_a", "tree_b", "tree_c"][xr.randi() % 3], p, Vector2(44, 30), 1.0, xr.randf() < 0.5, Color(0.8, 0.94, 0.96))


static func _camp_and_lair(m: Node, xr: RandomNumberGenerator) -> void:
	# Trại của ẩn sĩ
	if has_prop("campfire"):
		m._prop("campfire", CAMP + Vector2(0, 30), Vector2(40, 20))
	else:
		m._prop("barrel_a", CAMP + Vector2(0, 30), Vector2(40, 24))
	m.atmo.add_light(CAMP + Vector2(0, -10), Color(1.0, 0.6, 0.25), 2.6, 0.95, "always")
	m._prop("stall", CAMP + Vector2(-120, -20), Vector2(110, 50), 1.0, false, Color(0.7, 0.75, 0.8))
	m._prop("stool", CAMP + Vector2(70, 40), Vector2(24, 14))
	m._prop("stool", CAMP + Vector2(10, 84), Vector2(24, 14))
	m._prop("barrel_b", CAMP + Vector2(120, 20), Vector2(40, 24))
	m._prop("sign", CAMP + Vector2(-170, 90), Vector2(30, 14))
	# Hang ổ của Hắc Lang Vương: vòng đá và cây khô
	for i in 14:
		var a := TAU * i / 14.0
		var p := LAIR + Vector2(cos(a) * 240.0, sin(a) * 160.0)
		if m._dist_to_roads(p) > 60.0:
			m._prop("rock_a" if i % 2 == 0 else "rock_b", p, Vector2(34, 18), 1.0, i % 3 == 0, Color(0.7, 0.6, 0.62))
	for i in 5:
		var a := TAU * (i + 0.5) / 5.0
		var p := LAIR + Vector2(cos(a) * 300.0, sin(a) * 200.0)
		if has_prop("dead_tree") and m._dist_to_roads(p) > 80.0:
			m._prop("dead_tree", p, Vector2(36, 26), 1.0, i % 2 == 0)
	m.atmo.add_light(LAIR, Color(0.9, 0.3, 0.3), 3.0, 0.5)


# ---------------------------------------------------------------- núi quanh hang (sinh bằng điểm ảnh từ mặt nạ)
const MT_OUT := Vector2(375.0, 285.0)
const MT_IN := Vector2(238.0, 176.0)
const MT_FACE := 10   # độ cao mặt vách (số ô 4px)
static var _mt_noise_a: FastNoiseLite
static var _mt_noise_b: FastNoiseLite


static func _mt_init() -> void:
	if _mt_noise_a != null:
		return
	_mt_noise_a = FastNoiseLite.new()
	_mt_noise_a.seed = 31
	_mt_noise_a.frequency = 0.011
	_mt_noise_b = FastNoiseLite.new()
	_mt_noise_b.seed = 32
	_mt_noise_b.frequency = 0.014


## Điểm thế giới p có nằm trên khối núi (mặt trên) quanh Hang Linh Mạch không. Dùng chung cho vẽ, chắn đường và bản đồ nhỏ.
static func mountain_at(p: Vector2) -> bool:
	_mt_init()
	var d: Vector2 = p - CAVE
	if absf(d.x) > MT_OUT.x * 1.3 or absf(d.y) > MT_OUT.y * 1.3:
		return false
	var out := Vector2(d.x / MT_OUT.x, d.y / MT_OUT.y).length() + _mt_noise_a.get_noise_2d(p.x, p.y) * 0.22
	if out >= 1.0:
		return false
	var inn := Vector2(d.x / MT_IN.x, d.y / MT_IN.y).length() + _mt_noise_b.get_noise_2d(p.x, p.y) * 0.16
	if inn < 1.0:
		return false
	if d.x < 0.0 and absf(angle_difference(atan2(d.y, d.x), PI)) < 0.6:
		return false   # cửa hang phía tây
	return true


static func _mountain(m: Node) -> void:
	_mt_init()
	var cell: int = m.CELL
	var origin: Vector2 = CAVE - MT_OUT * 1.3
	var gw := int(MT_OUT.x * 2.6 / cell)
	var gh := int(MT_OUT.y * 2.6 / cell)
	var mask := PackedByteArray()
	mask.resize(gw * gh)
	for y in gh:
		for x in gw:
			if mountain_at(origin + Vector2(x + 0.5, y + 0.5) * cell):
				mask[y * gw + x] = 1
	# mặt vách: dưới mỗi mép nam của khối núi, MT_FACE ô, dừng khi gặp ô núi khác
	var face := PackedByteArray()
	face.resize(gw * gh)
	var depth := PackedByteArray()
	depth.resize(gw * gh)
	for x in gw:
		var y := 0
		while y < gh - 1:
			if mask[y * gw + x] == 1 and mask[(y + 1) * gw + x] == 0:
				for k in range(1, MT_FACE + 1):
					var yy := y + k
					if yy >= gh or mask[yy * gw + x] == 1:
						break
					face[yy * gw + x] = 1
					depth[yy * gw + x] = k
				y += MT_FACE
			else:
				y += 1
	var data := PackedByteArray()
	data.resize(gw * gh * 4)
	var streak := FastNoiseLite.new()
	streak.seed = 33
	streak.frequency = 0.5
	var grain := FastNoiseLite.new()
	grain.seed = 34
	grain.frequency = 0.09
	var outline := Color(0.13, 0.11, 0.16)
	var rock := [Color(0.66, 0.54, 0.46), Color(0.54, 0.43, 0.38), Color(0.42, 0.33, 0.31), Color(0.30, 0.24, 0.26), Color(0.21, 0.17, 0.2)]
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var col := Color(0, 0, 0, 0)
			var h := float(((x * 73856093) ^ (y * 19349663)) & 255) / 255.0
			if mask[i] == 1:
				var g := grain.get_noise_2d(x, y)
				col = Color(0.34, 0.60, 0.35) if g < 0.1 else Color(0.40, 0.67, 0.38)
				if h < 0.05:
					col = Color(0.50, 0.76, 0.44)
				elif h > 0.96:
					col = Color(0.28, 0.5, 0.3)
				var up := mask[(y - 1) * gw + x] if y > 0 else 0
				var dn := mask[(y + 1) * gw + x] if y < gh - 1 else 0
				var lf := mask[y * gw + x - 1] if x > 0 else 0
				var rt := mask[y * gw + x + 1] if x < gw - 1 else 0
				if dn == 0:
					col = Color(0.56, 0.82, 0.46)   # mép sáng ở rìa nam (nơi nhìn thấy vách)
				elif up == 0:
					col = outline.lerp(Color(0.2, 0.4, 0.26), 0.55)
				elif lf == 0 or rt == 0:
					col = outline.lerp(Color(0.2, 0.4, 0.26), 0.45)
			elif face[i] == 1:
				var k := int(depth[i])
				var tone := 0
				if k == 1:
					tone = 3   # bóng ngay dưới mép cỏ
				elif k <= 3:
					tone = 0
				elif k <= 6:
					tone = 1
				elif k <= 8:
					tone = 2
				else:
					tone = 3
				# thớ đá thẳng đứng và vạch tầng
				var s := streak.get_noise_2d(x * 3.0, y * 0.3)
				if s > 0.35:
					tone = mini(tone + 1, 4)
				elif s < -0.4:
					tone = maxi(tone - 1, 0)
				if k == 4 or k == 7:
					tone = mini(tone + 1, 4)
				if h > 0.97 and k > 2:
					tone = maxi(tone - 1, 0)
				col = rock[tone]
				if k == MT_FACE:
					col = outline
			if col.a > 0.0:
				data[i * 4] = int(col.r * 255.0)
				data[i * 4 + 1] = int(col.g * 255.0)
				data[i * 4 + 2] = int(col.b * 255.0)
				data[i * 4 + 3] = 255
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_RGBA8, data))
	spr.centered = false
	spr.scale = Vector2.ONE * cell
	spr.position = origin
	m.layer_ground.add_child(spr)
	# chắn đường: từng dải 32px, mỗi đoạn liền của (mặt trên + vách) là một khối
	for by in range(0, gh, 8):
		var y := by + 4
		if y >= gh:
			break
		var x := 0
		while x < gw:
			if mask[y * gw + x] == 1 or face[y * gw + x] == 1:
				var x0 := x
				while x < gw and (mask[y * gw + x] == 1 or face[y * gw + x] == 1):
					x += 1
				m.blockers.append(Rect2(origin + Vector2(x0, by) * cell, Vector2(x - x0, 8) * cell))
			else:
				x += 1
	m.no_decor.append(Rect2(origin, Vector2(gw, gh) * cell))

static func _cave(m: Node, xr: RandomNumberGenerator) -> void:
	_cave_floor(m)
	_mountain(m)
	# cửa hang: hai cụm đá canh và tinh thể nhỏ hai bên đường vào
	for sy in [-1.0, 1.0]:
		var gp := CAVE + Vector2(-300.0, sy * 84.0)
		m._prop("rock_b", gp, Vector2(34, 18), 1.3, sy < 0.0, Color(0.6, 0.6, 0.7))
		if has_prop("crystal"):
			m._prop("crystal", gp + Vector2(18, 8), Vector2(20, 12), 0.55, sy > 0.0)
		m.atmo.add_light(gp + Vector2(10, -20), Color(0.4, 0.85, 1.0), 1.1, 0.8)
	# tinh thể: vài cụm không đều + một tinh thể lớn ở giữa làm tâm điểm
	var centers := []
	for i in 6:
		var a := TAU * i / 6.0 + xr.randf_range(-0.4, 0.4)
		centers.append(CAVE + Vector2(cos(a) * xr.randf_range(70.0, 170.0), sin(a) * xr.randf_range(50.0, 120.0)))
	for c in centers:
		for k in xr.randi_range(1, 3):
			var p: Vector2 = c + Vector2(xr.randf_range(-26, 26), xr.randf_range(-14, 14))
			var s := xr.randf_range(0.55, 1.05)
			if has_prop("crystal"):
				m._prop("crystal", p, Vector2(24, 14) * s, s, xr.randf() < 0.5)
		m.atmo.add_light(c + Vector2(0, -24), Color(0.4, 0.85, 1.0), 1.4, 0.8)
	if has_prop("crystal"):
		m._prop("crystal", CAVE + Vector2(10, 14), Vector2(60, 30), 2.0)
	m.atmo.add_light(CAVE, Color(0.4, 0.8, 1.0), 4.4, 0.75)
	# đá vụn và măng đá rải trên nền
	for i in 22:
		var a := xr.randf() * TAU
		var r := sqrt(xr.randf())
		var p := CAVE + Vector2(cos(a) * 245.0 * r, sin(a) * 170.0 * r)
		if p.distance_to(CAVE) < 70.0 or m._dist_to_roads(p) < 40.0:
			continue
		var s := xr.randf_range(0.45, 0.85)
		m._prop("rock_a" if xr.randf() < 0.5 else "rock_b", p, Vector2(30, 16) * s, s, xr.randf() < 0.5, Color(0.55, 0.56, 0.68))


## Nền hang vẽ bằng điểm ảnh: đá phiến tối nhiều tông, nứt nẻ, gân phát sáng xanh, mép nhoè thành bóng sát vách.
static func _cave_floor(m: Node) -> void:
	var cell: int = m.CELL
	var rx := 305.0
	var ry := 232.0
	var origin: Vector2 = CAVE - Vector2(rx, ry)
	var gw := int(rx * 2.0 / cell)
	var gh := int(ry * 2.0 / cell)
	var tone := FastNoiseLite.new()
	tone.seed = 21
	tone.frequency = 0.06
	var edge := FastNoiseLite.new()
	edge.seed = 23
	edge.frequency = 0.08
	var vein := FastNoiseLite.new()
	vein.seed = 22
	vein.frequency = 0.045
	var crack := FastNoiseLite.new()
	crack.seed = 25
	crack.frequency = 0.11
	var data := PackedByteArray()
	data.resize(gw * gh * 4)
	var c0 := Color(0.16, 0.17, 0.24)
	var c1 := Color(0.21, 0.22, 0.30)
	var c2 := Color(0.27, 0.28, 0.37)
	var crack_col := Color(0.09, 0.09, 0.14)
	for y in gh:
		for x in gw:
			var nx := (x - gw * 0.5) / (gw * 0.5)
			var ny := (y - gh * 0.5) / (gh * 0.5)
			var d := Vector2(nx, ny).length() + edge.get_noise_2d(x, y) * 0.16
			var col := Color(0, 0, 0, 0)
			if d < 1.0:
				var t := tone.get_noise_2d(x, y)
				col = c0 if t < -0.12 else (c1 if t < 0.18 else c2)
				var h := float(((x * 73856093) ^ (y * 19349663)) & 255) / 255.0
				if h < 0.035:
					col = col.lightened(0.10)
				elif h > 0.98:
					col = col.darkened(0.18)
				if absf(crack.get_noise_2d(x, y)) < 0.018:
					col = crack_col
				var v := absf(vein.get_noise_2d(x, y))
				if v < 0.02 and d < 0.78:
					col = Color(0.42, 0.88, 1.0).lerp(Color(0.8, 1.0, 1.0), clampf(1.0 - d, 0.0, 1.0) * 0.6)
				elif v < 0.05 and d < 0.8:
					col = col.lerp(Color(0.2, 0.6, 0.8), 0.45)
				# bóng đổ sát vách: tối dần về mép
				if d > 0.72:
					col = col.darkened(floorf(clampf((d - 0.72) * 2.2, 0.0, 0.6) / 0.15) * 0.15)
			if col.a > 0.0:
				var i := (y * gw + x) * 4
				data[i] = int(col.r * 255.0)
				data[i + 1] = int(col.g * 255.0)
				data[i + 2] = int(col.b * 255.0)
				data[i + 3] = 255
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_RGBA8, data))
	s.centered = false
	s.scale = Vector2.ONE * cell
	s.position = origin
	m.layer_ground.add_child(s)
	m.no_decor.append(Rect2(origin, Vector2(rx, ry) * 2.0))

# ---------------------------------------------------------------- NPC, bù nhìn, thảo dược
static func spawn_npcs(m: Node) -> void:
	m._spawn_npc("hermit", "Ẩn sĩ Mặc Thạch", {"hair": "hair_topknot_silver", "clothes": "outfit_xam", "shoes": "shoes_cloth_brown"}, CAMP + Vector2(-38, 14))


static func extra_herbs(m: Node) -> void:
	var xr := RandomNumberGenerator.new()
	xr.seed = 4242
	var spots := [[Rect2(2700, 300, 1300, 1300), 18], [Rect2(300, 1950, 1900, 780), 12], [Rect2(3000, 2000, 900, 600), 8]]
	for s in spots:
		var r: Rect2 = s[0]
		var made := 0
		var tries := 0
		while made < int(s[1]) and tries < 400:
			tries += 1
			var p := r.position + Vector2(xr.randf() * r.size.x, xr.randf() * r.size.y)
			if not m._clear_spot(p, 40.0) or m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 40)):
				continue
			var h: Node2D = preload("res://scripts/herb.gd").new()
			h.position = p
			m.world.add_child(h)
			m.herbs.append(h)
			made += 1
