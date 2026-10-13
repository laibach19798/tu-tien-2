extends SceneTree
## Chụp bảng sư môn và sân sinh hoạt, không ghi save.
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
		main.switch_map_now("overworld", Vector2(1290, 2540))
		main.sect_life.from_dict({})
		main.player.position = Vector2(1290, 2540)
		main.camera.position = main.player.position
		main.atmo.t = 0.35
		main.sect_life.open_board()
	if frame == 25:
		root.get_texture().get_image().save_png("res://tools/sect_life_board.png")
		var scroll: ScrollContainer = main.sect_life.body.get_parent()
		scroll.scroll_vertical = 1000
	if frame == 40:
		root.get_texture().get_image().save_png("res://tools/sect_life_board_bottom.png")
		main.sect_life.close_board()
	if frame == 180:
		root.get_texture().get_image().save_png("res://tools/sect_life_courtyard.png")
		print("SECT LIFE SCREENSHOTS SAVED")
		quit()
	return false
