extends SceneTree
## Quay thử hiệu ứng skill bằng bộ quay phim của Godot (cần cửa sổ đồ hoạ, không chạy --headless):
##   Godot_console.exe --path . --script res://tools/vfx_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 330
## Không ghi đè file lưu thật.

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			main.school.joined = true
			main.cult.realm = 2
			main.cult.layer = 1
			main.cult.qi = 9999.0
			main.player.position = Vector2(880, 1215)
			main.direction = "right"
		20: main.school.cast(0)
		32: main.school.cast(0)
		44: main.school.cast(0)
		84: main.school.cast(1)
		140: main.school.cast(2)
		200: main.school.cast(3)
	main.cult.qi = 9999.0
	for k in main.school._cd.size():
		if frame != 20 and frame != 32 and frame != 44 and frame != 84 and frame != 140 and frame != 200:
			main.school._cd[k] = 0.0
	return false
