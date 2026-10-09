extends SceneTree
## Chụp ảnh áo choàng linh khí ở 8 hướng (đứng yên và đang chạy), ban ngày hoặc đêm.
## Chạy (cần cửa sổ): godot --path . --script res://tools/qi_shot.gd -- <ảnh.png> [outfit_id] [night]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://qi.png"
	var outfit_id: String = args[1] if args.size() > 1 else "tien_bao"
	var night: bool = args.size() > 2 and args[2] == "night"
	root.size = Vector2i(1280, 640)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.36)
	bg.size = Vector2(1280, 640)
	root.add_child(bg)
	if night:
		var cm := CanvasModulate.new()
		cm.color = Color(0.30, 0.37, 0.62)
		root.add_child(cm)
	var rows: Array = []
	for row in 2:
		var line: Array = []
		for i in 8:
			var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
			ch.scale = Vector2.ONE * 2.4
			ch.position = Vector2(80 + i * 150, 150 + row * 270)
			root.add_child(ch)
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": outfit_id, "shoes": "shoes_cloth_brown"})
			line.append(ch)
		rows.append(line)
	await process_frame
	for i in 8:
		(rows[0][i] as Node2D).set_motion("idle", Dir.ALL[i])
		(rows[1][i] as Node2D).set_motion("run", Dir.ALL[i])
	var dirs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
	for f in 70:
		for i in 8:
			(rows[1][i] as Node2D).position = Vector2(80 + i * 150, 420) + (dirs[i] as Vector2).normalized() * (f * 1.8)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
