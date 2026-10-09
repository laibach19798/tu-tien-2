extends CanvasLayer
## HUD tu luyện: thẻ nhân vật (cảnh giới, tu vi, linh khí, linh thạch, thời gian), nhiệm vụ, thanh chiêu thức, lời nhắc, thông báo.

var _medal: Medallion
var _realm: UIKit.Banner
var _state: Label
var _hp: UIKit.FancyBar
var _hurt: ColorRect
var _boss: PanelContainer
var _boss_name: Label
var _boss_bar: UIKit.FancyBar
var _death: Control
var _xp: UIKit.FancyBar
var _qi: UIKit.FancyBar
var _stones: Label
var _time_icon: UIKit.Icon
var _time: Label
var _quest_title: Label
var _quest_desc: Label
var _quest_bar: UIKit.FancyBar
var _quest_frame: UIKit.Frame
var _prompt: PanelContainer
var _prompt_box: HBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _slots: Array = []
var _skill_bar: HBoxContainer


func _ready() -> void:
	layer = 10
	_build_card()
	_build_quest()
	_build_prompt()
	_build_toast()
	_build_hints()
	_build_overlays()


# ---------------------------------------------------------------- thẻ nhân vật
func _build_card() -> void:
	var card := UIKit.Frame.new(Vector2(330, 0), 0.9)
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 14
	card.offset_top = 12
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_medal = Medallion.new()
	head.add_child(_medal)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(col)
	_realm = UIKit.Banner.new("Luyện Khí", 21, UIKit.GOLD, true)
	col.add_child(_realm)
	_state = UIKit.label("", 13, UIKit.MUTED)
	col.add_child(_state)
	_hp = UIKit.FancyBar.new("Khí huyết", UIKit.RED, 22.0)
	v.add_child(_hp)
	_xp = UIKit.FancyBar.new("Tu vi", UIKit.XP_GOLD, 22.0)
	v.add_child(_xp)
	_qi = UIKit.FancyBar.new("Linh khí", UIKit.QI_BLUE, 22.0)
	v.add_child(_qi)
	var sep := HSeparator.new()
	v.add_child(sep)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(UIKit.Icon.new("stone", Color.WHITE, 24.0))
	_stones = UIKit.label("0", 17, UIKit.STONE_TXT)
	row.add_child(_stones)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	_time_icon = UIKit.Icon.new("sun", UIKit.GOLD, 24.0)
	row.add_child(_time_icon)
	_time = UIKit.label("", 14, UIKit.PAPER)
	row.add_child(_time)


func update_status(c: Cultivation, meditating: bool, density: float) -> void:
	_realm.set_text("%s · Tầng %d" % [Cultivation.REALMS[c.realm], c.layer])
	_xp.set_value(c.xp, c.xp_needed())
	_qi.set_value(c.qi, c.qi_max())
	_medal.set_info(c.realm, c.layer, c.xp / maxf(c.xp_needed(), 1.0), c.ready_breakthrough, meditating)
	if meditating:
		_state.text = "Đang tu luyện (linh mạch x%.0f)" % density if density > 1.0 else "Đang tu luyện…"
		_state.add_theme_color_override("font_color", UIKit.JADE)
	elif c.ready_breakthrough:
		_state.text = "Tu vi viên mãn — nhấn B để đột phá"
		_state.add_theme_color_override("font_color", UIKit.GOLD)
	else:
		_state.text = "Nhấn F để ngồi thiền"
		_state.add_theme_color_override("font_color", UIKit.MUTED)


func set_stones(n: int) -> void:
	_stones.text = "%d" % n


func set_time(text: String) -> void:
	_time.text = text
	var night := text.contains("đêm")
	var dusk := text.contains("Hoàng hôn") or text.contains("Bình minh")
	_time_icon.set_kind("moon" if night else "sun", Color(0.78, 0.84, 1.0) if night else (Color(1.0, 0.6, 0.3) if dusk else UIKit.GOLD))


