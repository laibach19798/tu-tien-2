extends SceneTree
## Kiem tra luu/tai game va menu tam dung: Godot_console.exe --headless --path . --script res://tools/save_test.gd

var main: Node
var frame := 0
var log: Array[String] = []


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		OS.unset_environment("TUTIEN_NO_SAVE")
		main.slot_paths = ["user://t_auto.json", "user://t_1.json", "user://t_2.json", "user://t_3.json"]
		main.inv.stones = 777
		main.inv.add("yeu_dan", 3)
		main.player.position = Vector2(500, 800)
		main.vitals.hp = 55.0
		main.cult.realm = 2
		main.cult.layer = 4
		log.append("slot 2 truoc khi luu: %s" % str(main.slot_info(2)))
		log.append("luu: %s" % str(main.save_to_slot(2)))
		log.append("slot 2 sau khi luu: %s" % str(main.slot_info(2)))
		# pha huy trang thai
		main.inv.stones = 1
		main.inv.items.clear()
		main.player.position = Vector2(1280, 1100)
		main.cult.realm = 1
		main.cult.layer = 1
		log.append("tai: %s" % str(main.load_from_slot(2)))
		log.append("sau tai: stones=%d yeu_dan=%d pos=%s realm=%d layer=%d hp=%.0f" % [main.inv.stones, main.inv.count("yeu_dan"), str(main.player.position), main.cult.realm, main.cult.layer, main.vitals.hp])
		main.pause_menu.open_menu()
		log.append("pause: open=%s paused=%s" % [str(main.pause_menu.is_open()), str(paused)])
		for pg in ["save", "load", "keys", "main"]:
			main.pause_menu._go(pg)
		main.pause_menu.close_menu()
		log.append("dong: open=%s paused=%s" % [str(main.pause_menu.is_open()), str(paused)])
		for f in ["t_auto", "t_1", "t_2", "t_3"]:
			var path := "user://%s.json" % f
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		print("\n".join(log))
		print("=== SAVE TEST XONG ===")
		quit()
	return false