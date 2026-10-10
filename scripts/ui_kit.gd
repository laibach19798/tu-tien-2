extends RefCounted
class_name UIKit
## Bộ dựng giao diện kiểu pixel: khung vuông viền đậm, bảng màu ít, biểu tượng vẽ từ ma trận điểm ảnh. Không bo góc, không phát sáng.

const BLACK := Color(0.043, 0.047, 0.086)
const INK := Color(0.098, 0.114, 0.196)
const INK_2 := Color(0.137, 0.157, 0.263)
const INK_3 := Color(0.204, 0.231, 0.373)
const INK_4 := Color(0.298, 0.333, 0.510)
const GOLD := Color(0.953, 0.761, 0.286)
const GOLD_DK := Color(0.600, 0.400, 0.173)
const JADE := Color(0.314, 0.827, 0.639)
const JADE_DK := Color(0.133, 0.416, 0.365)
const PAPER := Color(0.957, 0.925, 0.847)
const MUTED := Color(0.600, 0.639, 0.745)
const RED := Color(0.906, 0.376, 0.345)
const QI_BLUE := Color(0.290, 0.639, 0.898)
const XP_GOLD := Color(0.953, 0.690, 0.208)
const STONE_TXT := Color(0.600, 0.898, 0.953)

const FONT_SCALE := 1.4   # VT323 nhỏ hơn phông thường nên mọi cỡ chữ nhân với hệ số này

static var _theme: Theme


static func S(px: float) -> int:
	return roundi(px * FONT_SCALE)


## Hộp phẳng, góc vuông (tham số radius giữ lại cho tương thích nhưng bị bỏ qua).
static func box(bg: Color, border: Color, bw := 2, _radius := 0, margin := Vector2(10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	return s


static func panel_style(alpha := 1.0) -> StyleBoxFlat:
	var s := box(Color(INK.r, INK.g, INK.b, alpha), BLACK, 3, 0, Vector2(22, 18))
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 1
	s.shadow_offset = Vector2(4, 4)
	return s


static func button_box(bg: Color, border: Color, lift := 3) -> StyleBoxFlat:
	var s := box(bg, border, 2, 0, Vector2(12, 6))
	s.border_width_bottom = 2 + lift
	s.border_color = border
	return s


## Theme dùng chung cho nút, nhãn, thanh cuộn...
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_default_font_size(S(16.0))
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.55))
	t.set_stylebox("normal", "Button", button_box(INK_3, BLACK))
	t.set_stylebox("hover", "Button", button_box(INK_4, GOLD_DK))
	var pressed := button_box(INK_2, GOLD, 1)
	pressed.content_margin_top = 8
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", button_box(Color(INK_2, 0.8), Color(BLACK, 0.8), 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var grab := box(JADE_DK, BLACK, 2, 0, Vector2.ZERO)
	var grab_hi := box(JADE, BLACK, 2, 0, Vector2.ZERO)
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, box(BLACK, BLACK, 0, 0, Vector2.ZERO))
		t.set_stylebox("scroll_focus", sb, box(BLACK, BLACK, 0, 0, Vector2.ZERO))
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)
	var line := StyleBoxLine.new()
	line.color = GOLD_DK
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	_theme = t
	return t


static func label(text: String, size_px := 16, color := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", S(size_px))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", BLACK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Vẽ chữ có bóng đen 1px.
static func shadow_text(c: CanvasItem, font: Font, pos: Vector2, text: String, size_px: int, color: Color) -> void:
	c.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, BLACK)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


## Vẽ ma trận điểm ảnh: mỗi ký tự là một ô, bảng màu tra theo ký tự ('.' là trong suốt).
static func bitmap(c: CanvasItem, origin: Vector2, rows: Array, pal: Dictionary, px: float) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or not pal.has(ch):
				continue
			c.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), pal[ch])


