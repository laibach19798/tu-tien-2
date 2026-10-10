extends RefCounted
class_name MapBuilder
## Dựng một map phụ (Maps.DEFS) vào các nút/biến hiện hành của main: nền ghép từ ảnh 64x64, đường mòn, vật thể, cổng, linh mạch, quái.
## main phải đã trỏ world / layer_ground / layer_shadows / blockers... sang bộ nút mới của map này trước khi gọi build().

const CELL := 64


static func build(m: Node, id: String) -> void:
	var d: Dictionary = Maps.DEFS[id]
	var xr := RandomNumberGenerator.new()
	xr.seed = hash(id)
	_ground(m, d, xr)
	_border(m, d, xr)
	if bool(d.get("war", false)):
		_war_world(m, d, xr)
	else:
		_props(m, d, xr)
	for g in d["gates"]:
		gate_visual(m, g)
	m.gates = []
	for g in d["gates"]:   # cổng ra: đích là chỗ đứng trước cổng ở thế giới gốc
		var gg: Dictionary = (g as Dictionary).duplicate()
		gg["to_pos"] = Maps.overworld_landing(id)
		m.gates.append(gg)
	m.map_herbs(xr, int(d.get("herbs", 0)))
	m.spawn_monster_groups(d["groups"])


# ---------------------------------------------------------------- nền
static func _load_tiles(d: Dictionary) -> Dictionary:
	var out := {}
	for k in ["base", "alt", "path", "rock"]:
		var imgs: Array = []
		for i in 4:
			var path := "res://assets/ground/%s_%s_%d.png" % [d["tiles"], k, i]
			if ResourceLoader.exists(path):
				var img: Image = (load(path) as Texture2D).get_image()
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				if img.get_width() != CELL or img.get_height() != CELL:
					img.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
				imgs.append(img)
		out[k] = imgs
	return out


static func _flat_tile(col: Color, xr: RandomNumberGenerator) -> Image:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for i in 40:   # vài đốm sáng/tối cho đỡ phẳng
		var c := col.lightened(0.07) if i % 2 == 0 else col.darkened(0.07)
		img.fill_rect(Rect2i(xr.randi_range(0, CELL - 6), xr.randi_range(0, CELL - 6), xr.randi_range(2, 6), xr.randi_range(2, 4)), c)
	return img


