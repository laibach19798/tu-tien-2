extends Node2D
## Linh thảo: bụi cỏ phát sáng, hái bằng phím E, mọc lại sau một lúc.

const RESPAWN := 90.0

var available := true
var _sprite: Sprite2D
var _t := randf() * 10.0
var _timer := 0.0


func _ready() -> void:
	var tex: Texture2D = load("res://assets/props/bush_d.png")
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	_sprite.scale = Vector2.ONE * 0.55
	_sprite.modulate = Color(0.85, 1.0, 0.65)
	add_child(_sprite)


func pick() -> void:
	available = false
	_timer = RESPAWN
	_sprite.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if not available:
		_timer -= delta
		if _timer <= 0.0:
			available = true
			_sprite.visible = true
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not available:
		return
	var a := 0.5 + 0.5 * sin(_t * 3.0)
	var c := Color(1.0, 1.0, 0.6, 0.35 + 0.5 * a)
	var p := Vector2(8.0 * sin(_t), -24.0 - 3.0 * a)
	draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), c, 1.5)
	draw_line(p + Vector2(0, -4), p + Vector2(0, 4), c, 1.5)
