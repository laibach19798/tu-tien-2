extends CanvasLayer
class_name Minimap
## Bản đồ nhỏ: góc phải dưới hiện vùng quanh nhân vật; phím M mở bản đồ toàn làng.
## Ảnh nền được vẽ một lần từ dữ liệu thế giới (đường đi, nhà, cây, ao...), 1 điểm ảnh = 8 điểm thế giới.

const PX := 8.0               # điểm thế giới / điểm ảnh bản đồ
const PAD := 32               # viền đệm quanh ảnh (điểm ảnh) để vùng nhìn gần mép bản đồ vẫn hợp lệ
const LOCAL_PX := 66          # số điểm ảnh bản đồ hiện trong ô nhỏ
const LOCAL_SCALE := 3.0      # điểm màn hình / điểm ảnh bản đồ (số nguyên để giữ nét pixel)
const FULL_SCALE := 1.5

const GROUND := Color(0.36, 0.58, 0.38)
const GROUND_2 := Color(0.33, 0.54, 0.35)
const ROAD := Color(0.83, 0.72, 0.52)
const ROAD_EDGE := Color(0.70, 0.58, 0.39)
const WATER := Color(0.30, 0.55, 0.78)
const FOREST := Color(0.16, 0.36, 0.24)
const FOREST_HI := Color(0.24, 0.48, 0.30)

# tên khu vực: [tâm, bán kính, tên]
const AREAS := [
	[Vector2(1280, 900), 330.0, "Quảng trường"],
	[Vector2(1050, 1220), 200.0, "Sân luyện kiếm"],
	[Vector2(1620, 1160), 210.0, "Khu chợ"],
	[Vector2(880, 1090), 150.0, "Tiệm may"],
	[Vector2(1900, 480), 210.0, "Ao sen (linh mạch)"],
	[Vector2(1560, 430), 190.0, "Rừng tre (linh mạch)"],
	[Vector2(2330, 1250), 190.0, "Góc đông nam (linh mạch)"],
	[Vector2(340, 1550), 260.0, "Ruộng rau"],
	[Vector2(330, 760), 280.0, "Vùng sói phía tây"],
	[Vector2(1450, 1620), 280.0, "Vùng sói phía nam"],
	[Vector2(2250, 980), 280.0, "Vùng yêu quái phía đông"],
	[Vector2(520, 430), 280.0, "Vùng yêu quái tây bắc"],
	[Vector2(1290, 2250), 150.0, "Cổng Kiếm Tông"],
	[Vector2(1290, 2500), 330.0, "Sân Kiếm Tông"],
	[Vector2(1290, 2000), 220.0, "Đường lên cổng núi"],
	[Vector2(2980, 820), 190.0, "Trại ẩn sĩ"],
	[Vector2(3650, 580), 260.0, "Hang ổ Hắc Lang Vương"],
	[Vector2(3300, 1250), 170.0, "Suối linh (linh mạch)"],
	[Vector2(3300, 850), 700.0, "Hắc Lâm"],
	[Vector2(3520, 2350), 320.0, "Hang Linh Mạch"],
	[Vector2(420, 2330), 280.0, "Vùng sói phía tây nam"],
	[Vector2(3300, 440), 260.0, "Vùng hắc lang"],
	[Vector2(3650, 1150), 260.0, "Vùng hắc lang nam"],
	[Vector2(3050, 1420), 240.0, "Vùng yêu tướng"],
]

var main: Node
var _tex: ImageTexture
var _img_w := 0
var _img_h := 0
var _local: LocalView
var _full_root: Control
var _full: FullView
var full_open := false
var _full_title: UIKit.Banner


func _ready() -> void:
	layer = 9


func is_full_open() -> bool:
	return full_open


func _areas() -> Array:
	return AREAS if main.current_map == "overworld" else main.map_def["areas"]


func area_name(p: Vector2) -> String:
	var best := "Ngoại ô làng" if main.current_map == "overworld" else str(main.map_def["name"])
	var best_d := INF
	for a in _areas():
		var d: float = p.distance_to(a[0])
		if d < float(a[1]) and d < best_d:
			best = a[2]
			best_d = d
	return best


