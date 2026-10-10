extends SceneTree
## Chụp ảnh phụ kiện đầu ở 8 hướng (ảnh đứng yên), mỗi hàng một kiểu.
## Chạy (cần cửa sổ): godot --path . --script res://tools/head_shot.gd -- <ảnh.png> [outfit_id] [trang 0|1]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://head.png"
	var outfit_id: String = args[1] if args.size() > 1 else "outfit_lam"
	root.size = Vector2i(1280, 960)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.36)
	bg.size = Vector2(1280, 960)
	root.add_child(bg)
	var page: int = int(args[2]) if args.size() > 2 else 0
	var all_items := ["head_band_white", "head_band_red", "head_pin_jade", "head_flower", "head_crown_gold", "head_mask_fox", "head_halo"]
	var items: Array = all_items.slice(0, 4) if page == 0 else all_items.slice(4)
	var chars: Array = []
	for r in items.size():
		for i in 8:
			var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
			ch.scale = Vector2.ONE * 2.4
			ch.position = Vector2(90 + i * 150, 140 + r * 150)
			root.add_child(ch)
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": outfit_id, "shoes": "shoes_cloth_brown", "head": items[r]})
			chars.append(ch)
	await process_frame
	for r in items.size():
		for i in 8:
			(chars[r * 8 + i] as Node2D).set_motion("idle", Dir.ALL[i])
	for f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
