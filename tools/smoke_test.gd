extends SceneTree
## Bài kiểm tra nhanh chạy không cần giao diện:
##   Godot_console.exe --headless --path . --script res://tools/smoke_test.gd
## Ép nhân vật gia nhập Kiếm phái, tung 4 chiêu, mua đồ, mở các giao diện, nói chuyện NPC, lưu/nạp game.

var main: Node
var frame := 0
var log: Array[String] = []


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")   # không ghi đè file lưu thật của người chơi
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		5:
			main.school.joined = true
			main.cult.realm = 2
			main.cult.layer = 1
			main.cult.qi = main.cult.qi_max()
			main.player.position = Vector2(1050, 1120)
			main.inv.add_stones(900)
		10: main.school.cast(0)
		30: main.school.cast(1)
		50: main.school.cast(2)
		70: main.school.cast(3)
		200:
			var hp := 0.0
			for t in get_nodes_in_group("targets"):
				hp += t.hp
			log.append("tong HP muc tieu con lai: %d (ban dau 360), hits=%d" % [int(hp), main.quests.sword_hits])
			# thời trang
			main.fashion.open_ui("shop")
			main.fashion._try("tien_bao")
			main.fashion._buy("tien_bao")
			main.fashion._buy("hair_long_silver")
			main.fashion._rotate()
			main.fashion.close_ui()
			main.fashion.open_ui("closet")
			main.fashion.close_ui()
			log.append("da so huu: %s" % str(main.wardrobe.owned))
			# cửa hàng + túi đồ
			main.inv.add("linh_thao", 3)
			main.inv.add("dan_tu_vi", 1)
			main.shop.open_shop()
			main.shop._sell("linh_thao", 3)
			main.shop.close_shop()
			main.bag.toggle()
			main.bag._use("dan_tu_vi")
			main.bag.close_bag()
		220:
			# nói chuyện với từng NPC, chọn đáp án đầu mỗi lần
			for n in main.npcs:
				main._talk(n)
				for i in 8:
					if main.dialogue.open:
						main.dialogue._pick(0)
			main.dialogue.close_dialogue() if main.dialogue.has_method("close_dialogue") else null
		240:
			log.append("quest: " + main.quests.tracker_text().replace("\n", " | "))
			log.append("tu vi: " + main.cult.realm_name())
		260:
			print("=== SMOKE TEST XONG ===")
			for l in log:
				print(l)
			quit(0)
	return false