static func _path_dist(p: Vector2, lines: Array) -> float:
	var best := INF
	for line in lines:
		for i in range(line.size() - 1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


## Mảng dán tròn có viền mờ: lật ngẫu nhiên tile, nhân alpha theo khoảng cách tới tâm và theo mức (độ đậm của mảng).
static func _stamps(tiles: Array, levels: Array, inner := 0.35) -> Array:
	var half := CELL * 0.5
	var out: Array = []   # out[level_index] = [Image...]
	for lv in levels:
		var list: Array = []
		for t in tiles:
			for flip in 4:
				var im: Image = (t as Image).duplicate()
				if flip & 1:
					im.flip_x()
				if flip & 2:
					im.flip_y()
				for y in CELL:
					for x in CELL:
						var r := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
						var f := 1.0 - smoothstep(inner, 1.0, r)
						var c := im.get_pixel(x, y)
						c.a *= f * float(lv)
						im.set_pixel(x, y, c)
				list.append(im)
		out.append(list)
	return out


static func _stamp_at(img: Image, stamps: Array, level: int, center: Vector2, xr: RandomNumberGenerator) -> void:
	var list: Array = stamps[level]
	var st: Image = list[xr.randi() % list.size()]
	img.blend_rect(st, Rect2i(0, 0, CELL, CELL), Vector2i(int(center.x) - CELL / 2, int(center.y) - CELL / 2))


static var _ground_cache := {}   # nền các map lớn (Tiểu Thế Giới) dựng lâu nên giữ lại cho lần vào sau


static func _ground_finish(m: Node, d: Dictionary, tex: ImageTexture, xr: RandomNumberGenerator) -> void:
	var size: Vector2 = d["size"]
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	m.layer_ground.add_child(spr)
	for i in int(size.x * size.y / 70000.0):
		var c3 := Vector2(xr.randf_range(0, size.x), xr.randf_range(0, size.y))
		var r := xr.randf_range(90, 240)
		m.layer_ground.add_child(m._blob(c3, r, r * xr.randf_range(0.55, 0.85), Color(0, 0.03, 0.08, 0.09) if i % 2 == 0 else Color(1, 1, 0.9, 0.05)))
	for line in d.get("path", []):
		m.path_lines.append({"pts": PackedVector2Array(line), "w": float(d.get("path_w", 90.0))})


static func _ground(m: Node, d: Dictionary, xr: RandomNumberGenerator) -> void:
	if bool(d.get("war", false)) and _ground_cache.has(d["name"]):
		_ground_finish(m, d, _ground_cache[d["name"]], xr)
		return
	var size: Vector2 = d["size"]
	var gw := int(ceil(size.x / CELL))
	var gh := int(ceil(size.y / CELL))
	var tiles := _load_tiles(d)
	var fallback := {
		"base": [_flat_tile(d["ground"], xr), _flat_tile(d["ground"].darkened(0.05), xr)],
		"alt": [_flat_tile(d["ground2"], xr)],
		"path": [_flat_tile(d["path_col"], xr)],
		"rock": [_flat_tile(d["rock_col"], xr)],
	}
	for k in fallback:
		if not tiles.has(k) or (tiles[k] as Array).is_empty():
			tiles[k] = fallback[k]
	var noise := FastNoiseLite.new()
	noise.seed = hash(d["name"])
	noise.frequency = 0.09
	var noise2 := FastNoiseLite.new()
	noise2.seed = hash(d["name"]) + 7
	noise2.frequency = 0.07
	var lines: Array = d.get("path", [])
	var pw: float = float(d.get("path_w", 90.0))
	var w := gw * CELL
	var h := gh * CELL
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# 1) nền: lát ô rồi phủ mảng tròn mềm lên để xoá đường kẻ ô
	for cy in gh:
		for cx in gw:
			var t: Image = (tiles["base"][xr.randi() % tiles["base"].size()] as Image).duplicate()
			if xr.randf() < 0.5:
				t.flip_x()
			if xr.randf() < 0.5:
				t.flip_y()
			img.blit_rect(t, Rect2i(0, 0, CELL, CELL), Vector2i(cx * CELL, cy * CELL))
	var base_st := _stamps(tiles["base"], [1.0])
	var y := 0.0
	while y < h + 40.0:
		var x := 0.0
		while x < w + 40.0:
			_stamp_at(img, base_st, 0, Vector2(x + xr.randf_range(-22, 22), y + xr.randf_range(-22, 22)), xr)
			x += 44.0
		y += 44.0
	# 2) mảng địa hình phụ (alt, rock): mềm dần theo nhiễu, né đường mòn
	var levels := [0.4, 0.7, 1.0]
	for kind in ["alt", "rock"]:
		var st := _stamps(tiles[kind], levels)
		var nz: FastNoiseLite = noise if kind == "alt" else noise2
		var thr: float = 0.26 if kind == "alt" else 0.36
		var sgn := 1.0 if kind == "alt" else -1.0
		y = 0.0
		while y < h:
			var x := 0.0
			while x < w:
				var c := Vector2(x + xr.randf_range(-14, 14), y + xr.randf_range(-14, 14))
				var v := sgn * nz.get_noise_2d(c.x / CELL, c.y / CELL)
				if v > thr - 0.1 and _path_dist(c, lines) > pw * 0.5 + 24.0:
					var k := smoothstep(thr - 0.1, thr + 0.2, v)
					_stamp_at(img, st, clampi(int(k * 2.99), 0, 2), c, xr)
				x += 30.0
			y += 30.0
	# 2b) vùng chủ đề của từng tông / địa bàn (Tiểu Thế Giới)
	if bool(d.get("war", false)):
		_paint_patches(img, xr)
	# 3) đường mòn: dải mảng dán dọc đường, rìa lệch ngẫu nhiên và mờ dần ra cỏ
	var path_st := _stamps(tiles["path"], [1.0])
	for line in lines:
		for i in range(line.size() - 1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var n := int(a.distance_to(b) / 16.0) + 1
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			for j in n + 1:
				var c: Vector2 = a.lerp(b, float(j) / n)
				for off in [-0.34, 0.0, 0.34]:
					_stamp_at(img, path_st, 0, c + side * (off * pw + xr.randf_range(-9, 9)) + dir * xr.randf_range(-6, 6), xr)
	# 4) ao/vật chặn: ô alt đậm thì chặn đường đi (nếu bản đồ yêu cầu)
	if bool(d.get("alt_blocks", false)):
		for cy in gh:
			for cx in gw:
				var c2 := Vector2(cx + 0.5, cy + 0.5) * CELL
				if noise.get_noise_2d(c2.x / CELL, c2.y / CELL) > 0.36 and _path_dist(c2, lines) > pw * 0.5 + 50.0 and not _near_gate_or_safe(m, d, c2):
					m.blockers.append(Rect2(cx * CELL + 10, cy * CELL + 10, CELL - 20, CELL - 20))
	if bool(d.get("war", false)):
		_paint_plazas(img, xr)
	var tex := ImageTexture.create_from_image(img)
	if bool(d.get("war", false)):
		_ground_cache[d["name"]] = tex
	_ground_finish(m, d, tex, xr)


# ---------------------------------------------------------------- nền làng (thế giới gốc)
## Nền cỏ cho cả thế giới gốc: cỏ xanh, vài mảng cỏ khô loang mềm. Trả về ảnh RGBA cỡ size.
static func village_ground(size: Vector2, xr: RandomNumberGenerator) -> Image:
	var tiles := _load_tiles({"tiles": "meadow"})
	var gw := int(ceil(size.x / CELL))
	var gh := int(ceil(size.y / CELL))
	var w := gw * CELL
	var h := gh * CELL
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for cy in gh:
		for cx in gw:
			var t: Image = (tiles["base"][xr.randi() % tiles["base"].size()] as Image).duplicate()
			if xr.randf() < 0.5:
				t.flip_x()
			if xr.randf() < 0.5:
				t.flip_y()
			img.blit_rect(t, Rect2i(0, 0, CELL, CELL), Vector2i(cx * CELL, cy * CELL))
	var base_st := _stamps(tiles["base"], [1.0])
	var y := 0.0
	while y < h + 40.0:
		var x := 0.0
		while x < w + 40.0:
			_stamp_at(img, base_st, 0, Vector2(x + xr.randf_range(-22, 22), y + xr.randf_range(-22, 22)), xr)
			x += 44.0
		y += 44.0
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.05
	var dry_st := _stamps(tiles["alt"], [0.35, 0.6, 0.85])
	y = 0.0
	while y < h:
		var x := 0.0
		while x < w:
			var c := Vector2(x + xr.randf_range(-14, 14), y + xr.randf_range(-14, 14))
			var v := noise.get_noise_2d(c.x / CELL, c.y / CELL)
			if v > 0.22:
				_stamp_at(img, dry_st, clampi(int(smoothstep(0.22, 0.5, v) * 2.99), 0, 2), c, xr)
			x += 34.0
		y += 34.0
	return img


## Vẽ mạng đường (path_lines của main) lên ảnh nền bằng mảng dán đất, rìa mờ ra cỏ.
static func paint_roads(img: Image, path_lines: Array, plaza_r: float, xr: RandomNumberGenerator) -> void:
	var tiles := _load_tiles({"tiles": "meadow"})
	var st := _stamps(tiles["path"], [1.0])
	for line in path_lines:
		var pts: PackedVector2Array = line["pts"]
		var wdt: float = float(line["w"])
		if pts.size() == 1:   # quảng trường: hình elip
			var rx := plaza_r - 14.0
			var ry := rx * 0.82
			var yy := -ry
			while yy <= ry:
				var xx := -rx
				while xx <= rx:
					if Vector2(xx / rx, yy / ry).length() <= 1.0:
						_stamp_at(img, st, 0, pts[0] + Vector2(xx, yy) + Vector2(xr.randf_range(-8, 8), xr.randf_range(-8, 8)), xr)
					xx += 26.0
				yy += 26.0
			continue
		var acc := 0.0
		for i in range(1, pts.size()):
			acc += pts[i].distance_to(pts[i - 1])
			if acc < 14.0:
				continue
			acc = 0.0
			var dir := (pts[i] - pts[maxi(i - 2, 0)]).normalized()
			var side := Vector2(-dir.y, dir.x)
			var n := maxi(2, int(ceil(wdt / 36.0)))
			for k in n:
				var off := lerpf(-(wdt * 0.5 - 16.0), wdt * 0.5 - 16.0, float(k) / float(n - 1))
				_stamp_at(img, st, 0, pts[i] + side * (off + xr.randf_range(-8, 8)) + dir * xr.randf_range(-6, 6), xr)


## Lát đá lên làng: sân quảng trường, đường vào nhà, một đoạn đường chính quanh quảng trường (mờ dần ra đất), và vài sân nhỏ.
## pads: [[tâm, rx, ry]] sân đá cát. Mảng dán đá có rìa gắt hơn mảng đất để nhìn ra lát đá.
static func paint_stone(img: Image, path_lines: Array, village: Rect2, center: Vector2, plaza_r: float, pads: Array, xr: RandomNumberGenerator) -> void:
	var tiles := _load_tiles({"tiles": "cobble"})
	if (tiles["base"] as Array).is_empty():
		return
	var cobble := _stamps((tiles["base"] as Array) + (tiles["path"] as Array).slice(0, 1), [1.0], 0.72)
	var flag := _stamps(tiles["alt"], [1.0], 0.72)
	var sand := _stamps(tiles["rock"], [1.0], 0.72)
	for pd in pads:
		_fill_ellipse(img, sand, pd[0], float(pd[1]), float(pd[2]), xr)
	for i in path_lines.size():
		var line: Dictionary = path_lines[i]
		var pts: PackedVector2Array = line["pts"]
		var wdt: float = float(line["w"])
		if pts.size() < 2:
			continue
		var lane := wdt <= 70.0
		var acc := 0.0
		for j in range(1, pts.size()):
			acc += pts[j].distance_to(pts[j - 1])
			if acc < 12.0:
				continue
			acc = 0.0
			if not village.has_point(pts[j]):
				continue
			var d := pts[j].distance_to(center)
			if not lane and d > 450.0:
				continue
			if not lane and xr.randf() > 1.0 - smoothstep(300.0, 450.0, d):
				continue
			var dir := (pts[j] - pts[maxi(j - 2, 0)]).normalized()
			var side := Vector2(-dir.y, dir.x)
			var offs: Array = [0.0] if lane else [-(wdt * 0.5 - 30.0), wdt * 0.5 - 30.0]
			for off in offs:
				_stamp_at(img, cobble, 0, pts[j] + side * (float(off) + xr.randf_range(-3, 3)) + dir * xr.randf_range(-4, 4), xr)
	# quảng trường (vẽ sau cùng để đè lên đường): sân đá phiến hình elip nhỏ hơn nền đất
	_fill_ellipse(img, flag, center, plaza_r * 0.62, plaza_r * 0.62 * 0.82, xr)


static func _fill_ellipse(img: Image, st: Array, c: Vector2, rx: float, ry: float, xr: RandomNumberGenerator) -> void:
	var yy := -ry
	while yy <= ry:
		var xx := -rx
		while xx <= rx:
			if Vector2(xx / rx, yy / ry).length() <= 1.0:
				_stamp_at(img, st, 0, c + Vector2(xx, yy) + Vector2(xr.randf_range(-3, 3), xr.randf_range(-3, 3)), xr)
			xx += 20.0
		yy += 20.0


# ---------------------------------------------------------------- Tiểu Thế Giới: vùng chủ đề
## Các vùng tô theo chủ đề: [{c, rx, ry, theme}] quanh căn cứ từng tông (to) và từng địa bàn (nhỏ).
static func war_patches() -> Array:
	var out: Array = []
	for sid in SectWar.SECTS:
		var h: Dictionary = SectWar.SECTS[sid]
		if h["theme"] != "meadow":
			out.append({"c": h["hq"], "rx": 780.0, "ry": 560.0, "theme": h["theme"]})
	for t in SectWar.TERRITORIES:
		if t["theme"] != "meadow":
			out.append({"c": t["pos"], "rx": 430.0, "ry": 320.0, "theme": t["theme"]})
	return out


static func _paint_patches(img: Image, xr: RandomNumberGenerator) -> void:
	var cache := {}
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.012
	for pt in war_patches():
		var theme: String = pt["theme"]
		if not cache.has(theme):
			var ts := _load_tiles({"tiles": theme})
			cache[theme] = [_stamps(ts["base"], [0.5, 1.0]), _stamps(ts["alt"], [0.5, 1.0])]
		var c: Vector2 = pt["c"]
		var rx: float = pt["rx"]
		var ry: float = pt["ry"]
		var y := c.y - ry * 1.25
		while y <= c.y + ry * 1.25:
			var x := c.x - rx * 1.25
			while x <= c.x + rx * 1.25:
				var p := Vector2(x + xr.randf_range(-12, 12), y + xr.randf_range(-12, 12))
				var nd := Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).length() + noise.get_noise_2d(p.x, p.y) * 0.45
				if nd < 1.0:
					var which := 1 if noise.get_noise_2d(p.x + 500.0, p.y) > 0.22 else 0
					_stamp_at(img, cache[theme][which], 1 if nd < 0.72 else 0, p, xr)
				x += 26.0
			y += 26.0


## Sân lát đá quanh căn cứ từng tông và quanh mỗi cờ địa bàn.
static func _paint_plazas(img: Image, xr: RandomNumberGenerator) -> void:
	var tiles := _load_tiles({"tiles": "cobble"})
	if (tiles["base"] as Array).is_empty():
		return
	var cobble := _stamps(tiles["base"], [1.0], 0.72)
	var flag := _stamps(tiles["alt"], [1.0], 0.72)
	var sand := _stamps(tiles["rock"], [1.0], 0.72)
	for sid in SectWar.SECTS:
		var hq: Vector2 = SectWar.SECTS[sid]["hq"]
		_fill_ellipse(img, cobble, hq, 330.0, 230.0, xr)
		_fill_ellipse(img, flag, hq, 170.0, 120.0, xr)
	for t in SectWar.TERRITORIES:
		_fill_ellipse(img, sand, t["pos"], 120.0, 80.0, xr)


# ---------------------------------------------------------------- Tiểu Thế Giới: vật thể, căn cứ, địa bàn
const THEME_PROPS := {
	"meadow": [
		{"n": "tree_a", "c": 14, "block": Vector2(44, 30)}, {"n": "tree_b", "c": 10, "block": Vector2(44, 30)}, {"n": "tree_big", "c": 6, "block": Vector2(54, 34)},
		{"n": "bush_a", "c": 12, "block": Vector2(30, 14)}, {"n": "rock_a", "c": 6, "block": Vector2(50, 26)},
		{"n": "flower_white", "c": 16}, {"n": "flower_pink", "c": 12},
	],
	"snow": [
		{"n": "tree_pine_snow", "c": 16, "block": Vector2(36, 24)}, {"n": "ice_crystal", "c": 6, "block": Vector2(40, 22)},
		{"n": "snow_mound", "c": 10}, {"n": "rock_a", "c": 5, "block": Vector2(50, 26), "tint": Color(0.82, 0.9, 1.0)},
	],
	"swamp": [
		{"n": "tree_swamp", "c": 12, "block": Vector2(40, 26)}, {"n": "reeds", "c": 20}, {"n": "mushroom_giant", "c": 6, "block": Vector2(36, 20)},
		{"n": "skull_stake", "c": 3, "block": Vector2(18, 10)},
	],
	"cave": [
		{"n": "stalagmite", "c": 12, "block": Vector2(36, 22)}, {"n": "crystal", "c": 5, "block": Vector2(50, 26)}, {"n": "cave_mushroom", "c": 10},
	],
	"lava": [
		{"n": "dead_tree", "c": 8, "block": Vector2(36, 22), "tint": Color(0.75, 0.5, 0.45)},
		{"n": "rock_a", "c": 10, "block": Vector2(50, 26), "tint": Color(0.7, 0.4, 0.35)}, {"n": "rock_b", "c": 6, "block": Vector2(50, 26), "tint": Color(0.7, 0.4, 0.35)},
	],
}


## Chỗ trống để đặt vật thể trang trí: không gần căn cứ, địa bàn, cổng, đường mòn.
static func _war_clear(m: Node, d: Dictionary, p: Vector2, lines: Array) -> bool:
	var size: Vector2 = d["size"]
	if p.x < 120.0 or p.y < 260.0 or p.x > size.x - 120.0 or p.y > size.y - 140.0:
		return false
	for sid in SectWar.SECTS:
		if p.distance_to(SectWar.SECTS[sid]["hq"]) < 400.0:
			return false
	for t in SectWar.TERRITORIES:
		if p.distance_to(t["pos"]) < 190.0:
			return false
	if _near_gate_or_safe(m, d, p) or _path_dist(p, lines) < float(d.get("path_w", 90.0)) * 0.5 + 40.0:
		return false
	return not m._is_blocked(Rect2(p.x - 50, p.y - 40, 100, 50))


static func _place_theme_props(m: Node, d: Dictionary, xr: RandomNumberGenerator, theme: String, c: Vector2, rx: float, ry: float, lines: Array, scale_k: float) -> void:
	for e in THEME_PROPS[theme]:
		var name := str(e["n"])
		if not ResourceLoader.exists("res://assets/props/%s.png" % name):
			continue
		var want := int(round(float(e["c"]) * scale_k))
		var made := 0
		var tries := 0
		while made < want and tries < want * 25:
			tries += 1
			var p := c + Vector2(xr.randf_range(-rx, rx), xr.randf_range(-ry, ry))
			if Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).length() > 1.0 or not _war_clear(m, d, p, lines):
				continue
			m._prop(name, p, e.get("block", Vector2.ZERO), 1.0, xr.randf() < 0.5, e.get("tint", Color.WHITE))
			made += 1


