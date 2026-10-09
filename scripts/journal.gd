extends CanvasLayer
## Sổ tay tu tiên: tab "Nhân vật" (phím P) và tab "Nhiệm vụ" (phím Q). Tab / nút để chuyển, Esc đóng.

var main: Node
var _frame: UIKit.Frame
var _tabs := {}
var _content: Control
var _tab := "char"
var _sel_quest := ""
var _preview: Node2D
var _dir_i := 0
var _rot_t := 0.0
const DIRS := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]


func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_frame = UIKit.Frame.new(Vector2(1020, 0))
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_frame.add_child(v)
	v.add_child(UIKit.Banner.new("Sổ Tay Tu Tiên", 26))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var group := ButtonGroup.new()
	for t in [["char", "Nhân vật  (P)"], ["quest", "Nhiệm vụ  (Q)"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(190, 40)
		b.pressed.connect(_set_tab.bind(t[0]))
		top.add_child(b)
		_tabs[t[0]] = b
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	top.add_child(UIKit.KeyCap.new("Tab", "Đổi tab", 13))
	top.add_child(UIKit.KeyCap.new("Esc", "Đóng", 13))
	_content = Control.new()
	_content.custom_minimum_size = Vector2(0, 520)
	v.add_child(_content)


func is_open() -> bool:
	return visible


func open_ui(tab: String) -> void:
	Sfx.play("ui_open")
	visible = true
	_tab = tab
	_dir_i = 0
	_build()


func close_ui() -> void:
	visible = false


func _set_tab(t: String) -> void:
	_tab = t
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_ESCAPE:
			close_ui()
		KEY_P:
			if _tab == "char":
				close_ui()
			else:
				_set_tab("char")
		KEY_Q:
			if _tab == "quest":
				close_ui()
			else:
				_set_tab("quest")
		KEY_TAB:
			_set_tab("quest" if _tab == "char" else "char")
		KEY_LEFT, KEY_A:
			_rotate(-1)
		KEY_RIGHT, KEY_D:
			_rotate(1)


func _process(delta: float) -> void:
	if visible and _tab == "char":
		_rot_t += delta
		if _rot_t > 3.0:
			_rot_t = 0.0
			_rotate(1)


func _rotate(step: int) -> void:
	if _tab != "char" or _preview == null:
		return
	_dir_i = (_dir_i + step + DIRS.size()) % DIRS.size()
	_preview.set_motion("idle", DIRS[_dir_i])


func _build() -> void:
	(_tabs[_tab] as Button).button_pressed = true
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_preview = null
	if _tab == "char":
		_build_char()
	else:
		_build_quests()


func _row(parent: Control, k: String, v: String, vc := UIKit.PAPER) -> void:
	var h := HBoxContainer.new()
	var a := UIKit.label(k, 16, UIKit.MUTED)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UIKit.label(v, 16, vc))
	parent.add_child(h)


func _fmt_time(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%d phút" % m if m < 60 else "%d giờ %d phút" % [m / 60, m % 60]


# ---------------------------------------------------------------- tab nhân vật
func _build_char() -> void:
	var cult: Cultivation = main.cult
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	_content.add_child(h)
	# --- cột trái: bệ trưng bày + trang phục
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(250, 330)
	left.add_child(stage)
	var pd := Pedestal.new()
	pd.position = Vector2(125, 160)
	stage.add_child(pd)
	_preview = load("res://character/hd/base_character.tscn").instantiate()
	_preview.scale = Vector2.ONE * 4.0
	_preview.position = Vector2(125, 276)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(_preview)
	Wardrobe.apply(_preview, main.wardrobe.equipped)
	_preview.set_motion("idle", DIRS[_dir_i])
	var eq := PanelContainer.new()
	eq.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.BLACK, 2, 0, Vector2(12, 8)))
	left.add_child(eq)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	eq.add_child(ev)
	for slot in Wardrobe.SLOTS:
		var id: String = main.wardrobe.equipped.get(slot, "")
		_row(ev, Wardrobe.SLOT_NAMES[slot], Wardrobe.ITEMS[id]["name"] if Wardrobe.ITEMS.has(id) else "—", UIKit.GOLD)
	# --- cột giữa: cảnh giới và chỉ số
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	h.add_child(mid)
	mid.add_child(UIKit.Banner.new("%s · Tầng %d" % [Cultivation.REALMS[cult.realm], cult.layer], 24, UIKit.GOLD, true))
	var hp := UIKit.FancyBar.new("Khí huyết", UIKit.RED, 24.0)
	hp.set_value(main.vitals.hp, main.vitals.max_hp)
	hp._disp = hp.value
	mid.add_child(hp)
	var xp := UIKit.FancyBar.new("Tu vi", UIKit.XP_GOLD, 24.0)
	xp.set_value(cult.xp, cult.xp_needed())
	xp._disp = xp.value
	mid.add_child(xp)
	var qi := UIKit.FancyBar.new("Linh khí", UIKit.QI_BLUE, 24.0)
	qi.set_value(cult.qi, cult.qi_max())
	qi._disp = qi.value
	mid.add_child(qi)
	var status := "Nhấn F để thiền, tích tu vi."
	var sc := UIKit.MUTED
	if cult.ready_breakthrough:
		status = "Tu vi viên mãn! Nhấn B để đột phá (thành công %d%%)." % roundi(Cultivation.BREAKTHROUGH_CHANCE * 100.0)
		sc = UIKit.GOLD
	var sl := UIKit.label(status, 15, sc)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(sl)
	mid.add_child(HSeparator.new())
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 3)
	mid.add_child(stats)
	var power := 100.0 * 0.12 * cult.step_index()
	_row(stats, "Cấp tu luyện", "%d / %d" % [cult.step_index() + 1, (Cultivation.REALMS.size() - 1) * Cultivation.LAYERS])
	_row(stats, "Sức mạnh kiếm", "+%d%%" % roundi(power), UIKit.JADE)
	_row(stats, "Khí huyết tối đa", "%d" % roundi(main.vitals.max_hp))
	_row(stats, "Linh khí tối đa", "%d" % roundi(cult.qi_max()))
	_row(stats, "Linh thạch", "%d" % main.inv.stones, UIKit.STONE_TXT)
	_row(stats, "Chức vị Kiếm Tông", Sect.rank_name(main.inv.merit_total), UIKit.JADE)
	_row(stats, "Cống hiến", "%d  (tổng %d)" % [main.inv.merit, main.inv.merit_total], Color(1.0, 0.82, 0.35))
	mid.add_child(HSeparator.new())
	var rec := VBoxContainer.new()
	rec.add_theme_constant_override("separation", 3)
	mid.add_child(rec)
	var kills := 0
	for k in main.quests.kills:
		kills += int(main.quests.kills[k])
	_row(rec, "Thời gian chơi", _fmt_time(main.playtime))
	_row(rec, "Đã thiền", _fmt_time(main.quests.meditate_time))
	_row(rec, "Yêu thú đã hạ", "%d" % kills)
	_row(rec, "Số lần trúng đòn (mộc nhân)", "%d" % main.quests.sword_hits)
	_row(rec, "Đan đã luyện", "%d" % main.quests.crafts)
	# --- cột phải: chiêu thức
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	right.add_child(UIKit.Banner.new("Kiếm Tông", 20, UIKit.JADE, true))
	if not main.school.joined:
		var nl := UIKit.label("Chưa bái sư. Hãy gặp Kiếm sư Lăng Tiêu ở sân luyện kiếm để học bốn chiêu kiếm.", 15, UIKit.MUTED)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(nl)
	for i in SwordSchool.SKILLS.size():
		right.add_child(_skill_card(i))


