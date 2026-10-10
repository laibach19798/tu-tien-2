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
	if not d.has("sect"):
		_border(m, d, xr)
	m.gates = []
	for g in d["gates"]:   # cổng ra: mặc định về chỗ đứng trước cổng ở thế giới gốc
		var gg: Dictionary = (g as Dictionary).duplicate()
		if not gg.has("to_pos"):
			gg["to_pos"] = Maps.overworld_landing(id)
		m.gates.append(gg)
	if d.has("sect"):
		for g in d["gates"]:
			gate_visual(m, g)
		_compound(m, d, xr)
	elif bool(d.get("war", false)):
		for g in d["gates"]:
			gate_visual(m, g)
		_war_world(m, d, xr)
	else:
		for g in d["gates"]:
			gate_visual(m, g)
		_props(m, d, xr)
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
	if (bool(d.get("war", false)) or d.has("sect")) and _ground_cache.has(d["name"]):
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
	var path_tiles: Array = tiles["path"]
	if d.has("path_theme"):   # đường lát đá riêng (khác nền)
		var pt := _load_tiles({"tiles": d["path_theme"]})
		if not (pt[d.get("path_row", "path")] as Array).is_empty():
			path_tiles = pt[d.get("path_row", "path")]
	var path_st := _stamps(path_tiles, [1.0], 0.55 if d.has("path_theme") else 0.35)
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
	if d.has("sect"):
		_paint_compound_plazas(img, d, xr)
		_paint_sky(img, str(SectWar.SECTS[d["sect"]]["theme"]), xr)
	var tex := ImageTexture.create_from_image(img)
	if bool(d.get("war", false)) or d.has("sect"):
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


static func _place_theme_props(m: Node, d: Dictionary, xr: RandomNumberGenerator, theme: String, c: Vector2, rx: float, ry: float, lines: Array, scale_k: float, clear := Callable()) -> void:
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
			if Vector2((p.x - c.x) / rx, (p.y - c.y) / ry).length() > 1.0:
				continue
			var spot_ok: bool = clear.call(p) if clear.is_valid() else _war_clear(m, d, p, lines)
			if not spot_ok:
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


## Căn cứ một tông trong Tiểu Thế Giới: chỉ có DUY NHẤT một cổng dịch chuyển vào tông môn (map riêng), vài cờ và lính gác ngoài cổng.
static func _hq(m: Node, sid: String, xr: RandomNumberGenerator) -> void:
	var h: Dictionary = SectWar.SECTS[sid]
	var pos: Vector2 = h["hq"]
	var col: Color = h["color"]
	var g := {"pos": pos, "to": "sect_" + sid, "to_pos": Maps.COMPOUND_ENTRY, "label": h["name"], "tint": col}
	m.gates.append(g)
	gate_visual(m, g, true)
	for off in [Vector2(-110, -40), Vector2(110, -40)]:
		_banner(m, pos + off, col)
	m.atmo.add_light(pos, col.lerp(Color(1, 0.85, 0.6), 0.4), 2.6, 0.7)
	m.no_decor.append(Rect2(pos.x - 300, pos.y - 220, 600, 440))
	if sid != SectWar.PLAYER:
		spawn_humanoids(m, sid, "", pos + Vector2(0, -170), 2, 1, false)


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


## Sinh một lính người (đệ tử / trưởng lão / tông chủ) của tông sid tại p.
static func spawn_one(m: Node, sid: String, kind: String, p: Vector2, tid := "", invader := false) -> Monster:
	var h: Dictionary = SectWar.SECTS[sid]
	var elder := kind != "sect_disciple"
	var mon := Monster.new()
	mon.outfit = h["elder"] if elder else h["disciple"]
	mon.sect_id = sid
	mon.territory_id = tid
	mon.invader = invader
	match kind:
		"sect_master":
			mon.display_name = str(h["master"])
		"sect_elder":
			mon.display_name = "Trưởng lão " + str(h["name"])
		_:
			mon.display_name = "Đệ tử " + str(h["name"])
	mon.setup(m, kind, p)
	m.world.add_child(mon)
	m.monsters.append(mon)
	return mon


