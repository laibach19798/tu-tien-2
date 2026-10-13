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
		["+100 cống hiến Kiếm Tông", func(): main.inv.add_merit(100); _toast("+100 cống hiến")],
		["+1000 cống hiến Kiếm Tông", func(): main.inv.add_merit(1000); _toast("+1000 cống hiến")],
		["Mỗi loại ×10", func(): _all_items(10)],
		["Nguyên liệu đan ×10", func(): _mats(10)],
		["Xoá hết túi đồ", func(): main.inv.items.clear(); main.inv.changed.emit(); _toast("Đã xoá túi đồ")],
		["Mở mọi trang phục", func(): _unlock_wardrobe()],
	])
	_section("Dịch chuyển (đóng menu sau khi đi)", [
		["Quảng trường", func(): _tp(main.CENTER + Vector2(0, 200))],
		["Lò luyện đan", func(): _tp(Vector2(1130, 1010) + Vector2(0, 60))],
		["Sân luyện kiếm", func(): _tp(Vector2(1050, 1170))],
		["Linh mạch ao sen", func(): _tp(Vector2(1900, 560))],
	] + Maps.DEFS.keys().map(func(id): return ["Map: " + Maps.map_name(id), func(): _go_map(str(id))]))
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
	_section("Pháp & bí tịch (V1)", [
		["Nhận mọi bí tịch", func(): _v1_all()],
		["Xoá hồi chiêu", func(): _v1_reset()],
		["Trạng thái lên quái", func(): _status_on_monsters()],
		["Buff lên mình", func(): _buffs_self()],
	])
	_section("Xem hiệu ứng chiêu (tung tại chỗ, hướng quái gần nhất)", _fx_buttons())
	_section("Quái (mọi loài)", _kind_buttons() + [
		["Tinh anh: Yêu quái", func(): _spawn_elite("goblin")],
		["Tinh anh: Sói", func(): _spawn_elite("wolf")],
		["Tinh anh: Cuồng lang", func(): _spawn_elite("wolf_charger")],
	])
	_section("NPC tông môn có chiêu (đối địch)", _sect_buttons())
	_section("NPC có tên: giao đấu thử (bộ pháp V1 thật)", _npc_duel_buttons() + [
		["In hồ sơ NPC vào console", func(): _print_npc_profiles()],
	])
	_section("Thế giới mở (đại vực)", [
		["Phi hành: mở khoá thử (không cần Trúc Cơ)", func(): main.flight.debug_unlock = true; _toast("Đã mở khoá phi hành (phím X)")],
		["Phát hiện mọi địa điểm", func(): _world_all(World.DISCOVERED)],
		["Mọi nơi thành tin đồn", func(): _world_all(World.RUMOR)],
		["Xoá hết khám phá", func(): _world_reset()],
		["Thêm một tin đồn", func(): main.province._daily_force()],
		["Mở bản đồ đại vực (R)", func(): close_menu(); main.journal.open_ui("world")],
		["Sự kiện: động phủ cổ tu", func(): _event("co_tu_dong_phu")],
		["Sự kiện: thương đội nạn", func(): _event("thuong_doi_nan")],
		["Sự kiện: linh thảo quý", func(): _event("linh_thao_quy")],
		["Sự kiện: yêu thú tinh anh", func(): _event("yeu_thu_tinh_anh")],
		["Sự kiện: đệ tử xung đột", func(): _event("xung_dot_de_tu")],
		["Sự kiện: linh mạch động", func(): _event("linh_mach_bien_dong")],
		["Tua 10 ngày (NPC làm việc)", func(): main.sect_life.day += 10; _toast("Đã tua 10 ngày game")],
		["Đưa mọi NPC về map này", func(): _npcs_here()],
		["Tài nguyên mọc lại hết", func(): main.resources.states.clear(); _toast("Mọi điểm khai thác đã mọc lại")],
		["+1 ngày game", func(): main.sect_life.day += 1; _toast("Đã tua 1 ngày game")],
	])
	_section("Cơ duyên & động phủ", [
		["+10 duyên", func(): main.destiny.duyen = minf(100.0, float(main.destiny.duyen) + 10.0); _toast("Duyên: %d" % int(main.destiny.duyen))],
		["Gọi cơ duyên ngẫu nhiên", func(): _roll_destiny()],
	] + _destiny_buttons() + _dong_phu_buttons())
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


func _go_map(id: String) -> void:
	main.switch_map_now(id, Maps.DEFS[id]["entry"])
	close_menu()


func _tp(pos: Vector2) -> void:
	if main.current_map != "overworld":
		main.switch_map_now("overworld", pos)
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


