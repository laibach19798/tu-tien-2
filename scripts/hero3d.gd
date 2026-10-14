extends Node3D
class_name Hero3D
## Nhân vật 3D low-poly (chibi) dựng từ khối cơ bản, tô toon + viền mực. Mặt trước của mô hình là +Z.
## Trang phục = bộ khối gắn vào các pivot của xương giả (thân, đầu, tay, chân) nên đổi bộ KHÔNG cần vẽ lại animation:
## thêm một bộ mới = thêm một entry vào OUTFITS.

const TOON := preload("res://scripts/toon3d.gdshader")
const INK := preload("res://scripts/toon3d_ink.gdshader")

const SKIN := Color("f6d3b3")
const BLUSH := Color("f2a09c")
const MOUTH := Color("a05a5a")
const EYE_DARK := Color("1c1520")

## Mỗi bộ: ten = tên hiển thị; robe/trim/ao_trong = màu áo ngoài/viền/vạt trong; dai = chiều dài áo ("dai" hoặc "ngan");
## tay = ống tay ("rong" hoặc "hep"); toc/toc_mau = kiểu và màu tóc; dau = phụ kiện đầu; lung = đồ đeo sau lưng;
## mat = màu mắt; giay = màu giày; phu = phụ kiện đeo hông (tui, ngoc, ngoc_do, chuong).
const OUTFITS := {
	"ao_vai": {
		"ten": "Áo Vải Tạp Dịch", "robe": Color("b39468"), "trim": Color("6b4f34"), "ao_trong": Color("d8c7a3"),
		"dai": "ngan", "tay": "hep", "toc": "ngan", "toc_mau": Color("3a2a2c"),
		"dau": "dai", "lung": [], "mat": Color("6b4a2f"), "giay": Color("4a3626"), "phu": ["tui"],
	},
	"dao_bao": {
		"ten": "Đạo Bào Thanh Vân", "robe": Color("3f86b5"), "trim": Color("f0ead6"), "ao_trong": Color("e9f2f7"),
		"dai": "dai", "tay": "rong", "toc": "bui", "toc_mau": Color("2c2231"),
		"dau": "none", "lung": ["kiem"], "mat": Color("2f6fb0"), "giay": Color("2d3a52"), "phu": ["ngoc"],
	},
	"tien_bao": {
		"ten": "Tiên Bào Bạch Vân", "robe": Color("f3f0e6"), "trim": Color("e0b13f"), "ao_trong": Color("cfe6f2"),
		"dai": "dai", "tay": "rong", "toc": "dai", "toc_mau": Color("8e9bd0"),
		"dau": "mien", "lung": ["ao_choang", "kiem"], "mat": Color("4aa3d8"), "giay": Color("e0b13f"), "phu": ["ngoc", "chuong"],
	},
	"ma_y": {
		"ten": "Huyết Ma Y", "robe": Color("2c2334"), "trim": Color("c4303f"), "ao_trong": Color("6a2430"),
		"dai": "dai", "tay": "rong", "toc": "gai", "toc_mau": Color("171019"),
		"dau": "none", "lung": ["ao_choang"], "mat": Color("e6354e"), "giay": Color("181019"), "phu": ["ngoc_do"],
	},
}
const ORDER := ["ao_vai", "dao_bao", "tien_bao", "ma_y"]
const SLOT_NAMES := ["mat", "toc", "ao", "dau", "lung", "phu", "tay_l", "tay_r", "giay_l", "giay_r"]

var outfit_id := ""
var move_amount := 0.0   # 0 = đứng yên, 1 = chạy hết tốc độ

var _mats := {}
var _built := false
var _phase := 0.0
var _time := 0.0
var _swing_t := -1.0

var _visual: Node3D
var _torso: Node3D
var _torso_mi: MeshInstance3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hair_back: Node3D   # tóc dài, đung đưa khi chạy
var _cape: Node3D        # áo choàng, bay khi chạy
var _tails: Array[Node3D] = []   # dải đai lưng, bay khi chạy
var _slots := {}         # tên slot -> Node3D chứa phần trang phục của slot đó (xoá và dựng lại khi đổi bộ)


func _ready() -> void:
	_build()
	set_outfit(outfit_id if outfit_id != "" else ORDER[0])


# ---------- dựng thân ----------