## Sinh lính người của một tông quanh center (nd đệ tử + ne trưởng lão). invader: quân xâm lược (hạ hết là bảo vệ được địa bàn).
static func spawn_humanoids(m: Node, sid: String, tid: String, center: Vector2, nd: int, ne: int, invader: bool) -> void:
	for i in nd + ne:
		var tries := 0
		while tries < 60:
			tries += 1
			var p := center + Vector2(m.rng.randf_range(-170, 170), m.rng.randf_range(-110, 110))
			if m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)) or (m.is_safe(p) and sid != SectWar.PLAYER):
				continue
			spawn_one(m, sid, "sect_elder" if i >= nd else "sect_disciple", p, tid, invader)
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


# ---------------------------------------------------------------- Tiên môn: cao nguyên giữa biển mây
const SKY := {
	"meadow": [Color(0.40, 0.62, 0.92), Color(0.86, 0.94, 1.0)],
	"lava": [Color(0.20, 0.06, 0.08), Color(0.78, 0.32, 0.20)],
	"snow": [Color(0.55, 0.72, 0.95), Color(0.95, 0.98, 1.0)],
	"swamp": [Color(0.12, 0.22, 0.20), Color(0.55, 0.72, 0.52)],
	"cave": [Color(0.08, 0.05, 0.18), Color(0.45, 0.30, 0.65)],
}
const CLIFF := {
	"meadow": Color(0.50, 0.50, 0.55), "lava": Color(0.22, 0.17, 0.17), "snow": Color(0.62, 0.70, 0.80),
	"swamp": Color(0.28, 0.34, 0.26), "cave": Color(0.26, 0.22, 0.34),
}


## Ngoài cao nguyên là bầu trời chuyển màu, mép cao nguyên là vách đá gồ ghề có bóng đổ.
static func _paint_sky(img: Image, theme: String, xr: RandomNumberGenerator) -> void:
	var pl: Rect2 = Maps.COMPOUND_PLATEAU
	var w := img.get_width()
	var h := img.get_height()
	var sky: Array = SKY[theme]
	var cliff: Color = CLIFF[theme]
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.012
	var fine := FastNoiseLite.new()
	fine.seed = 78
	fine.frequency = 0.09
	for y in h:
		var sky_col: Color = (sky[0] as Color).lerp(sky[1], clampf(float(y) / h, 0.0, 1.0))
		for x in w:
			var wob := noise.get_noise_2d(x, y) * 70.0
			var dx := minf(x - pl.position.x, pl.end.x - x) + wob
			var dy := minf(y - pl.position.y, pl.end.y - y) + wob
			var inside := minf(dx, dy)
			if inside > 44.0:
				continue
			if inside > 0.0:
				var t := 1.0 - inside / 44.0
				var c := cliff.lerp(Color(0.12, 0.12, 0.16), t * 0.7)
				c = c.lightened(fine.get_noise_2d(x, y) * 0.12)
				if inside < 8.0:
					c = c.darkened(0.25)
				img.set_pixel(x, y, c)
			else:
				var f := fine.get_noise_2d(x * 0.5, y * 0.5) * 0.04
				var sc := sky_col.lightened(f)
				if inside > -34.0:
					sc = sc.darkened(0.3 * (1.0 + inside / 34.0))
				img.set_pixel(x, y, sc)


static func _xt(name: String) -> Texture2D:
	var path := "res://assets/props/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


## Chặn người đi ra ngoài cao nguyên (vực mây).
static func _plateau_blockers(m: Node, size: Vector2) -> void:
	var pl: Rect2 = Maps.COMPOUND_PLATEAU
	m.blockers.append(Rect2(0, 0, size.x, pl.position.y + 12.0))
	m.blockers.append(Rect2(0, pl.end.y - 18.0, size.x, size.y - pl.end.y + 18.0))
	m.blockers.append(Rect2(0, 0, pl.position.x + 12.0, size.y))
	m.blockers.append(Rect2(pl.end.x - 12.0, 0, size.x - pl.end.x + 12.0, size.y))


