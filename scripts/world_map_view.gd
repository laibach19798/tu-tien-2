extends Control
class_name WorldMapView
## Bản đồ đại vực (tab trong sổ tay, phím R): hiện Thanh Vân Châu theo ba mức Chưa biết / Tin đồn / Đã phát hiện.
## Bên trái là bản đồ chiến lược (nhấn một điểm để xem), bên phải là hồ sơ khu vực và nhật ký tin tức.

const KIND_COLORS := {
	"city": Color(1.0, 0.85, 0.45),
	"sect": Color(0.55, 0.85, 1.0),
	"wild": Color(0.55, 0.85, 0.5),
	"ruin": Color(0.85, 0.7, 1.0),
	"hub": Color(1.0, 0.65, 0.4),
	"secret": Color(0.9, 0.6, 0.9),
}
const KIND_NAMES := {"city": "Thành / làng", "sect": "Tông môn", "wild": "Hoang dã", "ruin": "Di tích", "hub": "Đầu mối", "secret": "Động phủ"}
const ELEMENT_COLORS := {"kim": Color(0.9, 0.9, 0.7), "moc": Color(0.5, 0.85, 0.5), "thuy": Color(0.5, 0.7, 1.0), "hoa": Color(1.0, 0.55, 0.3), "tho": Color(0.8, 0.65, 0.4)}

var world: World
var main: Node
var selected := ""
var _canvas: Canvas
var _side: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	add_child(h)
	_canvas = Canvas.new()
	_canvas.view = self
	_canvas.custom_minimum_size = Vector2(640, 510)
	h.add_child(_canvas)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(350, 0)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 5)
	sc.add_child(_side)
	var here := _here()
	selected = here if here != "" else ""
	_refresh()


func _here() -> String:
	if main == null or main.player == null:
		return ""
	return world.location_at(str(main.current_map), main.player.position)


func select(id: String) -> void:
	selected = id
	_canvas.queue_redraw()
	_refresh()


func _line(text: String, color := UIKit.PAPER, size := 15) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	_side.add_child(l)
	return l


func _refresh() -> void:
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	var total := world.locations().size()
	_line("%s" % str(world.province().get("name", "Thanh Vân Châu")), UIKit.GOLD, 20)
	_line("Đã phát hiện %d/%d · Tin đồn %d" % [world.count(World.DISCOVERED), total, world.count(World.RUMOR)], UIKit.MUTED, 14)
	_side.add_child(HSeparator.new())
	if selected == "":
		_line("Nhấn một điểm trên bản đồ để xem hồ sơ khu vực.", UIKit.MUTED)
	else:
		_detail(selected)
	_side.add_child(HSeparator.new())
	_line("Tin tức gần đây", UIKit.JADE, 16)
	var shown := 0
	for i in range(world.log.size() - 1, -1, -1):
		var e: Dictionary = world.log[i]
		_line("Ngày %d: %s" % [int(e.get("day", 0)), str(e.get("text", ""))], UIKit.MUTED, 13)
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		_line("Chưa có tin tức. Đi lại, hỏi thăm và nghe ngóng sẽ có thêm tin.", UIKit.MUTED, 13)


