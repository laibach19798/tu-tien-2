extends CanvasLayer
class_name ScriptureGame
## Mini game "Đọc kinh" cho Tham ngộ kinh thư ở Tàng Kinh Các: năm câu kinh, mỗi câu một nhịp quét qua thanh,
## bấm đúng lúc dấu quét nằm trong vùng ngộ. Điểm 0–10 quyết định bội số tu vi nhận được.
## Ngộ Tính làm vùng ngộ rộng hơn và nhịp quét chậm hơn.
##   Lệch 0 điểm · Hợp 1 điểm · Hoàn hảo 2 điểm.

signal finished(result: Dictionary)   # {score:int, mult:float}

const VERSES := 5
const BASE_SPEED := 0.7        # lượt quét / giây ở câu đầu; mỗi câu nhanh thêm 15%
const MULT := [0.0, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5, 1.8, 2.2]
const LINES := [
	"Đạo khả đạo, phi thường đạo.",
	"Thượng thiện nhược thủy.",
	"Tâm tĩnh tự nhiên minh.",
	"Vạn pháp quy nhất.",
	"Khí tụ đan điền, thần định thức hải.",
	"Tri nhân giả trí, tự tri giả minh.",
	"Sinh sinh bất tức, biến hóa vô cùng.",
	"Kiếm tâm thông minh, vạn vật vô ngại.",
]

var _cfg: Dictionary = {}
var _verse := 0
var _score := 0
var _results: Array = []     # 0 / 1 / 2 từng câu
var _state := "idle"         # idle | run | feedback | result
var _phase := 0.0
var _center := 0.5
var _zone := 0.24
var _speed := 1.0
var _rng := RandomNumberGenerator.new()
var _lines: Array = []
var _gen := 0
var _time_scale := 1.0       # nhân thời gian chờ (test)
var _title: Label
var _verse_label: Label
var _info: Label
var _status: Label
var _track: Track
var _pips: HBoxContainer
var _play_box: VBoxContainer
var _result_box: VBoxContainer


## Tham số theo Ngộ Tính: vùng ngộ (tỉ lệ chiều dài thanh) và hệ số tốc độ quét.
static func params(insight: float) -> Dictionary:
	return {
		"zone": clampf(0.16 + (insight - 25.0) * 0.003, 0.12, 0.30),
		"speed": clampf(1.0 - (insight - 25.0) * 0.004, 0.7, 1.0),
	}


static func multiplier(score: int) -> float:
	return float(MULT[clampi(score, 0, MULT.size() - 1)])