# ---------------------------------------------------------------- dựng ảnh nền
func build() -> void:
	var extra: bool = main.current_map != "overworld"
	var gw: int = int(main.map_size.x / PX)
	var gh: int = int(main.map_size.y / PX)
	var ground: Color = main.map_def["mm"] if extra else GROUND
	_img_w = gw + PAD * 2
	_img_h = gh + PAD * 2
	var img := Image.create(_img_w, _img_h, false, Image.FORMAT_RGBA8)
	img.fill(FOREST)
	# nền cỏ + đường
	var rm: PackedByteArray = main.road_mask
	var rgw: int = main.road_gw
	var cell: int = main.CELL
	for y in gh:
		for x in gw:
			var h := ((x * 73856093) ^ (y * 19349663)) & 255
			var col := ground.darkened(0.07) if h < 40 else ground
			var mx := int(x * PX / cell)
			var my := int(y * PX / cell)
			var i := my * rgw + mx
			if i < rm.size() and rm[i] == 1:
				col = ROAD
			img.set_pixel(x + PAD, y + PAD, col)
	# viền đường
	var edge := []
	for y in range(1, gh - 1):
		for x in range(1, gw - 1):
			if img.get_pixel(x + PAD, y + PAD) == ROAD:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var c := img.get_pixel(x + PAD + d.x, y + PAD + d.y)
					if c != ROAD and c != ROAD_EDGE:
						edge.append(Vector2i(x + PAD, y + PAD))
						break
	for e in edge:
		img.set_pixelv(e, ROAD_EDGE)
	if extra:   # đường mòn của map phụ
		for pl in main.path_lines:
			var pts: PackedVector2Array = pl["pts"]
			for i in range(pts.size() - 1):
				var steps := int(pts[i].distance_to(pts[i + 1]) / PX)
				for j in steps + 1:
					_disc(img, _px(pts[i].lerp(pts[i + 1], float(j) / maxf(steps, 1.0))), float(pl["w"]) * 0.5 / PX, ROAD)
	# núi quanh Hang Linh Mạch
	for y in range(int((WorldExpansion.CAVE.y - 420.0) / PX), int((WorldExpansion.CAVE.y + 420.0) / PX)):
		for x in range(int((WorldExpansion.CAVE.x - 520.0) / PX), int((WorldExpansion.CAVE.x + 520.0) / PX)):
			if not extra and x >= 0 and y >= 0 and x < gw and y < gh and WorldExpansion.mountain_at(Vector2(x + 0.5, y + 0.5) * PX):
				img.set_pixel(x + PAD, y + PAD, Color(0.50, 0.46, 0.52))
	# ao sen
	var pz: Rect2 = main.pond_zone
	if pz.size.x > 0.0 and not extra:
		var pc := Vector2(pz.get_center())
		for y in range(int(pz.position.y / PX) + PAD - 1, int(pz.end.y / PX) + PAD + 2):
			for x in range(int(pz.position.x / PX) + PAD - 1, int(pz.end.x / PX) + PAD + 2):
				var wp := Vector2((x - PAD) * PX, (y - PAD) * PX)
				if Vector2((wp.x - pc.x) / (pz.size.x * 0.5), (wp.y - pc.y) / (pz.size.y * 0.5)).length() < 0.92 and x >= 0 and y >= 0 and x < _img_w and y < _img_h:
					img.set_pixel(x, y, WATER)
	# vật thể: phẳng trước, cao sau (sắp theo y để chồng đúng)
	var log: Array = main.prop_log.duplicate()
	log.sort_custom(func(a, b): return a["p"].y < b["p"].y)
	for pass_i in 2:
		for e in log:
			var n: String = e["n"]
			var flat: bool = n.begins_with("field") or n == "water" or n == "lily" or n == "bridge"
			if (pass_i == 0) == flat:
				_paint_prop(img, e)
	_tex = ImageTexture.create_from_image(img)
	_tex.set_meta("img", img)
	if _local == null:
		_local = LocalView.new()
		_local.mm = self
		add_child(_local)
		_local.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_local.offset_left = -14.0 - LocalView.SIZE_PX
		_local.offset_top = -14.0 - (LocalView.SIZE_PX + 22.0)
		_local.offset_right = -14.0
		_local.offset_bottom = -14.0
		_build_full()
	_full_title.set_text("Bản Đồ Làng" if main.current_map == "overworld" else "Bản Đồ %s" % str(main.map_def["name"]))
	_full.custom_minimum_size = Vector2((_img_w - PAD * 2) * FULL_SCALE, (_img_h - PAD * 2) * FULL_SCALE)
	_local.queue_redraw()
	_full.queue_redraw()


func _px(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / PX) + PAD, int(p.y / PX) + PAD)


