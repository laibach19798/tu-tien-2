extends SceneTree
## Kiểm tra đường dùng animation vung kiếm (hướng nhìn ngang): tung cả 4 chiêu và đếm xem hiệu ứng/sát thương có xảy ra.
##   Godot_console.exe --headless --path . --script res://tools/smoke_swing.gd

var main: Node
var frame := 0
var used_anim := {}


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	var p = main.player
	match frame:
		5:
			main.school.joined = true
			main.cult.realm = 2
			main.cult.layer = 1
			p.position = Vector2(880, 1215)
			main.direction = "right"
		10: _cast(0)
		40: _cast(1)
		80: _cast(2)
		130: _cast(3)
		420:
			var hp := 0.0
			for t in get_nodes_in_group("targets"):
				hp += t.hp
			print("=== SMOKE SWING XONG ===")
			print("dung animation vung kiem: ", used_anim)
			print("tong HP muc tieu con lai: %d / 360, busy=%s" % [int(hp), str(p.is_busy())])
			quit(0)
	main.cult.qi = 9999.0
	return false


func _cast(i: int) -> void:
	for k in main.school._cd.size():
		main.school._cd[k] = 0.0
	main.direction = "right"
	main.school.cast(i)
	used_anim[i] = main.player.is_busy()
