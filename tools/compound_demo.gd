extends SceneTree
## Chụp các tông môn: Godot_console.exe --path . --script res://tools/compound_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 280
var main: Node
var frame := 0
const SHOTS := [
	[40, "sect_kiem_tong", Vector2(1800, 2480)],
	[70, "sect_kiem_tong", Vector2(1800, 2150)],
	[100, "sect_kiem_tong", Vector2(1800, 1330)],
	[130, "sect_kiem_tong", Vector2(1800, 800)],
	[160, "sect_kiem_tong", Vector2(500, 600)],
	[190, "sect_kiem_tong", Vector2(3250, 1500)],
	[220, "sect_xich_viem", Vector2(1800, 1330)],
	[250, "sect_huyen_minh", Vector2(1800, 2150)],
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