func _detail(id: String) -> void:
	var st := world.state_of(id)
	var d: Dictionary = world.info(id)
	if st == World.UNKNOWN:
		_line("Chưa biết", UIKit.MUTED, 18)
		_line("Vùng này còn chìm trong sương. Đi tới các nơi kề cận hoặc nghe ngóng tin tức để biết thêm.", UIKit.MUTED)
		return
	if st == World.RUMOR:
		var r: Dictionary = world.rumors.get(id, {})
		_line("Tin đồn", UIKit.GOLD, 18)
		_line(str(r.get("text", "")), UIKit.PAPER)
		var rel := {"high": "đáng tin", "medium": "nghe lỏm, chưa chắc", "low": "mơ hồ, có thể sai"}
		_line("Nguồn: %s · Ngày %d · Độ tin cậy: %s" % [str(r.get("source", "")), int(r.get("day", 0)), str(rel.get(str(r.get("reliability", "medium")), ""))], UIKit.MUTED, 13)
		_line("Vị trí trên bản đồ chỉ là gần đúng. Tới tận nơi hoặc có thêm manh mối mới xác nhận được.", UIKit.MUTED, 13)
		return
	_line(world.display_name(id), KIND_COLORS.get(str(d.get("kind", "")), UIKit.PAPER), 20)
	_line("%s · %s" % [KIND_NAMES.get(str(d.get("kind", "")), ""), "Đã phát hiện"], UIKit.MUTED, 13)
	_line(str(d.get("intro", "")), UIKit.PAPER, 14)
	_line(str(d.get("role", "")), UIKit.MUTED, 14)
	var qi: Dictionary = d.get("qi", {})
	var qn: Array = world._data.get("qi_names", [])
	var en: Dictionary = world._data.get("element_names", {})
	var lvl := clampi(int(qi.get("level", 0)), 0, maxi(qn.size() - 1, 0))
	_line("Linh khí: %s · thiên hướng %s" % [str(qn[lvl]) if lvl < qn.size() else str(lvl), str(en.get(str(qi.get("element", "")), "—"))], ELEMENT_COLORS.get(str(qi.get("element", "")), UIKit.PAPER), 14)
	var dn: Array = world._data.get("danger_names", [])
	var dl := clampi(int(d.get("danger", 0)), 0, maxi(dn.size() - 1, 0))
	var dcol := Color(0.6, 0.9, 0.6).lerp(Color(1.0, 0.3, 0.3), float(dl) / 5.0)
	_line("Nguy hiểm: %s" % (str(dn[dl]) if dl < dn.size() else str(dl)), dcol, 14)
	var signs: Array = d.get("signs", [])
	if not signs.is_empty():
		_line("Dấu hiệu: " + "; ".join(PackedStringArray(signs)), UIKit.MUTED, 13)
	var res: Array = d.get("resources", [])
	if not res.is_empty():
		_line("Tài nguyên: " + ", ".join(PackedStringArray(res)), UIKit.PAPER, 13)
	if main != null and main.get("npc_world") != null:
		var here: Array = []
		for nid in main.npc_world.states:
			var ns: Dictionary = main.npc_world.states[nid]
			if str(ns.get("loc", "")) == id and str(ns.get("status", "ok")) != "seclusion":
				here.append("%s — %s" % [main.npc_world.display_name(str(nid)), main.npc_world.activity_text(str(nid))])
		if not here.is_empty():
			_line("Có thể gặp", UIKit.JADE, 15)
			for t in here:
				_line(str(t), UIKit.PAPER, 13)
	if main != null and main.get("events") != null:
		var evs: Array = main.events.active_at(id)
		var trs: Array = main.events.traces_at(id)
		if not evs.is_empty() or not trs.is_empty():
			_line("Diễn biến", UIKit.JADE, 15)
		for e in evs:
			var tp: Dictionary = main.events.tpl(str(e["tpl"]))
			var left := maxi(0, int(e["deadline"]) - int(main.sect_life.day))
			var phase := "Dấu hiệu" if str(e["state"]) == "sign" else "Đang diễn ra"
			_line("%s · %s (còn khoảng %d ngày)" % [phase, str(tp.get("name", "")), left], Color(1.0, 0.8, 0.45), 13)
		for t in trs:
			_line("Dấu vết: " + str(t["text"]), UIKit.MUTED, 13)
	var rts: Array = []
	for r in world.routes():
		var other := ""
		if str(r["a"]) == id:
			other = str(r["b"])
		elif str(r["b"]) == id:
			other = str(r["a"])
		if other == "" or not world.route_known(r):
			continue
		var os := world.state_of(other)
		var nm := world.display_name(other) if os == World.DISCOVERED else ("nơi chưa rõ" if os == World.RUMOR else "…")
		rts.append("%s %s · %d ngày, rủi ro %s — %s" % ["Đường tắt:" if str(r.get("kind", "")) == "shortcut" else "Đường chính:", nm, int(r.get("days", 1)), main.journey.risk_text(int(r.get("risk", 0)), 1) if main != null and main.get("journey") != null else "?", str(r.get("note", ""))])
	if not rts.is_empty():
		_line("Tuyến đường", UIKit.JADE, 15)
		for t in rts:
			_line(str(t), UIKit.MUTED, 13)
	if main != null and main.get("journey") != null and main.journey.can_travel_to(id):
		var here: String = main.journey.here()
		if here == id:
			_line("Ngươi đang ở đây.", UIKit.JADE, 13)
		else:
			var reason: String = main.journey.blocked_reason()
			if reason != "":
				_line(reason, UIKit.MUTED, 13)
			else:
				var go := Button.new()
				go.text = "Đi tới đây…"
				go.focus_mode = Control.FOCUS_NONE
				go.custom_minimum_size = Vector2(0, 38)
				go.pressed.connect(_show_routes.bind(id, here))
				_side.add_child(go)


