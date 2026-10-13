extends SceneTree
## Chụp binh khí các tông và màn Luyện công: Godot_console.exe --path . --script res://tools/weapon_shot.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 70
var main: Node
var frame := 0
const W := ["sword_thanh_huyen", "sword_dao_xichviem", "sword_thuong_hanbang", "sword_xa_docmon", "sword_liem_huyenminh"]


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.debug_peaceful = true
		main.switch_map_now("sect_kiem_tong", Vector2(1800, 1350))
		main.player.position = Vector2(1800, 1350)
		main.camera.position = main.player.position
		var layer := Node2D.new()
		layer.z_index = 500
		main.world.add_child(layer)
		var bg := ColorRect.new()
		bg.color = Color(0.16, 0.18, 0.26)
		bg.position = Vector2(1800 - 330, 1350 - 120)
		bg.size = Vector2(660, 250)
		layer.add_child(bg)
		for i in W.size():
			var it: Dictionary = Wardrobe.ITEMS[W[i]]
			for row in 2:
				var v := SwordVisual.new()
				v.shape = str(it.get("shape", "kiem"))
				v.length = SwordVisual.length_of(v.shape) + (6.0 if row == 0 else 0.0)
				v.sheath = row == 1
				v.blade_color = it.get("blade", SwordVisual.BLADE)
				v.configure_style(it["scabbard"], it["edge"], it["metal"], it["hilt"])
				if it.has("glow"):
					v.glow_color = it["glow"]
					v.glow = 0.5
				v.scale = Vector2.ONE * 3.2
				v.rotation = -PI / 2.0 + 0.0
				v.position = Vector2(1800 - 260 + i * 130, 1350 - 20 + row * 110)
				v.rotation = deg_to_rad(-70.0)
				layer.add_child(v)
	if frame == 30:
		main.school.joined = true
		main.cult.realm = 3
		main.wardrobe.grant("sword_dao_xichviem")
		main.wardrobe.equip("sword_dao_xichviem")
	return false