static func _war_world(m: Node, d: Dictionary, xr: RandomNumberGenerator) -> void:
	var lines: Array = d.get("path", [])
	# cây cối theo chủ đề của từng vùng, và đồng cỏ chung cho phần còn lại
	for pt in war_patches():
		var k: float = (float(pt["rx"]) * float(pt["ry"])) / (600.0 * 450.0)
		_place_theme_props(m, d, xr, str(pt["theme"]), pt["c"], float(pt["rx"]) * 0.95, float(pt["ry"]) * 0.95, lines, k)
	var size: Vector2 = d["size"]
	var patches := war_patches()
	for e in THEME_PROPS["meadow"]:
		var name := str(e["n"])
		var want := int(float(e["c"]) * 14.0)
		var made := 0
		var tries := 0
		while made < want and tries < want * 25:
			tries += 1
			var p := Vector2(xr.randf_range(120, size.x - 120), xr.randf_range(260, size.y - 140))
			var in_patch := false
			for pt in patches:
				if Vector2((p.x - pt["c"].x) / (float(pt["rx"]) * 1.1), (p.y - pt["c"].y) / (float(pt["ry"]) * 1.1)).length() < 1.0:
					in_patch = true
					break
			if in_patch or not _war_clear(m, d, p, lines):
				continue
			m._prop(name, p, e.get("block", Vector2.ZERO), 1.0, xr.randf() < 0.5, e.get("tint", Color.WHITE))
			made += 1
	for sid in SectWar.SECTS:
		_hq(m, str(sid), xr)
	m.territory_nodes = {}
	for t in SectWar.TERRITORIES:
		_territory(m, t, xr)
	# quân xâm lược đang chờ ở các địa bàn bị tập kích
	for tid in m.war.under_attack:
		spawn_humanoids(m, str(m.war.under_attack[tid]["by"]), str(tid), SectWar.territory(tid)["pos"], 4, 1, true)