func _build() -> void:
	_built = true
	_visual = Node3D.new()
	add_child(_visual)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.55, 0)
	_visual.add_child(_torso)
	_torso_mi = _add(_torso, _capsule(0.185, 0.46), SKIN, Vector3(0, 0.23, 0))
	_add(_torso, _cyl(0.06, 0.07, 0.1), SKIN, Vector3(0, 0.5, 0), Vector3.ZERO, true)   # cổ

	_head = Node3D.new()
	_head.position = Vector3(0, 0.82, 0)
	_torso.add_child(_head)
	var skull := _add(_head, _sphere(0.32), SKIN)
	skull.scale = Vector3(1.06, 0.97, 1.0)

	_leg_l = _make_leg(-0.1)
	_leg_r = _make_leg(0.1)
	_arm_l = _make_arm(-0.26)
	_arm_r = _make_arm(0.26)

	for slot in SLOT_NAMES:
		_slots[slot] = Node3D.new()
	_head.add_child(_slots["mat"])
	_head.add_child(_slots["toc"])
	_head.add_child(_slots["dau"])
	_torso.add_child(_slots["ao"])
	_torso.add_child(_slots["lung"])
	_torso.add_child(_slots["phu"])
	_arm_l.add_child(_slots["tay_l"])
	_arm_r.add_child(_slots["tay_r"])
	_leg_l.add_child(_slots["giay_l"])
	_leg_r.add_child(_slots["giay_r"])


func _make_leg(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0, 0)
	_torso.add_child(pivot)
	_add(pivot, _capsule(0.08, 0.5), SKIN, Vector3(0, -0.25, 0))
	return pivot


func _make_arm(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.4, 0)
	_torso.add_child(pivot)
	_add(pivot, _capsule(0.06, 0.36), SKIN, Vector3(0, -0.15, 0))
	_add(pivot, _sphere(0.068), SKIN, Vector3(0, -0.33, 0.01))
	for i in 3:   # ba ngón gộp lại + ngón cái
		_add(pivot, _capsule(0.018, 0.08), SKIN, Vector3((i - 1) * 0.03, -0.395, 0.025), Vector3(-8, 0, 0), false, false)
	_add(pivot, _capsule(0.019, 0.07), SKIN, Vector3(signf(x) * 0.065, -0.35, 0.05), Vector3(-30, 0, signf(x) * 35), false, false)
	return pivot


# ---------- đổi trang phục ----------

func set_outfit(id: String) -> void:
	if not OUTFITS.has(id):
		return
	outfit_id = id
	if not _built:
		return   # _ready sẽ gọi lại
	var o: Dictionary = OUTFITS[id]
	for slot in _slots:
		for c in _slots[slot].get_children():
			c.free()
	_hair_back = null
	_cape = null
	_tails.clear()
	_torso_mi.material_override = _mat(o["robe"])
	_dress_face(o)
	_dress_robe(o)
	_dress_sleeves(o)
	_dress_hair(o)
	_dress_headgear(o)
	_dress_back(o)
	_dress_accessories(o)
	_dress_shoes(o)


## Mặt: mắt nhiều lớp (viền tối, tròng, ánh dưới, đồng tử, hai điểm sáng) + mi trên, lông mày, mũi, miệng, má hồng, tai.
## Không vẽ viền mực cho chi tiết nhỏ để mặt không bị lem.
func _dress_face(o: Dictionary) -> void:
	var s: Node3D = _slots["mat"]
	var brow_col: Color = (o["toc_mau"] as Color).lightened(0.05)
	var eye_col: Color = o["mat"]
	for sx in [-1.0, 1.0]:
		var ex: float = sx * 0.125
		_add(s, _sphere(0.06), EYE_DARK, Vector3(ex, -0.035, 0.281), Vector3.ZERO, false, false).scale = Vector3(1.0, 1.4, 0.45)
		_add(s, _sphere(0.043), eye_col, Vector3(ex, -0.05, 0.296), Vector3.ZERO, false, false).scale = Vector3(1.0, 1.3, 0.4)
		_add(s, _sphere(0.03), eye_col.lightened(0.4), Vector3(ex, -0.088, 0.3), Vector3.ZERO, false, false).scale = Vector3(1.1, 0.65, 0.3)
		_add(s, _sphere(0.019), EYE_DARK, Vector3(ex, -0.046, 0.304), Vector3.ZERO, false, false).scale = Vector3(0.9, 1.5, 0.3)
		_add(s, _sphere(0.017), Color.WHITE, Vector3(ex + sx * 0.021, -0.001, 0.309), Vector3.ZERO, false, false)
		_add(s, _sphere(0.009), Color.WHITE, Vector3(ex - sx * 0.018, -0.088, 0.306), Vector3.ZERO, false, false)
		_add(s, _box(Vector3(0.108, 0.02, 0.014)), EYE_DARK, Vector3(ex, 0.043, 0.299), Vector3(0, 0, -sx * 10), false, false)    # mi trên
		_add(s, _box(Vector3(0.035, 0.012, 0.012)), EYE_DARK, Vector3(ex + sx * 0.058, 0.03, 0.292), Vector3(0, 0, sx * 32), false, false)   # đuôi mi
		_add(s, _box(Vector3(0.09, 0.018, 0.012)), brow_col, Vector3(ex, 0.098, 0.288), Vector3(0, 0, -sx * 9), false, false)
		_add(s, _sphere(0.045), BLUSH, Vector3(sx * 0.2, -0.1, 0.235), Vector3(0, sx * 38, 0), false, false).scale = Vector3(1.0, 0.6, 0.3)
		_add(s, _sphere(0.052), SKIN, Vector3(sx * 0.335, -0.03, -0.01), Vector3.ZERO, true).scale = Vector3(0.45, 1.0, 0.8)    # tai
	_add(s, _sphere(0.013), SKIN.darkened(0.12), Vector3(0, -0.077, 0.316), Vector3.ZERO, false, false)                           # mũi
	_add(s, _box(Vector3(0.045, 0.012, 0.01)), MOUTH, Vector3(0, -0.127, 0.3), Vector3.ZERO, false, false)