func _rect(img: Image, a: Vector2i, size: Vector2i, col: Color) -> void:
	for y in range(maxi(a.y, 0), mini(a.y + size.y, _img_h)):
		for x in range(maxi(a.x, 0), mini(a.x + size.x, _img_w)):
			img.set_pixel(x, y, col)


func _disc(img: Image, c: Vector2i, r: float, col: Color) -> void:
	for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			if x >= 0 and y >= 0 and x < _img_w and y < _img_h and Vector2(x - c.x, y - c.y).length() <= r:
				img.set_pixel(x, y, col)


func _paint_prop(img: Image, e: Dictionary) -> void:
	var n: String = e["n"]
	var foot: Vector2 = e["p"]
	var w: float = e["w"]
	var h: float = e["h"]
	var c := _px(foot)
	if n.begins_with("house"):
		var base := Color(0.30, 0.44, 0.76) if n.ends_with("blue") else Color(0.78, 0.32, 0.28)
		var pw := int(w * 0.62 / PX)
		var ph := int(h * 0.55 / PX)
		_rect(img, Vector2i(c.x - pw / 2 - 1, c.y - ph - 1), Vector2i(pw + 2, ph + 2), UIKit.BLACK)
		_rect(img, Vector2i(c.x - pw / 2, c.y - ph), Vector2i(pw, ph), base)
		_rect(img, Vector2i(c.x - pw / 2, c.y - ph), Vector2i(pw, 2), base.lightened(0.3))
		_rect(img, Vector2i(c.x - 1, c.y - 3), Vector2i(3, 3), Color(0.36, 0.24, 0.14))
	elif n.begins_with("tree"):
		var r := maxf(w * 0.30 / PX, 2.5)
		_disc(img, c + Vector2i(0, -int(h * 0.38 / PX)), r + 1.0, UIKit.BLACK.lerp(FOREST, 0.5))
		_disc(img, c + Vector2i(0, -int(h * 0.38 / PX)), r, FOREST)
		_disc(img, c + Vector2i(-1, -int(h * 0.38 / PX) - 1), r * 0.5, FOREST_HI)
	elif n.begins_with("cliff"):
		var cw := int(w * 0.7 / PX)
		_rect(img, Vector2i(c.x - cw / 2, c.y - int(h * 0.6 / PX)), Vector2i(cw, int(h * 0.6 / PX)), Color(0.46, 0.45, 0.52))
		_rect(img, Vector2i(c.x - cw / 2, c.y - int(h * 0.6 / PX)), Vector2i(cw, 1), Color(0.66, 0.65, 0.72))
	elif n.begins_with("campfire"):
		_disc(img, c + Vector2i(0, -2), 2.0, Color(1.0, 0.6, 0.2))
	elif n.begins_with("sect_gate"):
		_rect(img, Vector2i(c.x - 14, c.y - 6), Vector2i(29, 6), Color(0.72, 0.2, 0.2))
		_rect(img, Vector2i(c.x - 16, c.y - 9), Vector2i(33, 3), Color(0.18, 0.28, 0.5))
	elif n.begins_with("dead_tree"):
		_disc(img, c + Vector2i(0, -int(h * 0.3 / PX)), 2.2, Color(0.35, 0.3, 0.38))
	elif n.begins_with("bush"):
		_disc(img, c + Vector2i(0, -1), 1.6, FOREST)
	elif n.begins_with("bamboo"):
		_rect(img, c + Vector2i(0, -int(h * 0.5 / PX)), Vector2i(1, int(h * 0.5 / PX)), Color(0.42, 0.7, 0.36))
	elif n.begins_with("stall"):
		_rect(img, c + Vector2i(-6, -7), Vector2i(12, 7), Color(0.55, 0.38, 0.22))
		_rect(img, c + Vector2i(-6, -7), Vector2i(12, 2), Color(0.9, 0.82, 0.62))
	elif n == "well":
		_disc(img, c + Vector2i(0, -3), 4.0, Color(0.55, 0.58, 0.64))
		_disc(img, c + Vector2i(0, -3), 2.0, Color(0.20, 0.30, 0.45))
	elif n.begins_with("rock"):
		_disc(img, c + Vector2i(0, -1), 1.8, Color(0.6, 0.62, 0.68))
	elif n.begins_with("barrel") or n == "table":
		_rect(img, c + Vector2i(-1, -2), Vector2i(3, 2), Color(0.5, 0.34, 0.2))
	elif n.begins_with("field"):
		_rect(img, c + Vector2i(-int(w * 0.45 / PX), -int(h * 0.8 / PX)), Vector2i(int(w * 0.9 / PX), int(h * 0.8 / PX)), Color(0.56, 0.62, 0.30))
	elif n == "water":
		_rect(img, c + Vector2i(-int(w * 0.5 / PX), -int(h / PX)), Vector2i(int(w / PX), int(h / PX)), WATER)
	elif n == "bridge":
		_rect(img, c + Vector2i(-int(w * 0.5 / PX), -int(h / PX)), Vector2i(int(w / PX), int(h / PX)), Color(0.55, 0.4, 0.24))
	elif n.begins_with("fence"):
		_rect(img, c + Vector2i(-5, -1), Vector2i(11, 1), Color(0.48, 0.34, 0.2))
	elif not (n.begins_with("flower") or n.begins_with("reeds") or n.begins_with("snow_mound")):
		_disc(img, c + Vector2i(0, -1), 2.0 if h < 90.0 else 3.0, Color(0.30, 0.38, 0.34) if h >= 90.0 else Color(0.5, 0.52, 0.58))