## Căn cứ một tông: cổng tông, nhà, cờ; Kiếm Tông có thêm NPC và bù nhìn, các tông khác có lính canh.
static func _hq(m: Node, sid: String, xr: RandomNumberGenerator) -> void:
	var h: Dictionary = SectWar.SECTS[sid]
	var pos: Vector2 = h["hq"]
	var col: Color = h["color"]
	var tint := col.lerp(Color.WHITE, 0.55)
	m._prop("sect_gate", pos + Vector2(0, -190), Vector2(180, 24), 1.0, false, tint)
	m._house("house_blue", pos + Vector2(-330, -40), false, tint)
	m._house("house_red", pos + Vector2(330, -40), true, tint)
	for off in [Vector2(-170, -120), Vector2(170, -120), Vector2(-250, 150), Vector2(250, 150)]:
		_banner(m, pos + off, col)
	m.atmo.add_light(pos + Vector2(0, -60), col.lerp(Color(1, 0.85, 0.6), 0.5), 3.4, 0.7)
	m.no_decor.append(Rect2(pos.x - 400, pos.y - 260, 800, 520))
	if sid == SectWar.PLAYER:
		m._spawn_npc("sect_head", "Chưởng môn Thanh Huyền", {"hair": "hair_long_silver", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black"}, pos + Vector2(0, 0))
		m._prop("stall", pos + Vector2(-120, -105), Vector2(110, 40), 1.0, false, Color(0.9, 0.86, 0.7))
		m._spawn_npc("sect_keeper", "Chấp sự Mộ Dung", {"hair": "hair_ponytail_black", "clothes": "outfit_thanh", "shoes": "shoes_boot_black"}, pos + Vector2(-120, -60))
		for off in [Vector2(-240, 120), Vector2(-130, 160), Vector2(130, 160), Vector2(240, 120)]:
			var dm: TrainingDummy = preload("res://scripts/dummy.gd").new()
			dm.position = pos + off
			m.world.add_child(dm)
			m.blockers.append(Rect2(dm.position.x - 18, dm.position.y - 14, 36, 16))
			dm.got_hit.connect(m._on_dummy_hit)
	else:
		spawn_humanoids(m, sid, "", pos + Vector2(0, 60), 4, 1, false)


static func _banner(m: Node, p: Vector2, col: Color) -> void:
	var pname := "war_banner" if ResourceLoader.exists("res://assets/props/war_banner.png") else "sign"
	m._prop(pname, p, Vector2(16, 8), 1.0, false, col.lerp(Color.WHITE, 0.25))


## Một địa bàn: cờ + lính canh (hoặc đệ tử Kiếm Tông nếu đã chiếm).
static func _territory(m: Node, t: Dictionary, xr: RandomNumberGenerator) -> void:
	var tid: String = t["id"]
	var pos: Vector2 = t["pos"]
	var flag := TerritoryFlag.new()
	flag.setup(tid, m.war)
	flag.position = pos
	m.world.add_child(flag)
	m.npcs.append(flag)
	m.blockers.append(Rect2(pos.x - 14, pos.y - 10, 28, 12))
	m.territory_nodes[tid] = {"flag": flag, "allies": []}
	m.no_decor.append(Rect2(pos.x - 140, pos.y - 100, 280, 200))
	m.atmo.add_light(pos + Vector2(0, -40), SectWar.sect_color(m.war.owner_of(tid)).lerp(Color.WHITE, 0.4), 1.6, 0.6)
	_garrison(m, tid)


## Dựng lực lượng đứng ở địa bàn theo chủ hiện tại.
static func _garrison(m: Node, tid: String) -> void:
	var t := SectWar.territory(tid)
	var o: String = m.war.owner_of(tid)
	var pos: Vector2 = t["pos"]
	if o == SectWar.PLAYER:
		var outfit: Dictionary = SectWar.SECTS[SectWar.PLAYER]["disciple"]
		for off in [Vector2(-90, 40), Vector2(90, 40)]:
			m._spawn_npc("ally", "Đệ tử Kiếm Tông", outfit, pos + off)
			m.territory_nodes[tid]["allies"].append(m.npcs[m.npcs.size() - 1])
	elif o != "":
		spawn_humanoids(m, o, tid, pos, 3, 1, false)
	else:
		for g in t.get("guards", []):
			var made := 0
			var tries := 0
			while made < int(g[1]) and tries < 100:
				tries += 1
				var p := pos + Vector2(m.rng.randf_range(-170, 170), m.rng.randf_range(-110, 110))
				if m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)):
					continue
				var mon := Monster.new()
				mon.territory_id = tid
				mon.setup(m, str(g[0]), p)
				m.world.add_child(mon)
				m.monsters.append(mon)
				made += 1


