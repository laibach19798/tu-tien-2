extends Node2D
## Đệ tử luyện công trong sân tông: luyện kiếm (vung binh khí lặp lại, dùng nhân vật nền có sẵn)
## hoặc đả tọa hấp thụ linh khí (sprite ngồi thiền riêng từ Pixellab, nhuộm theo màu linh khí của tông).
## Thuần trang trí: không vào group "targets", không nhiệm vụ, không chặn đường.

const SIT_TEXTURE := preload("res://assets/props/disciple_sit.png")

var outfit: Dictionary = {}
var mode := "spar"   # "spar": lặp lại play_oneshot("slash") | "meditate": ngồi thiền, hào quang linh khí
var glow := Color(0.5, 0.9, 1.0)
var facing := "south"
var body: Node2D       # chỉ dùng cho mode "spar" (nhân vật nền đầy đủ: thân/tóc/áo)
var _sitter: Sprite2D  # chỉ dùng cho mode "meditate"
var _t := 0.0
var _next := 0.0
var _ring: Polygon2D


func _ready() -> void:
	var shadow := Shadow.make(15.0, 6.0, 0.3)
	add_child(shadow)
	if mode == "meditate":
		_build_sitter()
		_build_aura()
	else:
		body = load("res://character/hd/base_character.tscn").instantiate()
		Wardrobe.apply(body, outfit)
		add_child(body)
		body.set_motion("idle", facing)
	_next = randf_range(0.6, 2.6)


## Luyện kiếm: lặp một nhát chém chậm rãi, hồi lại tư thế đứng giữa các nhịp.
## Đả tọa: nhấp nhô rất nhẹ như đang điều tức, vòng linh khí dưới chân mờ tỏ theo nhịp thở.
func _process(delta: float) -> void:
	_t += delta
	if mode == "spar":
		if not body.is_busy():
			_next -= delta
			if _next <= 0.0:
				if not body.play_oneshot("slash", facing, 0.55):
					mode = "idle"   # bộ trang phục không có khung slash: đứng yên, không thử lại
				_next = randf_range(2.0, 3.2)
	elif mode == "meditate":
		_sitter.position.y = -27.0 + sin(_t * 0.9) * 1.0
		if _ring != null:
			_ring.color = Color(glow, 0.32 + 0.22 * sin(_t * 1.6))
			_ring.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 1.6))


## Sprite ngồi thiền riêng (assets/props/disciple_sit.png), nhuộm màu theo linh khí của tông
## bằng cùng shader dùng để nhuộm mái điện (scripts/outfit_dye.gdshader).
func _build_sitter() -> void:
	_sitter = Sprite2D.new()
	_sitter.texture = SIT_TEXTURE
	_sitter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sitter.position = Vector2(0, -27)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/outfit_dye.gdshader")
	mat.set_shader_parameter("hue", glow.h * 360.0)
	mat.set_shader_parameter("sat_mul", 1.0)
	mat.set_shader_parameter("val_mul", 1.0)
	_sitter.material = mat
	add_child(_sitter)


## Vòng linh khí dưới chân + linh khí li ti bay lên: biểu thị đang hấp thụ linh khí tu luyện.
func _build_aura() -> void:
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.42) * 22.0)
	_ring.polygon = pts
	_ring.color = Color(glow, 0.32)
	_ring.material = Fx.additive()
	_ring.z_index = -1
	add_child(_ring)
	var motes := CPUParticles2D.new()
	motes.amount = 10
	motes.lifetime = 2.4
	motes.preprocess = 2.4
	motes.position = Vector2(0, -20)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 16.0
	motes.direction = Vector2.UP
	motes.spread = 20.0
	motes.gravity = Vector2(0, -14)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 16.0
	motes.scale_amount_min = 1.6
	motes.scale_amount_max = 2.6
	motes.color = Color(glow, 0.75)
	motes.material = Fx.additive()
	add_child(motes)
