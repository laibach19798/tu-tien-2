extends Node2D
## Vệt chém hình lưỡi liềm quét theo một cung, rồi mờ dần. Hướng cục bộ 0 rad = +X.

var radius := 64.0
var a0 := -1.2
var a1 := 1.2
var color := Color(0.75, 0.95, 1.0)
var thickness := 0.42    # độ dày lưỡi liềm theo bán kính
var reveal := 0.0:
	set(v):
		reveal = v
		queue_redraw()
var fade := 1.0:
	set(v):
		fade = v
		queue_redraw()


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func play(life := 0.26) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "reveal", 1.0, life * 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "fade", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var t_hi := reveal
	var t_lo := maxf(0.0, reveal - 0.65)
	if t_hi - t_lo < 0.02:
		return
	var n := 22
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var t := lerpf(t_lo, t_hi, f)
		var ang := lerpf(a0, a1, t)
		var dir := Vector2(cos(ang), sin(ang))
		var w := maxf(1.2, radius * thickness * sin(PI * t) * f)
		outer.append(dir * radius)
		inner.append(dir * (radius - w))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, Color(color, 0.8 * fade))
	draw_polyline(outer, Color(1, 1, 1, fade), 2.0)
