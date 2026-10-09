extends Node2D
## Nhân vật 8 hướng (south, south-east, east, north-east, north, north-west, west, south-west).
## Tên animation: <hành động>_<hướng>, ví dụ idle_south, walk_north-east. Gốc chân ở (0,0).
## Các lớp HairBack / Clothes / Shoes / HairFront dùng cùng tên animation với thân (nếu có SpriteFrames).
@onready var body: AnimatedSprite2D = $Body
@onready var layers: Array[AnimatedSprite2D] = [$HairBack, $Clothes, $Shoes, $HairFront]
# Nhân với tốc độ khung hình gốc của từng animation
const ANIM_SPEED := {"walk": 1.0, "run": 0.9}
var _oneshot_key := ""
var facing := "south"
var mirrored := false   # giữ lại cho tương thích: nhân vật mới có đủ hướng nên không còn lật hình

func _ready() -> void:
	body.frame_changed.connect(_sync_layers)
	set_motion("idle", "south")

## direction: tên la bàn ("south-east") hoặc tên cũ ("front", "back", "left", "right").
func set_motion(action: String, direction: String) -> void:
	if _oneshot_key != "":
		return
	facing = Dir.normalize(direction)
	var key := action + "_" + facing
	if body.sprite_frames.has_animation(key):
		body.play(key)
	body.speed_scale = ANIM_SPEED.get(action, 1.0)
	_sync_layers()

func _sync_layers() -> void:
	for layer in layers:
		if layer.sprite_frames != null and layer.sprite_frames.has_animation(body.animation):
			layer.animation = body.animation
			layer.set_frame_and_progress(body.frame, body.frame_progress)
			layer.visible = true
		else:
			layer.visible = false


## Animation phát một lần (ra chiêu, nhảy...). Trong lúc phát, set_motion bị bỏ qua.
## Trả về false nếu chưa có animation đó cho hướng này.
func play_oneshot(action: String, direction: String, speed := 1.0) -> bool:
	var key := action + "_" + Dir.normalize(direction)
	if not has_motion(action, direction):
		return false
	facing = Dir.normalize(direction)
	body.speed_scale = speed
	_oneshot_key = key
	body.play(key)
	body.set_frame_and_progress(0, 0.0)
	if not body.animation_finished.is_connected(_on_oneshot_done):
		body.animation_finished.connect(_on_oneshot_done)
	_sync_layers()
	return true

## Animation vung kiếm vẽ cả người: chỉ phát khi bộ đang mặc có sẵn khung slash (thân trần bên dưới không có áo nên không được hiện ra).
const SKIN_ONLY := ["slash"]

func has_motion(action: String, direction: String) -> bool:
	var key := action + "_" + Dir.normalize(direction)
	if not body.sprite_frames.has_animation(key):
		return false
	if action in SKIN_ONLY:
		var clothes: AnimatedSprite2D = layers[1]
		return clothes.sprite_frames != null and clothes.sprite_frames.has_animation(key)
	return true

func is_busy() -> bool:
	return _oneshot_key != ""

func _on_oneshot_done() -> void:
	_oneshot_key = ""
	set_motion("idle", facing)
