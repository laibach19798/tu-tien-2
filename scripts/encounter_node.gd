extends Node2D
class_name EncounterNode
## Một cơ duyên trên bản đồ (kỳ ngộ, cổng động phủ, bia/rune/di hài trong động phủ).
## Đứng chung danh sách `main.npcs` để dùng lại cơ chế tương tác E và gợi ý; lựa chọn do `Destiny` xử lý.

var enc_id := ""
var data: Dictionary = {}
var display_name := ""
var kind := "orb"            # orb | sitter | figure | relic | gate | stone
var glow := Color(0.7, 0.9, 1.0)
var outfit: Dictionary = {}
var life := -1.0             # giây còn lại trước khi biến mất (< 0: không hết hạn)
# tương thích với vòng lặp NPC của main / minimap / quest
var npc_id := ""
var _marker: Label = null
var _facing := "south"
var _t := 0.0
var _ring: Polygon2D
var _body: Node2D


func setup(p_id: String, p_data: Dictionary) -> void:
	enc_id = p_id
	data = p_data
	npc_id = "destiny_" + p_id
	display_name = str(p_data.get("name", p_id))
	kind = str(p_data.get("kind", "orb"))
	var g: Array = p_data.get("glow", [0.7, 0.9, 1.0])
	glow = Color(float(g[0]), float(g[1]), float(g[2]))
	outfit = p_data.get("outfit", {})


## Hình người: đi hoặc đứng nhìn theo hướng dir (dùng cho NPC lang thang).
func set_walk(dir: Vector2, moving: bool) -> void:
	if _body != null and kind == "figure" and _body.has_method("set_motion"):
		_facing = Dir.from_vector(dir, _facing)
		_body.set_motion("walk" if moving else "idle", _facing)


func set_marker(_kind: String) -> void:
	pass   # cơ duyên không có dấu ! / ?


func prompt_text() -> String:
	return "E: " + str(data.get("prompt", "Quan sát"))


func _ready() -> void:
	var shadow := Shadow.make(15.0, 6.0, 0.3)
	add_child(shadow)
	match kind:
		"sitter":
			var spr := Sprite2D.new()
			spr.texture = load("res://assets/props/disciple_sit.png")
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(0, -27)
			spr.modulate = Color(0.72, 0.74, 0.8)   # xám tro: đã khuất từ lâu
			add_child(spr)
			_body = spr
		"figure":
			var body: Node2D = load("res://character/hd/base_character.tscn").instantiate()
			Wardrobe.apply(body, outfit)
			add_child(body)
			body.set_motion("idle", "south")
			_body = body
		"relic":
			var tex := load("res://assets/props/xt_sword.png") as Texture2D
			if tex != null:
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.position = Vector2(0, -tex.get_height() * 0.45)
				spr.modulate = Color(0.75, 0.6, 0.6)
				add_child(spr)
				_body = spr
		"prop":
			var ptex := load(str(data.get("sprite", ""))) as Texture2D
			if ptex != null:
				var ps := Sprite2D.new()
				ps.texture = ptex
				ps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ps.scale = Vector2(1.5, 1.5)
				ps.position = Vector2(0, -ptex.get_height() * 0.5 * 1.5 + 8.0)
				add_child(ps)
				_body = ps
		_:
			pass   # orb / stone / gate: chỉ có quầng sáng và ký hiệu vẽ bằng _draw
	_ring = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a) * 0.42) * (30.0 if kind != "gate" else 46.0))
	_ring.polygon = pts
	_ring.color = Color(glow, 0.3)
	_ring.material = Fx.additive()
	_ring.z_index = -1
	add_child(_ring)
	var l := Label.new()
	l.text = display_name
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", glow.lerp(Color.WHITE, 0.55))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(200, 0)
	l.position = Vector2(-100, -92 if kind in ["figure", "sitter", "prop"] else -70)
	l.z_index = 5
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	if _ring != null:
		_ring.color = Color(glow, 0.22 + 0.2 * sin(_t * 1.8))
	if life >= 0.0:
		life -= delta
		if life <= 0.0:
			var d := get_tree().get_first_node_in_group("destiny")
			if d != null:
				d.expire(self)
			else:
				queue_free()
	queue_redraw()


func _draw() -> void:
	if kind in ["figure", "sitter", "relic"] or (kind == "prop" and _body != null):
		return
	var pulse := 0.75 + 0.25 * sin(_t * 2.4)
	if kind == "gate":
		# vòm cửa động tối với viền sáng
		var pts := PackedVector2Array([Vector2(-34, 0), Vector2(-34, -42), Vector2(-20, -66), Vector2(0, -74), Vector2(20, -66), Vector2(34, -42), Vector2(34, 0)])
		draw_colored_polygon(pts, Color(0.04, 0.04, 0.07, 0.95))
		draw_polyline(pts, Color(glow, 0.9 * pulse), 3.0)
		return
	if kind == "pool":
		var rr := float(data.get("r", 150.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, rr, Color(0.35, 0.02, 0.06, 0.8))
		draw_circle(Vector2.ZERO, rr * 0.8, Color(0.6, 0.05, 0.1, 0.55 + 0.15 * pulse))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(glow, 0.9 * pulse), 3.0)
		for i in 5:
			var a := _t * 0.6 + float(i) * 1.7
			draw_circle(Vector2(cos(a), sin(a)) * rr * (0.3 + 0.1 * float(i)), 5.0 + 2.0 * sin(_t * 2.0 + float(i)), Color(1.0, 0.4, 0.45, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if kind == "stone":
		draw_rect(Rect2(-14, -44, 28, 44), Color(0.34, 0.34, 0.4))
		draw_rect(Rect2(-14, -44, 28, 44), Color(0.1, 0.1, 0.14), false, 2.0)
		draw_circle(Vector2(0, -26), 8.0, Color(glow, 0.9 * pulse))
		draw_circle(Vector2(0, -26), 3.0, Color(1, 1, 1, 0.9))
		return
	draw_circle(Vector2(0, -22), 11.0, Color(glow, 0.55 * pulse))
	draw_circle(Vector2(0, -22), 6.0, Color(1, 1, 1, 0.9))
	draw_line(Vector2(0, -50), Vector2(0, -34), Color(glow, 0.7 * pulse), 2.0)
