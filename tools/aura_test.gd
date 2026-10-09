extends SceneTree
## Kiểm tra hào quang trang phục: bật khi mặc tien_bao, gỡ khi đổi bộ.
## Chạy: godot --headless --path . --script res://tools/aura_test.gd

func _init() -> void:
	var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
	var cm := CanvasModulate.new()
	cm.color = Color(0.30, 0.37, 0.62)   # đêm sâu
	root.add_child(cm)
	root.add_child(ch)
	Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "tien_bao", "shoes": "shoes_cloth_brown"})
	for i in 30:
		ch.position.x += 2.0
		await process_frame
	var aura := ch.get_node_or_null("OutfitAura")
	var ok := aura != null and ch.get_node("Clothes").material is ShaderMaterial and ch.get_child(0) == aura
	var boosted: bool = aura != null and aura._light.energy > 1.0 and aura.self_modulate.r > 2.0
	print("bù màu đêm + đèn: ", boosted)
	ok = ok and boosted
	print("aura bật: ", ok, " | trail đang phát: ", aura._trail.emitting if aura else "n/a")
	Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"})
	await process_frame
	var off := ch.get_node_or_null("OutfitAura") == null and ch.get_node("Clothes").material == null
	print("aura gỡ khi đổi bộ: ", off)
	quit(0 if ok and off else 1)