# ---------------------------------------------------------------- điểm đánh dấu (dùng cho cả hai bản đồ)
## Trả về mảng {p, k, c}: k = player | npc | furnace | herb | monster ; c = màu.
func markers(include_monsters: bool, range_from := Vector2.ZERO, range_r := 0.0) -> Array:
	var out: Array = []
	for n in main.npcs:
		var col := Color(0.95, 0.95, 0.85)
		var mk: String = n._marker.text if n._marker != null and n._marker.visible else ""
		if mk == "!":
			col = Color(1.0, 0.88, 0.2)
		elif mk == "?":
			col = Color(0.4, 1.0, 0.5)
		out.append({"p": n.position, "k": "npc", "c": col, "mk": mk})
	if main.furnace != null:
		out.append({"p": main.furnace.position, "k": "furnace", "c": Color(1.0, 0.6, 0.2)})
	for h in main.herbs:
		if h.available:
			out.append({"p": h.position, "k": "herb", "c": Color(0.5, 1.0, 0.5)})
	if include_monsters:
		for m in main.monsters:
			if m.alive and (range_r <= 0.0 or m.position.distance_to(range_from) < range_r):
				out.append({"p": m.position, "k": "monster", "c": UIKit.RED, "aggro": m.state in ["chase", "windup", "recover"]})
	return out


