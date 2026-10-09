extends CanvasLayer
## Lò luyện đan: chọn công thức, có đủ nguyên liệu thì luyện (có thanh tiến độ), thành công hay hỏng tuỳ tỉ lệ.

signal crafted(item_id: String, success: bool)

var inv: Inventory
var cult: Cultivation
var _panel: UIKit.Frame
var _rows: VBoxContainer
var _stones: Label
var _progress: UIKit.FancyBar
var _result: Label
var _busy := false
var _dim: ColorRect


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_panel = UIKit.Frame.new(Vector2(700, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UIKit.Banner.new("Lò Luyện Đan", 24))
	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(UIKit.label("Bỏ nguyên liệu vào lò. Cảnh giới càng cao, tỉ lệ thành đan càng lớn.", 14, UIKit.MUTED))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(UIKit.KeyCap.new("Esc", "Đóng", 13))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	v.add_child(_rows)
	_progress = UIKit.FancyBar.new("Đang luyện", UIKit.RED, 22.0)
	_progress.show_numbers = false
	_progress.visible = false
	v.add_child(_progress)
	_result = UIKit.label("", 16, UIKit.GOLD)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result)


func is_open() -> bool:
	return visible


func open_ui() -> void:
	Sfx.play("ui_open")
	visible = true
	_result.text = ""
	_progress.visible = false
	_busy = false
	refresh()


func close_ui() -> void:
	if _busy:
		return
	visible = false


func chance_for(r: Dictionary) -> float:
	return clampf(float(r["chance"]) + 0.015 * cult.step_index(), 0.05, 0.98)


func can_make(r: Dictionary) -> bool:
	for id in r["mats"]:
		if inv.count(id) < int(r["mats"][id]):
			return false
	return true


func refresh() -> void:
	if not visible or inv == null:
		return
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for r in Items.RECIPES:
		_rows.add_child(_card(r))


func _card(r: Dictionary) -> Control:
	var ok := can_make(r)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.95), UIKit.BLACK, 2, 0, Vector2(12, 10)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	h.add_child(UIKit.item_icon(r["out"], 48.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	h.add_child(col)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 10)
	nrow.add_child(UIKit.label(Items.item_name(r["out"]), 18, UIKit.GOLD))
	nrow.add_child(UIKit.label("Thành đan %d%%" % roundi(chance_for(r) * 100.0), 13, UIKit.JADE))
	col.add_child(nrow)
	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 14)
	for id in r["mats"]:
		var need := int(r["mats"][id])
		var have := inv.count(id)
		var m := HBoxContainer.new()
		m.add_theme_constant_override("separation", 4)
		m.add_child(UIKit.item_icon(id, 24.0))
		m.add_child(UIKit.label("%s  %d/%d" % [Items.item_name(id), have, need], 14, UIKit.PAPER if have >= need else UIKit.RED))
		mats.add_child(m)
	col.add_child(mats)
	var b := Button.new()
	b.text = "Luyện"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 44)
	b.disabled = not ok or _busy
	b.pressed.connect(_craft.bind(r))
	h.add_child(b)
	return pc


func _craft(r: Dictionary) -> void:
	if _busy or not can_make(r):
		return
	_busy = true
	for id in r["mats"]:
		inv.remove(id, int(r["mats"][id]))
	_result.text = ""
	_progress.visible = true
	_progress.value = 0.0
	_progress._disp = 0.0
	var t := float(r["time"])
	var tw := create_tween()
	tw.tween_method(func(x: float): _progress.set_value(x * 100.0, 100.0), 0.0, 1.0, t)
	tw.tween_callback(_finish.bind(r))
	refresh()


func _finish(r: Dictionary) -> void:
	_busy = false
	_progress.visible = false
	var success := randf() < chance_for(r)
	Sfx.play("craft" if success else "fail")
	if success:
		inv.add(r["out"], 1)
		_result.text = "Thành đan!  +1 %s" % Items.item_name(r["out"])
		_result.add_theme_color_override("font_color", UIKit.JADE)
	else:
		inv.add("tro_dan", 1)
		_result.text = "Đan hỏng... chỉ còn nắm tro."
		_result.add_theme_color_override("font_color", UIKit.RED)
	crafted.emit(r["out"], success)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			close_ui()