# ---------------------------------------------------------------- V1, quái, NPC, cơ duyên
func _v1_defs() -> Array:
	var catalog = preload("res://scripts/v1/catalog.gd")
	var all: Array = catalog.data().books.duplicate()
	var eq = catalog.data().equipment
	all.append_array(eq if eq is Array else eq.values())
	return all


func _v1_all() -> void:
	var rt = main.cultivation_v1
	var n := 0
	for d in _v1_defs():
		var uid: String = rt.state.acquire(str(d["id"]), "debug", "linh")
		if uid != "":
			rt.state.learn(uid)
			n += 1
	rt.state.changed.emit()
	_toast("Đã nhận %d bí tịch/trang bị (Y → Bí tịch để trang bị)" % n)


func _v1_reset() -> void:
	var rt = main.cultivation_v1
	for k in rt.engine.cooldowns:
		rt.engine.cooldowns[k] = 0.0
	main.cult.qi = main.cult.qi_max()
	main.cult.changed.emit()
	_toast("Đã xoá hồi chiêu, đầy linh khí")


func _nearest_monsters(n: int) -> Array:
	var p: Vector2 = main.player.position
	var list: Array = []
	for m in main.monsters:
		if is_instance_valid(m) and m.alive:
			list.append(m)
	list.sort_custom(func(a, b): return a.position.distance_squared_to(p) < b.position.distance_squared_to(p))
	return list.slice(0, n)


func _status_on_monsters() -> void:
	var rt = main.cultivation_v1
	var all := ["kiem_an", "hon_an", "bleed", "burn", "slow", "armor_break", "weaken"]
	var n := 0
	for m in _nearest_monsters(4):
		var held := {}
		for i in all.size():
			if (i + n) % 2 == 0 or i < 3:
				held[all[i]] = {"stacks": 1 + (i + n) % 4, "remaining": 12.0, "tick": 999.0, "source": {}}
		var id := str(m.get_instance_id())
		rt.engine.statuses[id] = held
		rt._target_nodes[id] = m
		n += 1
	_toast("Đã gắn trạng thái lên %d quái (12 giây)" % n if n > 0 else "Không có quái gần để gắn")
	close_menu()


func _buffs_self() -> void:
	var rt = main.cultivation_v1
	var held := {}
	for sid in ["guard", "surge", "discount", "steadfast"]:
		held[sid] = {"stacks": 2, "remaining": 15.0, "tick": 999.0, "source": {}}
	rt.engine.statuses["player"] = held
	_toast("Đã gắn buff lên người (15 giây)")
	close_menu()


func _fx_buttons() -> Array:
	var out: Array = []
	for d in _v1_defs():
		if d.has("shape"):
			var def: Dictionary = d
			out.append([str(def.get("name", def["id"])), func(): _fx(def)])
	return out


func _fx(def: Dictionary) -> void:
	var near := _nearest_monsters(3)
	var aim: Vector2 = Dir.to_vector(main.direction)
	if not near.is_empty():
		aim = ((near[0].position as Vector2) - main.player.position).normalized()
	close_menu()
	SkillFx.cast(main, def, aim, near)
	SkillFx.body_motion(main, def, aim)


func _kind_buttons() -> Array:
	var out: Array = []
	for id in Monster.KINDS:
		var kid := str(id)
		out.append([str(Monster.KINDS[id].get("name", kid)), func(): _spawn(kid)])
	return out


func _spawn_elite(kind: String) -> void:
	var m := Monster.new()
	m.setup(main, kind, main.player.position + Dir.to_vector(main.direction) * 130.0)
	m.tier = maxi(m.tier, Hell.ELITE_MIN_TIER)
	var tries := 0
	while not m.elite and tries < 400:
		MonsterBehaviors._roll_elite(m)
		tries += 1
	main.world.add_child(m)
	main.monsters.append(m)
	_toast("Tinh anh: %s" % MonsterBehaviors.elite_name(m) if m.elite else "Không roll được tinh anh")
	close_menu()


func _sect_buttons() -> Array:
	var out: Array = []
	for sid in SectWar.SECTS:
		var s := str(sid)
		var nm := str(SectWar.SECTS[sid]["name"])
		for k in [["sect_disciple", "Đệ tử"], ["sect_elder", "Trưởng lão"], ["sect_master", "Tông chủ"]]:
			var kind := str(k[0])
			out.append(["%s %s" % [k[1], nm], func(): _sect_npc(s, kind)])
	return out


