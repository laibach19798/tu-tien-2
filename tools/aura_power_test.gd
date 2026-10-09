extends SceneTree
## Hào quang theo cảnh giới: aura_power thấp thì ít hiệu ứng, cao thì đủ; đột phá thì bùng vòng sáng.
## Chạy: godot --headless --path . --script res://tools/aura_power_test.gd

func _init() -> void:
	var cult := Cultivation.new()
	var ok := true
	cult.realm = 1; cult.layer = 1
	var p0 := cult.aura_power()
	cult.realm = 5; cult.layer = 1
	var p1 := cult.aura_power()
	cult.realm = 3; cult.layer = 5
	var pm := cult.aura_power()
	print("aura_power: Luyện Khí 1 = %.2f | Kim Đan 5 = %.2f | Hóa Thần = %.2f" % [p0, pm, p1])
	ok = ok and absf(p0 - 0.15) < 0.01 and absf(p1 - 1.0) < 0.01 and pm > p0 and pm < p1
	var ch: Node2D = load("res://character/hd/base_character.tscn").instantiate()
	root.add_child(ch)
	ch.set_meta("aura_power", 0.15)
	Wardrobe.apply(ch, {"hair": "hair_topknot_black", "clothes": "tien_bao", "shoes": "shoes_cloth_brown"})
	for i in 90:
		await process_frame
	var aura = ch.get_node("OutfitAura")
	var qi = ch.get_node("QiCape")
	var low_rise: int = aura._rise.amount
	var low_alpha: float = qi._alpha
	ch.set_meta("aura_power", 1.0)
	for i in 120:
		await process_frame
	var high_rise: int = aura._rise.amount
	var high_alpha: float = qi._alpha
	print("hạt linh khí thấp/cao: %d / %d | áo choàng linh khí alpha: %.2f / %.2f" % [low_rise, high_rise, low_alpha, high_alpha])
	ok = ok and low_rise < high_rise and low_alpha < 0.05 and high_alpha > 0.9
	aura.burst()
	await process_frame
	ok = ok and aura._burst > 0.9
	print("bùng khi đột phá: ", aura._burst > 0.9)
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
