extends SceneTree
## Quay canh quai vat tan cong: Godot_console.exe --path . --script res://tools/monster_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 240

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.player.position = Vector2(330, 900)
		main.camera.position = main.player.position
		var w: Monster = null
		var g: Monster = null
		for m in main.monsters:
			if m.kind_id == "wolf" and w == null:
				w = m
			if m.kind_id == "goblin" and g == null:
				g = m
		w.position = main.player.position + Vector2(190, 10)
		w.home = w.position
		g.position = main.player.position + Vector2(-210, -30)
		g.home = g.position
	return false