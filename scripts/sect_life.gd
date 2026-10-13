extends Node
## Đời sống Kiếm Tông. Trạng thái xã hội độc lập với NPC/map và được lưu cùng game.

signal changed

const PEOPLE := {
	"mac_tran": {"name": "Sư phụ Mặc Trần", "role": "Khảo hạch và truyền thụ", "clothes": "outfit_xam", "hair": "hair_topknot_silver"},
	"thanh_dao": {"name": "Sư tỷ Thanh Dao", "role": "Dược lý và chăm sóc đồng môn", "clothes": "outfit_thanh", "hair": "hair_long_silver"},
	"luc_an": {"name": "Đồng môn Lục An", "role": "Người bạn cùng tu luyện", "clothes": "outfit_plain", "hair": "hair_topknot_black"},
	"han_phong": {"name": "Đối thủ Hàn Phong", "role": "Trọng thực lực, thích tỷ thí", "clothes": "outfit_trang", "hair": "hair_topknot_black"},
}
const PLACES := [Vector2(1210, 2470), Vector2(1390, 2510), Vector2(1300, 2620)]
const PLACE_NAMES := ["Sân luyện kiếm", "Chấp Sự Đường · sân trước", "Sân tĩnh tu"]
const STAGES := ["new", "training", "field", "rescue", "together", "compete", "report", "exam", "done"]

var main: Node
var bonds := {"mac_tran": 0, "thanh_dao": 0, "luc_an": 0, "han_phong": 0}
var memories: Dictionary = {}
var daily: Dictionary = {}
var day := 1
var last_clock := 0.35
var stage := "new"
var branch := ""
var training_hits := 0
var field_kills := 0
var exam_hits := 0
var exam_left := 0.0
var gift_claimed := false
var mentor := false
var actors: Dictionary = {}
var paths: Dictionary = {}
var nav := AStarGrid2D.new()
var period := -1
var board: CanvasLayer
var panel: PanelContainer
var body: VBoxContainer
var refresh_left := 0.0

func setup(owner_main: Node) -> void:
	main = owner_main
	last_clock = main.atmo.t
	nav.region = Rect2i(0, 0, 32, 25)
	nav.cell_size = Vector2(16, 16)
	nav.offset = Vector2(1056, 2336)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for y in 25:
		for x in 32:
			var p := nav.get_point_position(Vector2i(x, y))
			nav.set_point_solid(Vector2i(x, y), main._is_blocked(Rect2(p - Vector2(16, 12), Vector2(32, 24))))
	for id in PEOPLE:
		var n := make_person(id, free_point(PLACES[0] + offset_for(id)))
		actors[id] = n
	_build_board()
	changed.connect(_refresh)
	changed.connect(main._refresh_quest_ui)
	changed.connect(_sync_presence)
	main.hud.toast("Kiếm Tông có đồng môn mới — nhấn H xem sinh hoạt và khảo hạch.")
	_update_schedule(true)
	_sync_presence()

func offset_for(id: String) -> Vector2:
	return Vector2((PEOPLE.keys().find(id) % 2) * 150 - 75, (PEOPLE.keys().find(id) / 2) * 90 - 45)

