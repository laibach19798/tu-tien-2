extends SceneTree
## Mọi trang phục trong Wardrobe.ITEMS phải nạp được, đủ animation, và chỉ bộ có "aura" mới sinh hào quang.
## Chạy: godot --headless --path . --script res://tools/wardrobe_test.gd

func _init() -> void:
	var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
	root.add_child(ch)
	var bad := 0
	for id in Wardrobe.ITEMS:
		var item: Dictionary = Wardrobe.ITEMS[id]
		var outfit := {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"}
		outfit[item["slot"]] = id
		Wardrobe.apply(ch, outfit)
		await process_frame
		if item["slot"] != "clothes":
			continue
		var f: SpriteFrames = ch.get_node("Clothes").sprite_frames
		var good := f != null
		if good:
			for a in ["idle_east", "walk_east", "run_east", "slash_south"]:
				good = good and f.has_animation(a)
			good = good and f.get_frame_count("walk_east") == 8 and f.get_frame_count("idle_east") == 4
		var has_aura := ch.get_node_or_null("OutfitAura") != null
		good = good and has_aura == item.has("aura")
		print("ok   " if good else "FAIL ", id, " aura=", has_aura)
		if not good:
			bad += 1
	print("TONG LOI: ", bad)
	quit(1 if bad > 0 else 0)
