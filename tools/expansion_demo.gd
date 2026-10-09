extends SceneTree
## Chup cac vung moi: Godot_console.exe --path . --script res://tools/expansion_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 150

const SPOTS := [Vector2(1290, 2380), Vector2(1290, 2640), Vector2(2980, 960), Vector2(3560, 700), Vector2(3300, 2350), Vector2(3000, 1150), Vector2(3560, 2420)]
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.atmo.t = 0.5
		main.debug_peaceful = true
		main.vitals.god = true
	if frame >= 5 and (frame - 5) % 20 == 0:
		var i := ((frame - 5) / 20) % SPOTS.size()
		main.player.position = SPOTS[i]
		main.camera.position = SPOTS[i]
	return false