extends Node3D
class_name Hero3D
## Nhân vật 3D low-poly (chibi) dựng từ khối cơ bản, tô toon + viền mực. Mặt trước của mô hình là +Z.
## Trang phục = bộ khối gắn vào các pivot của xương giả (thân, đầu, tay, chân) nên đổi bộ KHÔNG cần vẽ lại animation:
## thêm một bộ mới = thêm một entry vào OUTFITS.

const TOON := preload("res://scripts/toon3d.gdshader")
const INK := preload("res://scripts/toon3d_ink.gdshader")

const SKIN := Color("f3cfae")

## Mỗi bộ: ten = tên hiển thị; robe/trim = màu áo/viền; dai = chiều dài áo ("dai" hoặc "ngan");
## tay = ống tay ("rong" hoặc "hep"); toc/toc_mau = kiểu và màu tóc; dau = phụ kiện đầu; lung = đồ đeo sau lưng; mat = màu mắt.
const OUTFITS := {
	"ao_vai": {
		"ten": "Áo Vải Tạp Dịch", "robe": Color("a98b64"), "trim": Color("6b4f34"),
		"dai": "ngan", "tay": "hep", "toc": "ngan", "toc_mau": Color("2a2023"),
		"dau": "dai", "lung": [], "mat": Color("1a1418"),
	},
	"dao_bao": {
		"ten": "Đạo Bào Thanh Vân", "robe": Color("3f7fa8"), "trim": Color("e8e2cf"),
		"dai": "dai", "tay": "rong", "toc": "bui", "toc_mau": Color("231c26"),
		"dau": "none", "lung": ["kiem"], "mat": Color("1a1418"),
	},
	"tien_bao": {
		"ten": "Tiên Bào Bạch Vân", "robe": Color("f1efe6"), "trim": Color("d9a93a"),
		"dai": "dai", "tay": "rong", "toc": "dai", "toc_mau": Color("9fa9cc"),
		"dau": "mien", "lung": ["ao_choang", "kiem"], "mat": Color("3a5f8f"),
	},
	"ma_y": {
		"ten": "Huyết Ma Y", "robe": Color("2a2230"), "trim": Color("b32a3a"),
		"dai": "dai", "tay": "rong", "toc": "gai", "toc_mau": Color("120d16"),
		"dau": "none", "lung": ["ao_choang"], "mat": Color("e0334a"),
	},
}
const ORDER := ["ao_vai", "dao_bao", "tien_bao", "ma_y"]

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
	_torso_mi = _add(_torso, _capsule(0.2, 0.5), SKIN, Vector3(0, 0.25, 0))

	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, 0)
	_torso.add_child(_head)
	_add(_head, _sphere(0.32), SKIN)
	for sx in [-1.0, 1.0]:
		_add(_head, _sphere(0.045), Color.WHITE, Vector3(sx * 0.115, -0.01, 0.285)).name = "Eye"

	_leg_l = _make_leg(-0.11)
	_leg_r = _make_leg(0.11)
	_arm_l = _make_arm(-0.27)
	_arm_r = _make_arm(0.27)

	for slot in ["toc", "ao", "dau", "lung", "tay_l", "tay_r"]:
		_slots[slot] = Node3D.new()
	_head.add_child(_slots["toc"])
	_head.add_child(_slots["dau"])
	_torso.add_child(_slots["ao"])
	_torso.add_child(_slots["lung"])
	_arm_l.add_child(_slots["tay_l"])
	_arm_r.add_child(_slots["tay_r"])


func _make_leg(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0, 0)
	_torso.add_child(pivot)
	_add(pivot, _capsule(0.085, 0.55), SKIN, Vector3(0, -0.27, 0))
	return pivot


func _make_arm(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.42, 0)
	_torso.add_child(pivot)
	_add(pivot, _capsule(0.065, 0.38), SKIN, Vector3(0, -0.15, 0))
	_add(pivot, _sphere(0.075), SKIN, Vector3(0, -0.34, 0))
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
	_torso_mi.material_override = _mat(o["robe"])
	for eye in _head.get_children():
		if eye.name.begins_with("Eye"):
			(eye as MeshInstance3D).material_override = _mat(o["mat"])
	_dress_robe(o)
	_dress_sleeves(o)
	_dress_hair(o)
	_dress_headgear(o)
	_dress_back(o)


func _dress_robe(o: Dictionary) -> void:
	var s: Node3D = _slots["ao"]
	var robe: Color = o["robe"]
	var trim: Color = o["trim"]
	if o["dai"] == "dai":
		_add(s, _cyl(0.21, 0.37, 0.6), robe, Vector3(0, -0.23, 0), Vector3.ZERO, true)
		_add(s, _cyl(0.375, 0.375, 0.05), trim, Vector3(0, -0.5, 0), Vector3.ZERO, true)   # viền gấu áo
	else:
		_add(s, _cyl(0.21, 0.28, 0.2), robe, Vector3(0, -0.03, 0), Vector3.ZERO, true)
	_add(s, _cyl(0.215, 0.215, 0.07), trim, Vector3(0, 0.02, 0), Vector3.ZERO, true)       # đai lưng
	_add(s, _sphere(0.06), trim, Vector3(0, 0.0, 0.21))                                     # nút thắt đai
	_add(s, _cyl(0.17, 0.19, 0.06), trim, Vector3(0, 0.46, 0), Vector3.ZERO, true)          # cổ áo


