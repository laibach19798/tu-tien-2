extends SceneTree
## Nhặt trang phục rơi từ quái: lần đầu được món, nhặt trùng thì đổi ra linh thạch.
## Chạy: godot --headless --path . --script res://tools/loot_outfit_test.gd

class FakeHud:
	extends Node
	var toasts: Array = []
	func toast(t: String) -> void:
		toasts.append(t)

class FakeHost:
	extends Node
	var inv := Inventory.new()
	var wardrobe := Wardrobe.new()
	var hud := FakeHud.new()
	var player := Node2D.new()
	var vitals := Vitals.new()
	var texts: Array = []
	func float_text(_pos: Vector2, text: String, _c: Color) -> void:
		texts.append(text)

func _init() -> void:
	var ok := true
	var host := FakeHost.new()
	root.add_child(host)
	host.inv.stones = 0
	var l := Loot.new()
	l.setup(host, "outfit_wolf_king", 1, Vector2.ZERO)
	root.add_child(l)
	l._pickup()
	print("lần 1: ", host.texts, " | có áo: ", host.wardrobe.is_owned("outfit_wolf_king"), " | toast: ", host.hud.toasts)
	ok = ok and host.wardrobe.is_owned("outfit_wolf_king") and host.inv.stones == 0 and host.hud.toasts.size() == 1
	var l2 := Loot.new()
	l2.setup(host, "outfit_wolf_king", 1, Vector2.ZERO)
	root.add_child(l2)
	l2._pickup()
	print("lần 2 (trùng): ", host.texts.back(), " | linh thạch: ", host.inv.stones)
	ok = ok and host.inv.stones == 5
	print("TONG: ", "OK" if ok else "LOI")
	quit(0 if ok else 1)