## Sinh lính người của một tông quanh center (nd đệ tử + ne trưởng lão). invader: quân xâm lược (hạ hết là bảo vệ được địa bàn).
static func spawn_humanoids(m: Node, sid: String, tid: String, center: Vector2, nd: int, ne: int, invader: bool) -> void:
	var h: Dictionary = SectWar.SECTS[sid]
	for i in nd + ne:
		var elder := i >= nd
		var tries := 0
		while tries < 60:
			tries += 1
			var p := center + Vector2(m.rng.randf_range(-170, 170), m.rng.randf_range(-110, 110))
			if m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)) or (m.is_safe(p) and sid != SectWar.PLAYER):
				continue
			var mon := Monster.new()
			mon.outfit = h["elder"] if elder else h["disciple"]
			mon.sect_id = sid
			mon.territory_id = tid
			mon.invader = invader
			mon.display_name = ("Trưởng lão " if elder else "Đệ tử ") + str(h["name"])
			mon.setup(m, "sect_elder" if elder else "sect_disciple", p)
			m.world.add_child(mon)
			m.monsters.append(mon)
			break


## Cập nhật hình ảnh / lực lượng khi một địa bàn đổi chủ (đang ở trong map).
static func refresh_territory(m: Node, tid: String) -> void:
	var tn: Dictionary = m.territory_nodes.get(tid, {})
	if tn.is_empty():
		return
	(tn["flag"] as TerritoryFlag).refresh()
	for a in tn["allies"]:
		m.npcs.erase(a)
		a.queue_free()
	tn["allies"] = []
	var o: String = m.war.owner_of(tid)
	if o == SectWar.PLAYER:
		_garrison(m, tid)
		return
	var alive := 0
	for mon in m.monsters:
		if mon.territory_id == tid and mon.alive:
			mon.invader = false
			alive += 1
	if alive == 0:
		_garrison(m, tid)


