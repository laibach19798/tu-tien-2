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
	for t in [["char", "Nhân vật  (P)"], ["quest", "Nhiệm vụ  (Q)"], ["collect", "Sưu tầm  (O)"], ["diary", "Nhật ký  (L)"], ["world", "Đại vực  (R)"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 40)
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
		KEY_O:
			if _tab == "collect":
				close_ui()
			else:
				_set_tab("collect")
		KEY_L:
			if _tab == "diary":
				close_ui()
			else:
				_set_tab("diary")
		KEY_R:
			if _tab == "world":
				close_ui()
			else:
				_set_tab("world")
		KEY_TAB:
			var order := ["char", "quest", "collect", "diary", "world"]
			_set_tab(order[(order.find(_tab) + 1) % order.size()])
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
	match _tab:
		"char":
			_build_char()
		"quest":
			_build_quests()
		"diary":
			_build_diary()
		"world":
			_build_world()
		_:
			_build_collect()


func _build_world() -> void:
	var v := WorldMapView.new()
	v.world = main.province
	v.main = main
	_content.add_child(v)


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
	mid.add_theme_constant_override("separation", 3)
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
		status = "Tu vi viên mãn! Nhấn B để đột phá (thành công %d%%)." % roundi(Hell.breakthrough_chance(cult.realm) * 100.0)
		sc = UIKit.GOLD
	var sl := UIKit.label(status, 15, sc)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(sl)
	mid.add_child(HSeparator.new())
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 3)
	mid.add_child(stats)
	var power := 100.0 * preload("res://scripts/v1/catalog.gd").balance("realm_damage_per_step") * cult.step_index()
	_row(stats, "Cấp tu luyện", "%d / %d" % [cult.step_index() + 1, (Cultivation.REALMS.size() - 1) * Cultivation.LAYERS])
	_row(stats, "Sức mạnh cảnh giới", "+%d%%" % roundi(power), UIKit.JADE)
	_row(stats, "Khí huyết tối đa", "%d" % roundi(main.vitals.max_hp))
	_row(stats, "Linh khí tối đa", "%d" % roundi(cult.qi_max()))
	_row(stats, "Linh thạch", "%d" % main.inv.stones, UIKit.STONE_TXT)
	_row(stats, "Hệ tu luyện", "Y · Công / Tâm / Thân pháp", UIKit.JADE)
	_row(stats, "Danh hiệu", Wardrobe.title_name(main.wardrobe.title) if main.wardrobe.title != "" else "—", UIKit.GOLD)
	_row(stats, "Chức vị tông môn", main.inv.sect_rank_name(), UIKit.JADE)
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
	# --- cột phải: chiêu thức
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	right.add_child(UIKit.Banner.new("Tu luyện", 20, UIKit.JADE, true))
	var state = main.cultivation_v1.state
	var catalog = preload("res://scripts/v1/catalog.gd")
	for slot in state.equipped:
		var uid: String = state.equipped[slot]
		if state.instances.has(uid):
			var definition: Dictionary = catalog.definition(state.instances[uid].definition)
			var names = preload("res://scripts/v1/cultivation_ui.gd").SLOT_NAMES
			_row(right, names[slot], str(definition.get("name", "—")), UIKit.GOLD)
	# phím tắt theo trang bị thực tế
	var rt = main.cultivation_v1
	var keys := [["J", state.primary], ["K", rt.other_slot()], ["U", "cong2"], ["Space", "than"]]
	right.add_child(UIKit.label("Phím chiêu thức", 15, UIKit.MUTED))
	for k in keys:
		var d: Dictionary = state.def_for(str(k[1]))
		_row(right, "%s · %s" % [k[0], "Công Pháp" if k[1] == "cong" else ("Pháp Bảo" if k[1] == "artifact" else ("Công phụ" if k[1] == "cong2" else "Thân pháp"))],
			str(d.get("name", "Chưa trang bị")), UIKit.PAPER if not d.is_empty() else UIKit.MUTED)
	right.add_child(UIKit.label("Y · Bí tịch và trang bị", 15, UIKit.MUTED))