# ---------------------------------------------------------------- biểu tượng 12x12
const ICONS := {
	"stone": [
		"............",
		"....kkkk....",
		"...kcwwck...",
		"..kcwcccck..",
		".kcwcccbbck.",
		".kccccbbbck.",
		".kcccbbbbck.",
		"..kcbbbbck..",
		"...kcbbck...",
		"....kbbk....",
		".....kk.....",
		"............",
	],
	"herb": [
		"............",
		"....kk......",
		"...kGGk.kk..",
		"..kGgGGkGGk.",
		"..kGgGGkGgGk",
		"...kkGGkGgGk",
		".....kGGkkk.",
		"....kkGk....",
		".....kGk....",
		".....kGk....",
		"....kkGkk...",
		"............",
	],
	"pill": [
		"............",
		"....kkkk....",
		"...kllmmk...",
		"..klwlmmmk..",
		"..klllmmmk..",
		"..kmmmmmdk..",
		"..kmmmmddk..",
		"..kmmmdddk..",
		"...kmdddk...",
		"....kkkk....",
		"............",
		"............",
	],
	"sun": [
		"y....yy....y",
		".y...yy...y.",
		"..y.kkkk.y..",
		"....kyyyk...",
		"yy.kyywyyk.y",
		"yy.kyyyyyk.y",
		"....kyyyyk..",
		"..y.kkkk.y..",
		".y...yy...y.",
		"y....yy....y",
		"............",
		"............",
	],
	"moon": [
		"....kkkk....",
		"...kyyyk....",
		"..kyywk.....",
		".kyywk......",
		".kyyk.......",
		".kyyk.......",
		".kyyyk......",
		"..kyyykkk...",
		"...kyyyyyk..",
		"....kkkkkk..",
		"............",
		"............",
	],
	"hair": [
		"....kkkk....",
		"...kmmmmk...",
		"..kmllmmmk..",
		".kmlmmmmmmk.",
		".kmmmmmmmmk.",
		".kmmmkkmmmk.",
		".kmmk..kmmk.",
		".kmk....kmk.",
		".kdk....kdk.",
		".kk......kk.",
		"............",
		"............",
	],
	"clothes": [
		"..kkk..kkk..",
		".kmmmkkmmmk.",
		"kmmmmmmmmmmk",
		"kmlmmmmmmmmk",
		"kkmmmmmmmmkk",
		".kmmmmmmmmk.",
		".kmmmmmmmmk.",
		".kddddddddk.",
		".kmmmmmmmmk.",
		".kmmmmmmmmk.",
		".kmmmmmmmmk.",
		"..kkkkkkkk..",
	],
	"dye": [
		"....kkkk....",
		"....kddk....",
		"...kmmmmk...",
		"..kmmllmmk..",
		".kmmlmmmmmk.",
		".kmmmmmmmmk.",
		".kmmmmmmmdk.",
		".kmmmmmmddk.",
		"..kddddddk..",
		"...kkkkkk...",
		"............",
		"............",
	],
	"waist": [
		"............",
		".kkkkkkkkkk.",
		".kdddddddmk.",
		".kkkkkkkkkk.",
		"....kmk.....",
		"...kmmmk....",
		"...kmwmk....",
		"...kmmmk....",
		"....kkk.....",
		"....kmk.....",
		"...k.k.k....",
		"............",
	],
	"head": [
		"............",
		"..k..k..k...",
		".kmk.kmk.k..",
		".kmmkmmmkmk.",
		".kmmmmmmmmk.",
		".kdddddddmk.",
		".kmmmmmmmmk.",
		"..kkkkkkkk..",
		"............",
		"............",
		"............",
		"............",
	],
	"sword": [
		"..........kk",
		".........kwk",
		"........kwk.",
		".......kwk..",
		"......kwk...",
		".....kwk....",
		".k..kwk.....",
		"kmkkwk......",
		".kmmk.......",
		".kdmk.......",
		"kd.kk.......",
		"k...........",
	],
	"shoes": [
		"............",
		"..kkkk......",
		"..kmmk......",
		"..kmmk......",
		"..kmmk......",
		"..kmmkk.....",
		"..kmmmmkkk..",
		".kmmmmmmmmk.",
		".kmmmmmmmmk.",
		".kddddddddk.",
		"..kkkkkkkk..",
		"............",
	],
	"slash": [
		"..........kk",
		".........kcw",
		"........kcwk",
		".......kcwk.",
		"......kcwk..",
		".k...kcwk...",
		".kk.kcwk....",
		"..kkcwk.....",
		"...kck......",
		"..kbkk......",
		".kbk.k......",
		"kbk.........",
	],
	"qi": [
		"....kk......",
		"...kcck.....",
		"..kcwck..kk.",
		"..kccck.kcck",
		"..kccck.kwck",
		"..kccck.kcck",
		"..kccck.kcck",
		"..kccck..kk.",
		"..kcwck.....",
		"...kcck.....",
		"....kk......",
		"............",
	],
	"fly": [
		"..k...k...k.",
		".kck.kck.kck",
		".kwk.kwk.kwk",
		".kck.kck.kck",
		".kck.kck.kck",
		".kck.kck.kck",
		"kkkkkkkkkkkk",
		".kbk.kbk.kbk",
		".kbk.kbk.kbk",
		"..k...k...k.",
		"............",
		"............",
	],
	"storm": [
		"....kkkk....",
		"..kkccccckk.",
		".kcc.kk.cck.",
		".kc.kwwk.ck.",
		"kcc.kwwk.cck",
		"kc..kwwk..ck",
		"kc.kkwwkk.ck",
		"kcc.kwwk.cck",
		".kc..kk..ck.",
		".kcc....cck.",
		"..kkccccck..",
		"....kkkk....",
	],
	"fang": [
		"............",
		"..kkkkkk....",
		".kllmmmmk...",
		".kmmmmmdk...",
		"..kmmmdk....",
		"..kmmmdk....",
		"...kmdk.....",
		"...kmdk.....",
		"....kdk.....",
		"....kdk.....",
		".....kk.....",
		"............",
	],
	"hide": [
		"............",
		"..kk....kk..",
		".kmmkkkkmmk.",
		".kmmmmmmmmk.",
		"kmmlmmmmmmmk",
		"kmmmmmmmdmmk",
		"kmmmmmmmmmmk",
		"kmmdmmmlmmmk",
		".kmmmmmmmmk.",
		".kmmkmmkmmk.",
		"..kk.kk.kk..",
		"............",
	],
	"ash": [
		"............",
		"............",
		"............",
		"....kkkk....",
		"...kmmmmk...",
		"..kmlmmmmk..",
		".kmmmmdmmmk.",
		".kmdmmmmmdmk",
		"kmmmmmlmmmmk",
		"kkkkkkkkkkkk",
		"............",
		"............",
	],
	"lock": [
		"............",
		"....kkkk....",
		"...kmmmmk...",
		"...km..mk...",
		"...km..mk...",
		"..kkkkkkkk..",
		"..kmmmmmmk..",
		"..kmmkkmmk..",
		"..kmmkkmmk..",
		"..kmmmmmmk..",
		"..kkkkkkkk..",
		"............",
	],
}


