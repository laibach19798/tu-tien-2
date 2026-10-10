extends SceneTree
## Chụp ảnh áo vải nhuộm được với từng màu thuốc nhuộm (hàng trên: mặt trước, hàng dưới: đang chạy).
## Chạy (cần cửa sổ): godot --path . --script res://tools/dye_shot.gd -- <ảnh.png>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://dye.png"
	root.size = Vector2i(1280, 640)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.36)
	bg.size = Vector2(1280, 640)
	root.add_child(bg)
	var dyes: Array = [""]
	for id in Wardrobe.items_of("dye"):
		dyes.append(id)
	var chars: Array = []
	for i in dyes.size():
		var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
		ch.scale = Vector2.ONE * 2.0
		ch.position = Vector2(70 + (i % 6) * 205, 130 + (i / 6) * 220)
		root.add_child(ch)
		var outfit := {"hair": "hair_topknot_black", "clothes": "outfit_lam", "shoes": "shoes_cloth_brown"}
		if dyes[i] != "":
			outfit["dye"] = dyes[i]
		Wardrobe.apply(ch, outfit)
		chars.append(ch)
	await process_frame
	for ch in chars:
		(ch as Node2D).set_motion("idle", "south")
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
