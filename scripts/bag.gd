extends CanvasLayer
## Túi đồ (phím I): lưới ô vật phẩm, bảng chi tiết và nút dùng đan dược.

const COLS := 5
const MIN_SLOTS := 25

var inv: Inventory
var cult: Cultivation
var _panel: UIKit.Frame
var _stones: Label
var _grid: GridContainer
var _detail: VBoxContainer
var _selected := ""
var _dim: ColorRect


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_panel = UIKit.Frame.new(Vector2(800, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UIKit.Banner.new("Túi Đồ", 24))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
	_stones = UIKit.label("0", 18, UIKit.STONE_TXT)
	top.add_child(_stones)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(UIKit.KeyCap.new("I / Esc", "Đóng", 13))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	# lưới vật phẩm
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.28), Color(UIKit.GOLD_DK, 0.5), 1, 6, Vector2(10, 10)))
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	# chi tiết
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.8), Color(UIKit.GOLD_DK, 0.6), 1, 6, Vector2(16, 14)))
	body.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)


func is_open() -> bool:
	return visible


func toggle() -> void:
	visible = not visible
	if visible:
		_selected = ""
	refresh()


func close_bag() -> void:
	visible = false


func refresh() -> void:
	if not visible or inv == null:
		return
	_stones.text = "%d  linh thạch" % inv.stones
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var ids: Array = inv.items.keys()
	if _selected == "" or not inv.items.has(_selected):
		_selected = str(ids[0]) if not ids.is_empty() else ""
	var total := maxi(MIN_SLOTS, int(ceil(ids.size() / float(COLS))) * COLS)
	for i in total:
		var s := UIKit.Slot.new(64.0)
		if i < ids.size():
			var id := str(ids[i])
			s.set_item(id, inv.count(id))
			s.selected = id == _selected
			s.picked.connect(_select.bind(id))
		_grid.add_child(s)
	_fill_detail()


func _select(id: String) -> void:
	_selected = id
	refresh()


func _fill_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	_detail.custom_minimum_size = Vector2(300, 0)
	if _selected == "":
		var e := UIKit.label("Túi trống.\nHái linh thảo hoặc mua đan dược để bắt đầu.", 15, UIKit.MUTED)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(e)
		return
	var d: Dictionary = Items.DATA.get(_selected, {})
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_detail.add_child(head)
	head.add_child(UIKit.item_icon(_selected, 48.0))
	var col := VBoxContainer.new()
	head.add_child(col)
	col.add_child(UIKit.label(str(d.get("name", _selected)), 21, UIKit.GOLD))
	col.add_child(UIKit.label("Số lượng: %d" % inv.count(_selected), 14, UIKit.MUTED))
	_detail.add_child(HSeparator.new())
	var desc := UIKit.label(str(d.get("desc", "")), 15, UIKit.PAPER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 0)
	_detail.add_child(desc)
	var eff := ""
	if d.has("qi"):
		eff = "Hồi %d linh khí" % int(d["qi"])
	elif d.has("xp"):
		eff = "Tăng %d tu vi" % int(d["xp"])
	elif d.has("hp"):
		eff = "Hồi %d khí huyết" % int(d["hp"])
	if eff != "":
		_detail.add_child(UIKit.label("✦ " + eff, 15, UIKit.JADE))
	if int(d.get("sell", 0)) > 0:
		var p := HBoxContainer.new()
		p.add_child(UIKit.label("Giá bán: ", 14, UIKit.MUTED))
		p.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
		p.add_child(UIKit.label(" %d" % int(d["sell"]), 14, UIKit.STONE_TXT))
		_detail.add_child(p)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(grow)
	if d.get("usable", false):
		var b := Button.new()
		b.text = "Sử dụng"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(_use.bind(_selected))
		_detail.add_child(b)


func _use(id: String) -> void:
	inv.use(id, cult)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			close_bag()
			get_viewport().set_input_as_handled()
