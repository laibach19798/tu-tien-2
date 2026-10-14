extends Node
## Prototype 2.5D: nhân vật 3D low-poly (Hero3D) + camera nghiêng nhìn từ trên xuống + sprite pixel dựng đứng (billboard).
## Chạy: Godot --path . res://scenes/proto3d.tscn
## WASD / mũi tên: đi · 1-4: đổi trang phục · Space: vung tay · Z: bật/tắt độ phân giải thấp (pixel hoá)

const PIXEL_SHRINK := 3          # cảnh 3D render ở 1/3 độ phân giải rồi phóng to bằng nearest -> nhân vật ra "pixel" hợp với sprite
const SPEED := 4.0
const CAM_OFFSET := Vector3(0, 8.6, 11.0)   # nhìn xuống ~38° (camera chiếu trực giao)
const CAM_SIZE := 5.0
const WORLD_LIMIT := 28.0
## Prop sprite pixel có sẵn của game, đặt đứng bằng Sprite3D billboard (kiểu HD-2D).
const PROPS := [
	["bush_a", Vector3(-3.5, 0, -2)], ["bush_c", Vector3(4.2, 0, -4)], ["bamboo_a", Vector3(-5.5, 0, -6)],
	["bamboo_b", Vector3(5.8, 0, 1)], ["barrel_a", Vector3(3.0, 0, 3.5)], ["bush_d", Vector3(-4.8, 0, 4)],
	["bamboo_a", Vector3(-7.5, 0, 0.5)], ["bush_b", Vector3(7.5, 0, -7)], ["barrel_b", Vector3(-2.2, 0, 6.5)],
]

var world: Node3D
var cam: Camera3D
var hero: Hero3D
var container: SubViewportContainer
var label: Label
var outfit_idx := 0


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = PIXEL_SHRINK
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(container)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.handle_input_locally = false
	container.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	_build_world()
	_build_hud(layer)
	_refresh_label()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9c4d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f8cb4")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -28, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	world.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://scripts/toon3d_ground.gdshader")
	ground.material_override = gm
	world.add_child(ground)

	for p in PROPS:
		_add_prop(p[0], p[1])

	hero = Hero3D.new()
	world.add_child(hero)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.near = 0.1
	cam.far = 80.0
	cam.rotation_degrees = Vector3(-38, 0, 0)
	cam.position = CAM_OFFSET
	world.add_child(cam)


func _add_prop(name: String, pos: Vector3) -> void:
	var path := "res://assets/props/%s.png" % name
	if not ResourceLoader.exists(path):
		return
	var spr := Sprite3D.new()
	spr.texture = load(path)
	spr.pixel_size = 0.03
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	spr.offset = Vector2(0, spr.texture.get_height() * 0.5)   # gốc sprite ở chân
	spr.position = pos
	world.add_child(spr)


func _build_hud(layer: CanvasLayer) -> void:
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 660)
	layer.add_child(row)
	for i in Hero3D.ORDER.size():
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, Hero3D.OUTFITS[Hero3D.ORDER[i]]["ten"]]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_outfit_index.bind(i))
		row.add_child(b)


func set_outfit_index(i: int) -> void:
	outfit_idx = posmod(i, Hero3D.ORDER.size())
	hero.set_outfit(Hero3D.ORDER[outfit_idx])
	_refresh_label()


func _refresh_label() -> void:
	var o: Dictionary = Hero3D.OUTFITS[Hero3D.ORDER[outfit_idx]]
	label.text = "Prototype 2.5D · %s\nWASD đi · 1-4 đổi bộ · Space vung tay · Z pixel hoá (%s)" % [
		o["ten"], "bật" if container.stretch_shrink > 1 else "tắt"]


func _physics_process(delta: float) -> void:
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		hero.position += Vector3(dir.x, 0, dir.y) * SPEED * delta
		hero.position.x = clampf(hero.position.x, -WORLD_LIMIT, WORLD_LIMIT)
		hero.position.z = clampf(hero.position.z, -WORLD_LIMIT, WORLD_LIMIT)
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(dir.x, dir.y), minf(1.0, 14.0 * delta))
	hero.set_move(lerpf(hero.move_amount, dir.length(), minf(1.0, 12.0 * delta)))
	cam.position = cam.position.lerp(hero.position + CAM_OFFSET, minf(1.0, 6.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_outfit_index(event.physical_keycode - KEY_1)
		KEY_SPACE:
			hero.swing()
		KEY_Z:
			container.stretch_shrink = 1 if container.stretch_shrink > 1 else PIXEL_SHRINK
			_refresh_label()
