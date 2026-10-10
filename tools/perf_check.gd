extends SceneTree
## Đo FPS / draw call thật ở làng, Tiểu Thế Giới và tông môn. Chạy CÓ cửa sổ: godot --path . --script res://tools/perf_check.gd
## Đo hiệu năng thật (cần chạy có cửa sổ, không --headless).
var main: Node
var frame := 0
var spots: Array = []
var si := 0
var t0 := 0
var samples: Array = []
func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d) -> bool:
	frame += 1
	if frame == 5:
		main.debug_peaceful = true
		main.switch_map_now("overworld", Vector2(1280, 1100))
		spots = [["overworld", "overworld", Vector2(1280, 1100)], ["tieu_gioi", "tieu_gioi", Vector2(560, 2700)], ["tieu_gioi giua", "tieu_gioi", Vector2(2240, 1600)], ["tieu_gioi tong dich", "tieu_gioi", Vector2(3900, 900)], ["sect_kiem_tong cong", "sect_kiem_tong", Vector2(1800, 2300)], ["sect_kiem_tong dien", "sect_kiem_tong", Vector2(1800, 1300)]]
		_go()
	elif frame > 5 and frame - 5 - 1 == 0:
		pass
	if frame > 5:
		var n := frame - 5
		if n % 90 == 30:
			samples = []
			t0 = Time.get_ticks_msec()
		if n % 90 > 30:
			samples.append([Performance.get_monitor(Performance.TIME_PROCESS), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if n % 90 == 89:
			_report()
			si += 1
			if si >= spots.size():
				quit()
			else:
				_go()
	return false
func _go() -> void:
	var s: Array = spots[si]
	if main.current_map != s[1]:
		main.switch_map_now(s[1], s[2])
	main.player.position = s[2]
	main.camera.position = s[2]
func _report() -> void:
	var p := 0.0
	var ph := 0.0
	var dc := 0.0
	var ob := 0.0
	for s in samples:
		p += s[0]
		ph += s[1]
		dc += s[2]
		ob += s[3]
	var k := float(samples.size())
	var ms := float(Time.get_ticks_msec() - t0) / 60.0
	print("PROF ", spots[si][0], " | frame ~", snappedf(ms, 0.1), " ms (", snappedf(1000.0 / maxf(ms, 0.1), 1.0), " fps) | process ", snappedf(p / k * 1000.0, 0.1), " ms | physics ", snappedf(ph / k * 1000.0, 0.1), " ms | draw calls ", int(dc / k), " | objects ", int(ob / k))