func _build_full() -> void:
	_full_root = Control.new()
	_full_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full_root.visible = false
	_full_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full_root.add_child(dim)
	var frame := UIKit.Frame.new(Vector2.ZERO)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	_full_root.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	frame.add_child(v)
	_full_title = UIKit.Banner.new("Bản Đồ Làng", 24)
	v.add_child(_full_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	_full = FullView.new()
	_full.mm = self
	h.add_child(_full)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(210, 0)
	side.add_theme_constant_override("separation", 6)
	h.add_child(side)
	side.add_child(UIKit.Banner.new("Chú giải", 18, UIKit.JADE, true))
	for lg in [["player", "Bạn", Color(0.4, 1.0, 0.9)], ["npc", "Người (! ? có nhiệm vụ)", Color(1.0, 0.88, 0.2)], ["furnace", "Lò luyện đan", Color(1.0, 0.6, 0.2)],
			["herb", "Linh thảo", Color(0.5, 1.0, 0.5)], ["monster", "Vùng yêu thú", UIKit.RED], ["zone", "Linh mạch", Color(0.4, 0.9, 1.0)]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.color = lg[2]
		row.add_child(sw)
		row.add_child(UIKit.label(lg[1], 15, UIKit.PAPER))
		side.add_child(row)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(grow)
	side.add_child(UIKit.KeyCap.new("M / Esc", "Đóng", 13))
	var top_layer := CanvasLayer.new()
	top_layer.layer = 20
	add_child(top_layer)
	top_layer.add_child(_full_root)


func toggle_full() -> void:
	full_open = not full_open
	_full_root.visible = full_open
	if full_open:
		_full.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if full_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			toggle_full()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _local != null and main != null and main.player != null:
		_local.queue_redraw()
		if full_open:
			_full.queue_redraw()


## Ô nhỏ ở góc: vùng quanh nhân vật.
class LocalView extends Control:
	var mm: Minimap
	const SIZE_PX := 204.0

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE_PX, SIZE_PX + 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		if mm == null or mm._tex == null or mm.main == null or mm.main.player == null:
			return
		var main: Node = mm.main
		var pc: Vector2 = main.player.position
		var inner := Vector2(3, 3)
		var vs := Minimap.LOCAL_PX * Minimap.LOCAL_SCALE   # 198
		draw_rect(Rect2(0, 0, SIZE_PX, SIZE_PX), UIKit.BLACK)
		draw_rect(Rect2(1, 1, SIZE_PX - 2, SIZE_PX - 2), UIKit.GOLD_DK, false, 2.0)
		var base := pc / Minimap.PX
		var ip := Vector2(floorf(base.x), floorf(base.y))
		var fr := base - ip
		var half := Minimap.LOCAL_PX / 2
		var src := Rect2(ip.x - half + Minimap.PAD, ip.y - half + Minimap.PAD, Minimap.LOCAL_PX + 1, Minimap.LOCAL_PX + 1)
		var dst := Rect2(inner - fr * Minimap.LOCAL_SCALE, (Vector2.ONE * (Minimap.LOCAL_PX + 1)) * Minimap.LOCAL_SCALE)
		# giữ trong ô: clip bằng cách cắt khung hiển thị
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var clip := Rect2(inner, Vector2(vs, vs))
		_draw_clipped(mm._tex, src, dst, clip)
		var k := Minimap.LOCAL_SCALE / Minimap.PX
		var center := inner + Vector2(vs, vs) * 0.5
		# linh mạch: vầng sáng xanh
		for z in main.qi_zones:
			var zc: Vector2 = center + (z["pos"] - pc) * k
			var rx: float = z["r"] * k
			_pixel_ellipse(zc, rx, rx * 0.62, Color(0.4, 0.9, 1.0, 0.22), clip)
		for m in mm.markers(true, pc, 420.0):
			var v: Vector2 = (center + (m["p"] - pc) * k).floor()
			if not clip.grow(-4).has_point(v):
				continue
			_marker(m, v)
		# nhân vật
		var pv := center.floor()
		draw_rect(Rect2(pv - Vector2(4, 4), Vector2(8, 8)), UIKit.BLACK)
		draw_rect(Rect2(pv - Vector2(3, 3), Vector2(6, 6)), Color(0.4, 1.0, 0.9))
		var face: Vector2 = Dir.to_vector(main.direction)
		draw_rect(Rect2(pv + (face * 5.0).round() - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
		# nhãn: hướng bắc + tên khu vực
		var f := get_theme_default_font()
		UIKit.shadow_text(self, f, Vector2(SIZE_PX * 0.5 - 4, 18), "B", 18, UIKit.GOLD)
		var area := mm.area_name(pc)
		draw_rect(Rect2(0, SIZE_PX + 2, SIZE_PX, 20), Color(UIKit.INK, 0.9))
		draw_rect(Rect2(0, SIZE_PX + 2, SIZE_PX, 20), UIKit.BLACK, false, 2.0)
		var tw := f.get_string_size(area, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		UIKit.shadow_text(self, f, Vector2(floorf((SIZE_PX - tw) * 0.5), SIZE_PX + 17), area, 18, UIKit.PAPER)

	func _draw_clipped(tex: Texture2D, src: Rect2, dst: Rect2, clip: Rect2) -> void:
		# phần vùng dst nằm ngoài clip bị cắt: tính lại src tương ứng
		var inter := dst.intersection(clip)
		if inter.size.x <= 0.0 or inter.size.y <= 0.0:
			return
		var sx := src.size.x / dst.size.x
		var sy := src.size.y / dst.size.y
		var s2 := Rect2(src.position.x + (inter.position.x - dst.position.x) * sx, src.position.y + (inter.position.y - dst.position.y) * sy, inter.size.x * sx, inter.size.y * sy)
		draw_texture_rect_region(tex, inter, s2)

	func _pixel_ellipse(c: Vector2, rx: float, ry: float, col: Color, clip: Rect2) -> void:
		var y := -ry
		while y <= ry:
			var half := rx * sqrt(maxf(1.0 - (y * y) / (ry * ry), 0.0))
			var r := Rect2(c.x - half, c.y + y, half * 2.0, 3.0).intersection(clip)
			if r.size.x > 0.0 and r.size.y > 0.0:
				draw_rect(r, col)
			y += 3.0

	func _marker(m: Dictionary, v: Vector2) -> void:
		var col: Color = m["c"]
		match m["k"]:
			"npc":
				draw_rect(Rect2(v - Vector2(4, 4), Vector2(8, 8)), UIKit.BLACK)
				draw_rect(Rect2(v - Vector2(3, 3), Vector2(6, 6)), col)
				if m.get("mk", "") != "":
					var f := get_theme_default_font()
					UIKit.shadow_text(self, f, v + Vector2(-4, -6), str(m["mk"]), 16, col)
			"furnace":
				draw_rect(Rect2(v - Vector2(5, 5), Vector2(10, 10)), UIKit.BLACK)
				draw_rect(Rect2(v - Vector2(4, 4), Vector2(8, 8)), col)
			"herb":
				draw_rect(Rect2(v - Vector2(2, 2), Vector2(4, 4)), col)
			"monster":
				var big: bool = bool(m.get("aggro", false)) and (Time.get_ticks_msec() / 150) % 2 == 0
				var s := 7.0 if big else 5.0
				draw_rect(Rect2(v - Vector2(s * 0.5 + 1, s * 0.5 + 1), Vector2(s + 2, s + 2)), UIKit.BLACK)
				draw_rect(Rect2(v - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), col)


## Bản đồ toàn làng (phím M).
class FullView extends Control:
	var mm: Minimap

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if mm == null or mm._tex == null or mm.main == null or mm.main.player == null:
			return
		var main: Node = mm.main
		var sc := Minimap.FULL_SCALE
		draw_rect(Rect2(-3, -3, size.x + 6, size.y + 6), UIKit.BLACK)
		draw_texture_rect_region(mm._tex, Rect2(Vector2.ZERO, size), Rect2(Minimap.PAD, Minimap.PAD, mm._img_w - Minimap.PAD * 2, mm._img_h - Minimap.PAD * 2))
		draw_rect(Rect2(-1, -1, size.x + 2, size.y + 2), UIKit.GOLD_DK, false, 2.0)
		var k := sc / Minimap.PX
		for z in main.qi_zones:
			_ell(z["pos"] * k, z["r"] * k, z["r"] * k * 0.62, Color(0.4, 0.9, 1.0, 0.25))
		# vùng yêu thú (nhóm quái sinh ra)
		var f := get_theme_default_font()
		for g in main.map_def.get("groups", []):
			var c: Vector2 = g[1] * k
			_ell(c, 170.0 * k, 110.0 * k, Color(UIKit.RED, 0.22))
		for a in mm._areas():
			var nm: String = a[2]
			if main.current_map != "overworld" or nm in ["Quảng trường", "Sân luyện kiếm", "Khu chợ", "Tiệm may", "Ruộng rau", "Ao sen (linh mạch)", "Rừng tre (linh mạch)", "Cổng Kiếm Tông", "Sân Kiếm Tông", "Trại ẩn sĩ", "Hang ổ Hắc Lang Vương", "Hắc Lâm", "Hang Linh Mạch", "Suối linh (linh mạch)"] or nm.begins_with("Vùng"):
				nm = nm.replace(" (linh mạch)", "")
				var pos: Vector2 = a[0] * k
				var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				var col := UIKit.RED.lightened(0.3) if nm.begins_with("Vùng") else UIKit.PAPER
				UIKit.shadow_text(self, f, Vector2(clampf(pos.x - tw * 0.5, 2.0, size.x - tw - 2.0), pos.y), nm, 16, col)
		for m in mm.markers(false):
			var v: Vector2 = (m["p"] * k).floor()
			var col: Color = m["c"]
			draw_rect(Rect2(v - Vector2(4, 4), Vector2(8, 8)), UIKit.BLACK)
			draw_rect(Rect2(v - Vector2(3, 3), Vector2(6, 6)), col)
			if m["k"] == "npc" and m.get("mk", "") != "":
				UIKit.shadow_text(self, f, v + Vector2(-4, -6), str(m["mk"]), 16, col)
		var pv: Vector2 = (main.player.position * k).floor()
		draw_rect(Rect2(pv - Vector2(5, 5), Vector2(10, 10)), UIKit.BLACK)
		var blink := int(Time.get_ticks_msec() / 350) % 2 == 0
		draw_rect(Rect2(pv - Vector2(4, 4), Vector2(8, 8)), Color(0.4, 1.0, 0.9) if blink else Color.WHITE)

	func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var y := -ry
		while y <= ry:
			var half := rx * sqrt(maxf(1.0 - (y * y) / (ry * ry), 0.0))
			var r := Rect2(c.x - half, c.y + y, half * 2.0, 2.0).intersection(Rect2(Vector2.ZERO, size))
			if r.size.x > 0.0 and r.size.y > 0.0:
				draw_rect(r, col)
			y += 2.0
