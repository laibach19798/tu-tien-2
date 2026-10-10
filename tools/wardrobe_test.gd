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
		if item["slot"] == "dye":
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "outfit_lam", "shoes": "shoes_cloth_brown", "dye": id})
			await process_frame
			var dm := ch.get_node("Clothes").material as ShaderMaterial
			var ok_dye: bool = dm != null and absf(float(dm.get_shader_parameter("hue")) - float(item["hue"])) < 0.01
			Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "outfit_do", "shoes": "shoes_cloth_brown", "dye": id})
			await process_frame
			ok_dye = ok_dye and ch.get_node("Clothes").material == null   # áo không nhuộm được thì không bị nhuộm
			print("ok   " if ok_dye else "FAIL ", id)
			bad += 0 if ok_dye else 1
			continue
		if item["slot"] == "waist":
			var wg := ch.get_node_or_null("WaistGear")
			var ok_wg: bool = wg != null and wg.kind == item["kind"]
			print("ok   " if ok_wg else "FAIL ", id)
			bad += 0 if ok_wg else 1
			continue
		if item["slot"] == "head":
			var hg := ch.get_node_or_null("HeadGear")
			var ok_hg: bool = hg != null and hg.gear == item["gear"]
			print("ok   " if ok_hg else "FAIL ", id)
			bad += 0 if ok_hg else 1
			continue
		if item["slot"] == "sword":
			var sw := ch.get_node_or_null("BackSword")
			var ok_sw: bool = sw != null and sw.scabbard_color == item["scabbard"]
			print("ok   " if ok_sw else "FAIL ", id)
			bad += 0 if ok_sw else 1
			continue
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
	Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"})
	await process_frame
	var sw_gone := ch.get_node_or_null("BackSword") == null and ch.get_node_or_null("HeadGear") == null and ch.get_node_or_null("WaistGear") == null
	print("ok   " if sw_gone else "FAIL ", "go kiem deo khi khong mang")
	bad += 0 if sw_gone else 1
	print("TONG LOI: ", bad)
	quit(1 if bad > 0 else 0)
