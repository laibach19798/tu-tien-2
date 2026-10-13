extends Node2D
class_name ResourceNode
## Một điểm khai thác trên bản đồ (linh thảo, khoáng, di vật). Trạng thái nằm ở ResourceWorld (theo ID), nút chỉ hiển thị.
## Giữ giao diện của Herb cũ (available, pick, position) nên main.herbs dùng chung.

var node_id := ""
var kind_id := ""
var grade := 1
var res: ResourceWorld

var _sprite: Sprite2D
var _t := randf() * 10.0
var _poll := 0.0
var _ready_now := true

var kind: Dictionary:
	get:
		return res.kind_def(kind_id) if res != null else {}

var available: bool:
	get:
		return res != null and res.is_available(self)


func _ready() -> void:
	# ảnh pixel-art riêng của từng loại (assets/resources/<loại>.png); thiếu thì dùng bộ ảnh dự phòng cũ
	var own := "res://assets/resources/%s.png" % kind_id
	var look := str(kind.get("look", "herb"))
	var tex: Texture2D = null
	var native := ResourceLoader.exists(own)
	if native:
		tex = load(own)
	else:
		var path: String = {"herb": "res://assets/props/bush_d.png", "ore": "res://assets/props/rock_a.png", "crystal": "res://assets/props/crystal.png", "relic": "res://assets/props/xt_sword.png"}.get(look, "res://assets/props/bush_d.png")
		tex = load(path)
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.show_behind_parent = true   # _draw của nút (quầng sáng, lấp lánh) vẽ đè lên ảnh
		_sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 4.0)
		if not native:
			_sprite.scale = Vector2.ONE * 0.6
			var t: Array = kind.get("tint", [1, 1, 1])
			_sprite.modulate = Color(float(t[0]), float(t[1]), float(t[2]))
		add_child(_sprite)
	_apply_visibility(available)


func pick() -> void:
	if res != null and res.main != null:
		var owner := res.restricted_owner(node_id)
		if owner != "":
			res.ask_permission(self, owner)   # có hỏi thoại; hái xong (hoặc không) ở đó
		else:
			res.harvest(self)
	_apply_visibility(available)


func prompt_text() -> String:
	var cls := res.class_name_of(kind_id) if res != null else ""
	var owner := res.restricted_owner(node_id) if res != null else ""
	var tail := " · thuộc %s" % SectWar.sect_name(owner) if owner != "" else ""
	return "E: Thu thập %s (cấp %d · %s%s)" % [str(kind.get("name", "")), grade, cls, tail]


func _apply_visibility(v: bool) -> void:
	_ready_now = v
	if _sprite != null:
		_sprite.visible = v
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		var a := available
		if a != _ready_now:
			_apply_visibility(a)
	if _ready_now:
		queue_redraw()


func _draw() -> void:
	if not _ready_now:
		return
	var t: Array = kind.get("tint", [1, 1, 1])
	var base := Color(float(t[0]), float(t[1]), float(t[2])).lerp(Color.WHITE, 0.45)
	var a := 0.5 + 0.5 * sin(_t * 3.0)
	# quầng sáng dưới đất để nổi lên khỏi đá/bụi cây trang trí
	draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 20.0 + 2.0 * a, Color(base, 0.14 + 0.1 * a))
	draw_arc(Vector2.ZERO, 20.0 + 2.0 * a, 0.0, TAU, 24, Color(base, 0.45), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := Color(base, 0.35 + 0.5 * a)
	var p := Vector2(8.0 * sin(_t), -24.0 - 3.0 * a)
	draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), c, 1.5)
	draw_line(p + Vector2(0, -4), p + Vector2(0, 4), c, 1.5)
	# khan hiếm / độc nhất: thêm quầng sáng để người chơi nhận ra
	var cls := str(kind.get("class", ""))
	if cls != "renewable":
		var col := Color(1.0, 0.85, 0.4) if cls == "unique" else Color(0.7, 0.9, 1.0)
		draw_arc(Vector2(0, -12), 16.0 + 2.0 * a, 0.0, TAU, 20, Color(col, 0.25 + 0.3 * a), 1.5)