static func _tienfx(m: Node, d: Dictionary, col: Color, theme: String) -> void:
	var size: Vector2 = d["size"]
	var pl: Rect2 = Maps.COMPOUND_PLATEAU
	var sky := TienFx.new()
	sky.kind = "sky"
	sky.size = size
	sky.plateau = pl
	sky.tint = Color(1, 1, 1) if theme != "cave" and theme != "lava" else Color(0.85, 0.75, 0.95)
	var isle_a := _xt("xt_isle_a")
	var isle_b := _xt("xt_isle_b")
	var spots := [[600.0, 170.0, 0], [1250.0, 120.0, 1], [2350.0, 130.0, 0], [3000.0, 175.0, 1],
		[110.0, 1150.0, 1], [3490.0, 1500.0, 0], [120.0, 2150.0, 0], [3480.0, 880.0, 1]]
	m.layer_ground.add_child(sky)
	for sp in spots:
		var tex: Texture2D = isle_a if int(sp[2]) == 0 else isle_b
		if tex != null:
			sky.add_island(tex, Vector2(sp[0], sp[1]), 0.95, 7.0)
	var mist := TienFx.new()
	mist.kind = "mist"
	mist.size = size
	mist.plateau = pl
	mist.tint = col.lerp(Color.WHITE, 0.55)
	m._map_root.add_child(mist)
	_plateau_blockers(m, size)


# ---------------------------------------------------------------- Tông môn (map riêng)
## Sân lát đá trước từng điện và quảng trường lớn giữa tông môn.
static func _paint_compound_plazas(img: Image, d: Dictionary, xr: RandomNumberGenerator) -> void:
	var tiles := _load_tiles({"tiles": "cobble"})
	var row: String = SectWar.SECTS[d["sect"]]["pave"]
	if (tiles[row] as Array).is_empty():
		return
	var st := _stamps(tiles[row], [1.0], 0.72)
	_fill_ellipse(img, st, Vector2(1800, 2200), 560.0, 200.0, xr)   # quảng trường sơn môn
	_fill_ellipse(img, st, Vector2(1800, 1100), 520.0, 220.0, xr)   # sân chính điện
	for hall in Maps.COMPOUND_HALLS:
		var f: Vector2 = hall["foot"]
		_fill_ellipse(img, st, f + Vector2(0, 40), 250.0 if hall["id"] != "main" else 200.0, 110.0, xr)


static func _recolor(s: Sprite2D, roof: Dictionary) -> void:
	if roof.is_empty():
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/outfit_dye.gdshader")
	mat.set_shader_parameter("hue", float(roof["hue"]))
	mat.set_shader_parameter("sat_mul", float(roof["sat"]))
	mat.set_shader_parameter("val_mul", float(roof["val"]))
	s.material = mat