## Bảng màu theo biểu tượng; tint là màu chủ đạo cho đồ có thể nhuộm (đan dược, trang phục).
static func icon_palette(kind: String, tint: Color) -> Dictionary:
	var k := BLACK
	match kind:
		"stone":
			return {"k": k, "c": Color(0.40, 0.84, 0.96), "w": Color.WHITE, "b": Color(0.16, 0.50, 0.78)}
		"herb":
			return {"k": k, "G": Color(0.30, 0.74, 0.36), "g": Color(0.55, 0.90, 0.50)}
		"sun":
			return {"k": Color(0.70, 0.40, 0.10), "y": tint, "w": Color.WHITE}
		"moon":
			return {"k": Color(0.24, 0.28, 0.50), "y": tint, "w": Color.WHITE}
		"slash", "qi":
			return {"k": k, "c": JADE, "w": Color.WHITE, "b": GOLD_DK}
		"fly":
			return {"k": k, "c": JADE, "w": Color.WHITE, "b": GOLD_DK}
		"storm":
			return {"k": k, "c": JADE, "w": Color.WHITE}
		"lock":
			return {"k": k, "m": MUTED}
	return {"k": k, "m": tint, "l": tint.lightened(0.4), "d": tint.darkened(0.4), "w": Color.WHITE}


