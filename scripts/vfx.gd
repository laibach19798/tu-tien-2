extends RefCounted
class_name Vfx
## Hiệu ứng pixel-art dựng sẵn (assets/vfx/<tên>.png + .json, xuất từ Pixellab VFX): một bảng khung hình + anchor.
## Vfx.play(parent, "slash_kiem", pos, rotation) phát một lần rồi tự xoá; hiệu ứng vòng lặp (LOOPS) phát trong `hold` giây.
## Ảnh vẽ hướng sang phải (+x); `rot` xoay theo hướng ra chiêu. `travel` kéo cả hiệu ứng đi một đoạn trong lúc phát (đạn).

const DIR := "res://assets/vfx/"
## Hiệu ứng được xuất dạng vòng lặp: phát đủ `hold` giây rồi mờ đi.
const LOOPS := ["orb_green", "orb_arcane", "swords", "sigil", "water_jet"]

static var _cache: Dictionary = {}


static func has(name: String) -> bool:
	return not _load(name).is_empty()


static func _load(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var out: Dictionary = {}
	var png := DIR + name + ".png"
	var js := DIR + name + ".json"
	if ResourceLoader.exists(png) and FileAccess.file_exists(js):
		var f := FileAccess.open(js, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Dictionary:
			var frames: Array = []
			var durs: Array = []
			for fr in parsed["frames"]:
				var r: Dictionary = fr["frame"]
				frames.append(Rect2(float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"])))
				durs.append(float(fr.get("duration", 80)) / 1000.0)
			var a: Dictionary = (parsed.get("meta", {}) as Dictionary).get("anchor", {"x": 0, "y": 0})
			out = {"tex": load(png), "frames": frames, "durs": durs, "anchor": Vector2(float(a["x"]), float(a["y"]))}
	_cache[name] = out
	return out


## Phát một hiệu ứng. Trả về nút (hoặc null nếu không có tài nguyên → nơi gọi dùng hiệu ứng thủ tục).
static func play(parent: Node, name: String, pos: Vector2, rot := 0.0, hold := 1.0, travel := Vector2.ZERO, flip := false) -> Node2D:
	var d := _load(name)
	if d.is_empty() or parent == null:
		return null
	var c := Clip.new()
	c.data = d
	c.position = pos
	c.rotation = rot
	c.looping = name in LOOPS
	c.hold = hold
	c.travel = travel
	if flip:
		c.scale = Vector2(1, -1)
	parent.add_child(c)
	return c


class Clip extends Node2D:
	var data: Dictionary = {}
	var looping := false
	var hold := 1.0
	var travel := Vector2.ZERO
	var _t := 0.0
	var _frame := 0
	var _ft := 0.0
	var _start := Vector2.ZERO
	var _total := 0.0

	func _ready() -> void:
		z_index = 120
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_start = position
		if looping:
			_total = hold
		else:
			for d in data["durs"]:
				_total += float(d)

	func _process(delta: float) -> void:
		_t += delta
		_ft += delta
		var durs: Array = data["durs"]
		while _ft >= float(durs[_frame]):
			_ft -= float(durs[_frame])
			_frame += 1
			if _frame >= durs.size():
				if looping:
					_frame = 0
				else:
					queue_free()
					return
		if travel != Vector2.ZERO and _total > 0.0:
			position = _start + travel * clampf(_t / _total, 0.0, 1.0)
		if looping:
			if _t >= hold:
				queue_free()
				return
			modulate.a = clampf((hold - _t) / 0.18, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = (data["frames"] as Array)[_frame]
		var a: Vector2 = data["anchor"]
		draw_texture_rect_region(data["tex"], Rect2(-a, r.size), r)
