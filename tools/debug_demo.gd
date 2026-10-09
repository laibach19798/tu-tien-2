extends SceneTree
## Chay thu cac nut cua menu thu nghiem va chup anh: Godot_console.exe --path . --script res://tools/debug_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 60

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		var dm = main.debug_menu
		var log: Array[String] = []
		var before: float = main.inv.stones
		main.debug_menu.open_menu()
		log.append("menu mo, paused=%s" % str(paused))
		main.inv.add_stones(500)
		dm._full_xp()
		log.append("vien man: ready=%s layer=%d" % [str(main.cult.ready_breakthrough), main.cult.layer])
		dm._breakthrough()
		log.append("dot pha: %s" % main.cult.realm_name())
		dm._all_items(10)
		log.append("moi loai x10: linh_thao=%d dan_hoi_huyet=%d" % [main.inv.count("linh_thao"), main.inv.count("dan_hoi_huyet")])
		dm._spawn("wolf")
		log.append("so quai sau khi tao: %d, mo=%s" % [main.monsters.size(), str(dm.is_open())])
		dm.open_menu()
		dm._toggle_god()
		main.vitals.take(50.0, main.player.position)
		log.append("bat tu: hp=%.0f/%.0f god=%s" % [main.vitals.hp, main.vitals.max_hp, str(main.vitals.god)])
		dm._time(0.0)
		dm._speed(2.0)
		log.append("toc do engine=%.1f" % Engine.time_scale)
		dm._speed(1.0)
		dm._kill_all()
		dm._revive_all()
		dm._tp(main.CENTER)
		log.append("tp: pos=%s mo=%s" % [str(main.player.position), str(dm.is_open())])
		main.quests.states["q3"] = "active"
		dm._finish_quests()
		log.append("q3=%s" % main.quests.states.get("q3", "?"))
		dm._reset_quests()
		log.append("reset: %d trang thai" % main.quests.states.size())
		print("\n".join(log))
		dm.open_menu()
		dm._show_info = true
	if frame == 40:
		print("=== DEBUG DEMO XONG ===")
	return false