extends CanvasLayer
## Menu thử nghiệm (phím F1): lối tắt để kiểm tra nhanh từng tính năng. Game tạm dừng khi menu mở.
## Lưu ý: các thao tác ở đây ghi vào ô lưu tự động như bình thường, nên đừng dùng khi muốn giữ bản lưu sạch.

var main: Node
var _frame: UIKit.Frame
var _grid_box: VBoxContainer
var _info: Label
var _show_info := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_frame = UIKit.Frame.new(Vector2(960, 0))
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_frame.add_child(v)
	v.add_child(UIKit.Banner.new("Menu Thử Nghiệm", 26, UIKit.RED))
	var top := HBoxContainer.new()
	v.add_child(top)
	var note := UIKit.label("Lối tắt kiểm tra tính năng. Game tạm dừng trong lúc mở.", 15, UIKit.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(note)
	top.add_child(UIKit.KeyCap.new("F1 / Esc", "Đóng", 13))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 6)
	sc.add_child(_grid_box)
	# nhãn thông tin (FPS, toạ độ) nằm ở lớp riêng, luôn hiện khi bật
	var il := CanvasLayer.new()
	il.layer = 50
	il.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(il)
	_info = UIKit.label("", 16, UIKit.JADE)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.offset_right = -12
	_info.offset_bottom = -10
	_info.visible = false
	il.add_child(_info)


func is_open() -> bool:
	return visible


func open_menu() -> void:
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
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_F1:
		close_menu()


func _process(_delta: float) -> void:
	if _show_info and main != null and main.player != null:
		var p: Vector2 = main.player.position
		var near := ""
		for m in main.monsters:
			if m.alive and m.position.distance_to(p) < 400.0:
				near += "%s(%s) " % [m.kind["name"], m.state]
		_info.text = "FPS %d  ·  (%d, %d)  ·  %s  ·  t=%.2f\nQuái gần: %s" % [Engine.get_frames_per_second(), p.x, p.y, main.atmo.period_name(), main.atmo.t, near if near != "" else "—"]
	_info.visible = _show_info


# ---------------------------------------------------------------- dựng menu
func _build() -> void:
	for c in _grid_box.get_children():
		_grid_box.remove_child(c)
		c.queue_free()
	_section("Nhân vật", [
		["Hồi đầy HP + linh khí", func(): _heal()],
		["+1 tầng tu vi", func(): main.cult.add_xp(main.cult.xp_needed())],
		["Tu vi viên mãn", func(): _full_xp()],
		["+1 cảnh giới", func(): _breakthrough()],
		["Về Luyện Khí tầng 1", func(): _set_realm(1, 1)],
		["Lên Kim Đan tầng 1", func(): _set_realm(3, 1)],
		[_t("Bất tử", main.vitals.god), func(): _toggle_god()],
		[_t("Linh khí vô hạn", main.debug_inf_qi), func(): _toggle("debug_inf_qi")],
	])
	_section("Vật phẩm", [
		["+500 linh thạch", func(): main.inv.add_stones(500); _toast("+500 linh thạch")],
		["+5000 linh thạch", func(): main.inv.add_stones(5000); _toast("+5000 linh thạch")],
		["Mỗi loại ×10", func(): _all_items(10)],
		["Nguyên liệu đan ×10", func(): _mats(10)],
		["Xoá hết túi đồ", func(): main.inv.items.clear(); main.inv.changed.emit(); _toast("Đã xoá túi đồ")],
		["Mở mọi trang phục", func(): _unlock_wardrobe()],
	])
	_section("Dịch chuyển (đóng menu sau khi đi)", [
		["Quảng trường", func(): _tp(main.CENTER + Vector2(0, 200))],
		["Lò luyện đan", func(): _tp(main.furnace.position + Vector2(0, 60))],
		["Sân luyện kiếm", func(): _tp(Vector2(1050, 1170))],
		["Linh mạch ao sen", func(): _tp(Vector2(1900, 560))],
		["Khu sói phía tây", func(): _tp(Vector2(430, 760))],
		["Khu sói phía nam", func(): _tp(Vector2(1450, 1540))],
		["Yêu quái phía đông", func(): _tp(Vector2(2150, 980))],
		["Yêu quái tây bắc", func(): _tp(Vector2(620, 430))],
	])
	_section("Quái vật", [
		["Tạo sói trước mặt", func(): _spawn("wolf")],
		["Tạo yêu quái trước mặt", func(): _spawn("goblin")],
		["Diệt hết quái", func(): _kill_all()],
		["Hồi sinh hết quái", func(): _revive_all()],
		[_t("Quái hiền", main.debug_peaceful), func(): _toggle("debug_peaceful")],
		["Bị đánh -30 HP", func(): main.vitals.take(30.0, main.player.position + Vector2(40, 0)); close_menu()],
	])
	_section("Thế giới", [
		["Nửa đêm", func(): _time(0.0)],
		["Sáng", func(): _time(0.3)],
		["Trưa", func(): _time(0.5)],
		["Chiều tà", func(): _time(0.72)],
		[_speed_text(0.5), func(): _speed(0.5)],
		[_speed_text(1.0), func(): _speed(1.0)],
		[_speed_text(2.0), func(): _speed(2.0)],
		[_speed_text(4.0), func(): _speed(4.0)],
	])
	_section("Nhiệm vụ & hệ thống", [
		["Xong nhiệm vụ đang làm", func(): _finish_quests()],
		["Đặt lại nhiệm vụ", func(): _reset_quests()],
		["Gia nhập Kiếm Tông", func(): main.school.joined = true; _toast("Đã gia nhập Kiếm Tông")],
		["Rời Kiếm Tông", func(): main.school.joined = false; _toast("Đã rời Kiếm Tông")],
		[_t("Hiện FPS/toạ độ", _show_info), func(): _show_info = not _show_info; _build()],
		["Lưu ô tự động", func(): main.save_to_slot(0)],
	])
	var close := Button.new()
	close.text = "Đóng"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_menu)
	_grid_box.add_child(close)


