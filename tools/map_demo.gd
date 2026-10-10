extends SceneTree
## Chụp các map: Godot_console.exe --path . --script res://tools/map_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 200
var main: Node
var frame := 0
const SHOTS := [
	[10, "overworld", Vector2(1280, 1000)],
	[40, "overworld", Vector2(1100, 1200)],
	[70, "overworld", Vector2(1650, 1100)],
	[100, "tuyet_coc", Vector2(380, 1380)],
	[130, "linh_mach_dong", Vector2(500, 800)],
	[160, "tuyet_coc", Vector2(2000, 560)],
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
			main.switch_map_now(s[1], s[2])
			if s[0] == 10:
				main.atmo.t = 0.5
	if frame == 180:
		main.minimap.toggle_full()
	return false