# ---------------------------------------------------------------- tab nhật ký (cơ duyên, động phủ)
func _build_diary() -> void:
	var dest: Destiny = main.destiny
	var data: Dictionary = dest.diary()
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	_content.add_child(h)
	# trái: dòng thời gian (mới nhất ở trên)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	var log: Array = data["log"]
	if log.is_empty():
		var none := UIKit.label("Chưa có điều gì đáng ghi lại. Cơ duyên thường tìm đến người chịu đi xa và biết dừng chân.", 16, UIKit.MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
	for i in range(log.size() - 1, -1, -1):
		list.add_child(_diary_row(log[i]))
	# phải: động phủ đã biết, dấu ấn nhân quả, linh cảm
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.BLACK, 2, 0, Vector2(18, 14)))
	h.add_child(right)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	rs.add_child(col)
	col.add_child(UIKit.Banner.new("Động phủ", 20, UIKit.JADE, true))
	var places: Array = data["places"]
	if places.is_empty():
		col.add_child(_diary_text("Chưa nghe được manh mối nào về động phủ tiên nhân.", UIKit.MUTED))
	for p in places:
		col.add_child(_diary_text(str(p["name"]), UIKit.GOLD, 17))
		col.add_child(_diary_text(str(p["line"]), UIKit.PAPER))
	var marks: Array = data["marks"]
	if not marks.is_empty():
		col.add_child(HSeparator.new())
		col.add_child(UIKit.Banner.new("Dấu ấn", 20, UIKit.JADE, true))
		for m in marks:
			col.add_child(_diary_text(str(m), UIKit.PAPER))
	var hunches: Array = data["hunches"]
	if not hunches.is_empty():
		col.add_child(HSeparator.new())
		col.add_child(UIKit.Banner.new("Linh cảm", 20, UIKit.JADE, true))
		for m in hunches:
			col.add_child(_diary_text(str(m), UIKit.QI_BLUE))


func _diary_text(t: String, color: Color, size := 15) -> Label:
	var l := UIKit.label(t, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _diary_row(e: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.BLACK, 2, 0, Vector2(12, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var head := "%s · %s" % [Hell.date_text(int(e["day"])), Maps.map_name(str(e["map"])) if str(e["map"]) != "overworld" else "Thế giới"]
	v.add_child(UIKit.label(head, 13, UIKit.MUTED))
	v.add_child(UIKit.label(str(e["title"]), 18, UIKit.GOLD))
	var t := UIKit.label(str(e["text"]), 15, UIKit.PAPER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(500, 0)
	v.add_child(t)
	return pc


# ---------------------------------------------------------------- tab sưu tầm
func _build_collect() -> void:
	var w: Wardrobe = main.wardrobe
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	_content.add_child(h)
	# --- trái: các bộ trang phục
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	for sid in Wardrobe.SETS:
		list.add_child(_set_card(w, str(sid)))
	# --- phải: danh hiệu
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.BLACK, 2, 0, Vector2(14, 12)))
	h.add_child(right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	right.add_child(v)
	v.add_child(UIKit.Banner.new("Danh hiệu", 22, UIKit.GOLD, true))
	var total := Wardrobe.ITEMS.size()
	v.add_child(UIKit.label("Trang phục đã sưu tầm: %d / %d" % [w.owned.size(), total], 15, UIKit.MUTED))
	v.add_child(HSeparator.new())
	for tid in Wardrobe.all_title_ids():
		v.add_child(_title_row(w, str(tid)))


func _set_card(w: Wardrobe, sid: String) -> Control:
	var s: Dictionary = Wardrobe.SETS[sid]
	var pr := w.set_progress(sid)
	var done: bool = int(pr["have"]) == int(pr["total"])
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.9), UIKit.GOLD if done else UIKit.BLACK, 2, 0, Vector2(12, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var head := HBoxContainer.new()
	var nm := UIKit.label("Bộ %s" % str(s["name"]), 19, UIKit.GOLD if done else UIKit.PAPER)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(UIKit.label("%d / %d" % [pr["have"], pr["total"]], 17, UIKit.JADE if done else UIKit.MUTED))
	v.add_child(head)
	var tiers: Array = (s["bonus"] as Dictionary).keys()
	tiers.sort()
	var worn := 0
	for slot in s["pieces"]:
		if str(w.equipped.get(slot, "")) == str(s["pieces"][slot]):
			worn += 1
	for need in tiers:
		var on := worn >= int(need)
		v.add_child(UIKit.label("%d món: %s" % [need, Wardrobe.bonus_text(s["bonus"][need])], 14, UIKit.JADE if on else UIKit.MUTED))
	for slot in s["pieces"]:
		var id := str(s["pieces"][slot])
		var have := w.is_owned(id)
		var how := "" if have else Wardrobe.acquire_text(id, true)
		if not have and how == "":
			how = "Tiệm may, %d linh thạch" % int(Wardrobe.ITEMS[id]["price"])
		var line := "• %s: %s" % [Wardrobe.SLOT_NAMES[slot], Wardrobe.ITEMS[id]["name"]]
		if not have:
			line += "  —  " + how
		var pl := UIKit.label(line, 14, UIKit.PAPER if have else UIKit.MUTED)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
	return pc


func _title_row(w: Wardrobe, tid: String) -> Control:
	var got := w.earned_titles.has(tid)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(UIKit.label(Wardrobe.title_name(tid) if got else "???", 17, UIKit.GOLD if got else UIKit.MUTED))
	var hl := UIKit.label(Wardrobe.title_how(tid), 13, UIKit.MUTED)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(190, 0)
	col.add_child(hl)
	hb.add_child(col)
	if got:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, 34)
		if w.title == tid:
			b.text = "Bỏ"
			b.pressed.connect(func():
				w.set_title("")
				_build())
		else:
			b.text = "Đeo"
			b.pressed.connect(func():
				w.set_title(tid)
				_build())
		hb.add_child(b)
	return hb


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
