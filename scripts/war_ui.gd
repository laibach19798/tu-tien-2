extends CanvasLayer
## Bảng chiến sự Tiểu Thế Giới (phím G): thế lực các tông, danh sách địa bàn và nhật ký chiến sự.

var war: SectWar
var _frame: UIKit.Frame
var _content: VBoxContainer
var _t := 0.0


func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_frame = UIKit.Frame.new(Vector2(1040, 0))
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_frame)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_frame.add_child(_content)
	war.changed.connect(func(): if visible: _build())


func is_open() -> bool:
	return visible


func open_ui() -> void:
	Sfx.play("ui_open")
	visible = true
	_build()


func close_ui() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_G:
		close_ui()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 1.0:
		_t = 0.0
		_build()   # đếm ngược thời gian phòng thủ


func _build() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var top := HBoxContainer.new()
	var title := UIKit.Banner.new("Chiến Sự Tiểu Thế Giới", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UIKit.KeyCap.new("G", "Đóng", 13))
	_content.add_child(top)
	var sub := UIKit.label("Giữ %d địa bàn trở lên để trở thành bá chủ. Hạ lính canh rồi nhấn E ở cột cờ để chiếm; địch tập kích thì về giữ." % SectWar.WIN_COUNT, 14, UIKit.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(sub)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_content.add_child(h)
	# --- thế lực các tông
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	left.add_child(UIKit.Banner.new("Các tông môn", 18, UIKit.JADE, true))
	var ids := SectWar.SECTS.keys()
	ids.sort_custom(func(a, b): return war.count(a) > war.count(b))
	for sid in ids:
		left.add_child(_sect_row(str(sid)))
	# --- địa bàn
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	h.add_child(right)
	right.add_child(UIKit.Banner.new("Địa bàn", 18, UIKit.JADE, true))
	for t in SectWar.TERRITORIES:
		right.add_child(_territory_row(t))
	_content.add_child(HSeparator.new())
	_content.add_child(UIKit.Banner.new("Nhật ký chiến sự", 18, UIKit.JADE, true))
	var shown: Array = war.log.slice(maxi(0, war.log.size() - 6))
	if shown.is_empty():
		_content.add_child(UIKit.label("Chưa có giao tranh nào.", 14, UIKit.MUTED))
	for i in range(shown.size() - 1, -1, -1):
		var l := UIKit.label("• " + str(shown[i]), 14, UIKit.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(l)


func _sect_row(sid: String) -> Control:
	var col := SectWar.sect_color(sid)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), col if sid == SectWar.PLAYER else UIKit.BLACK, 2, 0, Vector2(10, 6)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(14, 14)
	sw.color = col
	hb.add_child(sw)
	var nm := UIKit.label(SectWar.sect_name(sid) + ("  (ta)" if sid == SectWar.PLAYER else ""), 17, col.lerp(Color.WHITE, 0.4))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	hb.add_child(UIKit.label("%d địa bàn · lực %d" % [war.count(sid), int(war.power(sid))], 14, UIKit.PAPER))
	return pc


func _territory_row(t: Dictionary) -> Control:
	var tid: String = t["id"]
	var own := war.owner_of(tid)
	var col := SectWar.sect_color(own) if own != "" else Color(0.75, 0.75, 0.75)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(10, 10)
	sw.color = col
	hb.add_child(sw)
	var nm := UIKit.label("%s  (%s)" % [t["name"], t["type"]], 15, UIKit.PAPER)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var status := SectWar.sect_name(own) if own != "" else "Vô chủ"
	var sc := col.lerp(Color.WHITE, 0.4)
	if war.under_attack.has(tid):
		status = "BỊ TẬP KÍCH %ds" % int(war.under_attack[tid]["left"])
		sc = UIKit.RED
	hb.add_child(UIKit.label(status, 15, sc))
	return hb
