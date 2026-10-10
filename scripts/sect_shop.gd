extends CanvasLayer
## Tàng Bảo Các của Kiếm Tông: hai cột ĐỔI (dùng điểm cống hiến, cần chức vị) và NỘP (đưa nguyên liệu lấy cống hiến).

const MERIT_TINT := Color(1.0, 0.82, 0.35)

var inv: Inventory
var wardrobe: Wardrobe
var _buy_rows: VBoxContainer
var _give_rows: VBoxContainer
var _merit: Label
var _rank: Label
var _next: Label
var _panel: UIKit.Frame
var _dim: ColorRect


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_panel = UIKit.Frame.new(Vector2(940, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UIKit.Banner.new("Tàng Bảo Các · Chấp sự Mộ Dung", 24))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.Icon.new("slash", MERIT_TINT, 24.0))
	_merit = UIKit.label("0", 18, MERIT_TINT)
	top.add_child(_merit)
	_rank = UIKit.label("", 16, UIKit.JADE)
	top.add_child(UIKit.spacer(0))
	top.add_child(_rank)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(UIKit.KeyCap.new("Esc", "Đóng", 13))
	_next = UIKit.label("", 14, UIKit.MUTED)
	v.add_child(_next)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)
	_buy_rows = _column(cols, "ĐỔI BẰNG CỐNG HIẾN")
	_give_rows = _column(cols, "NỘP NGUYÊN LIỆU")
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
	sc.custom_minimum_size = Vector2(420, 330)
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
	Sfx.play("ui_open")
	visible = true
	refresh()


func close_shop() -> void:
	visible = false


func refresh() -> void:
	if not visible or inv == null:
		return
	var rank := Sect.rank_of(inv.merit_total)
	_merit.text = "%d  cống hiến" % inv.merit
	_rank.text = "   Chức vị: %s" % Sect.rank_name(inv.merit_total)
	var need := Sect.to_next(inv.merit_total)
	_next.text = "Còn %d điểm tổng cống hiến nữa để thăng chức tiếp theo." % need if need > 0 else "Đã đạt chức vị cao nhất."
	for rows in [_buy_rows, _give_rows]:
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
	for e in Sect.SHOP:
		var id: String = e["id"]
		var title := ""
		var desc := ""
		var icon: Control
		var owned := false
		if e["kind"] == "item":
			var d: Dictionary = Items.DATA[id]
			title = str(d["name"])
			desc = str(d["desc"])
			icon = UIKit.item_icon(id, 48.0)
		else:
			var w: Dictionary = Wardrobe.ITEMS[id]
			title = str(w["name"])
			desc = str(w["desc"])
			icon = UIKit.Icon.new("clothes", Color(0.9, 0.9, 1.0), 48.0)
			owned = wardrobe != null and wardrobe.is_owned(id)
		var need_rank := int(e["rank"])
		if need_rank > rank:
			desc = "Cần chức vị: %s" % Sect.RANKS[need_rank]["name"]
		var b := _card(_buy_rows, icon, title, desc, int(e["cost"]), "Đã có" if owned else "Đổi", UIKit.GOLD if need_rank <= rank else UIKit.MUTED)
		b.disabled = owned or need_rank > rank or inv.merit < int(e["cost"])
		b.pressed.connect(_buy.bind(e))
	var any := false
	for id in inv.items:
		var d: Dictionary = Items.DATA.get(id, {})
		var m := int(d.get("merit", 0))
		if m <= 0:
			continue
		any = true
		var n := inv.count(id)
		var b := _card(_give_rows, UIKit.item_icon(id, 48.0), "%s  ×%d" % [d["name"], n], "Mỗi cái được cống hiến", m, "Nộp 1", UIKit.GOLD)
		b.pressed.connect(_give.bind(id, 1))
		if n > 1:
			var all := Button.new()
			all.text = "Hết"
			all.focus_mode = Control.FOCUS_NONE
			all.pressed.connect(_give.bind(id, n))
			b.get_parent().add_child(all)
	if not any:
		var l := UIKit.label("Không có gì để nộp.\nLinh thảo, nanh sói, da yêu, yêu đan, nanh Lang Vương đều đổi được cống hiến.", 15, UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_give_rows.add_child(l)


## Thẻ: biểu tượng | tên + mô tả | giá (cống hiến) + nút. Trả về nút chính.
func _card(parent: Control, icon: Control, title: String, desc: String, price: int, btn_text: String, title_color: Color) -> Button:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), Color(UIKit.GOLD_DK, 0.6), 1, 6, Vector2(10, 8)))
	parent.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	h.add_child(col)
	col.add_child(UIKit.label(title, 16, title_color))
	var dl := UIKit.label(desc, 13, UIKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(150, 0)
	col.add_child(dl)
	var price_box := HBoxContainer.new()
	price_box.add_theme_constant_override("separation", 3)
	price_box.add_child(UIKit.Icon.new("slash", MERIT_TINT, 24.0))
	price_box.add_child(UIKit.label(str(price), 15, MERIT_TINT))
	h.add_child(price_box)
	var b := Button.new()
	b.text = btn_text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 0)
	h.add_child(b)
	return b


func _buy(e: Dictionary) -> void:
	var id: String = e["id"]
	if Sect.rank_of(inv.merit_total) < int(e["rank"]) or not inv.spend_merit(int(e["cost"])):
		return
	if e["kind"] == "item":
		inv.add(id, 1)
		inv.message.emit("Đã đổi %s" % Items.item_name(id))
	else:
		wardrobe.owned.append(id)
		wardrobe.changed.emit()
		inv.message.emit("Đã nhận %s (nhấn C để mặc)" % Wardrobe.ITEMS[id]["name"])
	Sfx.play("pickup")
	refresh()


func _give(id: String, n: int) -> void:
	var per := int(Items.DATA[id]["merit"])
	if inv.remove(id, n):
		inv.add_merit(per * n)
		inv.message.emit("Đã nộp %s x%d  (+%d cống hiến)" % [Items.item_name(id), n, per * n])
		Sfx.play("coin")
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			close_shop()
