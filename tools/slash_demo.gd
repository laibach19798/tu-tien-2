extends SceneTree
## Phat animation vung kiem o 8 huong de kiem tra: Godot_console.exe --path . --script res://tools/slash_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 240

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
	if frame >= 8 and (frame - 8) % 28 == 0:
		var d: String = Dir.ALL[((frame - 8) / 28) % 8]
		main.direction = d
		var ok: bool = main.player.play_oneshot("slash", d, 1.0)
		print("slash ", d, " -> ", ok)
	return false