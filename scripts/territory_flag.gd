extends Node2D
class_name TerritoryFlag
## Cờ địa bàn trong Tiểu Thế Giới: vòng màu theo tông đang giữ, cờ nhuộm màu tông, tên địa bàn. Lại gần nhấn E để cắm cờ / xem thông tin.

var tid := ""
var npc_id := ""          # "flag:<tid>", để main xử lý như một đối tượng tương tác
var display_name := ""
var war: SectWar
var _banner: Sprite2D
var _label: Label
var _marker: Label        # giữ cho khớp giao diện NPC (bản đồ nhỏ, dấu !)
var _t := randf() * 10.0


func setup(p_tid: String, p_war: SectWar) -> void:
	tid = p_tid
	npc_id = "flag:" + p_tid
	war = p_war
	display_name = str(SectWar.territory(p_tid).get("name", ""))


func _ready() -> void:
	var tex: Texture2D = load("res://assets/props/war_banner.png") if ResourceLoader.exists("res://assets/props/war_banner.png") else load("res://assets/props/sign.png")
	_banner = Sprite2D.new()
	_banner.texture = tex
	_banner.centered = false
	_banner.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	add_child(_banner)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(240, 0)
	_label.position = Vector2(-120, -tex.get_height() - 44.0)
	_label.z_index = 160
	add_child(_label)
	refresh()


func set_marker(_kind: String) -> void:
	pass


func owner_id() -> String:
	return war.owner_of(tid)


func refresh() -> void:
	var o := owner_id()
	var col := SectWar.sect_color(o) if o != "" else Color(0.75, 0.75, 0.75)
	_banner.modulate = col.lerp(Color.WHITE, 0.25)
	var tag := SectWar.sect_name(o) if o != "" else "Vô chủ"
	_label.text = "%s\n(%s)" % [display_name, tag]
	_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.45))
	queue_redraw()


func prompt_text() -> String:
	if owner_id() == SectWar.PLAYER:
		return "E: Xem địa bàn %s" % display_name
	return "E: Cắm cờ chiếm %s" % display_name


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if war == null:
		return
	var o := owner_id()
	var col := SectWar.sect_color(o) if o != "" else Color(0.75, 0.75, 0.75)
	var attacked := war.under_attack.has(tid)
	if attacked:
		col = Color(1.0, 0.25, 0.2)
	var pulse := 0.5 + 0.5 * sin(_t * (6.0 if attacked else 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))   # ép dẹt như linh mạch cho hợp góc nhìn 2.5D
	draw_circle(Vector2.ZERO, 124.0, Color(col, 0.07))
	for i in 3:
		var r := 130.0 - i * 6.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col, (0.2 + 0.18 * pulse) if i == 0 else 0.08), 3.0 if i == 0 else 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
