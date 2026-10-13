extends CanvasLayer
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
var runtime: Node
var page := "loadout"
var method := "market"
var body: VBoxContainer
var header: Label
var tabs: HBoxContainer
var close_button: Button
var draft: Dictionary = {}
var selected_sect := "kiem_tong"
var scroll: ScrollContainer
var tab_buttons: Dictionary = {}
const QUALITY_COLORS := {"thuong": Color(0.78, 0.80, 0.86), "linh": Color(0.45, 0.85, 0.65), "huyen": Color(0.78, 0.55, 1.0)}
const PAGE_TITLES := {"origin": "TIÊN THIÊN", "loadout": "ĐANG TRANG BỊ", "books": "BÍ TỊCH", "gear": "TRANG BỊ", "log": "NHẬT KÝ CHIẾN ĐẤU"}
const SHAPE_NAMES := {"cone": "quạt cận chiến", "line": "đường thẳng", "single": "đơn mục tiêu", "ring": "vòng quanh người", "burst": "vùng quanh mục tiêu", "summon": "triệu hồi"}
const SLOT_NAMES := {"cong":"Công Pháp","cong2":"Công Pháp phụ","tam":"Tâm Pháp","than":"Thân Pháp","weapon":"Vũ Khí","armor":"Giáp / Pháp Y","artifact":"Pháp Bảo"}
const SOURCE_NAMES := {"starter":"Khởi đầu","sect_starter":"Truyền dạy nhập môn","market":"Thương hội","sect":"Tàng Kinh Các","npc":"Ân nghĩa NPC","unowned_ruin":"Di tích vô chủ","dong_phu":"Động phủ tiên nhân","loot":"Rơi từ địch","seized":"Chiến lợi phẩm có thù hận","legacy":"Bí tịch từ bản lưu cũ"}

