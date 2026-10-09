extends SceneTree
## Chup lo luyen dan va vat pham roi: Godot_console.exe --path . --script res://tools/alch_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 120

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.player.position = Vector2(1130, 1060)
		main.camera.position = main.player.position
		main.inv.add("linh_thao", 7)
		main.inv.add("soi_nanh", 2)
		main.inv.add("yeu_dan", 1)
		for id in ["stone", "soi_nanh", "yeu_dan", "da_yeu"]:
			var l := Loot.new()
			l.setup(main, id, 3 if id == "stone" else 1, main.player.position + Vector2(-90 + ["stone", "soi_nanh", "yeu_dan", "da_yeu"].find(id) * 60, -60))
			main.world.add_child(l)
			l._t = -5.0   # khong tu nhat
	if frame == 60:
		main.alchemy.open_ui()
	return false