static func draw_icon(c: CanvasItem, kind: String, tint: Color, origin: Vector2, px: float) -> void:
	if ICONS.has(kind):
		bitmap(c, origin, ICONS[kind], icon_palette(kind, tint), px)


## Biểu tượng điểm ảnh, tự phóng theo kích thước (số nguyên lần).
class Icon extends Control:
	var kind := "stone"
	var color := Color.WHITE

	func _init(k := "stone", c := Color.WHITE, px := 36.0) -> void:
		kind = k
		color = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_kind(k: String, c: Color) -> void:
		kind = k
		color = c
		queue_redraw()

	func _draw() -> void:
		var scale := maxf(floorf(minf(size.x, size.y) / 12.0), 1.0)
		var origin := ((size - Vector2(12, 12) * scale) * 0.5).floor()
		UIKit.draw_icon(self, kind, color, origin, scale)


static func item_icon(id: String, px := 36.0) -> Icon:
	var d: Dictionary = Items.DATA.get(id, {})
	return Icon.new(str(d.get("icon", "stone")), d.get("tint", Color.WHITE), px)

## Khung bảng: viền đen, viền vàng nâu, đường sáng bên trong và bốn đinh tán ở góc.
class Frame extends PanelContainer:
	func _init(min_size := Vector2.ZERO, alpha := 1.0) -> void:
		custom_minimum_size = min_size
		theme = UIKit.theme()
		add_theme_stylebox_override("panel", UIKit.panel_style(alpha))
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(3, 3, w - 6, h - 6), UIKit.GOLD_DK, false, 2.0)
		draw_rect(Rect2(5.5, 5.5, w - 11, h - 11), UIKit.INK_3, false, 1.0)
		for p in [Vector2(7, 7), Vector2(w - 11, 7), Vector2(7, h - 11), Vector2(w - 11, h - 11)]:
			draw_rect(Rect2(p, Vector2(4, 4)), UIKit.BLACK)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 2)), UIKit.GOLD)