## Ao sen giữa tông môn có cầu bắc ngang trục chính.
static func _pond(m: Node, c: Vector2, rx: float, ry: float, xr: RandomNumberGenerator) -> void:
	var cell := 4
	var pad := 56.0
	var gw := int((rx + pad) * 2.0 / cell)
	var gh := int((ry + pad) * 2.0 / cell)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.07
	var ripple := FastNoiseLite.new()
	ripple.seed = 17
	ripple.frequency = 0.3
	var img := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	var deep := Color(0.09, 0.40, 0.68)
	var mid := Color(0.13, 0.49, 0.77)
	var shallow := Color(0.27, 0.64, 0.88)
	var shine := Color(0.62, 0.86, 0.97)
	for y in gh:
		for x in gw:
			var wp := Vector2((x + 0.5) * cell - (rx + pad), (y + 0.5) * cell - (ry + pad))
			var dd := Vector2(wp.x / rx, wp.y / ry).length() + noise.get_noise_2d(x, y) * 0.12
			if dd < 1.0:
				var col := deep if dd < 0.5 else (mid if dd < 0.8 else shallow)
				if dd > 0.93:
					col = Color(0.82, 0.75, 0.6)   # bờ cát
				elif ripple.get_noise_2d(x * 0.6, y * 2.2) > 0.5 and dd < 0.85:
					col = shine
				img.set_pixel(x, y, col)
			elif dd < 1.12:
				img.set_pixel(x, y, Color(0.55, 0.52, 0.5))   # bờ đá
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.scale = Vector2.ONE * cell
	spr.position = c - Vector2(rx + pad, ry + pad)
	m.layer_ground.add_child(spr)
	# chặn người đi xuống nước, chừa lối cầu ở giữa
	m.blockers.append(Rect2(c.x - rx * 0.88, c.y - ry * 0.7, rx * 0.88 - 62.0, ry * 1.2))
	m.blockers.append(Rect2(c.x + 62.0, c.y - ry * 0.7, rx * 0.88 - 62.0, ry * 1.2))
	m.no_decor.append(Rect2(c.x - rx - 40, c.y - ry - 60, rx * 2 + 80, ry * 2 + 120))
	var bridge: Sprite2D = m._prop("bridge", Vector2(c.x, c.y + ry + 14.0), Vector2.ZERO, 1.1)
	bridge.z_index = -1
	for i in 7:
		var p := c + Vector2(xr.randf_range(-rx * 0.7, rx * 0.7), xr.randf_range(-ry * 0.5, ry * 0.4))
		if absf(p.x - c.x) > 80.0:
			m._prop("lily", p, Vector2.ZERO, 1.0, xr.randf() < 0.5)


static func _hall_rects(d: Dictionary) -> Array:
	var out: Array = []
	for hall in Maps.COMPOUND_HALLS:
		var f: Vector2 = hall["foot"]
		var sc: float = float(hall.get("sc", 1.3))
		var path := "res://assets/props/%s.png" % hall["prop"]
		var sz := Vector2(300, 260)
		if ResourceLoader.exists(path):
			sz = (load(path) as Texture2D).get_size()
		sz *= sc
		out.append(Rect2(f.x - sz.x * 0.5 - 70.0, f.y - sz.y - 60.0, sz.x + 140.0, sz.y + 200.0))
	return out


