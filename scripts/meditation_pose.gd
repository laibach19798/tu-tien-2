extends Node2D
class_name MeditationPose
## Tư thế ngồi thiền của người chơi: khi bấm F, nhân vật nền được ẩn đi và thay bằng sprite ngồi
## (assets/props/disciple_sit.png) nhuộm theo màu áo đang mặc, có vòng linh khí và linh khí bay lên.
## Nhân vật nền có nhiều lớp trang phục nên không thể vẽ sẵn mọi bộ ở tư thế ngồi; sprite ngồi lấy màu chủ đạo của áo.

const SIT_TEXTURE := preload("res://assets/props/disciple_sit.png")
## Màu chủ đạo theo kiểu áo (style trong Wardrobe.ITEMS): [hue, sat_mul, val_mul]; thiếu thì giữ màu gốc của sprite.
const STYLE_DYE := {
	"do": [355.0, 1.15, 1.0], "luc": [115.0, 1.05, 1.0], "tim": [275.0, 1.0, 1.0], "thanh": [178.0, 1.05, 1.0],
	"lam": [215.0, 1.1, 1.0], "trang": [205.0, 0.12, 1.35], "xam": [215.0, 0.1, 0.9], "vang": [45.0, 1.1, 1.1],
}

var _sprite: Sprite2D
var _ring: Polygon2D
var _motes: CPUParticles2D
var _shadow: Polygon2D
var _t := 0.0
var _glow := Color(0.5, 0.9, 1.0)


func _ready() -> void:
	visible = false
	z_index = 0
	_shadow = Shadow.make(16.0, 6.4, 0.34)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = SIT_TEXTURE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -27)
	add_child(_sprite)
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.42) * 26.0)
	_ring.polygon = pts
	_ring.color = Color(_glow, 0.35)
	_ring.material = Fx.additive()
	_ring.z_index = -1
	add_child(_ring)
	_motes = CPUParticles2D.new()
	_motes.amount = 14
	_motes.lifetime = 2.4
	_motes.preprocess = 2.4
	_motes.position = Vector2(0, -22)
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 18.0
	_motes.direction = Vector2.UP
	_motes.spread = 20.0
	_motes.gravity = Vector2(0, -16)
	_motes.initial_velocity_min = 8.0
	_motes.initial_velocity_max = 18.0
	_motes.scale_amount_min = 1.6
	_motes.scale_amount_max = 2.8
	_motes.color = Color(_glow, 0.8)
	_motes.material = Fx.additive()
	add_child(_motes)


## on: bật/tắt tư thế; pos: vị trí chân người chơi; dye: {hue, sat_mul, val_mul} hoặc rỗng; sc: tỉ lệ nhân vật.
func apply(on: bool, pos: Vector2, dye: Dictionary, glow: Color, sc: float) -> void:
	if on != visible:
		visible = on
		_motes.emitting = on
		if on:
			_t = 0.0
	if not on:
		return
	position = pos
	scale = Vector2.ONE * sc
	if dye.is_empty():
		_sprite.material = null
	else:
		var mat := _sprite.material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = load("res://scripts/outfit_dye.gdshader")
			_sprite.material = mat
		mat.set_shader_parameter("hue", float(dye["hue"]))
		mat.set_shader_parameter("sat_mul", float(dye["sat_mul"]))
		mat.set_shader_parameter("val_mul", float(dye["val_mul"]))
	_glow = glow


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_sprite.position.y = -27.0 + sin(_t * 0.9) * 1.0   # nhấp nhô rất nhẹ như đang điều tức
	_ring.color = Color(_glow, 0.32 + 0.22 * sin(_t * 1.6))
	_ring.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 1.6))


## Màu nhuộm cho sprite ngồi theo trang phục đang mặc: thuốc nhuộm (nếu có) rồi đến kiểu áo.
static func dye_for(equipped: Dictionary) -> Dictionary:
	var clothes: Dictionary = Wardrobe.ITEMS.get(str(equipped.get("clothes", "")), {})
	var dye_item: Dictionary = Wardrobe.ITEMS.get(str(equipped.get("dye", "")), {})
	if bool(clothes.get("dyeable", false)) and not dye_item.is_empty():
		return {"hue": float(dye_item["hue"]), "sat_mul": float(dye_item["sat_mul"]), "val_mul": float(dye_item["val_mul"])}
	var st: Array = STYLE_DYE.get(str(clothes.get("style", "")), [])
	if st.is_empty():
		return {}
	return {"hue": float(st[0]), "sat_mul": float(st[1]), "val_mul": float(st[2])}
