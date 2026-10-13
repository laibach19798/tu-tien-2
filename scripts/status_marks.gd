extends Node2D
class_name StatusMarks
## Biểu tượng trạng thái nổi trên đầu mục tiêu (V1): dấu ấn, chảy máu, thiêu đốt, hàn khí, phá giáp, suy yếu.
## Người chơi: các buff (Hộ Thể, Thừa Thế, Hồi Nguyên, Bất Khuất) nhỏ hơn, nổi phía trên đầu.
## Dữ liệu lấy thẳng từ engine.statuses nên chiêu mới có trạng thái cũ là tự có biểu tượng.
## Mỗi biểu tượng là một ảnh pixel-art 16x16 (viền đen 1px, ba mức sáng, một điểm chói) sinh một lần từ hình + màu.

const Data = preload("res://scripts/v1/catalog.gd")

const ENEMY := {
	"kiem_an": [Color(0.50, 0.85, 1.0), "seal_sword"],
	"hon_an": [Color(0.78, 0.50, 1.0), "seal_soul"],
	"bleed": [Color(0.92, 0.14, 0.20), "drop"],
	"burn": [Color(1.0, 0.55, 0.12), "flame"],
	"slow": [Color(0.60, 0.88, 1.0), "snow"],
	"armor_break": [Color(0.80, 0.80, 0.90), "shield_crack"],
	"weaken": [Color(0.85, 0.60, 0.35), "arrow_down"],
}
const SELF := {
	"guard": [Color(0.50, 0.85, 1.0), "shield"],
	"surge": [Color(1.0, 0.82, 0.30), "star"],
	"discount": [Color(0.45, 0.70, 1.0), "drop"],
	"steadfast": [Color(0.95, 0.95, 1.0), "diamond"],
}
const N := 16                # cạnh ảnh biểu tượng (px)
const GAP := 3.0

static var _tex: Dictionary = {}

var engine: Object
var nodes: Dictionary
var main: Node
var _t := 0.0


func _ready() -> void:
	z_index = 115
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if engine == null or main == null:
		return
	for id in engine.statuses:
		var held: Dictionary = engine.statuses[id]
		if held.is_empty():
			continue
		var node: Node2D = null
		var mine := str(id) == "player"
		if mine:
			node = main.player
		else:
			node = nodes.get(id) as Node2D
		if not is_instance_valid(node):
			continue
		if not mine and node.get("alive") == false:
			continue
		var table: Dictionary = SELF if mine else ENEMY
		var shown: Array = []
		for sid in held:
			if table.has(sid):
				shown.append(sid)
		if shown.is_empty():
			continue
		shown.sort()
		var top := -90.0 if mine else _top_offset(node)
		var base: Vector2 = (to_local(node.global_position) + Vector2(0, top)).floor()
		var total := shown.size() * (N + GAP) - GAP
		var x := floorf(base.x - total * 0.5)
		for i in shown.size():
			var sid: String = shown[i]
			var st: Dictionary = held[sid]
			var entry: Array = table[sid]
			var col: Color = entry[0]
			var left := float(st.get("remaining", 1.0)) / maxf(0.1, float(Data.data().statuses[sid].get("duration", 1.0)))
			var blink := left > 0.25 or int(_t * 8.0) % 2 == 0
			var bob := floorf(sin(_t * 3.0 + float(i) * 1.3) * 1.5 + 0.5)
			var pos := Vector2(x, base.y + bob)
			if blink:
				draw_texture(_icon(str(entry[1]), col), pos)
			# thanh thời gian còn lại + chấm tầng (pixel)
			var by := pos.y + N + 1.0
			draw_rect(Rect2(x, by, N, 3), Color(0.04, 0.04, 0.08, 0.95))
			draw_rect(Rect2(x + 1.0, by + 1.0, floorf((N - 2.0) * clampf(left, 0.0, 1.0)), 1), col.lightened(0.15))
			var stacks := int(st.get("stacks", 1))
			if stacks > 1:
				for p in mini(stacks, 5):
					draw_rect(Rect2(x + 1.0 + float(p) * 3.0, pos.y - 4.0, 2, 2), Color(0.04, 0.04, 0.08))
					draw_rect(Rect2(x + 1.0 + float(p) * 3.0, pos.y - 4.0, 2, 1), col.lightened(0.35))
					draw_rect(Rect2(x + 1.0 + float(p) * 3.0, pos.y - 3.0, 2, 1), col)
			x += N + GAP


## Độ cao phía trên đầu: dưới thanh máu của quái (kind.bar), mặc định cho mộc nhân và vật thể khác.
func _top_offset(node: Node2D) -> float:
	var kind = node.get("kind")
	if kind is Dictionary and (kind as Dictionary).has("bar"):
		return float((kind as Dictionary)["bar"]) - 22.0
	return -80.0