func _ready() -> void:
	layer = 25
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.04,0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.theme = UIKit.theme()
	panel.add_theme_stylebox_override("panel",UIKit.box(UIKit.INK,UIKit.GOLD_DK,2,0,Vector2(20,16)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 65
	panel.offset_right = -65
	panel.offset_top = 25
	panel.offset_bottom = -25
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	header = UIKit.label("TU LUYỆN · BÍ TỊCH VÀ PHÁP BẢO",23,UIKit.GOLD)
	column.add_child(header)
	tabs = HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["origin","Tiên thiên"],["loadout","Đang trang bị"],["books","Bí tịch"],["gear","Trang bị"],["log","Nhật ký chiến đấu"]]:
		tab_buttons[entry[0]] = button(tabs,entry[1],open_ui.bind(entry[0]))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 14
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",9)
	scroll.add_child(body)
	close_button = button(column,"Đóng [Y / Esc]",hide)

func button(parent: Node, text: String, action: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func line(text: String, color := UIKit.PAPER, size := 16) -> void:
	var label := UIKit.label(text,size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func open_ui(next_page := "loadout") -> void:
	page = "origin" if not runtime.state.origin.confirmed else next_page
	if not runtime.state.origin.confirmed and draft.is_empty():
		draft = Origin.roll(randi())
	scroll.scroll_vertical = 0
	refresh()
	show()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode in [KEY_Y,KEY_ESCAPE] and runtime.state.origin.confirmed:
			hide()

func refresh() -> void:
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	tabs.visible = runtime.state.origin.confirmed
	close_button.visible = runtime.state.origin.confirmed
	header.text = "TU LUYỆN · %s" % str(PAGE_TITLES.get(page, "BÍ TỊCH VÀ PHÁP BẢO"))
	for key in tab_buttons:
		var tb: Button = tab_buttons[key]
		var current: bool = key == page
		tb.add_theme_color_override("font_color", UIKit.GOLD if current else UIKit.PAPER)
		tb.text = ("▸ " if current else "") + str(tb.text).trim_prefix("▸ ")
	match page:
		"origin": _origin()
		"loadout": _loadout()
		"books", "gear": _inventory()
		"acquire": _acquire()
		"log": _log()

func _log() -> void:
	line("Nguồn → sự kiện → điều kiện → thực chi → hành động. Dòng mới nhất ở trên.",UIKit.MUTED,14)
	var logs: Array = runtime.engine.logs
	if logs.is_empty():
		line("Chưa có sự kiện. J ra chiêu, Space né rồi mở lại bảng.")
		return
	var shown := 0
	for i in range(logs.size() - 1, -1, -1):
		line(str(logs[i]),UIKit.PAPER,14)
		shown += 1
		if shown >= 60:
			break

func _origin() -> void:
	var confirmed: bool = runtime.state.origin.confirmed
	var d: Dictionary = runtime.state.origin if confirmed else draft
	line("Sáu tiên thiên (tổng 300) · năm ngũ hành (tổng 100) · một mệnh cách. Tư chất không khóa học ngoại phái.",UIKit.JADE,15)
	var attr: Array = []
	for id in Data.data().attributes:
		attr.append([str(Data.data().attributes[id]), str(d.attributes[id])])
	_stat_row(attr)
	var roots: Array = []
	for id in Data.data().elements:
		roots.append([str(Data.data().elements[id]), str(d.roots[id])])
	_stat_row(roots)
	var fate: Dictionary = Data.data().fates[d.fate]
	var box := _card(body)
	box.add_child(UIKit.label("Mệnh cách · %s" % fate.name,19,UIKit.GOLD))
	_text(box,str(fate.description),15,UIKit.PAPER)
	_text(box,"Căn Cốt: khí huyết · Kinh Mạch: linh lực, hồi khí · Ngộ Tính: giá tham ngộ và độ dễ của mini game Ngộ đạo (xem lại, tha lỗi, gợi ý) · Thần Thức: tầm cảm nhận · Linh Hoạt: di chuyển, cửa sổ né · Tâm Cảnh: kháng gián đoạn. Linh căn chỉ chỉnh nhẹ chi phí nguyên tố.",13,UIKit.MUTED)
	if not confirmed:
		var select := OptionButton.new()
		for id in Data.data().sects:
			select.add_item(Data.data().sects[id].name)
		select.select(Data.data().sects.keys().find(selected_sect))
		select.item_selected.connect(func(index): selected_sect = Data.data().sects.keys()[index])
		body.add_child(select)
		var row := HBoxContainer.new()
		body.add_child(row)
		button(row,"Roll lại cả bộ",func(): draft = Origin.roll(randi()); refresh())
		button(row,"Chốt tư chất và gia nhập",func(): runtime.confirm_origin(draft,selected_sect))
	else:
		line("Tông môn: %s · %s" % [Data.data().sects.get(runtime.state.sect,{"name":"Chưa gia nhập"}).name,Data.data().ranks[runtime.state.rank()]],UIKit.JADE)
		line("Tiên thiên đã chốt và được lưu, không roll lại khi tải game.",UIKit.MUTED,14)
		if not runtime.state.legacy.is_empty():
			line("Bản lưu cũ đã được chuyển sang hệ V1; dữ liệu cũ vẫn nằm trong phần lưu trữ.",UIKit.MUTED,14)

## Hàng ô số liệu: mỗi ô là [tên, giá trị].
func _stat_row(pairs: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation",8)
	body.add_child(h)
	for pr in pairs:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel",UIKit.box(Color(UIKit.INK_2,0.95),UIKit.BLACK,2,0,Vector2(10,6)))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation",0)
		pc.add_child(v)
		v.add_child(UIKit.label(str(pr[0]),13,UIKit.MUTED))
		v.add_child(UIKit.label(str(pr[1]),22,UIKit.PAPER))
		h.add_child(pc)

## Thẻ nền tối bo viền; trả về VBox bên trong để thêm nội dung.
func _card(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel",UIKit.box(Color(UIKit.INK_2,0.95),UIKit.BLACK,2,0,Vector2(12,9)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",4)
	pc.add_child(v)
	parent.add_child(pc)
	return v

func _text(parent: Node, text: String, size := 14, color := UIKit.PAPER) -> Label:
	var l := UIKit.label(text,size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120,0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func _grid() -> GridContainer:
	var margin := MarginContainer.new()   # chừa chỗ cho thanh cuộn, nếu không cột phải bị che
	margin.add_theme_constant_override("margin_right",20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(margin)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation",10)
	g.add_theme_constant_override("v_separation",10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(g)
	return g

## Phím bấm của từng ô theo trang bị hiện tại.
func _key_for(slot: String) -> String:
	var primary: String = runtime.state.primary
	match slot:
		"cong": return "J" if primary == "cong" else "K"
		"artifact": return "J" if primary == "artifact" else "K"
		"cong2": return "U"
		"than": return "Space"
	return ""

func _loadout() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",8)
	body.add_child(top)
	top.add_child(UIKit.label("Phím J ra chiêu của:",15,UIKit.MUTED))
	button(top,"Công Pháp",runtime.choose_primary.bind("cong"),runtime.state.primary == "cong")
	button(top,"Pháp Bảo (Bảo Tu)",runtime.choose_primary.bind("artifact"),runtime.state.primary == "artifact")
	var grid := _grid()
	for slot in SLOT_NAMES:
		var item: Dictionary = runtime.state.item_for(slot)
		var d: Dictionary = runtime.state.def_for(slot)
		var v := _card(grid)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation",8)
		v.add_child(head)
		var key := _key_for(slot)
		var cap_cell := Control.new()
		cap_cell.custom_minimum_size = Vector2(66,26)
		head.add_child(cap_cell)
		if key != "":
			cap_cell.add_child(UIKit.KeyCap.new(key,"",13))
		head.add_child(UIKit.label(str(SLOT_NAMES[slot]),14,UIKit.MUTED))
		var nm := UIKit.label(str(d.get("name","Chưa trang bị")),19,UIKit.GOLD if not d.is_empty() else UIKit.MUTED)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(nm)
		if item.is_empty():
			continue
		_item_body(v,item)
	_text(body,"Tâm Pháp tự kích hoạt, không có phím. Đổi bí tịch / trang bị ở tab Bí tịch và Trang bị khi ngoài giao tranh.",13,UIKit.MUTED)

## Phần thân của thẻ bí tịch / trang bị: dòng thông tin, số liệu cô đọng, các dòng hiệu ứng.
func _item_body(v: VBoxContainer, item: Dictionary) -> void:
	var p := parts(item)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation",8)
	v.add_child(meta)
	var q := UIKit.label(str(Data.data().qualities[item.quality].name),13,QUALITY_COLORS.get(str(item.quality),UIKit.PAPER))
	meta.add_child(q)
	var ml := _text(meta,str(p.meta),13,UIKit.MUTED)
	ml.custom_minimum_size = Vector2(60,0)
	if str(p.stats) != "":
		_text(v,str(p.stats),14,UIKit.JADE)
	for n in p.notes:
		_text(v,str(n),13,UIKit.PAPER)

## Tách thông tin một bản bí tịch / trang bị: meta (phái, độ hiếm, nguồn, yêu cầu), stats cô đọng, notes (hiệu ứng, dòng phụ...).
func parts(item: Dictionary) -> Dictionary:
	var d: Dictionary = Data.definition(item.definition)
	var meta := "%s · %s · Nguồn: %s" % [Data.data().sects.get(d.get("sect",""),{"name":"Trang bị"}).name,Data.data().secrecy[item.secrecy],SOURCE_NAMES.get(item.source,item.source)]
	if int(d.get("need", 0)) > 0:
		meta += " · Cần %s" % Data.step_name(int(d.need))
	var bits: Array[String] = []
	var full: Array[String] = []
	if d.has("cost"):
		var slot: String = d.slot
		var previous: String = runtime.state.equipped[slot]
		runtime.state.equipped[slot] = item.uid
		var quote: Dictionary = runtime.engine.cost(slot)
		var cooldown: float = runtime.engine.cooldown_for(slot)
		runtime.state.equipped[slot] = previous
		bits.append("Linh lực %.0f" % float(quote.actual))
		bits.append("hồi %.1fs" % cooldown)
		if float(d.get("cast_time",0)) > 0.0:
			bits.append("thi triển %.2fs" % float(d.get("cast_time",0)))
		full.append("Linh lực gốc %.1f → thực tế hiện tại %.1f · hồi %.1fs · thi triển %.2fs" % [quote.base,quote.actual,cooldown,d.get("cast_time",0)])
	if d.has("damage"):
		var reach: float = maxf(float(d.get("range",0)), GrandFx.reach(d))   # đại chiêu: tầm đánh khớp hình ảnh
		var shape: String = str(SHAPE_NAMES.get(d.get("shape",""),""))
		bits.append("sát thương %.0f" % float(d.damage))
		bits.append("tầm %.0f" % reach)
		if shape != "":
			bits.append(shape)
		full.append("Sát thương cơ sở %.0f · tầm %.0f · %s" % [d.damage,reach,shape])
	var notes: Array[String] = []
	if str(d.get("slot","")) in ["cong","artifact"] and SkillFx.is_grand(d):
		var extra := "Đại chiêu: gồng lực rồi bùng nổ"
		if GrandFx.impact_radius(d) > 0.0:
			extra += " · vùng nổ %.0f" % GrandFx.impact_radius(d)
			if str(d.get("shape","")) == "line":
				extra += " (ngoài tia nhận %d%% sát thương)" % roundi(GrandFx.SPLASH_FALLOFF * 100.0)
		if GrandFx.is_area_summon(d):
			extra += " · đánh tới %d mục tiêu, từ mục tiêu thứ hai nhận %d%%" % [GrandFx.SUMMON_MAX_TARGETS, roundi(GrandFx.SUMMON_FALLOFF * 100.0)]
		notes.append(extra)
	if d.get("shape", "") == "summon":
		var fate: Dictionary = Data.data().fates[runtime.state.origin.fate]
		notes.append("Duy trì %.1f linh lực / %.1fs; tồn tại %.1fs. Chỉ kế thừa hiệu ứng cho phép triệu hồi." % [Data.balance("summon_upkeep")+float(fate.get("summon_upkeep",0)),Data.balance("summon_interval"),float(d.get("duration",4))+float(fate.get("summon_duration",0))])
	if d.has("conditional"):
		notes.append("• " + str(d.conditional.get("text","")))
	for effect_id in d.get("effects",[]):
		notes.append("• " + str(Data.effect(effect_id).description))
	for affix_id in item.affixes:
		var a: Dictionary = Data.data().affixes[affix_id]
		notes.append("+ %s: %s" % [a.name,a.description])
	if Data.data().fates[runtime.state.origin.fate].get("reveal_hidden",false):
		notes.append("Thiên Nhãn thấy dòng tiềm ẩn: " + str(Data.data().affixes[item.hidden_affix].name))
	else:
		notes.append("Dòng tiềm ẩn chưa biết (tham ngộ để thay một dòng).")
	if item.fragment:
		notes.append("Tàn quyển: cần tham ngộ bổ khuyết trước khi học.")
	return {"meta": meta, "stats": " · ".join(bits), "full": full, "notes": notes, "quality": Data.data().qualities[item.quality].name}

## Bản văn đầy đủ (dùng làm gợi ý khi rê chuột và cho test).
func tooltip(item: Dictionary) -> String:
	var p := parts(item)
	var lines: Array[String] = ["%s · %s" % [p.quality,p.meta]]
	lines.append_array(p.full)
	lines.append_array(p.notes)
	return "\n".join(lines)

func _inventory() -> void:
	var books := page == "books"
	if books:
		_text(body,"Cách có thêm bí tịch: mua bản Phổ Truyền ở thương nhân (linh thạch) · đổi bí tịch của tông ở Tàng Kinh Các (công huân) · nhờ Thanh Dao truyền dạy khi thiện cảm đủ %d · đánh quái trong Linh Mạch Động để nhặt tàn quyển · tìm cơ duyên, động phủ." % int(Data.balance("npc_bond")),14,UIKit.JADE)
	else:
		_text(body,"Trang bị (vũ khí, giáp, pháp bảo): mua ở thương nhân bằng linh thạch hoặc tìm trong động phủ, di tích. Ngoại hình được giữ; vũ khí thời trang không cộng sát thương cho pháp bảo.",14,UIKit.JADE)
	if not runtime.state.research.is_empty():
		line("Đang tham ngộ: còn %.1f giây chơi. Đóng bảng để tiếp tục." % runtime.state.research.remaining,UIKit.GOLD,15)
	# đang dùng lên trước
	var uids: Array = []
	for uid in runtime.state.instances:
		var d0: Dictionary = Data.definition(runtime.state.instances[uid].definition)
		if (d0.slot in ["cong","tam","than"]) == books:
			uids.append(uid)
	uids.sort_custom(func(a, b): return int(_in_use(a)) > int(_in_use(b)))
	if uids.is_empty():
		line("Chưa có %s nào." % ("bí tịch" if books else "trang bị"),UIKit.MUTED)
		return
	var grid := _grid()
	for uid in uids:
		var item: Dictionary = runtime.state.instances[uid]
		var d: Dictionary = Data.definition(item.definition)
		var v := _card(grid)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation",8)
		v.add_child(head)
		var nm := UIKit.label(str(d.name),18,UIKit.GOLD)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		head.add_child(UIKit.label(str(SLOT_NAMES[d.slot]),14,UIKit.MUTED))
		if _in_use(uid):
			head.add_child(UIKit.label("[Đang dùng]",14,UIKit.JADE))
		_item_body(v,item)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation",6)
		row.add_theme_constant_override("v_separation",4)
		v.add_child(row)
		if not item.learned:
			var step: int = runtime.main.cult.step_index()
			var need := int(d.get("need", 0))
			var learn_button := button(row,"Học" if step >= need else "Học (cần %s)" % Data.step_name(need),func(): runtime.state.learn(uid,step),item.fragment or step < need)
			learn_button.tooltip_text = "Cảnh giới chưa đủ để lĩnh ngộ." if step < need else ""
		else:
			button(row,"Trang bị (J/K)" if d.slot == "cong" else "Trang bị",runtime.equip.bind(uid),runtime.state.equipped[d.slot] == uid)
			if d.slot == "cong":
				button(row,"Phụ (U)",runtime.equip.bind(uid,"cong2"),runtime.state.equipped.cong2 == uid)
		var study := button(row,"%s · %d linh thạch" % ["Bổ khuyết" if item.fragment else "Tham ngộ",runtime.state.study_cost()],runtime.study.bind(uid),not runtime.state.research.is_empty())
		var ins := float(runtime.state.origin.attributes.insight)
		var how := "Mini game Ngộ đạo: nhớ chuỗi ngũ hành, càng nhiều vòng càng ngộ sâu. Hỏng thì mất linh thạch." if not item.fragment else "Mini game Ngộ đạo: vượt từ 2 vòng để bổ khuyết tàn quyển."
		study.tooltip_text = how + "\n" + StudyGame.insight_text(ins)

func _in_use(uid: String) -> bool:
	var item: Dictionary = runtime.state.instances[uid]
	var d: Dictionary = Data.definition(item.definition)
	return runtime.state.equipped[d.slot] == uid or (d.slot == "cong" and runtime.state.equipped.cong2 == uid)

## Trang giao dịch: chỉ mở khi đứng trước NPC tương ứng (Tàng Kinh Các / thương nhân / Thanh Dao), không có tab riêng.
func _acquire() -> void:
	var st = runtime.state
	var main_node = runtime.main
	match method:
		"market":
			header.text = "THƯƠNG HỘI · BÍ TỊCH VÀ PHÁP BẢO"
			line("Mua bí tịch Phổ Truyền và trang bị bằng linh thạch. Linh thạch hiện có: %d." % main_node.inv.stones,UIKit.JADE)
		"sect":
			header.text = "TÀNG KINH CÁC · %s" % str(Data.data().sects.get(st.sect,{"name":"Chưa chọn"}).name).to_upper()
			line("Đổi bí tịch của tông bằng công huân · %s · Công huân %d · Uy tín %d." % [Data.data().ranks[st.rank()],main_node.inv.merit,st.reputation],UIKit.JADE)
		_:
			header.text = "THANH DAO · TRUYỀN DẠY NGOẠI PHÁI"
			var bond := int(main_node.sect_life.bonds.get("thanh_dao",0))
			line("Thanh Dao truyền dạy bí tịch công khai của phái khác, mỗi bí tịch một lần. Thiện cảm: %d / %d." % [bond,int(Data.balance("npc_bond"))],UIKit.JADE)
	if not st.wanted.is_empty():
		line("Thù hận do chiến lợi phẩm: %s. Dùng bí tịch mua hợp pháp không gây thù hận." % str(st.wanted),UIKit.RED)
	var entries: Array = Data.data().books.duplicate()
	if method == "market":
		entries.append_array(Data.data().equipment)
	for d in entries:
		if method == "market" and d.get("secrecy","public") != "public":
			continue
		if method == "sect" and d.get("sect","") != st.sect:
			continue
		if method == "npc" and (d.get("sect","") == st.sect or d.get("secrecy","") != "public"):
			continue
		var price := "%d công huân" % runtime.merit_price(d) if method == "sect" else ("Truyền dạy một lần" if method == "npc" else "%d linh thạch" % int(Data.balance("book_price") if d.slot in ["cong","tam","than"] else Data.balance("gear_price")))
		var reason: String = runtime.access_reason(d,method)
		var b := button(body,"%s · %s · %s" % [d.name,SLOT_NAMES[d.slot],price],runtime.acquire_from.bind(d.id,method),reason != "")
		b.tooltip_text = reason if reason != "" else "Nhận một bản mới có dòng phụ được roll riêng."
