extends SceneTree
## Chup ban do nho: Godot_console.exe --path . --script res://tools/minimap_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 100

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.player.position = Vector2(1180, 1010)
		main.camera.position = main.player.position
	if frame == 50:
		main.minimap.toggle_full()
	return false