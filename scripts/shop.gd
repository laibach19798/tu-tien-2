extends CanvasLayer
## Cửa hàng của thương nhân: hai cột MUA / BÁN, mỗi món là một thẻ có biểu tượng, mô tả và giá.

var inv: Inventory
var _buy_rows: VBoxContainer
var _sell_rows: VBoxContainer
var _stones: Label
var _panel: UIKit.Frame
var _dim: ColorRect


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_panel = UIKit.Frame.new(Vector2(900, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UIKit.Banner.new("Cửa Hàng · Thương nhân Lý Tam", 24))
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
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)
	_buy_rows = _column(cols, "MUA")
	_sell_rows = _column(cols, "BÁN")
	var close := Button.new()
	close.text = "Đóng"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 34)
	close.pressed.connect(close_shop)
	v.add_child(close)


func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	col.add_child(UIKit.Banner.new(title, 17, UIKit.JADE))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(400, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	sc.add_child(rows)
	return rows


func is_open() -> bool:
	return visible


func open_shop() -> void:
	visible = true
	refresh()


func close_shop() -> void:
	visible = false


func refresh() -> void:
	if not visible or inv == null:
		return
	_stones.text = "%d  linh thạch" % inv.stones
	for rows in [_buy_rows, _sell_rows]:
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
	for id in Items.SHOP_BUY:
		var d: Dictionary = Items.DATA[id]
		var b := _card(_buy_rows, id, str(d["name"]), str(d["desc"]), int(d["buy"]), "Mua")
		b.disabled = inv.stones < int(d["buy"])
		b.pressed.connect(_buy.bind(id))
	var any := false
	for id in inv.items:
		var d: Dictionary = Items.DATA.get(id, {})
		if int(d.get("sell", 0)) <= 0:
			continue
		any = true
		var n := inv.count(id)
		var b := _card(_sell_rows, id, "%s  ×%d" % [d["name"], n], "Giá mỗi cái", int(d["sell"]), "Bán 1")
		b.pressed.connect(_sell.bind(id, 1))
		if n > 1:
			var all := Button.new()
			all.text = "Hết"
			all.focus_mode = Control.FOCUS_NONE
			all.pressed.connect(_sell.bind(id, n))
			b.get_parent().add_child(all)
	if not any:
		var l := UIKit.label("Không có gì để bán.\nHái linh thảo để đổi lấy linh thạch.", 15, UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sell_rows.add_child(l)


## Thẻ vật phẩm: biểu tượng | tên + mô tả | giá + nút. Trả về nút chính.
func _card(parent: Control, id: String, title: String, desc: String, price: int, btn_text: String) -> Button:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), Color(UIKit.GOLD_DK, 0.6), 1, 6, Vector2(10, 8)))
	parent.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	h.add_child(UIKit.item_icon(id, 48.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	h.add_child(col)
	col.add_child(UIKit.label(title, 16, UIKit.GOLD))
	var dl := UIKit.label(desc, 13, UIKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(150, 0)
	col.add_child(dl)
	var price_box := HBoxContainer.new()
	price_box.add_theme_constant_override("separation", 3)
	price_box.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
	price_box.add_child(UIKit.label(str(price), 15, UIKit.STONE_TXT))
	h.add_child(price_box)
	var b := Button.new()
	b.text = btn_text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 0)
	h.add_child(b)
	return b


func _buy(id: String) -> void:
	var price := int(Items.DATA[id]["buy"])
	if inv.spend_stones(price):
		inv.add(id, 1)
		inv.message.emit("Đã mua %s" % Items.item_name(id))
	refresh()


func _sell(id: String, n: int) -> void:
	if inv.remove(id, n):
		inv.add_stones(int(Items.DATA[id]["sell"]) * n)
		inv.message.emit("Đã bán %s x%d" % [Items.item_name(id), n])
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			close_shop()