func _dress_robe(o: Dictionary) -> void:
	var s: Node3D = _slots["ao"]
	var robe: Color = o["robe"]
	var trim: Color = o["trim"]
	var inner: Color = o["ao_trong"]
	if o["dai"] == "dai":
		_add(s, _cyl(0.2, 0.395, 0.07), inner, Vector3(0, -0.475, 0), Vector3.ZERO, true)           # lớp váy trong lòi ra dưới gấu
		_add(s, _cyl(0.2, 0.36, 0.56), robe, Vector3(0, -0.2, 0), Vector3.ZERO, true)
		_add(s, _cyl(0.365, 0.365, 0.05), trim, Vector3(0, -0.44, 0), Vector3.ZERO, true)           # viền gấu áo
		for sx in [-1.0, 1.0]:   # hoa văn mây hai bên vạt
			_add(s, _sphere(0.045), trim, Vector3(sx * 0.17, -0.3, 0.255), Vector3(0, sx * 33, 0)).scale = Vector3(1.0, 1.0, 0.25)
			_add(s, _sphere(0.03), trim, Vector3(sx * 0.215, -0.33, 0.21), Vector3(0, sx * 45, 0)).scale = Vector3(1.0, 1.0, 0.25)
		_add(s, _box(Vector3(0.13, 0.52, 0.02)), inner, Vector3(0, -0.2, 0.285), Vector3(-15, 0, 0), false, false)   # vạt trong phía trước
		_add(s, _box(Vector3(0.14, 0.04, 0.025)), trim, Vector3(0, -0.45, 0.335), Vector3(-15, 0, 0), false, false)
	else:
		_add(s, _cyl(0.2, 0.27, 0.2), robe, Vector3(0, -0.03, 0), Vector3.ZERO, true)
	_add(s, _cyl(0.2, 0.2, 0.07), trim, Vector3(0, 0.02, 0), Vector3.ZERO, true)                      # đai lưng
	_add(s, _sphere(0.055), trim, Vector3(0, 0.02, 0.2))                                               # nút thắt đai
	# cổ áo chéo (hai vạt áo bắt chéo trước ngực)
	for sx in [-1.0, 1.0]:
		_add(s, _box(Vector3(0.06, 0.34, 0.02)), trim, Vector3(sx * 0.075, 0.32, 0.178), Vector3(0, 0, sx * 30), false, false)
	_add(s, _cyl(0.155, 0.175, 0.03), inner, Vector3(0, 0.425, 0), Vector3.ZERO, true)                # cổ áo trong
	_add(s, _cyl(0.15, 0.17, 0.05), trim, Vector3(0, 0.45, 0), Vector3.ZERO, true)                    # cổ áo đứng
	# nơ đai sau lưng
	var knot_pos := Vector3(0, 0.02, -0.205)
	_add(s, _sphere(0.04), trim, knot_pos)
	for sx in [-1.0, 1.0]:
		_add(s, _sphere(0.05), trim, knot_pos + Vector3(sx * 0.07, 0.01, 0), Vector3(0, 0, sx * 22), false, true).scale = Vector3(1.5, 0.8, 0.5)
	# dải đai buông sau lưng
	for sx in [-1.0, 1.0]:
		var tail := Node3D.new()
		tail.position = Vector3(sx * 0.06, 0.0, -0.2)
		s.add_child(tail)
		_add(tail, _box(Vector3(0.05, 0.3, 0.015)), trim, Vector3(0, -0.15, 0), Vector3(0, 0, sx * 6), false, false)
		_tails.append(tail)


