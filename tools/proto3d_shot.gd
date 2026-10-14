extends SceneTree
## Chụp ảnh prototype 3D (cần màn hình ảo nếu chạy trên máy chủ, không dùng --headless vì headless không vẽ):
##   xvfb-run -a Godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/proto3d_shot.gd -- <thư mục ra>
## Ra: lineup.png (4 trang phục cạnh nhau), walk.png (đang đi), pixel_off.png (tắt pixel hoá).

var demo: Node
var out_dir := "/tmp"
var frame := 0
var extras: Array[Hero3D] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	demo = load("res://scenes/proto3d.tscn").instantiate()
	root.add_child(demo)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		3:
			demo.set_physics_process(false)   # tắt camera tự theo để dựng khung hình
			# xếp 4 bộ thành một hàng nhìn thẳng vào camera
			demo.hero.position = Vector3(-1.5, 0, 0)
			demo.hero.set_outfit("ao_vai")
			var ids := ["dao_bao", "tien_bao", "ma_y"]
			for i in ids.size():
				var h := Hero3D.new()
				demo.world.add_child(h)
				h.position = Vector3(-0.5 + i, 0, 0)
				h.set_outfit(ids[i])
				extras.append(h)
			demo.cam.size = 3.4
			demo.cam.position = demo.CAM_OFFSET * 0.55 + Vector3(0, 0.2, 0)
		20: _save("lineup.png")
		21:
			for h in extras:
				h.queue_free()
			extras.clear()
			demo.hero.set_outfit("tien_bao")
			demo.hero.position = Vector3(0, 0, 0)
			demo.hero.rotation.y = deg_to_rad(135)
			demo.hero.set_move(1.0)
			demo.cam.size = 6.0
			demo.cam.position = demo.CAM_OFFSET
			demo.set_outfit_index(2)
		40: _save("walk.png")
		41:
			demo.container.stretch_shrink = 1
			demo.hero.set_move(0.0)
			demo.hero.rotation.y = 0.0
			demo.cam.size = 3.2
			demo.cam.position = demo.CAM_OFFSET * 0.5
		60:
			_save("pixel_off.png")
			quit(0)
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name)
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
