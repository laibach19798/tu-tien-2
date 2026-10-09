extends CanvasLayer
## Menu tạm dừng (Esc): tiếp tục, lưu game (3 ô), tải game (ô tự động + 3 ô), xem phím điều khiển, toàn màn hình, thoát.
## Khi mở, cây cảnh bị tạm dừng; menu vẫn chạy nhờ process_mode = ALWAYS.

const SETTINGS_PATH := "user://settings.cfg"

var main: Node
var _frame: UIKit.Frame
var _body: VBoxContainer
var _page := "main"
var _confirm := ""   # khoá của nút đang chờ bấm lần hai để xác nhận
var _fullscreen := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_frame = UIKit.Frame.new(Vector2(560, 0))
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_frame)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_frame.add_child(_body)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_set_fullscreen(bool(cfg.get_value("display", "fullscreen", false)), false)


func is_open() -> bool:
	return visible


func open_menu() -> void:
	Sfx.play("ui_open")
	_page = "main"
	_confirm = ""
	visible = true
	get_tree().paused = true
	_build()


func close_menu() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		if _page == "main":
			close_menu()
		else:
			_go("main")
	elif event.keycode == KEY_F11:
		_set_fullscreen(not _fullscreen)
		_build()


func _go(page: String) -> void:
	_page = page
	_confirm = ""
	_build()


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _build() -> void:
	_clear()
	match _page:
		"main":
			_build_main()
		"save":
			_build_slots(true)
		"load":
			_build_slots(false)
		"keys":
			_build_keys()


func _btn(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.disabled = disabled
	b.pressed.connect(cb)
	b.pressed.connect(Sfx.play.bind("ui_click"))
	return b


# ---------------------------------------------------------------- trang chính
func _build_main() -> void:
	_body.add_child(UIKit.Banner.new("Tạm Dừng", 26))
	var info := UIKit.label("%s  ·  thời gian chơi %s" % [main.cult.realm_name(), _fmt_time(main.playtime)], 15, UIKit.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(info)
	_body.add_child(UIKit.spacer(4))
	_body.add_child(_btn("Tiếp tục", close_menu))
	_body.add_child(_btn("Lưu game", _go.bind("save")))
	_body.add_child(_btn("Tải game", _go.bind("load")))
	_body.add_child(_btn("Điều khiển", _go.bind("keys")))
	_body.add_child(_btn("Menu thử nghiệm  (F1)", func():
		close_menu()
		main.debug_menu.open_menu()))
	_body.add_child(_btn("Toàn màn hình: %s  (F11)" % ("BẬT" if _fullscreen else "TẮT"), func():
		_set_fullscreen(not _fullscreen)
		_build()))
	_body.add_child(_btn("Nhạc nền: %s" % ("BẬT" if Sfx.music_on else "TẮT"), func():
		Sfx.set_music(not Sfx.music_on)
		_build()))
	_body.add_child(_btn("Hiệu ứng âm thanh: %s" % ("BẬT" if Sfx.sfx_on else "TẮT"), func():
		Sfx.set_sfx(not Sfx.sfx_on)
		_build()))
	var quit_text :="Thoát game (tự lưu)" if _confirm != "quit" else "Chắc chắn thoát? Bấm lần nữa"
	_body.add_child(_btn(quit_text, _on_quit))


func _on_quit() -> void:
	if _confirm != "quit":
		_confirm = "quit"
		_build()
		return
	main.save_to_slot(0, true)
	get_tree().quit()


# ---------------------------------------------------------------- ô lưu
func _build_slots(saving: bool) -> void:
	_body.add_child(UIKit.Banner.new("Lưu Game" if saving else "Tải Game", 26))
	var first := 1 if saving else 0
	for i in range(first, 4):
		_body.add_child(_slot_card(i, saving))
	_body.add_child(UIKit.spacer(2))
	_body.add_child(_btn("Quay lại  (Esc)", _go.bind("main")))


func _slot_card(i: int, saving: bool) -> Control:
	var info: Dictionary = main.slot_info(i)
	var empty := info.is_empty()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.INK_2, 0.95), UIKit.BLACK, 2, 0, Vector2(14, 10)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	col.add_child(UIKit.label("Tự động lưu" if i == 0 else "Ô %d" % i, 18, UIKit.GOLD))
	if empty:
		col.add_child(UIKit.label("Trống", 15, UIKit.MUTED))
	else:
		col.add_child(UIKit.label("%s  ·  %d linh thạch" % [info.get("realm", "?"), int(info.get("stones", 0))], 15, UIKit.PAPER))
		col.add_child(UIKit.label("%s  ·  chơi %s" % [info.get("when", ""), _fmt_time(float(info.get("playtime", 0.0)))], 14, UIKit.MUTED))
	var key := ("save" if saving else "load") + str(i)
	var label := "Lưu" if saving else "Tải"
	if _confirm == key:
		label = "Chắc chứ?"
	var b := _btn(label, _on_slot.bind(i, saving, empty, key), (not saving) and empty)
	b.custom_minimum_size = Vector2(110, 48)
	h.add_child(b)
	return pc


func _on_slot(i: int, saving: bool, empty: bool, key: String) -> void:
	var needs_confirm := (saving and not empty) or (not saving)
	if needs_confirm and _confirm != key:
		_confirm = key
		_build()
		return
	if saving:
		main.save_to_slot(i)
		_go("save")
	else:
		if main.load_from_slot(i):
			close_menu()
		else:
			_go("load")


# ---------------------------------------------------------------- điều khiển
func _build_keys() -> void:
	_body.add_child(UIKit.Banner.new("Điều Khiển", 26))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for e in [["WASD", "Di chuyển"], ["Shift", "Chạy"], ["F", "Ngồi thiền (hồi linh khí, tăng tu vi)"], ["B", "Đột phá cảnh giới"], ["E", "Tương tác (nói chuyện, hái thuốc, lò đan)"],
			["P", "Bảng nhân vật"], ["Q", "Nhật ký nhiệm vụ"], ["M", "Bản đồ toàn làng"], ["I", "Túi đồ"], ["C", "Tủ đồ (thay trang phục)"], ["J K L U", "Bốn chiêu kiếm"], ["T", "Tua nhanh thời gian"], ["Esc", "Tạm dừng"], ["F1", "Menu thử nghiệm"], ["F11", "Toàn màn hình"]]:
		grid.add_child(UIKit.KeyCap.new(e[0], "", 15))
		grid.add_child(UIKit.label(e[1], 16, UIKit.PAPER))
	_body.add_child(UIKit.spacer(2))
	_body.add_child(_btn("Quay lại  (Esc)", _go.bind("main")))


# ---------------------------------------------------------------- tiện ích
func _fmt_time(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 60:
		return "%d phút" % m
	return "%d giờ %d phút" % [m / 60, m % 60]


func _set_fullscreen(on: bool, save := true) -> void:
	_fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if save:
		var cfg := ConfigFile.new()
		cfg.set_value("display", "fullscreen", on)
		cfg.save(SETTINGS_PATH)
