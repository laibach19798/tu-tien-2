extends SceneTree
## Chụp Tiểu Thế Giới: Godot_console.exe --path . --script res://tools/war_demo.gd --write-movie <thư mục>/f.png --fixed-fps 30 --quit-after 260
var main: Node
var frame := 0
const SHOTS := [
	[10, Vector2(560, 2660)],      # căn cứ Kiếm Tông
	[40, Vector2(1380, 1000)],     # Mỏ Hỏa Tinh (Xích Viêm)
	[70, Vector2(2240, 520)],      # Hàn Băng Cung
	[100, Vector2(3300, 1400)],    # Đầm Độc
	[130, Vector2(3880, 2660)],    # Huyền Minh Giáo
	[160, Vector2(2240, 1700)],    # Thiên Mạch (vô chủ)
]


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.debug_peaceful = true
	if frame == 5:
		main.switch_map_now("tieu_gioi", Vector2(560, 2660))
	for s in SHOTS:
		if frame == s[0] and frame > 5:
			main.player.position = s[1]
			main.camera.position = s[1]
	if frame == 180:
		main.war.under_attack["t_linh_tuyen"] = {"by": "doc_mon", "left": 90.0}
		main.war.log.append("Độc Môn chiếm Mỏ Hỏa Tinh từ Xích Viêm Tông.")
		main.war.log.append("Độc Môn tập kích Linh Tuyền Nam Sơn! Về phòng thủ trong 120 giây.")
		main.war_ui.open_ui()
	if frame == 215:
		main.war_ui.close_ui()
		main.minimap.toggle_full()
	return false