func _dress_sleeves(o: Dictionary) -> void:
	var robe: Color = o["robe"]
	var trim: Color = o["trim"]
	for side in ["tay_l", "tay_r"]:
		var s: Node3D = _slots[side]
		if o["tay"] == "rong":
			_add(s, _cyl(0.085, 0.16, 0.3), robe, Vector3(0, -0.15, 0), Vector3.ZERO, true)
			_add(s, _cyl(0.162, 0.162, 0.04), trim, Vector3(0, -0.29, 0), Vector3.ZERO, true)
			_add(s, _cyl(0.14, 0.14, 0.03), (o["ao_trong"] as Color), Vector3(0, -0.31, 0), Vector3.ZERO, false, false)   # lót trong miệng tay áo
		else:
			_add(s, _cyl(0.075, 0.075, 0.24), robe, Vector3(0, -0.12, 0), Vector3.ZERO, true)
			_add(s, _cyl(0.078, 0.078, 0.03), trim, Vector3(0, -0.24, 0), Vector3.ZERO, true)


func _dress_hair(o: Dictionary) -> void:
	var s: Node3D = _slots["toc"]
	var c: Color = o["toc_mau"]
	var cap := _hadd(s, _sphere(0.335), c, Vector3(0, 0.055, -0.055))                                 # mũ tóc phủ đỉnh và sau đầu
	cap.scale = Vector3(1.07, 1.0, 1.03)
	# mái: bảy lọn nhọn rủ xuống trán, so le độ dài
	var xs := [-0.24, -0.16, -0.08, 0.0, 0.08, 0.16, 0.24]
	var lens := [0.2, 0.24, 0.22, 0.2, 0.22, 0.24, 0.2]
	var r := 0.335
	for i in xs.size():
		var x: float = xs[i]
		var h: float = lens[i]
		var yc := sqrt(r * r - x * x) * 0.93 - h * 0.5            # đỉnh lọn nằm sát mặt cong của đầu
		var zc := sqrt(maxf(r * r - x * x - yc * yc, 0.0))
		_hadd(s, _cyl(0.06, 0.0, h), c, Vector3(x, yc, zc), Vector3(-14, 0, -x * 100.0), true)
	# lọn tóc hai bên má: một lọn chính dài + một lọn nhỏ phía trước
	var long_hair: bool = o["toc"] == "dai"
	for sx in [-1.0, 1.0]:
		var side_len := 0.5 if long_hair else 0.3
		_hadd(s, _capsule(0.05, side_len), c, Vector3(sx * 0.3, -0.04 - side_len * 0.5 + 0.15, 0.04), Vector3(0, 0, sx * 4))
		_hadd(s, _capsule(0.03, side_len * 0.9), c, Vector3(sx * 0.26, -0.07 - side_len * 0.45 + 0.15, 0.15), Vector3(0, 0, sx * 6))
	match o["toc"]:
		"ngan":
			_hadd(s, _cyl(0.0, 0.03, 0.2), c, Vector3(0.03, 0.44, 0.1), Vector3(-25, 0, 18), true)    # sợi tóc dựng
		"bui":
			_hadd(s, _sphere(0.14), c, Vector3(0, 0.4, -0.06))
			_add(s, _cyl(0.1, 0.1, 0.04), o["trim"], Vector3(0, 0.3, -0.06), Vector3.ZERO, true)       # dây buộc búi
			_add(s, _cyl(0.014, 0.014, 0.38), Color("e0b13f"), Vector3(0, 0.4, -0.06), Vector3(0, 0, 90), true)   # trâm cài
			_hadd(s, _cyl(0.0, 0.03, 0.2), c, Vector3(0.03, 0.46, 0.08), Vector3(-25, 0, 18), true)    # sợi tóc dựng
		"dai":
			_hair_back = Node3D.new()
			_hair_back.position = Vector3(0, 0.12, -0.2)
			s.add_child(_hair_back)
			var back := _hadd(_hair_back, _capsule(0.2, 0.95), c, Vector3(0, -0.37, -0.02))
			back.scale = Vector3(1.15, 1.0, 0.7)
			for tip in [[-0.1, 0.2], [0.0, 0.26], [0.1, 0.2]]:   # ba chóp tóc nhọn ở đuôi
				_hadd(_hair_back, _cyl(0.07, 0.0, tip[1]), c, Vector3(tip[0], -0.86 - tip[1] * 0.4, -0.02), Vector3.ZERO, true)
			_add(_hair_back, _cyl(0.12, 0.12, 0.05), o["trim"], Vector3(0, -0.25, -0.02), Vector3.ZERO, true)   # dải buộc tóc
		"gai":
			for i in 6:
				var a := TAU * i / 6.0
				_hadd(s, _cyl(0.0, 0.07, 0.3), c, Vector3(sin(a) * 0.2, 0.3, cos(a) * 0.2 - 0.06), Vector3(cos(a) * 40, 0, -sin(a) * 40), true)
			_hadd(s, _cyl(0.0, 0.09, 0.4), c, Vector3(0, 0.42, -0.06), Vector3.ZERO, true)


