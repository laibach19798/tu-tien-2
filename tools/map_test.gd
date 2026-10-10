extends SceneTree
## Chuyển map: thế giới gốc không còn quái, cổng ở chỗ đi được, vào/ra từng map phụ, quái và đồ rơi theo map, lưu/tải đúng map.
## Chạy: godot --headless --path . --script res://tools/map_test.gd
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame != 6:
		return false
	var ok := true
	main.switch_map_now("overworld", Vector2(1280, 1100))   # file lưu thật có thể đang đứng ở map phụ
	# 1) thế giới gốc không còn quái
	print("quái ở thế giới gốc: ", main.monsters.size())
	ok = ok and main.monsters.is_empty() and main.current_map == "overworld"
	# 2) cổng ở thế giới gốc nằm chỗ đi được, chỗ về cũng đi được
	for g in Maps.OVERWORLD_GATES:
		var gp: Vector2 = g["pos"]
		var back := Maps.overworld_landing(g["to"])
		var b1: bool = main._is_blocked(Rect2(gp.x - 20, gp.y - 10, 40, 14))
		var b2: bool = main._is_blocked(Rect2(back.x - 12, back.y - 8, 24, 10))
		print("cổng ", g["to"], ": chặn=", b1, " chỗ về chặn=", b2)
		ok = ok and not b1 and not b2
	# 3) vào từng map phụ
	var total := {}
	for id in Maps.DEFS:
		var d: Dictionary = Maps.DEFS[id]
		main.switch_map_now(id, d["entry"])
		var by := {}
		for m in main.monsters:
			by[m.kind_id] = int(by.get(m.kind_id, 0)) + 1
			total[m.kind_id] = int(total.get(m.kind_id, 0)) + 1
		var entry_blocked: bool = main._is_blocked(Rect2(d["entry"].x - 12, d["entry"].y - 8, 24, 10))
		var gate_blocked := false
		for g in d["gates"]:
			var gp: Vector2 = g["pos"]
			gate_blocked = gate_blocked or main._is_blocked(Rect2(gp.x - 20, gp.y - 10, 40, 14))
		var safe_entry: bool = main.is_safe(d["entry"])
		print(id, ": quái ", by, " | cổng ", main.gates.size(), " | chặn chỗ đến=", entry_blocked, " cổng=", gate_blocked, " | an toàn chỗ đến=", safe_entry, " | props ", main.prop_log.size(), " | linh thảo ", main.herbs.size())
		ok = ok and main.current_map == id and main.monsters.size() > 0 and not entry_blocked and not gate_blocked and safe_entry and main.gates.size() == 1
		ok = ok and main.map_size == d["size"] and main.camera.limit_right == int(d["size"].x)
		# mỗi nhóm quái phải sinh đủ
		var want := {}
		for gr in d["groups"]:
			want[gr[0]] = int(want.get(gr[0], 0)) + int(gr[2])
		for k in want:
			if int(by.get(k, 0)) < want[k]:
				print("  THIẾU quái ", k, ": ", by.get(k, 0), "/", want[k])
				ok = false
		# quái không đứng trong vật chặn / vùng an toàn
		for m in main.monsters:
			if main.is_safe(m.position):
				print("  FAIL quái trong vùng an toàn ", m.kind_id, m.position)
				ok = false
		# đồ rơi đúng map: giết yêu tướng ở Linh Mạch Động thì có thể rơi đồ bộ Linh Mạch, ở map khác thì không
		var cave_only := ["outfit_linh_mach", "head_pin_crystal", "waist_crystal", "shoes_boot_crystal", "sword_crystal"]
		var elite = null
		for m in main.monsters:
			if m.kind_id == "goblin_elite":
				elite = m
				break
		if elite != null:
			var n := 0
			for i in 250:
				main.on_monster_killed(elite)
			for c in main.world.get_children():
				if c is Loot and cave_only.has(c.item):
					n += 1
			print("  đồ Linh Mạch rơi sau 250 lần hạ yêu tướng: ", n)
			ok = ok and ((n > 0) == (id == "linh_mach_dong"))
		# về làng bằng cổng ra
		main.switch_map_now("overworld", Maps.overworld_landing(id))
		ok = ok and main.current_map == "overworld" and main.monsters.is_empty() and main.map_size == main.WORLD
	print("tổng quái theo loại: ", total)
	for k in ["wolf", "goblin", "wolf_dark", "goblin_elite", "wolf_king"]:
		ok = ok and int(total.get(k, 0)) > 0
	# 4) lưu / tải giữ nguyên map
	main.switch_map_now("tuyet_coc", Maps.DEFS["tuyet_coc"]["entry"])
	var data: Dictionary = main._collect_save()
	print("lưu: map=", data["map"])
	ok = ok and data["map"] == "tuyet_coc"
	main.switch_map_now("overworld", Vector2(1280, 1100))
	main._apply_save(data, true)
	print("tải: map=", main.current_map, " pos=", main.player.position)
	ok = ok and main.current_map == "tuyet_coc"
	# 5) chết ở map phụ thì về làng
	main.switch_map_now("overworld", Vector2(1280, 1100))
	# 6) vào bằng cổng thật (đi vào vùng cổng)
	var g0: Dictionary = main.gates[0]
	main.player.position = g0["pos"]
	main._travel_lock = 0.0
	main._physics_process(0.016)
	print("đứng vào cổng: traveling=", main.traveling)
	ok = ok and main.traveling
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
	return true