static func tier_name(score: int) -> String:
	if score < 2:
		return "Tâm tán"
	if score < 5:
		return "Ngộ nông"
	if score < 8:
		return "Ngộ thường"
	if score < 10:
		return "Ngộ sâu"
	return "Đốn ngộ"


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
	_title = UIKit.label("ĐỌC KINH · TÀNG KINH CÁC", 24, UIKit.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_play_box = VBoxContainer.new()
	_play_box.add_theme_constant_override("separation", 12)
	v.add_child(_play_box)
	_verse_label = UIKit.label("", 22, UIKit.PAPER)
	_verse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verse_label.custom_minimum_size = Vector2(660, 0)
	_play_box.add_child(_verse_label)
	_info = UIKit.label("", 13, UIKit.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(660, 0)
	_play_box.add_child(_info)
	_track = Track.new()
	_track.custom_minimum_size = Vector2(660, 74)
	_play_box.add_child(_track)
	_pips = HBoxContainer.new()
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips.add_theme_constant_override("separation", 8)
	_play_box.add_child(_pips)
	_status = UIKit.label("", 18, UIKit.PAPER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_box.add_child(_status)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 12)
	_play_box.add_child(foot)
	var stop := Button.new()
	stop.text = "Dừng nhịp [Space]"
	stop.focus_mode = Control.FOCUS_NONE
	stop.custom_minimum_size = Vector2(220, 44)
	stop.pressed.connect(_press)
	foot.add_child(stop)
	var quit_b := Button.new()
	quit_b.text = "Bỏ đọc [Esc]"
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.pressed.connect(_abandon)
	foot.add_child(quit_b)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 10)
	_result_box.visible = false
	v.add_child(_result_box)


func is_active() -> bool:
	return visible


## cfg: {insight, seed, gain (tu vi cơ bản để hiện dự kiến), speed (test)}
func begin(cfg: Dictionary) -> void:
	_cfg = cfg
	_rng.seed = int(cfg.get("seed", randi()))
	_time_scale = float(cfg.get("speed", 1.0))
	var p := params(float(cfg.get("insight", 25.0)))
	_zone = float(p.zone)
	_speed = float(p.speed) * BASE_SPEED
	_verse = 0
	_score = 0
	_results.clear()
	_lines = LINES.duplicate()
	for i in _lines.size():
		var j := _rng.randi_range(0, _lines.size() - 1)
		var t = _lines[i]
		_lines[i] = _lines[j]
		_lines[j] = t
	_gen += 1
	_info.text = "Ngộ Tính %d: vùng ngộ %d%% thanh, nhịp quét %d%% tốc độ gốc. Hợp 1 điểm · Hoàn hảo 2 điểm (tối đa 10)." % [
		roundi(float(cfg.get("insight", 25.0))), roundi(_zone * 100.0), roundi(float(p.speed) * 100.0)]
	_play_box.visible = true
	_result_box.visible = false
	show()
	_start_verse()


func _start_verse() -> void:
	_center = _rng.randf_range(_zone * 0.5 + 0.04, 1.0 - _zone * 0.5 - 0.04)
	_phase = _rng.randf_range(0.0, 2.0)
	_verse_label.text = "「 %s 」" % str(_lines[_verse % _lines.size()])
	_status.text = "Câu %d / %d · bấm khi dấu quét vào vùng sáng" % [_verse + 1, VERSES]
	_status.add_theme_color_override("font_color", UIKit.PAPER)
	_track.center = _center
	_track.zone = _zone
	_refresh_pips()
	_state = "run"


func _refresh_pips() -> void:
	for c in _pips.get_children():
		_pips.remove_child(c)
		c.queue_free()
	for i in VERSES:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(26, 10)
		if i < _results.size():
			r.color = [Color(0.5, 0.2, 0.2), Color(0.4, 0.75, 0.6), Color(1.0, 0.85, 0.35)][int(_results[i])]
		else:
			r.color = Color(0.25, 0.28, 0.4)
		_pips.add_child(r)


func _process(delta: float) -> void:
	if _state != "run":
		return
	_phase += delta * _speed * (1.0 + 0.15 * float(_verse))
	_track.pos = _pos()


func _pos() -> float:
	var x := fposmod(_phase, 2.0)
	return x if x <= 1.0 else 2.0 - x


func _press() -> void:
	if _state != "run":
		return
	var d := absf(_pos() - _center)
	var pts := 0
	if d <= _zone * 0.18:
		pts = 2
		_status.text = "Hoàn hảo!"
		_status.add_theme_color_override("font_color", UIKit.GOLD)
	elif d <= _zone * 0.5:
		pts = 1
		_status.text = "Hợp nhịp"
		_status.add_theme_color_override("font_color", UIKit.JADE)
	else:
		_status.text = "Lệch nhịp..."
		_status.add_theme_color_override("font_color", UIKit.RED)
	_apply(pts)


## Ghi điểm cho câu hiện tại rồi sang câu kế (hoặc kết thúc). Tách riêng để test gọi trực tiếp.
func _apply(pts: int) -> void:
	_state = "feedback"
	_results.append(pts)
	_score += pts
	_refresh_pips()
	Sfx.play("ui_open", 0.8 + 0.15 * float(pts))
	var g := _gen
	await get_tree().create_timer(0.7 * _time_scale, true, false, true).timeout
	if g != _gen:
		return
	_verse += 1
	if _verse >= VERSES:
		_show_result()
	else:
		_start_verse()


func _abandon() -> void:
	if _state == "result" or _state == "idle":
		return
	_gen += 1
	_score = 0
	_results.clear()
	_show_result()


func _show_result() -> void:
	_state = "result"
	_play_box.visible = false
	for c in _result_box.get_children():
		_result_box.remove_child(c)
		c.queue_free()
	_result_box.visible = true
	var m := multiplier(_score)
	var t := UIKit.label("%s · %d / 10 điểm" % [tier_name(_score), _score], 22, UIKit.GOLD if m > 0.0 else UIKit.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(t)
	var gain := float(_cfg.get("gain", 0.0)) * m
	var d := UIKit.label(("Lĩnh ngộ được %d tu vi (×%.1f)." % [int(gain), m]) if m > 0.0 else "Tâm niệm tán loạn, chẳng ngộ được gì. Linh thạch đã tiêu.", 16, UIKit.PAPER)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(d)
	var ok := Button.new()
	ok.text = "Xác nhận"
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_done)
	_result_box.add_child(ok)


func _done() -> void:
	if _state != "result":
		return
	_state = "idle"
	_gen += 1
	hide()
	finished.emit({"score": _score, "mult": multiplier(_score)})


## Dành cho test: kết thúc ngay với số điểm cho trước.
func test_finish(score: int) -> void:
	_gen += 1
	_score = clampi(score, 0, 10)
	_show_result()
	_done()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		_abandon()
	elif k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if _state == "result":
			_done()
		else:
			_press()


## Thanh nhịp: nền, vùng ngộ (sáng dần về tâm) và dấu quét.
class Track extends Control:
	var center := 0.5
	var zone := 0.24
	var pos := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), UIKit.BLACK)
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.14, 0.16, 0.27))
		var zx := (center - zone * 0.5) * w
		var zw := zone * w
		draw_rect(Rect2(zx, 3, zw, h - 6), Color(0.18, 0.5, 0.42))
		var hx := (center - zone * 0.5 * 0.5) * w
		draw_rect(Rect2(hx, 3, zone * 0.5 * w, h - 6), Color(0.31, 0.83, 0.64))
		var px := (center - zone * 0.18) * w
		draw_rect(Rect2(px, 3, zone * 0.36 * w, h - 6), Color(1.0, 0.9, 0.5))
		var mx := clampf(pos, 0.0, 1.0) * w
		draw_rect(Rect2(mx - 3, 0, 6, h), Color.WHITE)
