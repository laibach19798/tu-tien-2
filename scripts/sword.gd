extends Node2D
class_name SwordVisual
## Thanh kiếm vẽ bằng code, mũi kiếm hướng +X. Dùng cho kiếm cầm tay, kiếm sau lưng và phi kiếm.

const BLADE := Color(0.86, 0.92, 1.0)
const EDGE := Color(1, 1, 1)
const LINE := Color(0.22, 0.28, 0.40)
const GOLD := Color(0.95, 0.78, 0.30)
const HILT := Color(0.45, 0.28, 0.20)
const SCABBARD := Color(0.30, 0.20, 0.15)
const SCABBARD_EDGE := Color(0.52, 0.38, 0.28)

var length := 30.0:
	set(v):
		length = v
		queue_redraw()
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()
var glow_color := Color(0.6, 0.9, 1.0)
var shape := "kiem":   # kiem | dao | thuong | xa | liem (binh khí các tông)
	set(v):
		shape = v
		queue_redraw()
var blade_color := BLADE:
	set(v):
		blade_color = v
		queue_redraw()
var sheath := false:   # true: vẽ vỏ kiếm (kiếm đeo lưng) thay vì lưỡi kiếm trần
	set(v):
		sheath = v
		queue_redraw()
# Màu theo kiểu kiếm (mặc định như trước); đổi qua configure_style()
var scabbard_color := SCABBARD
var scabbard_edge := SCABBARD_EDGE
var gold_color := GOLD
var hilt_color := HILT


## Chiều dài chuẩn theo hình dạng binh khí (kiếm đeo lưng).
static func length_of(shape: String) -> float:
	match shape:
		"dao": return 28.0
		"thuong": return 40.0
		"xa": return 30.0
		"liem": return 34.0
	return 26.0


## Đặt màu vỏ, viền, chi tiết kim loại và chuôi cho kiếm đeo lưng.
func configure_style(scabbard: Color, edge: Color, metal: Color, hilt: Color) -> void:
	scabbard_color = scabbard
	scabbard_edge = edge
	gold_color = metal
	hilt_color = hilt
	queue_redraw()


func _draw() -> void:
	var l := length
	if glow > 0.0:
		draw_line(Vector2(0, 0), Vector2(l, 0), Color(glow_color, 0.18 * glow), 13.0)
		draw_line(Vector2(2, 0), Vector2(l, 0), Color(glow_color, 0.38 * glow), 7.0)
	if shape != "kiem":
		_draw_weapon(l)
		return
	var hw := 2.3 if sheath else 2.6
	var pts := PackedVector2Array([Vector2(4, -hw), Vector2(l - 7, -hw), Vector2(l, 0), Vector2(l - 7, hw), Vector2(4, hw)])
	draw_colored_polygon(pts, scabbard_color if sheath else blade_color)
	draw_line(Vector2(4, -0.6), Vector2(l - 5, -0.6), scabbard_edge if sheath else EDGE, 1.2)
	if sheath:
		draw_rect(Rect2(l - 9.0, -hw - 0.6, 3.0, hw * 2.0 + 1.2), gold_color)   # khoen trên vỏ
		draw_rect(Rect2(8.0, -hw - 0.6, 2.0, hw * 2.0 + 1.2), gold_color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), LINE, 1.0)
	draw_rect(Rect2(1.0, -6.0, 3.0, 12.0), gold_color)
	draw_rect(Rect2(-9.0, -1.5, 10.0, 3.0), hilt_color)
	draw_circle(Vector2(-10, 0), 2.2, gold_color)


