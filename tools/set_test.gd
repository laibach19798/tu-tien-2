extends SceneTree
## Thưởng bộ trang phục: số món -> mốc thưởng, cộng dồn nhiều bộ, và tác dụng lên tu vi / khí huyết.
## Chạy: godot --headless --path . --script res://tools/set_test.gd

func _init() -> void:
	var ok := true
	var none := Wardrobe.total_bonus({})
	ok = ok and none["dmg"] == 0.0 and none["xp"] == 0.0 and none["hp"] == 0.0 and none["speed"] == 0.0
	# Kiếm Tu: 1 món chưa có, 2 món +8% dmg, 4 món +22% dmg +5% speed
	var kt1 := Wardrobe.total_bonus({"sword": "sword_black"})
	var kt2 := Wardrobe.total_bonus({"sword": "sword_black", "head": "head_band_red"})
	var kt4 := Wardrobe.total_bonus({"clothes": "outfit_do", "head": "head_band_red", "shoes": "shoes_boot_black", "sword": "sword_black"})
	print("Kiếm Tu 1/2/4 món: dmg %.2f / %.2f / %.2f, speed(4) %.2f" % [kt1["dmg"], kt2["dmg"], kt4["dmg"], kt4["speed"]])
	ok = ok and kt1["dmg"] == 0.0 and absf(kt2["dmg"] - 0.08) < 0.001 and absf(kt4["dmg"] - 0.22) < 0.001 and absf(kt4["speed"] - 0.05) < 0.001
	# hai bộ cùng lúc: Kiếm Tu 2 món + Giang Hồ 2 món (khăn trắng + hồ lô; sword_iron khác sword_black nên không trùng slot)
	var mix := Wardrobe.total_bonus({"sword": "sword_black", "head": "head_band_red", "clothes": "outfit_lam", "waist": "waist_gourd"})
	print("hai bộ cùng lúc: dmg %.2f speed %.2f" % [mix["dmg"], mix["speed"]])
	ok = ok and absf(mix["dmg"] - 0.08) < 0.001
	var txt := Wardrobe.bonus_text({"dmg": 0.08, "xp": 0.0, "hp": 0.1, "speed": 0.0})
	print("bonus_text: ", txt)
	ok = ok and txt.contains("8%") and txt.contains("10%")
	# tác dụng thật lên hệ thống
	var cult := Cultivation.new()
	var vit := Vitals.new()
	vit.setup(cult)
	var base_hp := vit.max_hp
	vit.set_hp_bonus(0.2)
	print("max_hp: %.0f -> %.0f" % [base_hp, vit.max_hp])
	ok = ok and absf(vit.max_hp - base_hp * 1.2) < 0.5
	cult.xp_mult = 1.5
	var x0 := cult.xp
	cult.add_xp(10.0)
	print("xp thêm khi xp_mult=1.5: %.1f" % (cult.xp - x0))
	ok = ok and absf((cult.xp - x0) - 15.0) < 0.01
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