# ---------------------------------------------------------------- nhiệm vụ
func _build_quest() -> void:
	_quest_frame = UIKit.Frame.new(Vector2(310, 0), 0.88)
	_quest_frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_frame.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_frame.offset_right = -14
	_quest_frame.offset_top = 12
	add_child(_quest_frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_quest_frame.add_child(v)
	v.add_child(UIKit.Banner.new("Nhiệm vụ (Q)", 18, UIKit.GOLD, true))
	_quest_title = UIKit.label("", 17, UIKit.JADE)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_title.custom_minimum_size = Vector2(266, 0)
	v.add_child(_quest_title)
	_quest_desc = UIKit.label("", 14, UIKit.PAPER)
	_quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_desc.custom_minimum_size = Vector2(266, 0)
	v.add_child(_quest_desc)
	_quest_bar = UIKit.FancyBar.new("", UIKit.JADE, 16.0)
	_quest_bar.visible = false
	v.add_child(_quest_bar)


## Văn bản từ Quests.tracker_text(): dòng 1 là tên, dòng 2 là mô tả (x/y), dòng cuối có thể là lời nhắc trả nhiệm vụ.
func set_quest(text: String) -> void:
	var lines := text.split("\n")
	_quest_title.text = lines[0]
	var rest := ""
	for i in range(1, lines.size()):
		rest += ("\n" if rest != "" else "") + lines[i]
	var rx := RegEx.new()
	rx.compile("\\((\\d+)/(\\d+)\\)")
	var m := rx.search(rest)
	if m != null:
		_quest_bar.visible = true
		_quest_bar.set_value(float(m.get_string(1)), float(m.get_string(2)))
		rest = rx.sub(rest, "", true).strip_edges()
	else:
		_quest_bar.visible = false
	_quest_desc.text = rest
	_quest_desc.visible = rest != ""
	_quest_frame.reset_size.call_deferred()


# ---------------------------------------------------------------- chiêu thức
## Thanh chiêu thức ở đáy màn hình.
func build_skillbar(skills: Array) -> void:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK, 0.55), Color(UIKit.GOLD_DK, 0.7), 1, 12, Vector2(12, 4)))
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_bottom = -10
	add_child(plate)
	_skill_bar = HBoxContainer.new()
	_skill_bar.add_theme_constant_override("separation", 6)
	plate.add_child(_skill_bar)
	for s in skills:
		var slot := UIKit.SkillSlot.new(s)
		_skill_bar.add_child(slot)
		_slots.append(slot)


func update_skills(infos: Array) -> void:
	for i in mini(infos.size(), _slots.size()):
		var info: Dictionary = infos[i]
		_slots[i].set_state(clampf(info["cd"], 0.0, 1.0), info["unlocked"], info["afford"])


# ---------------------------------------------------------------- lời nhắc & thông báo
func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK, 0.82), UIKit.GOLD, 1, 14, Vector2(14, 6)))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_bottom = -118
	_prompt.visible = false
	add_child(_prompt)
	_prompt_box = HBoxContainer.new()
	_prompt_box.add_theme_constant_override("separation", 8)
	_prompt.add_child(_prompt_box)


func set_prompt(text: String) -> void:
	_prompt.visible = text != ""
	if text == "":
		return
	for c in _prompt_box.get_children():
		_prompt_box.remove_child(c)
		c.queue_free()
	var key := "E"
	var msg := text
	var p := text.find(": ")
	if p > 0 and p <= 3:
		key = text.substr(0, p)
		msg = text.substr(p + 2)
	_prompt_box.add_child(UIKit.KeyCap.new(key, "", 15))
	_prompt_box.add_child(UIKit.label(msg, 17, UIKit.PAPER))


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK, 0.9), UIKit.GOLD, 2, 16, Vector2(26, 8)))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 146
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast_label = UIKit.label("", 20, UIKit.GOLD)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


func toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast.offset_top = 130
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_property(_toast, "offset_top", 146.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.4)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.9)


# ---------------------------------------------------------------- gợi ý phím
func _build_hints() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 14
	box.offset_bottom = -10
	box.modulate = Color(1, 1, 1, 0.82)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for h in [["WASD", "Di chuyển"], ["Shift", "Chạy"], ["F", "Thiền"], ["B", "Đột phá"], ["E", "Tương tác"], ["P", "Nhân vật"], ["Q", "Nhiệm vụ"], ["M", "Bản đồ"], ["I", "Túi đồ"], ["C", "Tủ đồ"], ["T", "Tua thời gian"], ["Esc", "Tạm dừng"]]:
		box.add_child(UIKit.KeyCap.new(h[0], h[1], 12))


