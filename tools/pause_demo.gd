extends SceneTree
## Chup menu tam dung: Godot_console.exe --path . --script res://tools/pause_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 140

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.slot_paths = ["user://nope_0.json", "user://nope_1.json", "user://nope_2.json", "user://nope_3.json"]
		main.pause_menu.open_menu()
	if frame == 35:
		main.pause_menu._go("save")
	if frame == 65:
		main.pause_menu._go("load")
	if frame == 95:
		main.pause_menu._go("keys")
	return false