extends CanvasLayer
class_name StudyGame
## Mini game "Ngộ đạo" cho chức năng Tham ngộ: nhớ và lặp lại chuỗi ngũ hành mỗi vòng dài thêm.
## Số vòng vượt qua quyết định tầng ngộ (Progression.study_tier): hỏng / thường / sâu / đốn ngộ.
##   thường: một dòng phụ bị thay ngẫu nhiên · sâu: tự chọn dòng bị thay · đốn ngộ: thấy trước dòng mới, được chọn thay hoặc giữ nguyên.
## Ngộ Tính cho số lần "xem lại" chuỗi. Chạy theo giờ thật nên không bị ảnh hưởng bởi hitstop.

signal finished(result: Dictionary)   # {cleared:int, tier:String, replace:int}  replace: -1 ngẫu nhiên, -2 giữ nguyên, >=0 chỉ số dòng

const Progression = preload("res://scripts/v1/progression.gd")
const ROUNDS := 5
const LENGTHS := [3, 4, 5, 6, 7]
const ELEMENTS := [
	{"id": "kim", "name": "Kim", "col": Color(0.95, 0.86, 0.45), "key": KEY_1},
	{"id": "moc", "name": "Mộc", "col": Color(0.45, 0.90, 0.50), "key": KEY_2},
	{"id": "thuy", "name": "Thủy", "col": Color(0.40, 0.70, 1.00), "key": KEY_3},
	{"id": "hoa", "name": "Hỏa", "col": Color(1.00, 0.50, 0.28), "key": KEY_4},
	{"id": "tho", "name": "Thổ", "col": Color(0.80, 0.62, 0.38), "key": KEY_5},
]
const TIER_TEXT := {
	"fail": ["Tâm loạn", "Ngộ không thành. Linh thạch đã tiêu, bản này không đổi."],
	"ok": ["Ngộ được một phần", "Một dòng phụ bị thay ngẫu nhiên bằng dòng tiềm ẩn."],
	"good": ["Ngộ sâu", "Ngươi chọn dòng phụ muốn bỏ; dòng mới là dòng tiềm ẩn."],
	"perfect": ["Đốn ngộ", "Thấy rõ dòng tiềm ẩn trước khi chọn: thay một dòng hoặc giữ nguyên."],
}

var _cfg: Dictionary = {}
var _seq: Array = []
var _round := 0
var _pos := 0
var _cleared := 0
var _peeks := 0
var _mistakes := 0      # số lần sai còn được tha
var _params: Dictionary = {}
var _idle := 0.0         # giây chờ ở lượt nhập (cho gợi ý của Ngộ Tính cao)
var _info: Label
var _state := "idle"    # idle | show | input | result
var _gen := 0           # đổi mỗi lần bắt đầu / bỏ để các coroutine cũ tự dừng
var _buttons: Array[Button] = []
var _styles: Array = []   # [thường, sáng]
var _status: Label
var _round_label: Label
var _peek_button: Button
var _result_box: VBoxContainer
var _play_box: VBoxContainer
var _title: Label
var _rng := RandomNumberGenerator.new()
var _speed := 1.0       # nhân thời gian chờ (test đặt nhỏ để chạy nhanh)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.03, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.theme = UIKit.theme()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.GOLD_DK, 2, 0, Vector2(26, 20)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_title = UIKit.label("NGỘ ĐẠO", 24, UIKit.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_play_box = VBoxContainer.new()
	_play_box.add_theme_constant_override("separation", 12)
	v.add_child(_play_box)
	_round_label = UIKit.label("", 16, UIKit.JADE)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_box.add_child(_round_label)
	_info = UIKit.label("", 13, UIKit.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(660, 0)
	_play_box.add_child(_info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_play_box.add_child(row)
	for i in ELEMENTS.size():
		var e: Dictionary = ELEMENTS[i]
		var col: Color = e["col"]
		var b := Button.new()
		b.text = "%d\n%s" % [i + 1, e["name"]]
		b.custom_minimum_size = Vector2(110, 110)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
		var dim := UIKit.box(col.darkened(0.62), UIKit.BLACK, 3, 0, Vector2(8, 8))
		var lit := UIKit.box(col.lightened(0.15), Color.WHITE, 3, 0, Vector2(8, 8))
		_styles.append([dim, lit])
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, dim)
		b.pressed.connect(_press.bind(i))
		row.add_child(b)
		_buttons.append(b)
	_status = UIKit.label("", 18, UIKit.PAPER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_box.add_child(_status)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 12)
	_play_box.add_child(foot)
	_peek_button = Button.new()
	_peek_button.focus_mode = Control.FOCUS_NONE
	_peek_button.pressed.connect(_peek)
	foot.add_child(_peek_button)
	var quit_b := Button.new()
	quit_b.text = "Bỏ ngộ [Esc]"
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.pressed.connect(_abandon)
	foot.add_child(quit_b)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 10)
	_result_box.visible = false
	v.add_child(_result_box)


