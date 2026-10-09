extends RefCounted
class_name SkinLibrary
## Dựng SpriteFrames của một skin từ các spritesheet PNG theo quy ước tên file, không cần file .tres.
## Thêm skin mới = bỏ PNG vào character/hd/fashion/, đặt tên <tiền_tố>_<kiểu>_<hành_động>.png.
## Mỗi sheet: 8 hàng theo thứ tự Dir.ALL, mỗi hàng là các frame của một hướng. Số frame lấy từ chiều rộng ảnh.

const FASHION_DIR := "res://character/hd/fashion/"

# hành động -> kích thước ô, tốc độ, lặp
const ANIMS := {
	"idle": {"cell": 64, "fps": 4.0, "loop": true},
	"walk": {"cell": 64, "fps": 10.0, "loop": true},
	"run": {"cell": 64, "fps": 14.0, "loop": true},
	"jump": {"cell": 64, "fps": 12.0, "loop": false},
	"slash": {"cell": 96, "fps": 14.0, "loop": false},
}

static var _cache := {}


## base: "<tiền_tố>_<kiểu>" như "clothes_robe"; thử thêm bản bỏ tiền_tố ("robe") cho kiểu đặt tên cũ như plb_navy_walk.png.
## Trả null nếu không có sheet nào.
static func build(prefix: String, style: String) -> SpriteFrames:
	var key := prefix + "_" + style
	if _cache.has(key):
		return _cache[key]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for action in ANIMS:
		var tex := _find_sheet([key, style], action)
		if tex != null:
			_add_action(frames, action, tex)
	if frames.get_animation_names().is_empty():
		frames = null
	_cache[key] = frames
	return frames


static func _find_sheet(bases: Array, action: String) -> Texture2D:
	for b in bases:
		var path: String = FASHION_DIR + "%s_%s.png" % [b, action]
		if ResourceLoader.exists(path):
			return load(path)
	return null


static func _add_action(frames: SpriteFrames, action: String, tex: Texture2D) -> void:
	var def: Dictionary = ANIMS[action]
	var cell: int = def["cell"]
	var cols := int(tex.get_width() / cell)
	for row in Dir.ALL.size():
		if (row + 1) * cell > tex.get_height():
			break
		var anim := StringName(action + "_" + Dir.ALL[row])
		frames.add_animation(anim)
		frames.set_animation_speed(anim, def["fps"])
		frames.set_animation_loop(anim, def["loop"])
		for col in cols:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * cell, row * cell, cell, cell)
			frames.add_frame(anim, at)
