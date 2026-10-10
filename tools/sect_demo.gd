extends SceneTree
## Chup so tay Kiem Tong: sân Kiem Tong voi Chap su (frame 20) va Tang Bao Cac (frame 60)
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.school.joined = true
		main.quests.states["q8"] = "done"
		main.inv.add_merit(180)
		main.inv.add("yeu_dan", 3)
		main.inv.add("soi_nanh", 4)
		main.player.position = WorldExpansion.SECT_C + Vector2(-60, 20)
		main.camera.position = main.player.position
	if frame == 50:
		main.sect_shop.open_shop()
	return false
