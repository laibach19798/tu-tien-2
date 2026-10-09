extends Node2D
class_name Loot
## Vật phẩm rơi trên đất: nảy ra, đứng bập bềnh, tự nhặt khi người chơi lại gần. Biến mất sau một lúc.

var host: Node
var item := "stone"   # "stone" = linh thạch, còn lại là id vật phẩm
var amount := 1
var _t := 0.0
var _vel := Vector2.ZERO
var _h := 0.0
var _hv := 0.0
var _landed := false
var _life := 60.0


func setup(p_host: Node, id: String, n: int, from: Vector2) -> void:
	host = p_host
	item = id
	amount = n
	position = from
	_vel = Vector2(randf_range(-60.0, 60.0), randf_range(-25.0, 25.0))
	_hv = 150.0


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if not _landed:
		_hv -= 520.0 * delta
		_h = maxf(_h + _hv * delta, 0.0)
		position += _vel * delta
		_vel = _vel.lerp(Vector2.ZERO, minf(1.0, delta * 3.0))
		if _h <= 0.0 and _hv < 0.0:
			_landed = true
	elif host != null and host.player != null and _t > 0.5 and host.vitals.alive():
		if position.distance_to(host.player.position) < 38.0:
			_pickup()
			return
	if _life < 5.0:
		modulate.a = 0.5 + 0.5 * sin(_t * 18.0)
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _pickup() -> void:
	var label := ""
	Sfx.play("coin" if item == "stone" else "pickup")
	if item == "stone":
		host.inv.add_stones(amount)
		label = "+%d linh thạch" % amount
	else:
		host.inv.add(item, amount)
		label = "+%d %s" % [amount, Items.item_name(item)]
	host.float_text(host.player.position + Vector2(0, -70), label, UIKit.STONE_TXT if item == "stone" else UIKit.PAPER)
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 4.0) * 2.0 if _landed else 0.0
	var icon := "stone" if item == "stone" else str(Items.DATA.get(item, {}).get("icon", "stone"))
	var tint: Color = Items.DATA.get(item, {}).get("tint", Color.WHITE)
	draw_rect(Rect2(-8, -1, 16, 3), Color(0, 0, 0, 0.35))
	UIKit.draw_icon(self, icon, tint, Vector2(-12, -26 - _h + bob), 2.0)
	if _landed:
		var s := fmod(_t * 1.5, 1.0)
		if s < 0.2:
			draw_rect(Rect2(8, -28 + bob, 2, 2), Color.WHITE)
