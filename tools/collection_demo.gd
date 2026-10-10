extends SceneTree
## Chụp tab Sưu tầm: Godot_console.exe --path . --script res://tools/collection_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 100

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		for id in ["outfit_wolf_king", "waist_wolf_fang", "shoes_boot_wolf", "head_band_wolf", "sword_wolf", "outfit_linh_mach", "waist_crystal"]:
			main.wardrobe.grant(id)
		main.wardrobe.equip("outfit_wolf_king")
		main.wardrobe.equip("sword_wolf")
		main.journal.open_ui("collect")
	if frame == 30:
		main.wardrobe.equip("outfit_linh_mach")
		main.wardrobe.equip("waist_crystal")
		main.journal.open_ui("collect")
	if frame == 50:
		main.journal.open_ui("char")
	if frame == 70:
		main.journal.close_ui()
		main.fashion.open_ui("closet")
	return false