static func _compound(m: Node, d: Dictionary, xr: RandomNumberGenerator) -> void:
	var sid: String = d["sect"]
	var h: Dictionary = SectWar.SECTS[sid]
	var col: Color = h["color"]
	var roof: Dictionary = h.get("roof", {})
	var lines: Array = d["path"]
	var rects := _hall_rects(d)
	# sơn môn: cổng lớn nhuộm màu tông (cổng dịch chuyển nằm dưới vòm cổng)
	var gate: Sprite2D = m._prop("sect_gate", Maps.COMPOUND_GATE + Vector2(0, 30), Vector2(180, 24), 1.15, false, col.lerp(Color.WHITE, 0.55))
	gate.z_index = 0
	m.no_decor.append(Rect2(Maps.COMPOUND_GATE.x - 220, Maps.COMPOUND_GATE.y - 240, 440, 300))
	# tường rào hai bên sơn môn
	var fy := Maps.COMPOUND_GATE.y + 30.0
	for x in range(110, 3500, 100):
		if absf(float(x) - Maps.COMPOUND_GATE.x) < 230.0:
			continue
		m._prop("fence_c", Vector2(x, fy), Vector2(98, 14))
	_pond(m, Vector2(1800, 1650), 360.0, 82.0, xr)
	# các điện
	for hall in Maps.COMPOUND_HALLS:
		var f: Vector2 = hall["foot"]
		var path := "res://assets/props/%s.png" % hall["prop"]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var sc: float = float(hall.get("sc", 1.3))
		var bw: float = tex.get_width() * sc * 0.82
		var s: Sprite2D = m._prop(str(hall["prop"]), f, Vector2(bw, 70.0), sc)
		_recolor(s, roof)
		m.atmo.add_light(f + Vector2(0, -60), Color(1.0, 0.82, 0.55), 2.2, 0.6)
		var l := Label.new()
		l.text = str(hall["name"])
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(300, 0)
		l.position = f + Vector2(-150, -tex.get_height() * sc - 34.0)
		l.z_index = 150
		m.world.add_child(l)
	# công trình đặc trưng của tông địch (lò rèn, tháp băng, chòi độc, đàn tế)
	var sig_path := "res://assets/props/sig_%s.png" % sid
	if sid != SectWar.PLAYER and ResourceLoader.exists(sig_path):
		var st: Texture2D = load(sig_path)
		for sp in [Vector2(1290, 1700), Vector2(2310, 1700)]:
			m._prop("sig_" + sid, sp, Vector2(st.get_width() * 1.2, 60.0), 1.5)
			m.atmo.add_light(sp + Vector2(0, -90), col, 2.0, 0.7)
	# đình, đèn lồng dọc trục chính, cờ hiệu tông
	for pp in [Vector2(520, 1620), Vector2(3080, 1620)]:
		if ResourceLoader.exists("res://assets/props/pavilion.png"):
			var pv: Sprite2D = m._prop("pavilion", pp, Vector2(150, 40), 1.4)
			_recolor(pv, roof)
	_tien_architecture(m, d, xr, col, roof)
	var yy := 2350.0
	while yy > 1150.0:
		for sx in [-140.0, 140.0]:
			var lp := Vector2(1800.0 + sx, yy)
			if absf(yy - 1650.0) < 130.0:
				continue
			m._prop("lantern", lp, Vector2(14, 8))
			m.atmo.add_light(lp + Vector2(0, -80), Color(1.0, 0.8, 0.5), 1.3, 0.55)
		yy -= 200.0
	for bp in [Vector2(1560, 2290), Vector2(2040, 2290), Vector2(1560, 1180), Vector2(2040, 1180)]:
		_banner(m, bp, col)
	for sx in [-190.0, 190.0]:
		if ResourceLoader.exists("res://assets/props/stone_lion.png"):
			m._prop("stone_lion", Maps.COMPOUND_GATE + Vector2(sx, -60.0), Vector2(40, 14), 1.4)
	# cây cối / cảnh theo chủ đề của tông, né các điện, ao và đường
	var plazas: Array = [[Vector2(1800, 2200), 560.0, 200.0], [Vector2(1800, 1100), 520.0, 220.0]]
	for hall in Maps.COMPOUND_HALLS:
		plazas.append([(hall["foot"] as Vector2) + Vector2(0, 40), 250.0, 110.0])
	var extra_rects: Array = [Rect2(1360, 400, 880, 420), Rect2(1450, 1980, 700, 220), Rect2(1380, 2200, 840, 200), Rect2(1140, 1130, 1320, 240)]
	var clear := func(p: Vector2) -> bool:
		if not Maps.COMPOUND_PLATEAU.grow(-110.0).has_point(p):
			return false
		for r in rects:
			if (r as Rect2).has_point(p):
				return false
		for r in extra_rects:
			if (r as Rect2).has_point(p):
				return false
		if Rect2(1380, 1500, 840, 300).has_point(p) or _path_dist(p, lines) < 100.0 or p.distance_to(Maps.COMPOUND_GATE) < 300.0:
			return false
		for e in plazas:   # sân lát đá và sân trước từng điện: không mọc cây
			if Vector2((p.x - e[0].x) / (float(e[1]) + 40.0), (p.y - e[0].y) / (float(e[2]) + 40.0)).length() < 1.0:
				return false
		return not m._is_blocked(Rect2(p.x - 50, p.y - 40, 100, 50))
	_place_theme_props(m, d, xr, str(h["theme"]), Vector2(1800, 1450), 1700.0, 1250.0, lines, 5.0, clear)
	_tienfx(m, d, col, str(h["theme"]))
	if sid == SectWar.PLAYER:
		_compound_npcs(m)
	else:
		_compound_hostiles(m, sid)


