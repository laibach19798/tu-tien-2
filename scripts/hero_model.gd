extends Node3D
class_name HeroModel
## Nhân vật dùng model thật dựng bằng Blender (tools/blender/make_hero.py -> assets/models/hero.glb): có xương, skin và animation.
## API giống Hero3D (set_outfit, set_move, swing) nên cảnh demo dùng được cả hai. Bộ đồ lấy từ Hero3D.OUTFITS:
## - màu: vật liệu m_<vai trò> trong model được thay bằng shader toon với màu của bộ đồ;
## - hình dạng: mỗi mảnh tên <nhóm>__<chi tiết>, nhóm nào bộ đồ không dùng thì ẩn đi.

const MODEL := preload("res://assets/models/hero.glb")
const TOON := preload("res://scripts/toon3d.gdshader")
const INK := preload("res://scripts/toon3d_ink.gdshader")

const FIXED := {
	"skin": Hero3D.SKIN, "skin_dark": Color("d2a07e"), "sole": Color("e8e0cc"), "ink": Hero3D.EYE_DARK, "white": Color.WHITE,
	"blush": Hero3D.BLUSH, "mouth": Hero3D.MOUTH, "gold": Color("e0b13f"), "steel": Color("dfe9f2"),
	"gourd": Color("c98a3c"), "bamboo": Color("8aa860"),
}
const ROBE_GROUP := {"dai": "robe_long", "trung": "robe_mid", "ngan": "robe_short"}
const HAIR_GROUP := {"ngan": "hair_short", "bui": "hair_bun", "dai": "hair_long", "gai": "hair_spike", "duoi": "hair_ponytail", "song": "hair_twin"}
const HEAD_GROUP := {"dai": "head_band", "mien": "head_crown", "khan": "head_khan", "non": "head_non"}
const BACK_GROUP := {"ao_choang": "back_cape", "kiem": "back_sword"}
const ACC_GROUP := {"tui": "acc_pouch", "ngoc": "acc_jade", "ngoc_do": "acc_jade", "chuong": "acc_bell", "ho_lo": "acc_gourd", "sao": "acc_flute"}

var outfit_id := ""
var move_amount := 0.0   # 0 = đứng yên, 1 = chạy hết tốc độ

var _model: Node3D
var _anim: AnimationPlayer
var _parts: Array[MeshInstance3D] = []
var _roles := {}   # MeshInstance3D -> vai trò vật liệu (bỏ "m_")
var _attacking := false
var _mats := {}


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	_collect(_model)
	_anim = _find_anim(_model)
	if _anim != null:
		_anim.animation_finished.connect(_on_anim_finished)
		_anim.play("idle")
	set_outfit(outfit_id if outfit_id != "" else Hero3D.ORDER[0])


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mat := mi.mesh.surface_get_material(0)
		_parts.append(mi)
		_roles[mi] = String(mat.resource_name).trim_prefix("m_") if mat != null else "skin"
	for c in n.get_children():
		_collect(c)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a != null:
			return a
	return null


# ---------- trang phục ----------

func set_outfit(id: String) -> void:
	if not Hero3D.OUTFITS.has(id):
		return
	outfit_id = id
	if _model == null:
		return   # _ready sẽ gọi lại
	var o: Dictionary = Hero3D.OUTFITS[id]
	var groups := _visible_groups(o)
	_mats.clear()
	for mi in _parts:
		var group := String(mi.name).split("__")[0]
		mi.visible = group in groups
		if mi.visible:
			mi.material_override = _material(_roles[mi], o, group == "face", String(mi.name).begins_with("hair_base__bang") or String(mi.name).begins_with("hair_base__lock"))


func _visible_groups(o: Dictionary) -> Array:
	var g := ["body", "face", "hair_base", "shoes", "robe_top"]
	g.append(ROBE_GROUP[o["dai"]])
	g.append("sleeve_wide" if o["tay"] == "rong" else "sleeve_narrow")
	if o["tay"] == "giap":
		g.append("sleeve_guard")   # hộ tay
	if o.has("quan"):
		g.append("pants")
	g.append(HAIR_GROUP[o["toc"]])
	if HEAD_GROUP.has(o["dau"]):
		g.append(HEAD_GROUP[o["dau"]])
	for item in o["lung"]:
		g.append(BACK_GROUP[item])
	var i := 0
	for item in o["phu"]:
		g.append("%s_%s" % [ACC_GROUP[item], "l" if i == 0 else "r"])
		i += 1
	return g


func _role_color(role: String, o: Dictionary) -> Color:
	match role:
		"robe": return o["robe"]
		"trim": return o["trim"]
		"inner": return o["ao_trong"]
		"hair": return o["toc_mau"]
		"shoe": return o["giay"]
		"eye": return o["mat"]
		"eye_light": return (o["mat"] as Color).lightened(0.4)
		"jade": return Color("e0455a") if "ngoc_do" in o["phu"] else Color("6fcf9a")
		"gem": return Color("e6354e")
		"pants": return o.get("quan", o["robe"])
		"hat": return o.get("non", o["trim"])
	return FIXED.get(role, Color.MAGENTA)


func _material(role: String, o: Dictionary, no_ink: bool, no_shine := false) -> ShaderMaterial:
	var key := role + ("n" if no_ink else "") + ("s" if no_shine else "")
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", _role_color(role, o))
	if role == "skin":
		m.set_shader_parameter("cut", -0.25)   # da chỉ tối ở mặt hướng hẳn xuống
	elif role == "hair" and not no_ink and not no_shine:
		m.set_shader_parameter("shine", 0.16)    # vòng sáng trên tóc (chỉ mũ tóc/tóc dài, lọn mái nhỏ thì tắt)
	if not no_ink:
		var ink := ShaderMaterial.new()
		ink.shader = INK
		m.next_pass = ink
	_mats[key] = m
	return m


# ---------- chuyển động ----------

func set_move(amount: float) -> void:
	move_amount = clampf(amount, 0.0, 1.0)


## Vung kiếm một nhát.
func swing() -> void:
	if _anim != null and not _attacking:
		_attacking = true
		_anim.speed_scale = 1.0
		_anim.play("attack", 0.1)


func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == &"attack":
		_attacking = false


func _process(_delta: float) -> void:
	if _anim == null or _attacking:
		return
	var want := "walk" if move_amount > 0.1 else "idle"
	if _anim.current_animation != want:
		_anim.play(want, 0.2)
	_anim.speed_scale = lerpf(0.8, 1.25, move_amount) if want == "walk" else 1.0
