extends SceneTree
## Chụp các tông môn: Godot_console.exe --path . --script res://tools/compound_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 280
var main: Node
var frame := 0
const SHOTS := [
	[40, "sect_kiem_tong", Vector2(1800, 2300)],
	[70, "sect_kiem_tong", Vector2(1800, 1300)],
	[100, "sect_kiem_tong", Vector2(1000, 2150)],
	[130, "sect_kiem_tong", Vector2(2700, 2560)],
	[160, "sect_kiem_tong", Vector2(600, 860)],
	[190, "sect_xich_viem", Vector2(1800, 1760)],
	[220, "sect_doc_mon", Vector2(1800, 1760)],
	[250, "sect_huyen_minh", Vector2(1800, 1100)],
]


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.debug_peaceful = true
	for s in SHOTS:
		if frame == s[0]:
			if main.current_map != s[1]:
				main.switch_map_now(s[1], s[2])
			main.player.position = s[2]
			main.camera.position = s[2]
	return false