func free_point(want: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var dist := INF
	for y in 25:
		for x in 32:
			var cell := Vector2i(x, y)
			if nav.is_point_solid(cell):
				continue
			var p := nav.get_point_position(cell)
			if p.distance_squared_to(want) < dist:
				best = p
				dist = p.distance_squared_to(want)
	return best

func make_person(id: String, pos: Vector2) -> Node2D:
	var d: Dictionary = PEOPLE[id]
	var n: Node2D = preload("res://scripts/npc.gd").new()
	n.setup(id, d.name, {"clothes": d.clothes, "hair": d.hair, "shoes": "shoes_boot_black"})
	n.position = pos
	main.world.add_child(n)
	main.npcs.append(n)
	return n

func _process(delta: float) -> void:
	if main == null:
		return
	var clock: float = main.atmo.t
	if clock < last_clock - 0.5:
		day += 1
		daily.clear()
	last_clock = clock
	if exam_left > 0.0:
		if main.current_map != "overworld" or main._dead:
			_fail_exam()
		elif not main._ui_blocked():
			exam_left = maxf(0.0, exam_left - delta)
			if exam_left == 0.0:
				_fail_exam()
	if main.current_map == "overworld":
		_update_schedule()
		if not main._ui_blocked():
			_move_people(delta)
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = 1.0
		if is_open():
			_refresh()
		if exam_left > 0.0:
			main._refresh_quest_ui()

func _sync_presence() -> void:
	if actors.has("luc_an"):
		actors.luc_an.visible = stage not in ["field", "rescue", "together", "compete"]
	if main != null:
		map_entered()

func _period() -> int:
	var t: float = main.atmo.t
	return 0 if t >= 0.22 and t < 0.48 else (1 if t >= 0.48 and t < 0.72 else 2)

func _update_schedule(force := false) -> void:
	var next := _period()
	if next == period and not force:
		return
	period = next
	for id in actors:
		var n: Node2D = actors[id]
		var target := free_point(PLACES[period] + offset_for(id))
		var start := Vector2i((free_point(n.position) - nav.offset) / 16.0)
		var end := Vector2i((target - nav.offset) / 16.0)
		paths[id] = nav.get_point_path(start, end)

func _move_people(delta: float) -> void:
	for id in actors:
		var n: Node2D = actors[id]
		var route: PackedVector2Array = paths.get(id, PackedVector2Array())
		var visual: Node = n.get_child(1)
		if route.is_empty():
			visual.set_motion("idle", "south")
			continue
		var v := route[0] - n.position
		if v.length() < 3.0:
			route.remove_at(0)
			paths[id] = route
		else:
			n.position = n.position.move_toward(route[0], delta * 65.0)
			visual.set_motion("walk", "east" if v.x > 0 else "west")

func _build_board() -> void:
	board = CanvasLayer.new()
	board.layer = 18
	add_child(board)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(shade)
	panel = PanelContainer.new()
	panel.theme = UIKit.theme()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK, UIKit.GOLD_DK, 2, 0, Vector2.ZERO))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 35
	panel.offset_bottom = -35
	board.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(UIKit.Banner.new("KIẾM TÔNG · SƯ MÔN VÀ ĐỒNG ĐẠO", 26, UIKit.GOLD, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 14
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var close := Button.new()
	close.text = "Cuộn để xem tất cả đồng môn   ·   Đóng [H / Esc]"
	close.pressed.connect(close_board)
	column.add_child(close)
	board.hide()

func is_open() -> bool:
	return board != null and board.visible

func open_board() -> void:
	main.meditating = false
	_refresh()
	board.show()

func close_board() -> void:
	board.hide()

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_H, KEY_ESCAPE]:
		close_board()
		get_viewport().set_input_as_handled()

func _line(text: String, color := Color(0.88, 0.88, 0.82)) -> void:
	var label := UIKit.label(text, 19, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)

func _refresh() -> void:
	if body == null:
		return
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_line("Ngày %d · %s · %s" % [day, main.atmo.period_name(), main.inv.sect_rank_name()], UIKit.JADE)
	_line("Cống hiến: %d dùng được / %d tích lũy. Nội môn cần 100 tích lũy và vượt khảo hạch." % [main.inv.merit, main.inv.merit_total])
	var tsect := SectWar.PLAYER
	if main.inv.sect_rank() >= 1:
		_line("Ngân quỹ %s: %s · %d linh thạch · nuôi đệ tử %d mỗi ngày (hôm qua %+d)." % [SectWar.sect_name(tsect), main.treasury.status_name(tsect), main.treasury.stock(tsect), main.treasury.upkeep(tsect), int(main.treasury.last_net.get(tsect, 0))], UIKit.JADE)
	else:
		_line("Ngân quỹ %s: %s." % [SectWar.sect_name(tsect), main.treasury.status_name(tsect)], UIKit.JADE)
	var mine: Array = main.missions.mine()
	if mine.is_empty():
		_line("Việc tông môn: %d việc đang mở (gặp Chấp sự để nhận)." % main.missions.open_for(tsect).size())
	else:
		for mm in mine:
			_line("Việc đang làm — " + main.missions.describe(mm), UIKit.GOLD)
	_line(objective(), UIKit.GOLD)
	_line("Hành trình: gặp Mặc Trần → luyện kiếm → Sói Lĩnh → báo cáo → khảo hạch.\nWASD di chuyển · E trò chuyện · J/K/L/U ra chiêu · M xem bản đồ.")
	for id in PEOPLE:
		body.add_child(HSeparator.new())
		var n: Node2D = actors.get(id)
		var loc := "%s (%d, %d)" % [PLACE_NAMES[_period()], int(n.position.x), int(n.position.y)] if is_instance_valid(n) else "Kiếm Tông"
		if id == "luc_an" and stage in ["field", "rescue", "together", "compete"]:
			loc = "Đang cầu cứu tại Sói Lĩnh (460, 960); gặp bản thân ở đó để tiếp tục nhiệm vụ"
		_line("%s · %s %d/100" % [PEOPLE[id].name, relation(id), bonds[id]], UIKit.JADE)
		_line("%s · %s" % [PEOPLE[id].role, loc])
		_line(str(memories.get(id, "Chưa có kỷ niệm chung.")))
	_line("Sáng: luyện kiếm · Chiều: việc tông môn · Tối: tĩnh tu. Có thể gặp và nhận nhiệm vụ mọi buổi. Mỗi người nhận trò chuyện/quà một lần mỗi ngày trong game.")

func relation(id: String) -> String:
	var value := int(bonds[id])
	return "Xa cách" if value < 0 else ("Tri kỷ" if value >= 70 else ("Tin cậy" if value >= 40 else ("Thân thiện" if value >= 15 else "Sơ giao")))

func objective() -> String:
	match stage:
		"new": return "Gặp Mặc Trần ở sân Kiếm Tông phía nam làng để nhận thử thách nhập môn."
		"training": return "Luyện kiếm: đánh trúng mộc nhân %d/10 lần ở sân cạnh Lăng Tiêu, rồi báo Mặc Trần." % training_hits
		"field": return "Qua cổng Sói Lĩnh phía tây làng, gặp Lục An gần lối vào (460, 960)."
		"rescue", "together", "compete": return "Sói Lĩnh: hạ sói %d/%d, rồi %s." % [field_kills, kill_goal(), "báo Mặc Trần" if stage == "compete" else "trở lại Lục An"]
		"report": return "Trở về Kiếm Tông báo cáo Mặc Trần. Lựa chọn của bạn sẽ được đồng môn ghi nhớ."
		"exam":
			if exam_left > 0.0: return "Khảo hạch: %d/12 lần trúng mộc nhân · còn %d giây. Rời bản đồ hoặc trọng thương sẽ phải thi lại." % [exam_hits, ceili(exam_left)]
			return "Tích lũy 100 cống hiến rồi gặp Mặc Trần: đánh trúng mộc nhân 12 lần trong 60 giây. Có thể thử lại."
		"done": return "Đã vượt khảo hạch nội môn. Gặp Mặc Trần bái sư; tiếp tục vun đắp quan hệ với đồng môn."
	return ""

func _bond(id: String, amount: int, memory: String) -> void:
	bonds[id] = clampi(int(bonds[id]) + amount, -100, 100)
	if amount >= 10 or amount < 0 or not memories.has(id):
		memories[id] = memory

func talk(id: String) -> void:
	var nm: String = PEOPLE[id].name
	if not main.school.joined:
		main.dialogue.say(nm, ["Hãy gặp Kiếm sư Lăng Tiêu ở sân luyện kiếm trong làng để gia nhập Kiếm Tông trước. Nhấn H để xem sổ đồng môn."])
		return
	var opts: Array = []
	if id == "thanh_dao" and main.get("cultivation_v1") != null:
		opts.append({"text":"Trao đổi bí tịch ngoại phái", "call":main.cultivation_v1.open_source.bind("npc")})
	if id == "mac_tran":
		opts.append({"text": "Sư môn / khảo hạch", "call": mentor_task})
	if id == "luc_an" and main.current_map == "soi_linh":
		opts.append({"text": "Giúp Lục An thoát hiểm", "call": rescue_dialogue})
	if id == "luc_an" and stage == "done" and branch != "compete" and not gift_claimed:
		opts.append({"text": "Nhận lời cảm ơn", "call": gratitude})
	opts.append({"text": "Trò chuyện / cùng luyện tập (mỗi ngày)", "call": socialize.bind(id)})
	opts.append({"text": "Tặng 1 Hồi Huyết Đan (+3 thiện cảm, mỗi ngày)", "call": give_gift.bind(id)})
	opts.append({"text": "Xem sổ đồng môn [H]", "call": open_board})
	opts.append({"text": "Tạm biệt", "call": Callable()})
	main.dialogue.choose(nm, "%s · %s\n%s" % [relation(id), PEOPLE[id].role, memories.get(id, "Một gương mặt mới trong sư môn. Ta mong chúng ta có thể tin cậy nhau.")], opts)

func socialize(id: String) -> void:
	var key := id + "_talk"
	if daily.has(key):
		main.dialogue.say(PEOPLE[id].name, ["Hôm nay chúng ta đã trao đổi rồi. Hẹn ngày mai cùng tu luyện."])
		return
	daily[key] = true
	var lines := {"mac_tran": "Lăng Tiêu dạy ngươi nhập môn. Ta sẽ xem ngươi dùng kiếm để bảo vệ điều gì.", "thanh_dao": "Trước khi đi xa hãy chuẩn bị đan dược. Người trở về cùng đồng đội mới là người thắng.", "luc_an": "Ta tiến bộ chậm, nhưng sẽ không bỏ cuộc. Có ngươi cùng luyện, ta yên tâm hơn.", "han_phong": "Chiêu kiếm của ngươi có tiến bộ. Hẹn gặp trong kỳ khảo hạch, ta sẽ không nhường đâu."}
	var gain := mini(5, maxi(0, 35 - int(bonds[id])))
	_bond(id, gain, "Ngày %d: đã cùng trao đổi việc tu luyện." % day)
	main.dialogue.say(PEOPLE[id].name, [lines[id], "Thiện cảm +%d. Những việc lớn mới tạo nên tình nghĩa sâu sắc." % gain])
	changed.emit()

func give_gift(id: String) -> void:
	if daily.has(id + "_gift"):
		main.dialogue.say(PEOPLE[id].name, ["Ta đã nhận quà hôm nay rồi. Ngươi hãy giữ thuốc phòng thân."])
		return
	if not main.inv.remove("dan_hoi_huyet", 1):
		main.dialogue.say(PEOPLE[id].name, ["Ngươi chưa có Hồi Huyết Đan. Có thể luyện ở lò đan trong làng."])
		return
	daily[id + "_gift"] = true
	# Quà không thể tự mở mức quan hệ Tin cậy.
	if int(bonds[id]) < 35:
		bonds[id] = mini(35, int(bonds[id]) + 3)
	main.dialogue.say(PEOPLE[id].name, ["Cảm ơn viên đan. Ta sẽ mang theo khi xuống núi."])
	changed.emit()

func mentor_task() -> void:
	match stage:
		"new":
			stage = "training"
			main.dialogue.say(PEOPLE.mac_tran.name, ["Ta là Mặc Trần, phụ trách khảo hạch. Hãy đánh trúng mộc nhân ở sân Lăng Tiêu mười lần, rồi quay lại gặp ta."])
		"training":
			if training_hits >= 10:
				stage = "field"
				_bond("han_phong", 10, "Đã chứng kiến bạn hoàn thành bài luyện kiếm.")
				main.inv.add("dan_hoi_huyet", 2)
				main.dialogue.say(PEOPLE.mac_tran.name, ["Tốt. Hàn Phong và Lục An đã tới Sói Lĩnh. Hãy theo cổng phía tây làng đến đó khảo sát. Mang theo hai viên Hồi Huyết Đan này."])
			else:
				main.dialogue.say(PEOPLE.mac_tran.name, [objective()])
		"report":
			stage = "exam"
			main.inv.add_merit(100)
			main.treasury.pay_player(60 if branch == "compete" else 30, "Thưởng nhiệm vụ Sói Lĩnh")   # thưởng lấy từ ngân quỹ, không vượt kho
			_bond("mac_tran", 5 if branch == "compete" else 25, "Đã đánh giá lựa chọn của bạn trong chuyến Sói Lĩnh.")
			main.dialogue.say(PEOPLE.mac_tran.name, ["Ngươi giữ được thành tích, nhưng hãy nhớ ai đã ở lại phía sau." if branch == "compete" else "Ngươi đã đặt tính mạng đồng môn lên trước thành tích. Ta ghi nhận điều đó.", "Nhận 100 cống hiến. Khi sẵn sàng, gặp ta để khảo hạch nội môn: 12 lần trúng mộc nhân trong 60 giây."])
		"exam":
			if exam_left > 0.0:
				main.dialogue.say(PEOPLE.mac_tran.name, [objective()])
			elif main.inv.merit_total < 100:
				main.dialogue.say(PEOPLE.mac_tran.name, ["Cần tổng cộng 100 cống hiến. Làm nhiệm vụ hoặc nộp nguyên liệu tại Tàng Bảo Các."])
			else:
				main.dialogue.choose(PEOPLE.mac_tran.name, "Ta sẽ đưa ngươi tới sân Lăng Tiêu. Thời gian bắt đầu khi đóng hội thoại. Có thể thử lại miễn phí.", [{"text": "Bắt đầu khảo hạch", "call": start_exam}, {"text": "Chuẩn bị thêm", "call": Callable()}])
		"done":
			if not mentor:
				main.dialogue.choose(PEOPLE.mac_tran.name, "Ngươi đã đủ tư cách nội môn. Có muốn theo ta tiếp tục học kiếm?", [{"text": "Bái Mặc Trần làm sư phụ", "call": accept_mentor}, {"text": "Để ta suy nghĩ", "call": Callable()}])
			else:
				main.dialogue.say(PEOPLE.mac_tran.name, ["Kiếm quyết ta đã truyền, hãy thử ghép công pháp bằng phím Y. Đừng quên các đồng môn đã cùng ngươi đi qua hoạn nạn."])
		_:
			main.dialogue.say(PEOPLE.mac_tran.name, [objective()])
	changed.emit()

func on_training_hit() -> void:
	if main.current_map != "overworld" or not main.school.joined:
		return
	if stage == "training":
		training_hits = mini(10, training_hits + 1)
	if stage == "exam" and exam_left > 0.0:
		exam_hits += 1
		if exam_hits >= 12:
			exam_left = 0.0
			stage = "done"
			main.inv.pass_inner_exam()
			main.hud.toast("Vượt khảo hạch nội môn! Nhấn H xem sư môn; trở về gặp Mặc Trần.")
	changed.emit()

func rescue_dialogue() -> void:
	if stage == "field":
		var opts: Array = [{"text": "Ta sẽ cứu ngươi (hạ 3 sói)", "call": choose_branch.bind("rescue")}]
		if int(bonds.han_phong) >= 15:
			opts.append({"text": "Nhờ Hàn Phong phối hợp (hạ 2 sói)", "call": choose_branch.bind("together")})
		opts.append({"text": "Ưu tiên khảo hạch (hạ 5 sói)", "call": choose_branch.bind("compete")})
		opts.append({"text": "Để ta chuẩn bị", "call": Callable()})
		main.dialogue.choose(PEOPLE.luc_an.name, "Ta bị thương khi thoát khỏi bầy sói. Hãy giúp ta mở đường về!\nHàn Phong chỉ đồng ý phối hợp khi thiện cảm đạt 15 (hiện %d)." % bonds.han_phong, opts)
	elif stage in ["rescue", "together"] and field_kills >= kill_goal():
		stage = "report"
		_bond("luc_an", 35, "Bạn đã quay lại cứu ta ở Sói Lĩnh. Ta sẽ không quên.")
		_bond("thanh_dao", 15, "Đã nghe chuyện bạn đưa Lục An trở về an toàn.")
		if branch == "together":
			_bond("han_phong", 25, "Chúng ta đã hợp sức cứu Lục An. Ta kính trọng quyết định đó.")
		main.dialogue.say(PEOPLE.luc_an.name, ["Đường đã thông, ta có thể tự trở về. Cảm ơn ngươi! Hãy báo lại với Mặc Trần."])
		changed.emit()
	else:
		main.dialogue.say(PEOPLE.luc_an.name, [objective()])

func choose_branch(choice: String) -> void:
	if stage != "field" or choice not in ["rescue", "together", "compete"]:
		return
	if choice == "together" and int(bonds.han_phong) < 15:
		return
	stage = choice
	branch = choice
	field_kills = 0
	if choice == "compete":
		_bond("luc_an", -20, "Bạn đã bỏ đi khi ta cầu cứu. Thanh Dao đã đưa ta về sau đó.")
		_bond("thanh_dao", -10, "Ta phải xuống núi đón Lục An sau khi bạn ưu tiên khảo hạch.")
	main.dialogue.say(PEOPLE.luc_an.name, ["Hàn Phong nhận chặn một con sói ở lối sau. Ngươi xử lý hai con còn lại rồi quay về đây." if choice == "together" else ("Ta hiểu... ngươi cứ đi đi." if choice == "compete" else "Hạ ba con sói trên đường, rồi quay lại đón ta.")])
	changed.emit()

func kill_goal() -> int:
	return 2 if branch == "together" else (5 if branch == "compete" else 3)

func on_kill(kind: String) -> void:
	if main.current_map != "soi_linh" or kind not in ["wolf", "wolf_dark"] or stage not in ["rescue", "together", "compete"]:
		return
	field_kills = mini(kill_goal(), field_kills + 1)
	if stage == "compete" and field_kills >= kill_goal():
		stage = "report"
		_bond("han_phong", 10, "Bạn đã hoàn thành chuyến khảo hạch với thành tích tốt.")
	main.hud.toast(objective())
	changed.emit()

func map_entered() -> void:
	if main == null or main.current_map != "soi_linh":
		return
	if stage in ["field", "rescue", "together", "compete"]:
		for n in main.npcs:
			if n.npc_id == "luc_an":
				return
		make_person("luc_an", Vector2(460, 960))
		main._refresh_quest_ui()
	else:
		for n in main.npcs.duplicate():
			if n.npc_id == "luc_an":
				main.npcs.erase(n)
				n.queue_free()

func start_exam() -> void:
	if stage != "exam" or main.inv.merit_total < 100 or main.current_map != "overworld":
		return
	main.player.position = Vector2(1050, 1150) + Vector2(0, 35)
	main.cult.qi = main.cult.qi_max()
	exam_hits = 0
	exam_left = 60.0
	main.hud.toast("Khảo hạch bắt đầu: 12 lần trúng mộc nhân trong 60 giây! J/K/L/U ra chiêu.")
	changed.emit()

func _fail_exam() -> void:
	exam_left = 0.0
	exam_hits = 0
	main.hud.toast("Khảo hạch chưa đạt. Trở lại Mặc Trần để thử lại miễn phí.")
	changed.emit()

func accept_mentor() -> void:
	if stage != "done" or mentor:
		return
	mentor = true
	_bond("mac_tran", 20, "Đã bái Mặc Trần làm sư phụ sau kỳ khảo hạch.")
	main.dialogue.say(PEOPLE.mac_tran.name, ["Từ nay ngươi là môn sinh của ta. Hãy đến Tàng Kinh Các, lấy công huân đổi bí tịch nội truyền, rồi mở bảng Y để bày Công, Tâm, Thân Pháp."])
	changed.emit()

func gratitude() -> void:
	if gift_claimed or stage != "done" or branch not in ["rescue", "together"]:
		return
	gift_claimed = true
	main.inv.add("dan_hoi_huyet", 2)
	main.dialogue.say(PEOPLE.luc_an.name, ["Hai viên đan này ta dành dụm được. Ngày ở Sói Lĩnh, ngươi đã quay lại vì ta. Lần sau để ta giúp ngươi."])
	changed.emit()

func marker(id: String) -> String:
	if id == "mac_tran":
		if stage == "done" and mentor:
			return ""
		return "?" if stage in ["report", "done"] or (stage == "training" and training_hits >= 10) else "!"
	if id == "luc_an" and main.current_map == "soi_linh":
		return "?" if field_kills >= kill_goal() else "!"
	return ""

func to_dict() -> Dictionary:
	return {"bonds": bonds.duplicate(), "memories": memories.duplicate(), "daily": daily.duplicate(), "day": day, "stage": stage, "branch": branch, "training_hits": training_hits, "field_kills": field_kills, "gift_claimed": gift_claimed, "mentor": mentor}

func from_dict(data: Dictionary) -> void:
	for id in PEOPLE:
		bonds[id] = clampi(int(data.get("bonds", {}).get(id, 0)), -100, 100)
	memories = data.get("memories", {}).duplicate()
	daily = data.get("daily", {}).duplicate()
	day = maxi(1, int(data.get("day", 1)))
	stage = str(data.get("stage", "new"))
	if stage not in STAGES:
		stage = "new"
	branch = str(data.get("branch", ""))
	training_hits = clampi(int(data.get("training_hits", 0)), 0, 10)
	field_kills = clampi(int(data.get("field_kills", 0)), 0, 5)
	gift_claimed = bool(data.get("gift_claimed", false))
	mentor = bool(data.get("mentor", false))
	# Một bài thi đang dở được thi lại; không lưu thời gian để tránh hết giờ khi tải.
	exam_left = 0.0
	exam_hits = 0
	if main != null:
		last_clock = main.atmo.t
		changed.emit()
