extends SceneTree
## Chụp ảnh kiếm đeo lưng ở 8 hướng cho từng kiểu kiếm.
## Chạy (cần cửa sổ): godot --path . --script res://tools/sword_shot.gd -- <ảnh.png> [outfit_id]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://sword.png"
	var outfit_id: String = args[1] if args.size() > 1 else "outfit_lam"
	root.size = Vector2i(1280, 640)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.36)
	bg.size = Vector2(1280, 640)
	root.add_child(bg)
	var swords := ["sword_iron", "sword_frost", "sword_flame"]
	var chars: Array = []
	for r in swords.size():
		for i in 8:
			var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
			ch.scale = Vector2.ONE * 2.2
			ch.position = Vector2(90 + i * 150, 120 + r * 190)
			root.add_child(ch)
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": outfit_id, "shoes": "shoes_cloth_brown", "sword": swords[r]})
			chars.append(ch)
	await process_frame
	for r in swords.size():
		for i in 8:
			(chars[r * 8 + i] as Node2D).set_motion("idle", Dir.ALL[i])
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