## Tiêu đề: chữ có bóng, gạch chân vàng 2px.
class Banner extends Control:
	var text := ""
	var size_px := 20
	var color := UIKit.GOLD
	var align_left := false

	func _init(t := "", sz := 20, c := UIKit.GOLD, left := false) -> void:
		text = t
		size_px = UIKit.S(sz)
		color = c
		align_left = left
		custom_minimum_size = Vector2(0, size_px + 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_text(t: String) -> void:
		text = t
		queue_redraw()

	func _draw() -> void:
		var f := get_theme_default_font()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var x := 2.0 if align_left else floorf((size.x - tw) * 0.5)
		UIKit.shadow_text(self, f, Vector2(x, size_px + 1), text, size_px, color)
		var y := size.y - 4.0
		draw_rect(Rect2(0, y, size.x, 2), UIKit.GOLD_DK)
		draw_rect(Rect2(0, y, 12, 2), color)


## Thanh chỉ số kiểu pixel: viền đen, ruột chia ô, vệt sáng ở trên.
class FancyBar extends Control:
	var value := 0.0
	var max_value := 1.0
	var color := UIKit.XP_GOLD
	var title := ""
	var show_numbers := true
	var _disp := 0.0
	var _flash := 0.0

	func _init(t := "", c := UIKit.XP_GOLD, h := 22.0) -> void:
		title = t
		color = c
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, m: float) -> void:
		if v > value + 0.01:
			_flash = 0.35
		value = v
		max_value = maxf(m, 1.0)

	func _process(delta: float) -> void:
		var before := _disp
		_disp = move_toward(_disp, value, maxf(absf(value - _disp) * 8.0 * delta, 0.5))
		var f := _flash
		_flash = maxf(0.0, _flash - delta)
		if _disp != before or f > 0.0:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), UIKit.BLACK)
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.07, 0.08, 0.14))
		var inner := Rect2(3, 3, w - 6, h - 6)
		var ratio := clampf(_disp / max_value, 0.0, 1.0)
		var fw := floorf(inner.size.x * ratio / 2.0) * 2.0
		if fw > 0.0:
			var c := color.lightened(0.45) if _flash > 0.0 else color
			draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), c)
			draw_rect(Rect2(inner.position, Vector2(fw, 3)), c.lightened(0.4))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 3), Vector2(fw, 3)), c.darkened(0.35))
			var x := inner.position.x + 12.0
			while x < inner.position.x + fw:
				draw_rect(Rect2(x, inner.position.y, 2, inner.size.y), Color(0, 0, 0, 0.35))
				x += 12.0
		var f := get_theme_default_font()
		var fs := int(clampf(h - 3, 12, 22))
		var ty := h * 0.5 + fs * 0.28
		if title != "":
			UIKit.shadow_text(self, f, Vector2(8, ty), title, fs, UIKit.PAPER)
		if show_numbers:
			var txt := "%d / %d" % [roundi(value), roundi(max_value)]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			UIKit.shadow_text(self, f, Vector2(w - tw - 8, ty), txt, fs, UIKit.PAPER)


## Ô vật phẩm vuông.
class Slot extends Control:
	var icon: Icon
	var count := 0
	var selected := false
	var empty := true
	var hovered := false
	signal picked

	func _init(px := 64.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; queue_redraw())

	func set_item(id: String, n: int) -> void:
		if icon != null:
			icon.queue_free()
			icon = null
		empty = id == ""
		count = n
		if not empty:
			icon = UIKit.item_icon(id, 48.0)
			icon.size = icon.custom_minimum_size
			icon.position = ((custom_minimum_size - icon.custom_minimum_size) * 0.5).floor() - Vector2(0, 2)
			add_child(icon)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not empty and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), UIKit.BLACK)
		draw_rect(Rect2(2, 2, w - 4, h - 4), UIKit.INK_2 if not empty else Color(0.075, 0.085, 0.15))
		if not empty:
			draw_rect(Rect2(2, 2, w - 4, 2), UIKit.INK_3)
		if selected:
			draw_rect(Rect2(0, 0, w, h), UIKit.JADE, false, 4.0)
		elif hovered and not empty:
			draw_rect(Rect2(0, 0, w, h), UIKit.GOLD, false, 4.0)
		if count > 1:
			var f := get_theme_default_font()
			var txt := str(count)
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			UIKit.shadow_text(self, f, Vector2(w - tw - 6, h - 6), txt, 22, UIKit.PAPER)


