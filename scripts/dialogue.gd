extends CanvasLayer
## Hộp hội thoại: chân dung người nói, chữ hiện dần, lựa chọn có số. Nói nhiều câu liên tiếp (say) hoặc đưa ra lựa chọn (choose).
## Phím: E/Space/Enter để tiếp (lần đầu hiện hết chữ), 1-9 để chọn.

const CHARS_PER_SEC := 70.0
const TINTS := [Color(0.45, 0.9, 0.75), Color(1.0, 0.82, 0.4), Color(0.55, 0.78, 1.0), Color(0.95, 0.55, 0.6), Color(0.8, 0.6, 1.0), Color(0.6, 0.95, 0.5)]

var open := false
var _portrait: Portrait
var _name: UIKit.Banner
var _text: Label
var _box: VBoxContainer
var _opts: Array = []
var _panel: UIKit.Frame
var _type_tween: Tween
var _typing := false


func _ready() -> void:
	layer = 20
	_panel = UIKit.Frame.new(Vector2(940, 0), 0.95)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -22
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_panel.add_child(h)
	_portrait = Portrait.new()
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	_name = UIKit.Banner.new("", 22, UIKit.GOLD, true)
	v.add_child(_name)
	_text = UIKit.label("", 19, UIKit.PAPER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(740, 66)
	v.add_child(_text)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	v.add_child(_box)
	_panel.visible = false


## lines: Array[String]. then: Callable gọi khi nói xong.
func say(speaker: String, lines: Array, then := Callable()) -> void:
	_next(speaker, lines, 0, then)


## options: Array of {"text": String, "call": Callable}
func choose(speaker: String, text: String, options: Array) -> void:
	_show(speaker, text, options)


func _next(speaker: String, lines: Array, i: int, then: Callable) -> void:
	if i >= lines.size():
		if then.is_valid():
			then.call()
		return
	var label := "Tiếp tục" if i < lines.size() - 1 else "Xong"
	_show(speaker, lines[i], [{"text": label, "call": _next.bind(speaker, lines, i + 1, then)}])


func _show(speaker: String, text: String, options: Array) -> void:
	_name.set_text(speaker)
	_portrait.set_speaker(speaker)
	_text.text = text
	_opts = options
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = ("%s   (E)" % options[i]["text"]) if options.size() == 1 else "%d.  %s" % [i + 1, options[i]["text"]]
		b.pressed.connect(_pick.bind(i))
		_box.add_child(b)
	open = true
	_panel.visible = true
	_box.visible = false
	_start_typing(text.length())


func _start_typing(n: int) -> void:
	if _type_tween:
		_type_tween.kill()
	_text.visible_characters = 0
	_typing = true
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_characters", n, maxf(n / CHARS_PER_SEC, 0.05))
	_type_tween.tween_callback(_finish_typing)


func _finish_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	_text.visible_characters = -1
	_typing = false
	_box.visible = true


func _pick(i: int) -> void:
	if i < 0 or i >= _opts.size():
		return
	if _typing:
		_finish_typing()
	var cb: Callable = _opts[i]["call"]
	open = false
	_panel.visible = false
	if cb.is_valid():
		cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if not open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k: int = event.keycode
	if _typing and (k == KEY_E or k == KEY_SPACE or k == KEY_ENTER):
		_finish_typing()
	elif (k == KEY_E or k == KEY_SPACE or k == KEY_ENTER) and _opts.size() == 1:
		_pick(0)
	elif k >= KEY_1 and k <= KEY_9:
		_pick(k - KEY_1)


## Chân dung: ô vuông khung đôi, chữ cái đầu tên to ở giữa, màu theo người nói.
class Portrait extends Control:
	var initial := "?"
	var tint := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_speaker(speaker: String) -> void:
		var words := speaker.split(" ", false)
		initial = words[words.size() - 1].substr(0, 1).to_upper() if not words.is_empty() else "?"
		tint = TINTS[absi(speaker.hash()) % TINTS.size()]
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 104, 104), UIKit.BLACK)
		draw_rect(Rect2(3, 3, 98, 98), UIKit.GOLD, false, 2.0)
		draw_rect(Rect2(6, 6, 92, 92), Color(tint.r * 0.30, tint.g * 0.30, tint.b * 0.30))
		draw_rect(Rect2(6, 6, 92, 6), Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5))
		draw_rect(Rect2(6, 86, 92, 12), Color(tint.r * 0.18, tint.g * 0.18, tint.b * 0.18))
		for p in [Vector2(10, 10), Vector2(88, 10), Vector2(10, 88), Vector2(88, 88)]:
			draw_rect(Rect2(p, Vector2(6, 6)), UIKit.GOLD)
		var f := get_theme_default_font()
		var fs := 84
		var tw := f.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UIKit.shadow_text(self, f, Vector2(floorf(52 - tw * 0.5), 74), initial, fs, tint.lightened(0.45))