## Kiến trúc tiên môn: đại môn, nhị môn, tháp chín tầng giữa mây, đỉnh đồng, tiên hạc, kiếm bia, đào tiên, đèn linh, tháp ngọc.
static func _tien_architecture(m: Node, d: Dictionary, xr: RandomNumberGenerator, col: Color, roof: Dictionary) -> void:
	var cyan := Color(0.5, 0.9, 1.0)
	var pl := _xt("xt_pailou")
	if pl != null:
		var s: Sprite2D = m._prop("xt_pailou", Vector2(1800, 2400), Vector2.ZERO, 1.25, false)
		_recolor(s, roof)
		var half := pl.get_width() * 1.25 * 0.5
		m.blockers.append(Rect2(1800 - half, 2370, half - 105.0, 36))
		m.blockers.append(Rect2(1800 + 105.0, 2370, half - 105.0, 36))
		m.atmo.add_light(Vector2(1800, 2300), cyan, 3.0, 0.8)
		m.no_decor.append(Rect2(1800 - half, 2150, half * 2, 300))
	var ig := _xt("xt_inner_gate")
	if ig != null:
		var s2: Sprite2D = m._prop("xt_inner_gate", Vector2(1800, 2040), Vector2.ZERO, 1.1, false)
		_recolor(s2, roof)
		var half2 := ig.get_width() * 1.1 * 0.5
		m.blockers.append(Rect2(1800 - half2, 2015, half2 - 70.0, 30))
		m.blockers.append(Rect2(1800 + 70.0, 2015, half2 - 70.0, 30))
	_put(m, "xt_sky_tower", Vector2(1800, 640), Vector2(120, 50), 1.25, cyan)
	for sx in [-1.0, 1.0]:
		_put(m, "xt_stupa", Vector2(1800 + sx * 980.0, 1260), Vector2(34, 14), 1.4, cyan)
		_put(m, "xt_huabiao", Vector2(1800 + sx * 330.0, 2330), Vector2(30, 14), 1.3)
		_put(m, "xt_crane", Vector2(1800 + sx * 560.0, 2290), Vector2(110, 16), 1.2)
		_put(m, "xt_ding", Vector2(1800 + sx * 250.0, 1210), Vector2(80, 20), 1.1, cyan)
		_put(m, "xt_peach", Vector2(1800 + sx * 1480.0, 1010), Vector2(40, 18), 1.2, Color(1.0, 0.6, 0.8))
		_put(m, "xt_peach", Vector2(1800 + sx * 1120.0, 760), Vector2(40, 18), 1.0, Color(1.0, 0.6, 0.8))
	_put(m, "xt_sword", Vector2(1300, 2290), Vector2(70, 18), 1.3, cyan)
	_put(m, "xt_sword", Vector2(2300, 2290), Vector2(70, 18), 1.3, cyan)
	for hall in Maps.COMPOUND_HALLS:
		if hall["id"] == "main":
			continue
		var f: Vector2 = hall["foot"]
		for sx in [-1.0, 1.0]:
			_put(m, "xt_lamp", f + Vector2(sx * 190.0, 70), Vector2(20, 10), 1.1, cyan)


static func _put(m: Node, name: String, foot: Vector2, block: Vector2, sc: float, glow := Color(0, 0, 0, 0)) -> void:
	var tex := _xt(name)
	if tex == null:
		return
	m._prop(name, foot, block, sc, false)
	if glow.a > 0.0:
		m.atmo.add_light(foot + Vector2(0, -tex.get_height() * sc * 0.4), glow, 1.6 + sc, 0.7)