## Ô chiêu thức: khung vuông, phím tắt, biểu tượng, tiêu hao, hồi chiêu.
class SkillSlot extends Control:
	var info := {}
	var cd := 0.0
	var unlocked := true
	var afford := true
	var _pulse := 0.0

	func _init(skill: Dictionary) -> void:
		info = skill
		custom_minimum_size = Vector2(68, 86)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(p_cd: float, p_unlocked: bool, p_afford: bool) -> void:
		if p_cd <= 0.0 and cd > 0.0 and unlocked:
			_pulse = 0.25
		if p_cd != cd or p_unlocked != unlocked or p_afford != afford:
			queue_redraw()
		cd = p_cd
		unlocked = p_unlocked
		afford = p_afford

	func _process(delta: float) -> void:
		if _pulse > 0.0:
			_pulse = maxf(0.0, _pulse - delta)
			queue_redraw()

	func _draw() -> void:
		var f := get_theme_default_font()
		var box := Rect2(4, 4, 60, 60)
		var edge := UIKit.GOLD if unlocked else UIKit.INK_4
		if unlocked and not afford:
			edge = UIKit.RED
		draw_rect(Rect2(box.position - Vector2(2, 2), box.size + Vector2(4, 4)), UIKit.BLACK)
		draw_rect(box, edge, false, 2.0)
		draw_rect(box.grow(-2), UIKit.INK_2)
		draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 2)), UIKit.INK_3)
		var kind := str(info.get("id", "slash"))
		var tint := Color.WHITE if unlocked else Color(0.35, 0.38, 0.5)
		var origin := (box.get_center() - Vector2(24, 24)).floor()
		if unlocked:
			UIKit.draw_icon(self, kind, Color.WHITE, origin, 4.0)
		else:
			UIKit.bitmap(self, origin, UIKit.ICONS[kind], {"k": UIKit.BLACK, "c": tint, "w": tint, "b": tint}, 4.0)
			UIKit.draw_icon(self, "lock", Color.WHITE, (box.get_center() - Vector2(18, 18)).floor(), 3.0)
		if unlocked and cd > 0.0:
			var h := floorf(box.size.y * clampf(cd, 0.0, 1.0) / 4.0) * 4.0
			draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, maxf(h - 4, 0.0))), Color(0, 0, 0, 0.62))
		if _pulse > 0.0:
			draw_rect(box.grow(-2), Color(1, 1, 1, _pulse * 1.6))
		# phím tắt
		var key := str(info.get("key", ""))
		draw_rect(Rect2(box.position.x - 2, box.position.y - 2, 18, 18), UIKit.BLACK)
		draw_rect(Rect2(box.position.x, box.position.y, 14, 14), edge)
		var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, Vector2(box.position.x + 7 - kw * 0.5, box.position.y + 12), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.BLACK)
		# tiêu hao linh khí
		var cost := "%d" % int(info.get("cost", 0))
		var cw := f.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var cc := UIKit.QI_BLUE if afford else UIKit.RED
		var cx := box.end.x - cw - 8.0
		draw_rect(Rect2(cx - 8, box.end.y - 14, 6, 6), UIKit.BLACK)
		draw_rect(Rect2(cx - 7, box.end.y - 13, 4, 4), cc)
		UIKit.shadow_text(self, f, Vector2(cx, box.end.y - 5), cost, 20, cc)
		# tên
		var nm := str(info.get("name", ""))
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		UIKit.shadow_text(self, f, Vector2(floorf(size.x * 0.5 - nw * 0.5), 82), nm, 20, UIKit.PAPER if unlocked else UIKit.MUTED)


## Phím tắt dạng keycap.
class KeyCap extends Control:
	var key := ""
	var label := ""
	var fs := 13

	func _init(k := "E", txt := "", font_size := 13) -> void:
		key = k
		label = txt
		fs = UIKit.S(font_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := ThemeDB.fallback_font
		var kw := maxf(f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12, fs + 10)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		custom_minimum_size = Vector2(kw + (tw + 8 if txt != "" else 0.0), fs + 10)

	func _draw() -> void:
		var f := get_theme_default_font()
		var kw := maxf(f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12, fs + 10)
		draw_rect(Rect2(0, 0, kw, size.y), UIKit.BLACK)
		draw_rect(Rect2(2, 2, kw - 4, size.y - 6), UIKit.INK_4)
		draw_rect(Rect2(2, 2, kw - 4, 2), UIKit.PAPER)
		draw_rect(Rect2(2, size.y - 4, kw - 4, 2), UIKit.INK_2)
		var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(floorf((kw - tw) * 0.5), size.y * 0.5 + fs * 0.28), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.BLACK)
		if label != "":
			UIKit.shadow_text(self, f, Vector2(kw + 6, size.y * 0.5 + fs * 0.28), label, fs, UIKit.PAPER)
