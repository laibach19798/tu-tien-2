extends CanvasLayer
## Giao diện thời trang: "shop" (tiệm may: mua + mặc thử) và "closet" (tủ đồ: chỉ đồ đã có).
## Bên phải là bệ trưng bày nhân vật, xoay được 8 hướng.

var wardrobe: Wardrobe
var inv: Inventory
var mode := "shop"

var _tab := "clothes"
var _rows: VBoxContainer
var _tab_buttons := {}
var _stones: Label
var _title: UIKit.Banner
var _panel: UIKit.Frame
var _dim: ColorRect
var _preview_root: Node2D
var _preview: Node2D
var _preview_name: Label
var _right: Control
var _preview_outfit: Dictionary = {}
var _dirs := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
var _dir_i := 0
var _dir_names := {"south": "Chính diện", "south-east": "Chéo phải", "east": "Mặt phải", "north-east": "Chéo sau phải", "north": "Phía sau", "north-west": "Chéo sau trái", "west": "Mặt trái", "south-west": "Chéo trái"}


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_panel = UIKit.Frame.new(Vector2(600, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = 36
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_title = UIKit.Banner.new("", 24)
	v.add_child(_title)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
	_stones = UIKit.label("0", 18, UIKit.STONE_TXT)
	top.add_child(_stones)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(UIKit.KeyCap.new("Esc", "Đóng", 13))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for slot in Wardrobe.SLOTS:
		var b := Button.new()
		b.text = "  " + Wardrobe.SLOT_NAMES[slot]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = slot == _tab
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(slot))
		tabs.add_child(b)
		_tab_buttons[slot] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	# Bệ trưng bày (bên phải)
	_preview_root = Node2D.new()
	add_child(_preview_root)
	_preview_root.add_child(Stage.new())
	var floor_shadow := Shadow.make(80.0, 22.0, 0.4)
	floor_shadow.position = Vector2(0, 112)
	_preview_root.add_child(floor_shadow)
	_preview = load("res://character/hd/base_character.tscn").instantiate()
	_preview.scale = Vector2.ONE * 3.5
	_preview.position = Vector2(0, 120)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_root.add_child(_preview)
	_right = Control.new()
	add_child(_right)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(300, 0)
	vb.position = Vector2(-150, 156)
	_right.add_child(vb)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK, 0.85), Color(UIKit.GOLD_DK, 0.8), 1, 8, Vector2(12, 6)))
	vb.add_child(plate)
	_preview_name = UIKit.label("", 14, UIKit.GOLD)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate.add_child(_preview_name)
	var rot := HBoxContainer.new()
	rot.add_theme_constant_override("separation", 8)
	vb.add_child(rot)
	var prev := Button.new()
	prev.text = "◀"
	prev.focus_mode = Control.FOCUS_NONE
	prev.custom_minimum_size = Vector2(52, 36)
	prev.pressed.connect(_rotate.bind(-1))
	rot.add_child(prev)
	var hint := UIKit.label("Xoay nhân vật (A / D)", 13, UIKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rot.add_child(hint)
	var nxt := Button.new()
	nxt.text = "▶"
	nxt.focus_mode = Control.FOCUS_NONE
	nxt.custom_minimum_size = Vector2(52, 36)
	nxt.pressed.connect(_rotate.bind(1))
	rot.add_child(nxt)
	_place_preview()
	get_viewport().size_changed.connect(_place_preview)


func _place_preview() -> void:
	var s := get_viewport().get_visible_rect().size
	_preview_root.position = Vector2(s.x * 0.76, s.y * 0.42)
	_right.position = _preview_root.position


func is_open() -> bool:
	return visible


func open_ui(p_mode: String) -> void:
	mode = p_mode
	_title.set_text("Tiệm May · Tô Nương" if mode == "shop" else "Tủ Đồ")
	_preview_outfit = wardrobe.equipped.duplicate()
	_dir_i = 0
	visible = true
	_refresh_preview()
	refresh()


func close_ui() -> void:
	visible = false


func _set_tab(slot: String) -> void:
	_tab = slot
	refresh()


func _rotate(step := 1) -> void:
	_dir_i = (_dir_i + step + _dirs.size()) % _dirs.size()
	_refresh_preview()


func _refresh_preview() -> void:
	Wardrobe.apply(_preview, _preview_outfit)
	_preview.set_motion("idle", _dirs[_dir_i])
	var parts: Array = []
	for slot in Wardrobe.SLOTS:
		var id: String = _preview_outfit.get(slot, "")
		if id != "" and Wardrobe.ITEMS.has(id):
			parts.append(Wardrobe.ITEMS[id]["name"])
	_preview_name.text = "%s\n%s" % [_dir_names[_dirs[_dir_i]], "\n".join(parts)]


func refresh() -> void:
	if not visible or wardrobe == null:
		return
	_stones.text = "%d  linh thạch" % inv.stones
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var any := false
	for id in Wardrobe.items_of(_tab):
		var d: Dictionary = Wardrobe.ITEMS[id]
		var own := wardrobe.is_owned(id)
		if mode == "closet" and not own:
			continue
		any = true
		_rows.add_child(_card(id, d, own))
	if not any:
		_rows.add_child(UIKit.label("Chưa có món nào.", 15, UIKit.MUTED))


func _card(id: String, d: Dictionary, own: bool) -> Control:
	var trying: bool = _preview_outfit.get(_tab, "") == id
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.JADE if trying else Color(UIKit.GOLD_DK, 0.6), 2 if trying else 1, 6, Vector2(10, 8)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	var kind := str(d["slot"])
	var tint: Color = d["tint"]
	h.add_child(UIKit.Icon.new(kind, tint, 48.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	h.add_child(col)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 8)
	nrow.add_child(UIKit.label(str(d["name"]), 16, UIKit.GOLD))
	if own:
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.JADE_DK, 0.9), UIKit.JADE, 1, 8, Vector2(7, 0)))
		tag.add_child(UIKit.label("Đã có", 12, UIKit.JADE))
		nrow.add_child(tag)
	col.add_child(nrow)
	var dl := UIKit.label(str(d["desc"]), 13, UIKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(200, 0)
	col.add_child(dl)
	var try_b := Button.new()
	try_b.text = "Thử"
	try_b.focus_mode = Control.FOCUS_NONE
	try_b.pressed.connect(_try.bind(id))
	h.add_child(try_b)
	var act := Button.new()
	act.focus_mode = Control.FOCUS_NONE
	act.custom_minimum_size = Vector2(104, 0)
	if wardrobe.is_equipped(id):
		act.text = "Đang mặc"
		act.disabled = true
	elif own:
		act.text = "Mặc"
		act.pressed.connect(_equip.bind(id))
	else:
		act.text = "Mua · %d" % int(d["price"])
		act.disabled = inv.stones < int(d["price"])
		act.pressed.connect(_buy.bind(id))
	h.add_child(act)
	return pc


func _try(id: String) -> void:
	_preview_outfit[Wardrobe.ITEMS[id]["slot"]] = id
	_refresh_preview()
	refresh()


func _equip(id: String) -> void:
	wardrobe.equip(id)
	_preview_outfit = wardrobe.equipped.duplicate()
	_refresh_preview()
	refresh()


func _buy(id: String) -> void:
	if wardrobe.buy(id, inv):
		inv.message.emit("Đã mua %s" % Wardrobe.ITEMS[id]["name"])
		wardrobe.equip(id)
		_preview_outfit = wardrobe.equipped.duplicate()
		_refresh_preview()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE or (mode == "closet" and event.keycode == KEY_C):
			close_ui()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_rotate(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_rotate(1)


## Bệ trưng bày kiểu pixel: bệ elip dựng từ các dòng chữ nhật, chấm ngọc chạy quanh.
class Stage extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _ellipse(center: Vector2, rx: float, ry: float, color: Color, px := 4.0) -> void:
		var y := -ry
		while y <= ry:
			var half := rx * sqrt(maxf(1.0 - (y * y) / (ry * ry), 0.0))
			var w := floorf(half / px) * px
			draw_rect(Rect2(center.x - w, center.y + y, w * 2.0, px), color)
			y += px

	func _draw() -> void:
		var c := Vector2(0, 118)
		_ellipse(c + Vector2(6, 8), 116.0, 36.0, Color(0, 0, 0, 0.45))
		_ellipse(c + Vector2(0, 8), 112.0, 34.0, UIKit.BLACK)
		_ellipse(c + Vector2(0, 4), 108.0, 32.0, UIKit.GOLD_DK)
		_ellipse(c, 104.0, 30.0, UIKit.INK_3)
		_ellipse(c, 92.0, 25.0, UIKit.INK_2)
		for i in 12:
			var a := _t * 0.5 + TAU * i / 12.0
			var p := c + Vector2(roundf(cos(a) * 80.0 / 4.0) * 4.0, roundf(sin(a) * 21.0 / 4.0) * 4.0)
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), UIKit.JADE if i % 3 == 0 else UIKit.JADE_DK)