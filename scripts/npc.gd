extends Node2D
## NPC: dùng lại nhân vật nền, nhuộm màu khác, có tên và dấu nhiệm vụ (! / ?) phía trên.

var npc_id := ""
var display_name := ""
var outfit: Dictionary = {}
var _marker: Label
var _t := 0.0


func setup(id: String, p_name: String, p_outfit: Dictionary) -> void:
	npc_id = id
	display_name = p_name
	outfit = p_outfit


func _ready() -> void:
	var shadow := Shadow.make(16.0, 6.4, 0.34)
	shadow.position = Vector2(2, 0)
	add_child(shadow)
	var body: Node2D = load("res://character/hd/base_character.tscn").instantiate()
	Wardrobe.apply(body, outfit)
	add_child(body)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.position = Vector2(-70, -88)
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	_marker = Label.new()
	_marker.add_theme_font_size_override("font_size", 36)
	_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	_marker.add_theme_constant_override("outline_size", 6)
	_marker.position = Vector2(-10, -122)
	_marker.visible = false
	add_child(_marker)


func set_marker(kind: String) -> void:
	if _marker == null:
		return
	_marker.visible = kind != ""
	_marker.text = kind
	_marker.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2) if kind == "!" else Color(0.5, 1.0, 0.5))


func _process(delta: float) -> void:
	_t += delta
	if _marker:
		_marker.position.y = -122.0 + sin(_t * 4.0) * 3.0