## Danh sách phương án tuyến từ nơi đang đứng tới đích.
func _show_routes(dest: String, here: String) -> void:
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	_line("Đi tới %s" % world.display_name(dest), UIKit.GOLD, 19)
	_line("Từ %s. Chọn tuyến — mỗi ngày đi đường có thể gặp biến cố." % world.display_name(here), UIKit.MUTED, 13)
	var options: Array = main.journey.plan(here, dest)
	if options.is_empty():
		_line("Chưa biết đường tới đó. Hỏi thăm người đi đường hoặc khám phá thêm để lộ tuyến.", UIKit.MUTED)
	for o in options:
		var legs: int = (o["path"] as Array).size()
		var via: Array = []
		for e in o["path"]:
			via.append(world.display_name(str(e["to"])))
		var txt := "%s · %d ngày · rủi ro %s%s\nQua: %s" % [str(o["label"]), int(o["days"]), main.journey.risk_text(int(o["risk"]), legs), (" · có đường tắt" if int(o["shortcuts"]) > 0 else ""), " → ".join(PackedStringArray(via))]
		var b := Button.new()
		b.text = txt.replace("\\n", "\n")
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 60)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_go.bind(o, here))
		_side.add_child(b)
		var signs: Array = o.get("signs", [])
		if not signs.is_empty():
			_line("Dấu hiệu: " + "; ".join(PackedStringArray(signs)), Color(1.0, 0.7, 0.4), 12)
	var back := Button.new()
	back.text = "Quay lại"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_refresh)
	_side.add_child(back)


func _go(option: Dictionary, here: String) -> void:
	main.journal.close_ui()
	main.journey.begin(option, here)


