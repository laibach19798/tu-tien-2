extends RefCounted
class_name Shadow
## Bóng đổ hình elip dưới chân vật thể (tạo chiều sâu 2.5D).


static func make(rx: float, ry: float, alpha := 0.3) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	p.polygon = pts
	p.color = Color(0.02, 0.05, 0.12, alpha)
	return p
