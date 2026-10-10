extends SceneTree
## Chụp ảnh vật treo thắt lưng: hàng trên đứng yên 8 hướng, hàng dưới đang chạy (sau vài khung).
## Chạy (cần cửa sổ): godot --path . --script res://tools/waist_shot.gd -- <ảnh.png> [waist_id] [outfit_id]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://waist.png"
	var waist: String = args[1] if args.size() > 1 else "waist_jade_bell"
	var outfit_id: String = args[2] if args.size() > 2 else "outfit_lam"
	root.size = Vector2i(1280, 640)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.36)
	bg.size = Vector2(1280, 640)
	root.add_child(bg)
	var rows: Array = []
	for row in 2:
		var line: Array = []
		for i in 8:
			var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
			ch.scale = Vector2.ONE * 3.0
			ch.position = Vector2(90 + i * 150, 190 + row * 280)
			root.add_child(ch)
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": outfit_id, "shoes": "shoes_cloth_brown", "waist": waist})
			line.append(ch)
		rows.append(line)
	await process_frame
	for i in 8:
		(rows[0][i] as Node2D).set_motion("idle", Dir.ALL[i])
		(rows[1][i] as Node2D).set_motion("run", Dir.ALL[i])
	var dirs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
	for f in 50:
		for i in 8:
			(rows[1][i] as Node2D).position = Vector2(90 + i * 150, 470) + (dirs[i] as Vector2).normalized() * (f * 1.6)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
