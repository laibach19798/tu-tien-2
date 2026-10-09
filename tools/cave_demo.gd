extends SceneTree
const SPOTS := [Vector2(3300, 2350), Vector2(3520, 2380), Vector2(3520, 2200)]
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