## Binh khí các tông. Mũi hướng +X, chuôi ở gốc. Khi sheath = true thì vẽ bằng màu vỏ (đeo lưng).
func _draw_weapon(l: float) -> void:
	var body := scabbard_color if sheath else blade_color
	var edge := scabbard_edge if sheath else EDGE
	match shape:
		"dao":   # đao lưỡi cong bản rộng, sống lưng dày, mũi vung lên
			var pts := PackedVector2Array([Vector2(4, -3.2), Vector2(l * 0.5, -4.6), Vector2(l - 7.0, -7.2), Vector2(l + 1.0, -3.4),
				Vector2(l - 9.0, 1.6), Vector2(l * 0.5, 3.2), Vector2(4, 3.2)])
			draw_colored_polygon(pts, body)
			draw_polyline(PackedVector2Array([Vector2(5, 3.0), Vector2(l * 0.5, 3.0), Vector2(l - 9.0, 1.4), Vector2(l, -3.4)]), edge, 1.2)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[0]]), LINE, 1.0)
			draw_circle(Vector2(3, 0), 4.2, gold_color)
			draw_circle(Vector2(3, 0), 2.2, hilt_color)
			draw_rect(Rect2(-10.0, -1.6, 12.0, 3.2), hilt_color)
			draw_circle(Vector2(-11, 0), 2.4, gold_color)
		"thuong":   # thương: cán dài, mũi lá, tua
			draw_line(Vector2(-12, 0), Vector2(l - 9.0, 0), hilt_color if not sheath else scabbard_color, 3.0)
			draw_line(Vector2(-12, -0.5), Vector2(l - 9.0, -0.5), scabbard_edge, 1.0)
			var tip := PackedVector2Array([Vector2(l - 11.0, 0), Vector2(l - 6.0, -4.2), Vector2(l + 8.0, 0), Vector2(l - 6.0, 4.2)])
			draw_colored_polygon(tip, body)
			draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[3], tip[0]]), LINE, 1.0)
			draw_line(Vector2(l - 4.0, 0), Vector2(l + 6.0, 0), edge, 1.0)
			draw_rect(Rect2(l - 13.0, -2.0, 3.0, 4.0), gold_color)
			var tassel := Color(0.85, 0.2, 0.22)
			draw_colored_polygon(PackedVector2Array([Vector2(l - 12.0, 0), Vector2(l - 20.0, 5.0), Vector2(l - 17.0, 7.5), Vector2(l - 11.0, 2.0)]), tassel)
		"xa":   # xà kiếm: thân kiếm uốn lượn như rắn
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			var n := 9
			for i in n + 1:
				var f := float(i) / float(n)
				var x := lerpf(4.0, l, f)
				var y := sin(f * TAU * 1.5) * 3.2 * (1.0 - f * 0.4)
				var w := lerpf(2.6, 0.6, f)
				top.append(Vector2(x, y - w))
				bot.append(Vector2(x, y + w))
			bot.reverse()
			var poly := PackedVector2Array()
			poly.append_array(top)
			poly.append_array(bot)
			draw_colored_polygon(poly, body)
			draw_polyline(top, edge, 1.0)
			draw_polyline(PackedVector2Array(poly + PackedVector2Array([poly[0]])), LINE, 1.0)
			draw_rect(Rect2(1.0, -5.0, 3.0, 10.0), gold_color)
			draw_rect(Rect2(-9.0, -1.5, 10.0, 3.0), hilt_color)
			draw_circle(Vector2(-10, 0), 2.6, gold_color)
		"liem":   # liêm: cán dài, lưỡi hái cong ngược
			draw_line(Vector2(-12, 0), Vector2(l * 0.75, 0), hilt_color if not sheath else scabbard_color, 3.0)
			draw_line(Vector2(-12, -0.6), Vector2(l * 0.75, -0.6), scabbard_edge, 1.0)
			var arc := PackedVector2Array()
			var cx := l * 0.72
			for i in 11:
				var a := lerpf(0.2, 2.5, float(i) / 10.0)
				arc.append(Vector2(cx + sin(a) * 13.0, -cos(a) * 14.0 - 1.0))
			var inner := PackedVector2Array()
			for i in 11:
				var a2 := lerpf(2.4, 0.3, float(i) / 10.0)
				inner.append(Vector2(cx + sin(a2) * 8.0, -cos(a2) * 9.5 - 1.0))
			var blade := PackedVector2Array()
			blade.append_array(arc)
			blade.append_array(inner)
			draw_colored_polygon(blade, body)
			draw_polyline(arc, edge, 1.2)
			draw_polyline(PackedVector2Array(blade + PackedVector2Array([blade[0]])), LINE, 1.0)
			draw_rect(Rect2(cx - 3.0, -3.0, 5.0, 6.0), gold_color)
			draw_circle(Vector2(-13, 0), 2.6, gold_color)
