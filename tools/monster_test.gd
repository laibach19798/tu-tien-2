extends SceneTree
## Kiem tra chien dau: quai duoi va danh nguoi choi, nguoi choi giet quai nhan loot, chet roi hoi sinh, luyen dan.
## Godot_console.exe --headless --path . --script res://tools/monster_test.gd

var main: Node
var frame := 0
var log: Array[String] = []
var wolf: Monster
var _t_death := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.switch_map_now("soi_linh", Maps.DEFS["soi_linh"]["entry"])
		for m in main.monsters:
			if m.kind_id == "wolf":
				wolf = m
				break
		log.append("so quai: %d, soi dau tien tai %s (an toan=%s)" % [main.monsters.size(), str(wolf.position), str(main.is_safe(wolf.position))])
		main.player.position = wolf.position + Vector2(150, 0)
	if frame == 90:
		log.append("sau 1.5s: quai state=%s, hp nguoi choi=%.0f/%.0f" % [wolf.state, main.vitals.hp, main.vitals.max_hp])
	if frame == 360:
		log.append("sau 6s: hp nguoi choi=%.0f/%.0f, quai state=%s dist=%.0f" % [main.vitals.hp, main.vitals.max_hp, wolf.state, wolf.position.distance_to(main.player.position)])
		var before_xp: float = main.cult.xp
		var kills_before: int = main.quests.kills.get("wolf", 0)
		wolf.take_hit(9999.0, main.player.position)
		log.append("giet soi: alive=%s, kills %d -> %d, xp %.1f -> %.1f" % [str(wolf.alive), kills_before, main.quests.kills.get("wolf", 0), before_xp, main.cult.xp])
	if frame == 380:
		var loots := 0
		for c in main.world.get_children():
			if c is Loot:
				loots += 1
		log.append("so vat roi tren dat: %d" % loots)
		# luyen dan
		main.inv.add("linh_thao", 6)
		main.inv.add("soi_nanh", 1)
		main.alchemy.open_ui()
		var r: Dictionary = Items.RECIPES[1]
		log.append("co the luyen hoi huyet: %s, ti le %.0f%%" % [str(main.alchemy.can_make(r)), main.alchemy.chance_for(r) * 100.0])
		main.alchemy._finish(r)
		log.append("sau luyen: dan_hoi_huyet=%d tro_dan=%d" % [main.inv.count("dan_hoi_huyet"), main.inv.count("tro_dan")])
		main.alchemy.close_ui()
		# chet
		main.vitals.take(9999.0, main.player.position)
		log.append("nguoi choi chet: _dead=%s hp=%.0f" % [str(main._dead), main.vitals.hp])
		_t_death = Time.get_ticks_msec()
	if _t_death > 0 and Time.get_ticks_msec() - _t_death > 3500:
		log.append("hoi sinh: _dead=%s hp=%.0f pos=%s" % [str(main._dead), main.vitals.hp, str(main.player.position)])
		print("\n".join(log))
		print("=== MONSTER TEST XONG ===")
		quit()
	return false