## Mỗi NPC có tên một nút: gọi họ ra giao đấu ngay trước mặt, mang đúng chiêu và thủ pháp theo hồ sơ V1 (không để lại hậu quả).
func _npc_duel_buttons() -> Array:
	var out: Array = []
	var nw = main.npc_world
	if nw == null:
		return out
	for id in nw.agent_ids():
		var nid := str(id)
		var style := str(NpcProfile.STYLES.get(nw.style_of(nid), ""))
		out.append(["%s · b%d · %s" % [nw.display_name(nid), nw.step_of(nid), style], func(): _duel_npc(nid)])
	return out


func _duel_npc(id: String) -> void:
	var nw = main.npc_world
	if nw == null:
		return
	nw._duel_tick(0)
	if nw.start_duel(id, "debug"):
		_toast("%s ra giao đấu (thử)" % nw.display_name(id))
		close_menu()
	else:
		_toast("Không dựng được trận (đang có trận khác hoặc bản đồ chiến sự)")


func _print_npc_profiles() -> void:
	var nw = main.npc_world
	if nw == null:
		return
	for id in nw.agent_ids():
		var p = nw.profile_of(str(id))
		print("NPC %s | bậc %d | %s | %s | %s" % [nw.display_name(str(id)), nw.step_of(str(id)), ", ".join(NpcProfile.trait_words(nw.traits_of(str(id)))), str(NpcProfile.STYLES.get(nw.style_of(str(id)), "")), "; ".join(NpcProfile.loadout_text(p))])
	_toast("Đã in hồ sơ %d NPC vào console" % nw.agent_ids().size())


func _sect_npc(sid: String, kind: String) -> void:
	var p: Vector2 = main.player.position + Dir.to_vector(main.direction) * 220.0
	MapBuilder.spawn_one(main, sid, kind, p, "", true)
	close_menu()


func _event(tpl: String) -> void:
	var e: Dictionary = main.events.spawn(tpl, int(main.sect_life.day))
	if e.is_empty():
		_toast("Chưa đủ điều kiện sinh sự kiện này")
		return
	_toast("Sự kiện %s ở %s" % [str(main.events.tpl(tpl).get("name", "")), main.province.display_name(str(e["loc"]))])


func _npcs_here() -> void:
	var loc: String = main.province.location_at(str(main.current_map), main.player.position)
	if loc == "":
		_toast("Chỗ này chưa thuộc địa điểm nào")
		return
	for id in main.npc_world.states:
		main.npc_world.states[id]["loc"] = loc
		main.npc_world.states[id]["status"] = "ok"
	main.npc_world._dirty = true
	_toast("Các NPC đã tới %s" % main.province.display_name(loc))
	close_menu()


func _world_all(state: String) -> void:
	var w: World = main.province
	for id in w.locations():
		var sid := str(id)
		if state == World.DISCOVERED:
			w.discover(sid, "thử nghiệm")
		elif w.state_of(sid) == World.UNKNOWN:
			w.add_rumor(sid, "", "thử nghiệm", "medium")
	_toast("Đã đặt trạng thái khám phá")


func _world_reset() -> void:
	var w: World = main.province
	w.states.clear()
	w.rumors.clear()
	w.log.clear()
	w._apply_defaults()
	w.changed.emit()
	_toast("Đã xoá khám phá (giữ nơi khởi đầu)")


func _roll_destiny() -> void:
	main.destiny._roll(false)
	close_menu()


func _destiny_buttons() -> Array:
	var out: Array = []
	for id in main.destiny.encounters():
		var eid := str(id)
		var e: Dictionary = main.destiny.encounters()[id]
		if str(e.get("kind", "")) == "gate":
			continue
		out.append(["Cơ duyên: " + str(e.get("name", eid)), func(): _spawn_destiny(eid)])
	return out


func _spawn_destiny(id: String) -> void:
	var p: Vector2 = main.player.position + Dir.to_vector(main.direction) * 110.0
	main.destiny._spawn(id, p, true)
	close_menu()


func _dong_phu_buttons() -> Array:
	var out: Array = []
	for id in main.destiny.dong_phu():
		var did := str(id)
		out.append(["Động phủ: " + str(main.destiny.dong_phu()[id].get("name", did)), func(): _dong_phu(did)])
	return out


## Đủ mảnh bản đồ rồi đưa tới vùng có cổng động phủ (cổng tự hiện khi đủ mảnh).
func _dong_phu(id: String) -> void:
	var info: Dictionary = main.destiny.dong_phu().get(id, {})
	if info.is_empty():
		return
	main.destiny.fragments[id] = int(info["fragments"])
	var region := str(info["region"])
	if Maps.DEFS.has(region):
		main.switch_map_now(region, Maps.DEFS[region]["entry"])
	main.destiny._spawn_gate_if_here()
	_toast("Đã đủ mảnh: tìm cổng động phủ trong vùng này")
	close_menu()