func is_active() -> bool:
	return visible


## cfg: {name, seed, insight, fragment, affixes: [{name, desc}], hidden: {name, desc}}
func begin(cfg: Dictionary) -> void:
	_cfg = cfg
	_rng.seed = int(cfg.get("seed", 1))
	_speed = float(cfg.get("speed", 1.0))
	_round = 0
	_cleared = 0
	_params = Progression.study_params(float(cfg.get("insight", 25.0)))
	_peeks = int(_params.peeks)
	_mistakes = int(_params.mistakes)
	_info.text = insight_text(float(cfg.get("insight", 25.0)))
	_gen += 1
	_title.text = "NGỘ ĐẠO · %s" % str(cfg.get("name", ""))
	_play_box.visible = true
	_result_box.visible = false
	show()
	_next_round()


func _next_round() -> void:
	_seq.clear()
	for i in maxi(2, int(LENGTHS[_round]) + int(_params.len_delta)):
		_seq.append(_rng.randi_range(0, ELEMENTS.size() - 1))
	_round_label.text = "Vòng %d / %d · chuỗi %d ngũ hành" % [_round + 1, ROUNDS, _seq.size()]
	_show_sequence()


func _show_sequence() -> void:
	_state = "show"
	_pos = 0
	_status.text = "Ghi nhớ..."
	_status.add_theme_color_override("font_color", UIKit.MUTED)
	_update_peek()
	var g := _gen
	await _wait(0.45)
	for id in _seq:
		if g != _gen:
			return
		_flash(int(id), float(_params.flash))
		Sfx.play("ui_open", 0.8 + 0.12 * float(id))
		await _wait(float(_params.flash) + 0.18)
	if g != _gen:
		return
	_state = "input"
	_idle = 0.0
	_status.text = "Đến lượt ngươi · bấm 1-5 hoặc chuột"
	_status.add_theme_color_override("font_color", UIKit.PAPER)
	_update_peek()


func _update_peek() -> void:
	_peek_button.text = "Xem lại [R] · còn %d" % _peeks
	_peek_button.disabled = _peeks <= 0 or _state != "input"


func _peek() -> void:
	if _state != "input" or _peeks <= 0:
		return
	_peeks -= 1
	_show_sequence()


func _press(i: int) -> void:
	if _state != "input":
		return
	_flash(i, 0.18)
	Sfx.play("ui_open", 0.8 + 0.12 * float(i))
	_idle = 0.0
	if i != int(_seq[_pos]) and _mistakes > 0:
		_mistakes -= 1
		_status.text = "Sai! Ngộ Tính tha cho một lần · còn tha %d lần" % _mistakes
		_status.add_theme_color_override("font_color", UIKit.GOLD)
		return
	if i != int(_seq[_pos]):
		_state = "wrong"
		_status.text = "Sai rồi! Tâm niệm tán loạn."
		_status.add_theme_color_override("font_color", UIKit.RED)
		_update_peek()
		var g := _gen
		await _wait(0.9)
		if g == _gen:
			_finish_play()
		return
	_pos += 1
	if _pos >= _seq.size():
		_cleared += 1
		_state = "between"
		_status.text = "Vượt qua vòng %d!" % _cleared
		_status.add_theme_color_override("font_color", UIKit.JADE)
		_update_peek()
		var g2 := _gen
		await _wait(0.7)
		if g2 != _gen:
			return
		_round += 1
		if _round >= ROUNDS:
			_finish_play()
		else:
			_next_round()


func _abandon() -> void:
	if _state == "result" or _state == "idle":
		return
	_gen += 1
	_cleared = 0
	_finish_play()


