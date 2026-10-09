extends SceneTree
## Chụp hào quang tiên bào ở 5 cảnh giới (Luyện Khí .. Hóa Thần) và một nhân vật đang bùng vòng sáng đột phá.
## Chạy (cần cửa sổ): godot --path . --script res://tools/aura_power_shot.gd -- <ảnh.png> [outfit_id] [night]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://power.png"
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
	var cult := Cultivation.new()
	var chars: Array = []
	for i in 6:
		cult.realm = mini(i + 1, 5)
		cult.layer = 1
		var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
		ch.scale = Vector2.ONE * 3.0
		ch.position = Vector2(120 + i * 200, 360)
		ch.set_meta("aura_power", cult.aura_power())
		root.add_child(ch)
		Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": outfit_id, "shoes": "shoes_cloth_brown"})
		chars.append(ch)
	for f in 150:
		if f == 90:
			chars[5].get_node("OutfitAura").burst()
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
