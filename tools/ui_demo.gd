extends SceneTree
## Chup giao dien: Godot_console.exe --path . --script res://tools/ui_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 260
## Khung 20: HUD | 60: tui do | 100: cua hang | 140: tiem may | 180: hoi thoai

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.player.position = Vector2(1220, 1000)
		main.inv.add("linh_thao", 7)
		main.inv.add("dan_tu_khi", 3)
		main.inv.add("dan_tu_vi", 1)
		main.inv.add_stones(240)
	if frame == 8:
		main.hud.toast("Gia nhập Kiếm Tông! Phím J/K/L/U để ra chiêu.")
	if frame == 50:
		main.bag.toggle()
	if frame == 90:
		main.bag.close_bag()
		main.shop.open_shop()
	if frame == 130:
		main.shop.close_shop()
		main.fashion.open_ui("shop")
	if frame == 170:
		main.fashion.close_ui()
		main.dialogue.choose("Trưởng lão Vân Hạc", "Tiểu hữu, linh khí nơi này dồi dào, rất thích hợp để tu luyện. Ngươi cần ta giúp gì chăng?", [
			{"text": "Hỏi về nhiệm vụ", "call": Callable()},
			{"text": "Xem tiệm may (mua / mặc thử)", "call": Callable()},
			{"text": "Tạm biệt", "call": Callable()},
		])
	return false