func _skill_card(i: int) -> Control:
	var s: Dictionary = SwordSchool.SKILLS[i]
	var cult: Cultivation = main.cult
	var open: bool = main.school.joined and main.school.step_unlocked(i)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.GOLD_DK if open else UIKit.BLACK, 2, 0, Vector2(10, 8)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	var icon := UIKit.Icon.new(str(s["id"]), Color.WHITE, 48.0)
	icon.modulate = Color.WHITE if open else Color(0.5, 0.5, 0.6)
	hb.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	hb.add_child(col)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 8)
	nrow.add_child(UIKit.KeyCap.new(str(s["key"]), "", 12))
	nrow.add_child(UIKit.label(str(s["name"]), 18, UIKit.PAPER if open else UIKit.MUTED))
	col.add_child(nrow)
	var dl := UIKit.label(str(s["desc"]), 13, UIKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(190, 0)
	col.add_child(dl)
	var need := int(s["need"])
	var info := "Tiêu hao %d linh khí · hồi %.1fs" % [int(s["cost"]), float(s["cd"])]
	var ic := UIKit.QI_BLUE
	if not main.school.joined:
		info = "Cần bái sư"
		ic = UIKit.RED
	elif not open:
		info = "Mở ở %s tầng %d" % [Cultivation.REALMS[1 + need / Cultivation.LAYERS], need % Cultivation.LAYERS + 1]
		ic = UIKit.RED
	col.add_child(UIKit.label(info, 14, ic))
	return pc


# ---------------------------------------------------------------- tab nhiệm vụ
func _build_quests() -> void:
	var q: QuestLog = main.quests
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	_content.add_child(h)
	var order: Array = []
	for pass_state in ["ready", "active", "available", "locked", "done"]:
		for i in QuestLog.QUESTS.size():
			if q.status(i) == pass_state:
				order.append(i)
	if _sel_quest == "" or q._find(_sel_quest).is_empty():
		_sel_quest = QuestLog.QUESTS[order[0]]["id"] if not order.is_empty() else ""
	# danh sách
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(360, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	for i in order:
		list.add_child(_quest_row(i))
	# chi tiết
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.BLACK, 2, 0, Vector2(18, 14)))
	h.add_child(right)
	right.add_child(_quest_detail())