# ---------------------------------------------------------------- khí huyết, trọng thương
func update_hp(hp: float, max_hp: float) -> void:
	_hp.set_value(hp, max_hp)


## Màn hình loé đỏ khi bị đánh.
func flash_hurt() -> void:
	_hurt.color.a = 0.38
	var tw := create_tween()
	tw.tween_property(_hurt, "color:a", 0.0, 0.35)


func show_death(title: String, sub: String) -> void:
	_death.visible = true
	_death.get_node("T").text = title
	_death.get_node("S").text = sub
	_death.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_death, "modulate:a", 1.0, 0.5)


func hide_death() -> void:
	var tw := create_tween()
	tw.tween_property(_death, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _death.visible = false)


## Thanh máu thủ lĩnh (hiện khi lại gần), name = "" để ẩn.
func set_boss(boss_name: String, hp: float, max_hp: float) -> void:
	_boss.visible = boss_name != ""
	if boss_name == "":
		return
	_boss_name.text = boss_name
	_boss_bar.set_value(hp, max_hp)


func _build_overlays() -> void:
	_boss = PanelContainer.new()
	_boss.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK, 0.9), UIKit.BLACK, 3, 0, Vector2(14, 8)))
	_boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss.offset_top = 14
	_boss.visible = false
	add_child(_boss)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bv.custom_minimum_size = Vector2(420, 0)
	_boss.add_child(bv)
	_boss_name = UIKit.label("", 22, UIKit.RED)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = UIKit.FancyBar.new("", UIKit.RED, 20.0)
	_boss_bar.show_numbers = false
	bv.add_child(_boss_bar)
	_hurt = ColorRect.new()
	_hurt.color = Color(0.9, 0.1, 0.1, 0.0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)
	_death = Control.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	add_child(_death)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.0, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(dim)
	var t := UIKit.label("", 40, UIKit.RED)
	t.name = "T"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.offset_top = -40
	_death.add_child(t)
	var s := UIKit.label("", 18, UIKit.PAPER)
	s.name = "S"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.grow_horizontal = Control.GROW_DIRECTION_BOTH
	s.offset_top = 20
	_death.add_child(s)

## Huy hiệu cảnh giới: ô vuông có số tầng, màu theo cảnh giới, nhấp nháy khi sẵn sàng đột phá.
class Medallion extends Control:
	var realm := 1
	var layer := 1
	var ratio := 0.0
	var ready_bt := false
	var meditating := false
	var _t := 0.0

	const TINTS := [Color(0.7, 0.7, 0.75), Color(0.31, 0.83, 0.64), Color(0.29, 0.64, 0.9), Color(0.95, 0.76, 0.29), Color(0.75, 0.5, 0.95), Color(0.91, 0.38, 0.35)]

	func _init() -> void:
		custom_minimum_size = Vector2(60, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_info(r: int, l: int, x: float, ready: bool, med: bool) -> void:
		realm = r
		layer = l
		ratio = clampf(x, 0.0, 1.0)
		ready_bt = ready
		meditating = med
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if ready_bt or meditating:
			queue_redraw()

	func _draw() -> void:
		var tint: Color = TINTS[clampi(realm, 0, TINTS.size() - 1)]
		var border := UIKit.GOLD
		if ready_bt and int(_t * 4.0) % 2 == 0:
			border = Color.WHITE
		elif meditating:
			border = UIKit.JADE
		draw_rect(Rect2(0, 0, 60, 60), UIKit.BLACK)
		draw_rect(Rect2(2, 2, 56, 56), border, false, 2.0)
		draw_rect(Rect2(4, 4, 52, 52), Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35))
		draw_rect(Rect2(4, 4, 52, 4), Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55))
		draw_rect(Rect2(4, 50, 52, 6), UIKit.BLACK)
		draw_rect(Rect2(5, 51, floorf(50.0 * ratio / 2.0) * 2.0, 4), UIKit.XP_GOLD)
		var f := get_theme_default_font()
		var txt := str(layer)
		var fs := 44
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UIKit.shadow_text(self, f, Vector2(floorf(30 - tw * 0.5), 42), txt, fs, tint.lightened(0.5))