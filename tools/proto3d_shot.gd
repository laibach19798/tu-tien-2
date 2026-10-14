extends SceneTree
## Chụp ảnh prototype 3D (cần màn hình ảo nếu chạy trên máy chủ, không dùng --headless vì headless không vẽ):
##   xvfb-run -a Godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/proto3d_shot.gd -- <thư mục ra>
## Ra: lineup.png + lineup2.png (4 bộ cạnh nhau, 2 nhóm), walk.png (đang đi), pixel_off.png (tắt pixel hoá), detail_*/back_*/face_* (cận cảnh).

var demo: Node
var out_dir := "/tmp"
var frame := 0
var extras: Array[Node3D] = []
## [bộ, góc xoay độ, độ cao tâm khung, cỡ khung, tên file]
const DETAILS := [
	["tien_bao", 0, 0.9, 2.5, "detail_tien_bao.png"], ["dao_bao", 0, 0.9, 2.5, "detail_dao_bao.png"],
	["kiem_tu", 0, 0.9, 2.5, "detail_kiem_tu.png"], ["dan_su", 0, 0.9, 2.5, "detail_dan_su.png"],
	["hong_nhan", 0, 0.9, 2.5, "detail_hong_nhan.png"], ["an_si", 0, 0.9, 2.5, "detail_an_si.png"],
	["kiem_tu", 180, 0.9, 2.5, "back_kiem_tu.png"], ["hong_nhan", 180, 0.9, 2.5, "back_hong_nhan.png"],
	["kiem_tu", 0, 1.3, 1.2, "face_kiem_tu.png"], ["hong_nhan", 0, 1.3, 1.2, "face_hong_nhan.png"],
]


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
				var h: Node3D = demo.make_hero()
				demo.world.add_child(h)
				h.position = Vector3(-0.5 + i, 0, 0)
				h.set_outfit(ids[i])
				extras.append(h)
			demo.cam.size = 3.4
			demo.cam.position = demo.CAM_OFFSET * 0.55 + Vector3(0, 0.2, 0)
		20: _save("lineup.png")
		21:
			# nhóm bộ thứ hai
			var ids2 := ["kiem_tu", "dan_su", "hong_nhan", "an_si"]
			demo.hero.set_outfit(ids2[0])
			for i in extras.size():
				extras[i].set_outfit(ids2[i + 1])
		23: _save("lineup2.png")
		24:
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
		63: _save("pixel_off.png")
	if frame > 63:
		_detail_shots()
	return false


## Cận cảnh từng bộ (mặt trước + mặt sau) ở độ phân giải đầy đủ để xem chi tiết.
func _detail_shots() -> void:
	var k := (frame - 64) / 3
	var step := (frame - 64) % 3
	if k >= DETAILS.size():
		quit(0)
		return
	var d: Array = DETAILS[k]
	if step == 0:
		demo.hero.set_outfit(d[0])
		demo.hero.rotation.y = deg_to_rad(d[1])
		demo.hero.set_move(0.0)
		demo.hero.position = Vector3.ZERO
		demo.cam.size = d[3]
		demo.cam.position = Vector3(0, d[2], 0) + demo.CAM_OFFSET
	elif step == 2:
		_save(d[4])


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name)
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
