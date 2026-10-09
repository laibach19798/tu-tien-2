extends SceneTree
## Quay nhân vật quay qua 8 hướng đứng yên (kiểm tra kích thước / mốc chân / bóng):
##   Godot_console.exe --path . --script res://tools/look_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 110

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.player.position = Vector2(1220, 1000)
		main.wardrobe.owned.append("tien_bao")
		main.wardrobe.equip("tien_bao")
		main.wardrobe.equipped["hair"] = "hair_topknot_silver"
		main.wardrobe.changed.emit()
	if frame >= 5:
		main.direction = Dir.ALL[((frame - 5) / 12) % 8]
	return false