func _dress_sleeves(o: Dictionary) -> void:
	var robe: Color = o["robe"]
	var trim: Color = o["trim"]
	for side in ["tay_l", "tay_r"]:
		var s: Node3D = _slots[side]
		if o["tay"] == "rong":
			_add(s, _cyl(0.08, 0.15, 0.34), robe, Vector3(0, -0.17, 0), Vector3.ZERO, true)
			_add(s, _cyl(0.152, 0.152, 0.045), trim, Vector3(0, -0.33, 0), Vector3.ZERO, true)
		else:
			_add(s, _cyl(0.078, 0.078, 0.26), robe, Vector3(0, -0.13, 0), Vector3.ZERO, true)


func _dress_hair(o: Dictionary) -> void:
	var s: Node3D = _slots["toc"]
	var c: Color = o["toc_mau"]
	_add(s, _sphere(0.335), c, Vector3(0, 0.05, -0.06))                                     # mũ tóc phủ đỉnh và sau đầu
	var mai := _add(s, _sphere(0.2), c, Vector3(0, 0.2, 0.17), Vector3(-15, 0, 0))               # mái
	mai.scale = Vector3(1.05, 0.42, 0.7)
	match o["toc"]:
		"bui":
			_add(s, _sphere(0.13), c, Vector3(0, 0.4, -0.05))
			_add(s, _cyl(0.014, 0.014, 0.36), Color("d9a93a"), Vector3(0, 0.4, -0.05), Vector3(0, 0, 90), true)   # trâm cài
		"dai":
			_hair_back = Node3D.new()
			_hair_back.position = Vector3(0, 0.1, -0.2)
			s.add_child(_hair_back)
			_add(_hair_back, _capsule(0.2, 0.9), c, Vector3(0, -0.36, -0.02))
		"gai":
			for i in 6:
				var a := TAU * i / 6.0
				var spike := _cyl(0.0, 0.07, 0.3)
				_add(s, spike, c, Vector3(sin(a) * 0.2, 0.3, cos(a) * 0.2 - 0.06), Vector3(cos(a) * 40, 0, -sin(a) * 40), true)
			_add(s, _cyl(0.0, 0.09, 0.4), c, Vector3(0, 0.42, -0.06), Vector3.ZERO, true)


func _dress_headgear(o: Dictionary) -> void:
	var s: Node3D = _slots["dau"]
	match o["dau"]:
		"dai":
			_add(s, _cyl(0.325, 0.325, 0.07), o["trim"], Vector3(0, 0.13, 0), Vector3.ZERO, true)   # dải buộc tóc
		"mien":
			_add(s, _cyl(0.12, 0.15, 0.1), o["trim"], Vector3(0, 0.36, -0.02), Vector3.ZERO, true)  # kim quan
			_add(s, _cyl(0.014, 0.014, 0.44), o["trim"], Vector3(0, 0.38, -0.02), Vector3(0, 0, 90), true)


func _dress_back(o: Dictionary) -> void:
	var s: Node3D = _slots["lung"]
	var items: Array = o["lung"]
	if "ao_choang" in items:
		_cape = Node3D.new()
		_cape.position = Vector3(0, 0.44, -0.2)
		s.add_child(_cape)
		_add(_cape, _box(Vector3(0.5, 0.85, 0.03)), o["trim"], Vector3(0, -0.4, -0.01), Vector3.ZERO, true)
		_add(_cape, _box(Vector3(0.46, 0.8, 0.032)), o["robe"], Vector3(0, -0.4, 0.0), Vector3.ZERO, true)
	if "kiem" in items:
		var sword := Node3D.new()
		sword.position = Vector3(0, 0.25, -0.3)
		sword.rotation_degrees = Vector3(0, 0, 38)
		s.add_child(sword)
		_add(sword, _box(Vector3(0.05, 0.85, 0.02)), Color("dfe9f2"), Vector3(0, 0.1, 0), Vector3.ZERO, true)
		_add(sword, _box(Vector3(0.2, 0.04, 0.04)), Color("d9a93a"), Vector3(0, -0.34, 0), Vector3.ZERO, true)
		_add(sword, _box(Vector3(0.05, 0.2, 0.05)), o["trim"], Vector3(0, -0.47, 0), Vector3.ZERO, true)


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


# ---------- tiện ích dựng mesh ----------

func _mat(color: Color, radial := false) -> ShaderMaterial:
	var key := color.to_html() + ("r" if radial else "")
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	var ink := ShaderMaterial.new()
	ink.shader = INK
	ink.set_shader_parameter("radial", radial)
	m.next_pass = ink
	_mats[key] = m
	return m


func _add(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, radial := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, radial)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 14
	m.rings = 4
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