func _dress_headgear(o: Dictionary) -> void:
	var s: Node3D = _slots["dau"]
	match o["dau"]:
		"dai":
			_add(s, _cyl(0.335, 0.335, 0.06), o["trim"], Vector3(0, 0.15, 0), Vector3.ZERO, true)   # dải buộc tóc
		"mien":
			_add(s, _cyl(0.1, 0.14, 0.1), o["trim"], Vector3(0, 0.36, -0.03), Vector3.ZERO, true)  # kim quan
			_add(s, _cyl(0.014, 0.014, 0.44), o["trim"], Vector3(0, 0.38, -0.03), Vector3(0, 0, 90), true)
			_add(s, _sphere(0.032), Color("e6354e"), Vector3(0, 0.2, 0.29), Vector3.ZERO, false, false)   # ngọc điểm trán


func _dress_back(o: Dictionary) -> void:
	var s: Node3D = _slots["lung"]
	var items: Array = o["lung"]
	if "ao_choang" in items:
		_cape = Node3D.new()
		_cape.position = Vector3(0, 0.44, -0.2)
		s.add_child(_cape)
		_add(_cape, _box(Vector3(0.5, 0.85, 0.03)), o["trim"], Vector3(0, -0.4, 0.0), Vector3.ZERO, true)           # lót + viền
		_add(_cape, _box(Vector3(0.44, 0.79, 0.03)), o["robe"], Vector3(0, -0.4, -0.014), Vector3.ZERO, true)     # mặt ngoài
	if "kiem" in items:
		var sword := Node3D.new()
		sword.position = Vector3(0, 0.25, -0.3)
		sword.rotation_degrees = Vector3(0, 0, 38)
		s.add_child(sword)
		_add(sword, _box(Vector3(0.05, 0.85, 0.02)), Color("dfe9f2"), Vector3(0, 0.1, 0), Vector3.ZERO, true)
		_add(sword, _box(Vector3(0.2, 0.04, 0.04)), Color("e0b13f"), Vector3(0, -0.34, 0), Vector3.ZERO, true)
		_add(sword, _box(Vector3(0.05, 0.2, 0.05)), o["trim"], Vector3(0, -0.47, 0), Vector3.ZERO, true)


## Phụ kiện đeo ở hông: túi vải, ngọc bội có tua, chuông. Đung đưa theo bước chạy (xem _process).
func _dress_accessories(o: Dictionary) -> void:
	var s: Node3D = _slots["phu"]
	var trim: Color = o["trim"]
	var slot := 0
	for item in o["phu"]:
		var x := (-0.27 if slot == 0 else 0.27)
		slot += 1
		var hang := Node3D.new()
		hang.position = Vector3(x, 0.0, 0.13)
		s.add_child(hang)
		_tails.append(hang)
		match item:
			"tui":
				_add(hang, _box(Vector3(0.1, 0.11, 0.055)), Color("8a6a43"), Vector3(0, -0.07, 0), Vector3.ZERO, true)
				_add(hang, _box(Vector3(0.105, 0.04, 0.06)), Color("6b4f34"), Vector3(0, -0.03, 0.002), Vector3.ZERO, true)
			"ngoc", "ngoc_do":
				var jade := Color("6fcf9a") if item == "ngoc" else Color("e0455a")
				_add(hang, _box(Vector3(0.012, 0.1, 0.012)), trim, Vector3(0, -0.05, 0), Vector3.ZERO, false, false)
				_add(hang, _torus(0.02, 0.05), jade, Vector3(0, -0.13, 0), Vector3(90, 0, 0))
				for t in [-1.0, 0.0, 1.0]:
					_add(hang, _box(Vector3(0.012, 0.09, 0.012)), trim, Vector3(t * 0.014, -0.22, 0), Vector3.ZERO, false, false)
			"chuong":
				_add(hang, _box(Vector3(0.01, 0.07, 0.01)), trim, Vector3(0, -0.035, 0), Vector3.ZERO, false, false)
				_add(hang, _sphere(0.04), Color("e0b13f"), Vector3(0, -0.1, 0))