func _finish_play() -> void:
	_gen += 1
	_state = "result"
	var tier: String = Progression.study_tier(_cleared)
	var fragment := bool(_cfg.get("fragment", false))
	_play_box.visible = false
	for c in _result_box.get_children():
		_result_box.remove_child(c)
		c.queue_free()
	_result_box.visible = true
	var txt: Array = TIER_TEXT[tier]
	var t := UIKit.label("%s · %d / %d vòng" % [txt[0], _cleared, ROUNDS], 22, UIKit.GOLD if tier != "fail" else UIKit.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(t)
	var desc_text: String = str(txt[1])
	if fragment:
		desc_text = "Bổ khuyết tàn quyển thành công: có thể học." if tier != "fail" else "Chưa bổ khuyết được tàn quyển. Linh thạch đã tiêu."
	_wrap(desc_text, 16, UIKit.PAPER)
	var choose := (tier == "good" or tier == "perfect") and not fragment
	if choose:
		if tier == "perfect" or bool(_params.get("reveal_good", false)):
			var h: Dictionary = _cfg.get("hidden", {})
			_wrap("Dòng tiềm ẩn: %s — %s" % [str(h.get("name", "?")), str(h.get("desc", ""))], 16, UIKit.JADE)
		else:
			_wrap("Chọn dòng phụ muốn bỏ (dòng mới là dòng tiềm ẩn, chưa rõ):", 15, UIKit.MUTED)
		var affixes: Array = _cfg.get("affixes", [])
		for i in affixes.size():
			var a: Dictionary = affixes[i]
			var b := Button.new()
			b.text = "Thay dòng: %s — %s" % [str(a.get("name", "")), str(a.get("desc", ""))]
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = false
			b.pressed.connect(_done.bind(tier, i))
			_result_box.add_child(b)
		if tier == "perfect":
			var keep := Button.new()
			keep.text = "Giữ nguyên, không thay dòng nào"
			keep.focus_mode = Control.FOCUS_NONE
			keep.pressed.connect(_done.bind(tier, -2))
			_result_box.add_child(keep)
	else:
		var ok := Button.new()
		ok.text = "Xác nhận"
		ok.focus_mode = Control.FOCUS_NONE
		ok.pressed.connect(_done.bind(tier, -1))
		_result_box.add_child(ok)


func _done(tier: String, replace: int) -> void:
	if _state != "result":
		return
	_state = "idle"
	_gen += 1
	hide()
	finished.emit({"cleared": _cleared, "tier": tier, "replace": replace})


func _wrap(text: String, size: int, color: Color) -> void:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(660, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(l)


func _flash(i: int, dur: float) -> void:
	var b := _buttons[i]
	var st: Array = _styles[i]
	for name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(name, st[1])
	await _wait(dur)
	for name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(name, st[0])


func _process(delta: float) -> void:
	if _state != "input" or float(_params.get("hint_delay", 0.0)) <= 0.0:
		return
	_idle += delta
	if _idle >= float(_params.hint_delay):
		_idle = float(_params.hint_delay) - 2.5   # nhắc lại sau mỗi 2,5 giây nghĩ thêm
		_flash(int(_seq[_pos]), 0.28)
		_status.text = "Ngộ Tính mách bảo: ký hiệu tiếp theo thoáng sáng..."


static func insight_text(insight: float) -> String:
	var p: Dictionary = Progression.study_params(insight)
	var bits: Array[String] = ["xem lại %d lần" % int(p.peeks)]
	if int(p.mistakes) > 0:
		bits.append("tha %d lần sai" % int(p.mistakes))
	if int(p.len_delta) > 0:
		bits.append("chuỗi dài hơn 1 (Ngộ Tính thấp)")
	elif int(p.len_delta) < 0:
		bits.append("chuỗi ngắn hơn 1")
	if float(p.hint_delay) > 0.0:
		bits.append("gợi ý sau %.0fs nghĩ" % float(p.hint_delay))
	if bool(p.reveal_good):
		bits.append("ngộ sâu cũng thấy dòng tiềm ẩn")
	return "Ngộ Tính %d: %s." % [roundi(insight), ", ".join(bits)]


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec * _speed, true, false, true).timeout


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		_abandon()
	elif k == KEY_R:
		_peek()
	else:
		for i in ELEMENTS.size():
			if k == int(ELEMENTS[i]["key"]) or k == KEY_KP_1 + i:
				_press(i)