# ---------------------------------------------------------------- sinh ảnh pixel-art
static func _icon(shape: String, col: Color) -> Texture2D:
	var key := "%s|%s" % [shape, col.to_html(false)]
	if _tex.has(key):
		return _tex[key]
	var dark := col.darkened(0.45)
	var mid := col
	var light := col.lerp(Color.WHITE, 0.5)
	var outline := Color(0.05, 0.04, 0.09)
	var mask: Array = []
	for y in N:
		var row: Array = []
		for x in N:
			row.append(_inside(shape, (float(x) + 0.5 - N * 0.5) / (N * 0.5), (float(y) + 0.5 - N * 0.5) / (N * 0.5)))
		mask.append(row)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in N:
		for x in N:
			if mask[y][x]:
				var u := (float(x) + 0.5 - N * 0.5) / (N * 0.5)
				var v := (float(y) + 0.5 - N * 0.5) / (N * 0.5)
				var c := mid
				if shape == "flame":
					c = light if v < -0.1 else (mid if v < 0.45 else dark)
				else:
					var s := u + v
					c = light if s < -0.45 else (dark if s > 0.45 else mid)
				img.set_pixel(x, y, c)
	# chi tiết bên trong (vạch kiếm, mắt hồn, vết nứt, lõi lửa)
	_detail(img, shape, light, dark)
	# viền đen 1px quanh hình
	for y in N:
		for x in N:
			if mask[y][x]:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < N and ny < N and mask[ny][nx]:
					near = true
			if near:
				img.set_pixel(x, y, outline)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static func _inside(shape: String, u: float, v: float) -> bool:
	match shape:
		"diamond", "seal_sword", "seal_soul":
			return absf(u) + absf(v) <= 0.82
		"drop":
			if u * u + (v - 0.28) * (v - 0.28) <= 0.40 * 0.40 + 0.01:
				return true
			return v >= -0.82 and v < 0.28 and absf(u) <= (v + 0.82) * 0.42
		"flame":
			# thân giọt nước lệch, ngọn nhọn cong sang phải, một lưỡi phụ bên trái
			if u * u + (v - 0.30) * (v - 0.30) <= 0.46 * 0.46:
				return true
			if v >= -0.85 and v < 0.30 and absf(u - 0.10 * (v + 0.85)) <= (v + 0.85) * 0.40:
				return true
			return v >= -0.35 and v < 0.35 and absf(u + 0.38) <= (v + 0.35) * 0.30
		"snow":
			for a in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var dist := absf(-sin(a) * u + cos(a) * v)
				var along := absf(cos(a) * u + sin(a) * v)
				if dist <= 0.13 and along <= 0.85:
					return true
			return false
		"shield", "shield_crack":
			var inside := v >= -0.78 and v <= 0.12 and absf(u) <= 0.70
			if v > 0.12 and v <= 0.85:
				inside = absf(u) <= 0.70 * (0.85 - v) / 0.73
			if shape == "shield_crack" and inside:
				# vết nứt chéo từ mép trên xuống
				if absf(u - (-0.25 + 0.35 * (v + 0.78) / 1.6)) <= 0.075 and v > -0.78 and v < 0.55:
					return false
			return inside
		"arrow_down":
			if v >= -0.80 and v <= 0.05 and absf(u) <= 0.26:
				return true
			return v > 0.05 and v <= 0.85 and absf(u) <= 0.78 * (0.85 - v) / 0.80
		"star":
			return pow(absf(u), 0.62) + pow(absf(v), 0.62) <= 0.92
	return false


static func _detail(img: Image, shape: String, light: Color, dark: Color) -> void:
	var c := N / 2
	match shape:
		"seal_sword":
			for y in range(c - 4, c + 4):
				_put(img, c - 1, y, Color.WHITE)
			_put(img, c - 2, c - 1, light)
			_put(img, c, c - 1, light)
		"seal_soul":
			for p in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				_put(img, c + p.x, c + p.y, Color.WHITE)
			for p in [Vector2i(-3, 0), Vector2i(2, 0), Vector2i(-1, -3), Vector2i(-1, 2)]:
				_put(img, c + p.x, c + p.y, dark)
		"flame":
			for p in [Vector2i(-1, 4), Vector2i(0, 4), Vector2i(-1, 3), Vector2i(0, 3), Vector2i(0, 2)]:
				_put(img, c + p.x, c + p.y, Color(1.0, 0.95, 0.6))
		"drop":
			_put(img, c - 2, c + 1, Color.WHITE)
			_put(img, c - 2, c + 2, Color.WHITE)
		"star":
			_put(img, c - 1, c - 1, Color.WHITE)
			_put(img, c, c - 1, Color.WHITE)
			_put(img, c - 1, c, Color.WHITE)
			_put(img, c, c, Color.WHITE)
		"diamond":
			_put(img, c - 1, c - 1, Color.WHITE)
			_put(img, c, c - 1, Color.WHITE)
		"shield":
			for y in range(c - 5, c + 2):
				_put(img, c - 1, y, light)
				_put(img, c, y, light)
		"snow":
			_put(img, c - 1, c - 1, Color.WHITE)
			_put(img, c, c, Color.WHITE)
		"arrow_down":
			_put(img, c - 1, c - 5, light)
			_put(img, c, c - 5, light)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < N and y < N and img.get_pixel(x, y).a > 0.0:
		img.set_pixel(x, y, c)