# ---------------------------------------------------------------- vật thể
static func _near_gate_or_safe(m: Node, d: Dictionary, p: Vector2) -> bool:
	for g in d["gates"]:
		if p.distance_to(g["pos"]) < 170.0:
			return true
	for z in d.get("safe", []):
		if p.distance_to(z[0]) < float(z[1]) + 20.0:
			return true
	return false


static func _border(m: Node, d: Dictionary, xr: RandomNumberGenerator) -> void:
	if not d.has("border"):
		return
	var b: Dictionary = d["border"]
	var names: Array = b["names"]
	var step := int(b["step"])
	var size: Vector2 = d["size"]
	var lines: Array = d.get("path", [])
	for layer in int(b["rows"]):
		for x in range(80 + layer * 60, int(size.x) - 60, step):
			for y in [185.0 + layer * 70.0, size.y - 10.0 - layer * 60.0]:
				_border_prop(m, d, xr, names, b, Vector2(x + xr.randf_range(-30, 30), y + xr.randf_range(-10, 10)), lines)
		for y in range(330 + layer * 80, int(size.y) - 100, step + 20):
			for x in [80.0 + layer * 60.0, size.x - 80.0 - layer * 60.0]:
				_border_prop(m, d, xr, names, b, Vector2(x + xr.randf_range(-15, 15), y + xr.randf_range(-30, 30)), lines)


