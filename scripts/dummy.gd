extends Node2D
class_name TrainingDummy
## Mộc nhân luyện kiếm: nhận sát thương, rung lắc, hiện số sát thương, đổ xuống rồi dựng lại.
## Mốc (origin) là chân của mộc nhân. Mọi mục tiêu đều ở group "targets" và có take_hit/hit_center/alive.

signal got_hit(dmg: float)

const WOOD := Color(0.55, 0.37, 0.22)
const DARK := Color(0.28, 0.17, 0.11)
const STRAW := Color(0.86, 0.72, 0.36)
const CLOTH := Color(0.78, 0.70, 0.55)
const RED := Color(0.70, 0.20, 0.20)

var max_hp := 120.0
var hp := 120.0
var alive := true
var _flash := 0.0
var _wobble := 0.0
var _phase := 0.0


func _ready() -> void:
	add_to_group("targets")
	hp = max_hp
	var sh := Shadow.make(18.0, 6.0, 0.32)
	add_child(sh)
	move_child(sh, 0)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -36)


func take_hit(dmg: float, from: Vector2) -> bool:
	if not alive:
		return false
	hp -= dmg
	_flash = 1.0
	var side := signf(global_position.x - from.x)
	_wobble = (side if side != 0.0 else 1.0) * 0.2
	_phase = 0.0
	_show_number(dmg)
	got_hit.emit(dmg)
	if hp <= 0.0:
		alive = false
		var tw := create_tween()
		tw.tween_property(self, "rotation", (side if side != 0.0 else 1.0) * 1.45, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(4.0)
		tw.tween_callback(_respawn)
	return true


func _respawn() -> void:
	rotation = 0.0
	hp = max_hp
	alive = true
	_wobble = 0.0


func _show_number(dmg: float) -> void:
	var l := Label.new()
	l.text = str(int(dmg))
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 200
	get_parent().add_child(l)
	l.global_position = hit_center() + Vector2(randf_range(-14.0, 14.0) - 8.0, -34.0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if alive:
		_phase += delta * 30.0
		_wobble = lerpf(_wobble, 0.0, minf(1.0, delta * 7.0))
		rotation = _wobble * cos(_phase)
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	var b := 1.0 + _flash * 1.1
	modulate = Color(b, b, b, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-15, -6, 30, 6), DARK)
	draw_rect(Rect2(-12, -9, 24, 4), WOOD)
	draw_rect(Rect2(-4, -58, 8, 52), WOOD)
	draw_rect(Rect2(-4, -58, 8, 52), DARK, false, 1.0)
	draw_rect(Rect2(-26, -46, 52, 7), WOOD)
	draw_rect(Rect2(-26, -46, 52, 7), DARK, false, 1.0)
	draw_rect(Rect2(-10, -53, 20, 25), CLOTH)
	draw_rect(Rect2(-10, -53, 20, 25), DARK, false, 1.0)
	draw_rect(Rect2(-10, -43, 20, 3), RED)
	draw_circle(Vector2(0, -65), 10.0, STRAW)
	draw_arc(Vector2(0, -65), 10.0, 0.0, TAU, 20, DARK, 1.0)
	draw_rect(Rect2(-10, -71, 20, 4), RED)
	draw_circle(Vector2(-3.5, -64), 1.3, DARK)
	draw_circle(Vector2(3.5, -64), 1.3, DARK)
	if alive and hp < max_hp:
		draw_rect(Rect2(-22, -90, 44, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-21, -89, 42.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color(0.35, 0.85, 0.4))