# ---------------------------------------------------------------- bản đồ
class Canvas extends Control:
	var view: WorldMapView
	var _t := 0.0
	var _fog: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var r := RandomNumberGenerator.new()
		r.seed = 77
		for i in 60:
			_fog.append([r.randf(), r.randf(), r.randf_range(0.5, 1.0)])

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _scale() -> float:
		var m: Array = view.world.province().get("map", [1000, 640])
		return minf(size.x / float(m[0]), size.y / float(m[1]))

	func _to_screen(p: Vector2) -> Vector2:
		return p * _scale()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var best := ""
			var best_d := 26.0
			for id in view.world.locations():
				if view.world.state_of(str(id)) == World.UNKNOWN:
					continue
				var d := _to_screen(view.world.map_pos(str(id))).distance_to(event.position)
				if d < best_d:
					best_d = d
					best = str(id)
			view.select(best)

	func _draw() -> void:
		var w: World = view.world
		var f := get_theme_default_font()
		var s := _scale()
		# nền: bản đồ da cổ tối, lưới mờ
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.2))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.7, 0.45), false, 2.0)
		var m: Array = w.province().get("map", [1000, 640])
		for gx in range(0, int(m[0]) + 1, 100):
			draw_line(Vector2(gx, 0) * s, Vector2(gx, float(m[1])) * s, Color(1, 1, 1, 0.045), 1.0)
		for gy in range(0, int(m[1]) + 1, 100):
			draw_line(Vector2(0, gy) * s, Vector2(float(m[0]), gy) * s, Color(1, 1, 1, 0.045), 1.0)
		# sương mù phủ lên mọi nơi chưa biết
		for id in w.locations():
			if w.state_of(str(id)) != World.UNKNOWN:
				continue
			var c := _to_screen(Vector2(float(w.info(str(id))["pos"][0]), float(w.info(str(id))["pos"][1])))
			for q in _fog:
				var off := Vector2(cos(float(q[0]) * TAU), sin(float(q[1]) * TAU)) * 46.0 * float(q[2])
				draw_circle(c + off, 24.0 * float(q[2]) + 6.0, Color(0.55, 0.6, 0.7, 0.07))
		# tuyến đường
		for r in w.routes():
			var sa := w.state_of(str(r["a"]))
			var sb := w.state_of(str(r["b"]))
			if sa == World.UNKNOWN or sb == World.UNKNOWN or not w.route_known(r):
				continue
			var pa := _to_screen(w.map_pos(str(r["a"])))
			var pb := _to_screen(w.map_pos(str(r["b"])))
			var both := sa == World.DISCOVERED and sb == World.DISCOVERED
			var shortcut := str(r.get("kind", "")) == "shortcut"
			var col := Color(1.0, 0.65, 0.3, 0.7) if shortcut else Color(0.85, 0.78, 0.55, 0.75)
			if both and not shortcut:
				draw_line(pa, pb, col, 2.0)
			else:
				_dashed(pa, pb, Color(col, 0.55 if both else 0.35), 9.0)
		# địa điểm
		var here := view._here()
		for id in w.locations():
			var st := w.state_of(str(id))
			if st == World.UNKNOWN:
				continue
			var d: Dictionary = w.info(str(id))
			var p := _to_screen(w.map_pos(str(id)))
			var kc: Color = KIND_COLORS.get(str(d.get("kind", "")), Color.WHITE)
			if st == World.RUMOR:
				var rr := w.rumor_radius(str(id)) * s
				_dashed_circle(p, rr, Color(0.9, 0.85, 0.6, 0.65))
				draw_string(f, p + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.5))
			else:
				draw_circle(p, 9.0, Color(0, 0, 0, 0.85))
				draw_circle(p, 7.0, kc)
				draw_circle(p, 3.0, Color(1, 1, 1, 0.9))
				var nm := w.display_name(str(id))
				var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				draw_string(f, p + Vector2(-tw * 0.5 + 1, 24), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.9))
				draw_string(f, p + Vector2(-tw * 0.5, 23), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.93, 0.85))
			if str(id) == view.selected:
				draw_arc(p, 15.0 + 2.0 * sin(_t * 4.0), 0.0, TAU, 28, Color(1, 1, 1, 0.9), 2.0)
			if str(id) == here:
				draw_arc(p, 20.0 + 3.0 * sin(_t * 3.0), 0.0, TAU, 28, Color(0.5, 1.0, 0.7, 0.9), 2.0)
				draw_string(f, p + Vector2(-34, -24), "Bạn ở đây", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1.0, 0.75))
		# chú thích
		draw_string(f, Vector2(12, size.y - 12), "Nét liền: đường chính · nét đứt cam: đường tắt · vòng ? : tin đồn (vị trí gần đúng)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))

	func _dashed(a: Vector2, b: Vector2, col: Color, seg: float) -> void:
		var d := b - a
		var dist := d.length()
		var dir := d / maxf(dist, 0.001)
		var t := 0.0
		while t < dist:
			draw_line(a + dir * t, a + dir * minf(t + seg * 0.55, dist), col, 2.0)
			t += seg

	func _dashed_circle(c: Vector2, r: float, col: Color) -> void:
		var n := 18
		for i in n:
			var a0 := TAU * float(i) / float(n)
			draw_arc(c, r, a0, a0 + TAU / float(n) * 0.55, 6, col, 2.0)