const STATUS_TEXT := {"ready": "Có thể trả", "active": "Đang làm", "available": "Có thể nhận", "locked": "Chưa mở", "done": "Hoàn thành"}


func _status_color(s: String) -> Color:
	match s:
		"ready", "done":
			return UIKit.JADE
		"active":
			return UIKit.GOLD
		"available":
			return UIKit.QI_BLUE
	return UIKit.MUTED


func _quest_row(i: int) -> Control:
	var q: QuestLog = main.quests
	var qd: Dictionary = QuestLog.QUESTS[i]
	var st := q.status(i)
	var sel: bool = qd["id"] == _sel_quest
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = ""
	b.pressed.connect(func():
		_sel_quest = qd["id"]
		_build())
	if sel:
		b.add_theme_stylebox_override("normal", UIKit.button_box(UIKit.INK_4, UIKit.GOLD))
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	var title := "???" if st == "locked" else str(qd["title"])
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UIKit.label(title, 18, UIKit.PAPER if st != "done" else UIKit.MUTED)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var s := UIKit.label(STATUS_TEXT[st], 14, _status_color(st))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_child(col)
	b.add_child(m)
	return b


func _quest_detail() -> Control:
	var q: QuestLog = main.quests
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var qd: Dictionary = q._find(_sel_quest)
	if qd.is_empty():
		v.add_child(UIKit.label("Chưa có nhiệm vụ nào.", 18, UIKit.MUTED))
		return v
	var idx := 0
	for i in QuestLog.QUESTS.size():
		if QuestLog.QUESTS[i]["id"] == _sel_quest:
			idx = i
	var st := q.status(idx)
	if st == "locked":
		v.add_child(UIKit.Banner.new("???", 24, UIKit.MUTED, true))
		var l := UIKit.label("Hoàn thành các nhiệm vụ trước đó để mở nhiệm vụ này.", 16, UIKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return v
	v.add_child(UIKit.Banner.new(str(qd["title"]), 24, UIKit.GOLD, true))
	v.add_child(UIKit.label(STATUS_TEXT[st], 16, _status_color(st)))
	var who := UIKit.label("Giao bởi: %s   ·   Trả tại: %s" % [QuestLog.npc_name(qd["giver"]), QuestLog.npc_name(qd["turn_in"])], 14, UIKit.MUTED)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(who)
	v.add_child(HSeparator.new())
	var d := UIKit.label(str(qd["desc"]), 17, UIKit.PAPER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	if st == "active" or st == "ready":
		var p := q.progress(qd)
		var bar := UIKit.FancyBar.new("Tiến độ", UIKit.JADE, 24.0)
		bar.set_value(p.x, p.y)
		bar._disp = bar.value
		v.add_child(bar)
		if st == "ready":
			v.add_child(UIKit.label("Đã đủ! Quay lại gặp %s để nhận thưởng." % QuestLog.npc_name(qd["turn_in"]), 16, UIKit.JADE))
	elif st == "available":
		v.add_child(UIKit.label("Hãy đến gặp %s (dấu ! trên đầu)." % QuestLog.npc_name(qd["giver"]), 16, UIKit.QI_BLUE))
	var intro: Array = qd.get("intro", [])
	if not intro.is_empty():
		var il := UIKit.label("“%s”" % str(intro[0]), 14, UIKit.MUTED)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(il)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grow)
	v.add_child(HSeparator.new())
	v.add_child(UIKit.label("Phần thưởng", 16, UIKit.GOLD))
	var r: Dictionary = qd["reward"]
	var rh := HFlowContainer.new()
	rh.add_theme_constant_override("h_separation", 14)
	if int(r.get("stones", 0)) > 0:
		var sbox := HBoxContainer.new()
		sbox.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
		sbox.add_child(UIKit.label(" %d linh thạch" % int(r["stones"]), 16, UIKit.STONE_TXT))
		rh.add_child(sbox)
	if int(r.get("merit", 0)) > 0:
		var mbox := HBoxContainer.new()
		mbox.add_child(UIKit.Icon.new("slash", Color(1.0, 0.82, 0.35), 24.0))
		mbox.add_child(UIKit.label(" %d cống hiến" % int(r["merit"]), 16, Color(1.0, 0.82, 0.35)))
		rh.add_child(mbox)
	var its: Dictionary = r.get("items", {})
	for k in its:
		var ib := HBoxContainer.new()
		ib.add_child(UIKit.item_icon(str(k), 24.0))
		ib.add_child(UIKit.label(" %s ×%d" % [Items.item_name(str(k)), int(its[k])], 16, UIKit.PAPER))
		rh.add_child(ib)
	v.add_child(rh)
	return v


## Bệ trưng bày nhỏ dưới chân nhân vật.
class Pedestal extends Node2D:
	func _ellipse(center: Vector2, rx: float, ry: float, color: Color, px := 4.0) -> void:
		var y := -ry
		while y <= ry:
			var half := rx * sqrt(maxf(1.0 - (y * y) / (ry * ry), 0.0))
			var w := floorf(half / px) * px
			draw_rect(Rect2(center.x - w, center.y + y, w * 2.0, px), color)
			y += px

	func _draw() -> void:
		var c := Vector2(0, 116)
		_ellipse(c + Vector2(5, 7), 100.0, 28.0, Color(0, 0, 0, 0.45))
		_ellipse(c + Vector2(0, 7), 96.0, 27.0, UIKit.BLACK)
		_ellipse(c + Vector2(0, 3), 92.0, 25.0, UIKit.GOLD_DK)
		_ellipse(c, 88.0, 23.0, UIKit.INK_3)
		_ellipse(c, 76.0, 18.0, UIKit.INK_2)