func _section(title: String, items: Array) -> void:
	_grid_box.add_child(UIKit.Banner.new(title, 18, UIKit.JADE, true))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_grid_box.add_child(g)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(it[1])
		g.add_child(b)


func _t(name: String, on: bool) -> String:
	return "%s: %s" % [name, "BẬT" if on else "TẮT"]


func _speed_text(x: float) -> String:
	return "Tốc độ ×%s%s" % [str(x), "  ●" if is_equal_approx(main.debug_speed, x) else ""]


func _toast(text: String) -> void:
	main.hud.toast(text)


# ---------------------------------------------------------------- thao tác
func _heal() -> void:
	main.vitals.hp = main.vitals.max_hp
	main.vitals.changed.emit()
	main.cult.qi = main.cult.qi_max()
	main.cult.changed.emit()
	_toast("Đã hồi đầy")


func _full_xp() -> void:
	var c: Cultivation = main.cult
	c.layer = Cultivation.LAYERS
	c.xp = c.xp_needed()
	c.ready_breakthrough = true
	c.changed.emit()
	_toast("Tu vi viên mãn, nhấn B để đột phá")


func _breakthrough() -> void:
	var c: Cultivation = main.cult
	if c.realm >= Cultivation.REALMS.size() - 1:
		_toast("Đã ở cảnh giới cao nhất")
		return
	_set_realm(c.realm + 1, 1)


func _set_realm(r: int, l: int) -> void:
	var c: Cultivation = main.cult
	c.realm = r
	c.layer = l
	c.xp = 0.0
	c.ready_breakthrough = false
	c.changed.emit()
	_toast("Cảnh giới: %s" % c.realm_name())


func _toggle_god() -> void:
	main.vitals.god = not main.vitals.god
	_build()


func _toggle(prop: String) -> void:
	main.set(prop, not main.get(prop))
	_build()


func _all_items(n: int) -> void:
	for id in Items.DATA:
		main.inv.add(id, n)
	_toast("Mỗi loại +%d" % n)


func _mats(n: int) -> void:
	for id in ["linh_thao", "soi_nanh", "yeu_dan", "da_yeu"]:
		main.inv.add(id, n)
	_toast("Nguyên liệu +%d" % n)


func _unlock_wardrobe() -> void:
	for id in Wardrobe.ITEMS:
		if not main.wardrobe.owned.has(id):
			main.wardrobe.owned.append(id)
	main.wardrobe.changed.emit()
	_toast("Đã mở khoá mọi trang phục (phím C để mặc)")


func _tp(pos: Vector2) -> void:
	main.player.position = pos
	main.camera.position = pos
	close_menu()


func _spawn(kind: String) -> void:
	var p: Vector2 = main.player.position + Dir.to_vector(main.direction) * 130.0
	var m := Monster.new()
	m.setup(main, kind, p)
	main.world.add_child(m)
	main.monsters.append(m)
	close_menu()


func _kill_all() -> void:
	var n := 0
	for m in main.monsters:
		if m.alive:
			m.take_hit(99999.0, main.player.position)
			n += 1
	_toast("Đã diệt %d quái" % n)


func _revive_all() -> void:
	for m in main.monsters:
		m.reset_to_home()
	_toast("Quái đã hồi sinh")


func _time(t: float) -> void:
	main.atmo.t = t
	_toast("Giờ: %s" % main.atmo.period_name())


func _speed(x: float) -> void:
	main.debug_speed = x
	Engine.time_scale = x
	_build()


func _finish_quests() -> void:
	var n := 0
	for qd in QuestLog.QUESTS:
		if main.quests.states.get(qd["id"], "") == "active":
			main.quests.complete(qd["id"])
			n += 1
	if n == 0:
		_toast("Không có nhiệm vụ đang làm")


func _reset_quests() -> void:
	var q: QuestLog = main.quests
	q.states.clear()
	q.kills.clear()
	q.crafts = 0
	q.sword_hits = 0
	q.meditate_time = 0.0
	q.changed.emit()
	_toast("Đã đặt lại nhiệm vụ")