## Chức năng từng điện của Kiếm Tông: mỗi điện có một người phụ trách (hoặc vật thể) ở cửa.
static func _compound_npcs(m: Node) -> void:
	var halls := {}
	for hall in Maps.COMPOUND_HALLS:
		halls[hall["id"]] = hall["foot"]
	var door := func(id: String, off := Vector2(0, 70)) -> Vector2: return (halls[id] as Vector2) + off
	m._spawn_npc("sect_head", "Chưởng môn Thanh Huyền", {"hair": "hair_long_silver", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black"}, door.call("main", Vector2(0, 60)))
	m._spawn_npc("sect_keeper", "Chấp sự Mộ Dung", {"hair": "hair_ponytail_black", "clothes": "outfit_thanh", "shoes": "shoes_boot_black"}, door.call("treasure"))
	m._spawn_npc("scripture_elder", "Trưởng lão Tàng Kinh", {"hair": "hair_long_silver", "clothes": "outfit_xam", "shoes": "shoes_cloth_white"}, door.call("library"))
	m._spawn_npc("war_elder", "Trưởng lão Chiến Sự", {"hair": "hair_topknot_silver", "clothes": "outfit_do", "shoes": "shoes_boot_black", "sword": "sword_black"}, door.call("war"))
	m._spawn_npc("array_master", "Trận pháp sư Vân Cơ", {"hair": "hair_ponytail_black", "clothes": "outfit_tim", "shoes": "shoes_boot_black", "head": "head_pin_jade"}, door.call("array"))
	m._spawn_npc("tailor", "Y quán chủ Tô Nương", {"hair": "hair_ponytail_brown", "clothes": "outfit_lam", "dye": "dye_green", "shoes": "shoes_boot_black"}, door.call("tailor"))
	# lò luyện đan cạnh Luyện Đan Phòng
	var fu := Furnace.new()
	fu.position = door.call("alchemy", Vector2(190, 60))
	m.world.add_child(fu)
	m.furnace = fu
	m.blockers.append(Rect2(fu.position.x - 24, fu.position.y - 16, 48, 18))
	# bù nhìn ở Diễn Võ Đường
	for off in [Vector2(-250, 100), Vector2(-130, 150), Vector2(0, 175), Vector2(130, 150), Vector2(250, 100)]:
		var dm: TrainingDummy = preload("res://scripts/dummy.gd").new()
		dm.position = (halls["training"] as Vector2) + off
		m.world.add_child(dm)
		m.blockers.append(Rect2(dm.position.x - 18, dm.position.y - 14, 36, 16))
		dm.got_hit.connect(m._on_dummy_hit)


## Tông địch: tông chủ ngồi ở chính điện, trưởng lão và đệ tử canh các điện.
static func _compound_hostiles(m: Node, sid: String) -> void:
	var halls := {}
	for hall in Maps.COMPOUND_HALLS:
		halls[hall["id"]] = hall["foot"]
	spawn_one(m, sid, "sect_master", (halls["main"] as Vector2) + Vector2(0, 90))
	for id in ["library", "war", "treasure", "alchemy"]:
		spawn_one(m, sid, "sect_elder", (halls[id] as Vector2) + Vector2(0, 110))
	for id in ["main", "library", "war", "treasure", "alchemy", "training", "array", "meditation", "tailor"]:
		var f: Vector2 = halls[id]
		for off in [Vector2(-130, 120), Vector2(130, 120)]:
			if id == "training" or id == "array":
				if off.x < 0.0:
					continue   # hai điện ngoài cùng gần cổng: chỉ một lính, để người chơi có chỗ lùi
			var p: Vector2 = f + off
			if m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)):
				continue
			spawn_one(m, sid, "sect_disciple", p)


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
static func gate_visual(m: Node, g: Dictionary, labeled := false) -> void:
	var pos: Vector2 = g["pos"]
	var tint: Color = g.get("tint", Color(0.7, 0.9, 1.0))
	if labeled:
		var l := Label.new()
		l.text = str(g["label"])
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.5))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(240, 0)
		l.position = pos + Vector2(-120, -62)
		l.z_index = 150
		m.world.add_child(l)
	var glow := GateGlow.new()
	glow.tint = tint
	glow.position = pos
	m.layer_ground.add_child(glow)
	m.atmo.add_light(pos, tint, 0.9, 0.8, "always")
	m.no_decor.append(Rect2(pos.x - 60, pos.y - 40, 120, 80))