## Giày: mũi hơi cong lên nhô khỏi gấu áo, có đế.
func _dress_shoes(o: Dictionary) -> void:
	for side in ["giay_l", "giay_r"]:
		var s: Node3D = _slots[side]
		_add(s, _capsule(0.075, 0.24), o["giay"], Vector3(0, -0.5, 0.05), Vector3(82, 0, 0))
		_add(s, _sphere(0.04), (o["giay"] as Color).lightened(0.25), Vector3(0, -0.47, 0.17), Vector3.ZERO, false, false)
		_add(s, _box(Vector3(0.15, 0.025, 0.27)), Color("e8e0cc"), Vector3(0, -0.545, 0.05), Vector3.ZERO, true)    # đế giày trắng


# ---------- chuyển động giả lập (không cần file animation) ----------

func set_move(amount: float) -> void:
	move_amount = clampf(amount, 0.0, 1.0)


## Vung tay phải một nhát (thử cho đòn đánh).
func swing() -> void:
	_swing_t = 0.0


func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	_phase += delta * (2.0 + 9.0 * move_amount)
	var m := move_amount
	var sw := sin(_phase)
	_leg_l.rotation.x = sw * 0.75 * m
	_leg_r.rotation.x = -sw * 0.75 * m
	_arm_l.rotation.x = -sw * 0.6 * m
	_arm_l.rotation.z = -0.1 - sin(_time * 2.0) * 0.015
	_arm_r.rotation.z = 0.1 + sin(_time * 2.0) * 0.015
	var arm_r_x := sw * 0.6 * m
	if _swing_t >= 0.0:
		_swing_t += delta
		var u := _swing_t / 0.4
		if u >= 1.0:
			_swing_t = -1.0
		else:
			arm_r_x = lerpf(-2.6, 0.2, u * u) if u > 0.25 else lerpf(0.0, -2.6, u / 0.25)
	_arm_r.rotation.x = arm_r_x
	_visual.position.y = absf(sw) * 0.05 * m
	_torso.scale.y = 1.0 + sin(_time * 2.0) * 0.012
	_head.rotation.z = sin(_phase * 0.5) * 0.04 * m
	if _hair_back != null:
		_hair_back.rotation.x = 0.08 + 0.35 * m + sin(_time * 1.6) * 0.04
	if _cape != null:
		_cape.rotation.x = 0.06 + 0.4 * m + sin(_time * 2.2 + _phase) * 0.05 * (0.4 + m)
	for i in _tails.size():
		_tails[i].rotation.x = 0.1 + 0.6 * m + sin(_time * 3.0 + i) * 0.08


# ---------- tiện ích dựng mesh ----------

func _mat(color: Color, radial := false, ink := true) -> ShaderMaterial:
	var key := color.to_html() + ("r" if radial else "") + ("" if ink else "n")
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	if color == SKIN:
		m.set_shader_parameter("cut", -0.25)   # da chỉ tối ở mặt hướng hẳn xuống, tránh cằm bị bóng như râu
	if ink:
		var ink_mat := ShaderMaterial.new()
		ink_mat.shader = INK
		ink_mat.set_shader_parameter("radial", radial)
		m.next_pass = ink_mat
	_mats[key] = m
	return m


func _add(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, radial := false, ink := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, radial, ink)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Tóc: như _add nhưng có vòng sáng (angel ring) cho giống tranh anime.
func _hadd(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, radial := false) -> MeshInstance3D:
	var mi := _add(parent, mesh, color, pos, rot_deg, radial)
	var key := color.to_html() + ("r" if radial else "") + "h"
	if not _mats.has(key):
		var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("shine", 0.3)
		_mats[key] = m
	mi.material_override = _mats[key]
	return mi


func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 8
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 20
	m.rings = 6
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 16
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