static func _border_prop(m: Node, d: Dictionary, xr: RandomNumberGenerator, names: Array, b: Dictionary, p: Vector2, lines: Array) -> void:
	if _path_dist(p, lines) < float(d.get("path_w", 90.0)) * 0.5 + 60.0 or _near_gate_or_safe(m, d, p):
		return
	m._prop(str(names[xr.randi() % names.size()]), p, b["block"], 1.0, xr.randf() < 0.5, b.get("tint", Color.WHITE))


static func _props(m: Node, d: Dictionary, xr: RandomNumberGenerator) -> void:
	var size: Vector2 = d["size"]
	var lines: Array = d.get("path", [])
	var pw: float = float(d.get("path_w", 90.0))
	for e in d["props"]:
		var name := str(e["n"])
		if not ResourceLoader.exists("res://assets/props/%s.png" % name):
			continue   # ảnh chưa có thì bỏ qua (map vẫn chạy được)
		var block: Vector2 = e.get("block", Vector2.ZERO)
		var tint: Color = e.get("tint", Color.WHITE)
		var made := 0
		var tries := 0
		while made < int(e["count"]) and tries < int(e["count"]) * 30:
			tries += 1
			var p := Vector2(xr.randf_range(120, size.x - 120), xr.randf_range(260, size.y - 140))
			if _path_dist(p, lines) < pw * 0.5 + 40.0 or _near_gate_or_safe(m, d, p):
				continue
			if m._is_blocked(Rect2(p.x - 50, p.y - 40, 100, 50)):
				continue
			m._prop(name, p, block, 1.0, xr.randf() < 0.5, tint)
			made += 1


## Cổng dịch chuyển: chỉ là một điểm sáng tròn nhỏ trên nền (đi vào là chuyển map).
static func gate_visual(m: Node, g: Dictionary) -> void:
	var pos: Vector2 = g["pos"]
	var tint: Color = g.get("tint", Color(0.7, 0.9, 1.0))
	var glow := GateGlow.new()
	glow.tint = tint
	glow.position = pos
	m.layer_ground.add_child(glow)
	m.atmo.add_light(pos, tint, 0.9, 0.8, "always")
	m.no_decor.append(Rect2(pos.x - 60, pos.y - 40, 120, 80))
