extends Node
class_name SwordSchool
## Kiếm phái: trạng thái bái sư Kiếm Tông, kiếm đeo lưng, rung màn hình / khựng hình. Chiêu thức do hệ tu luyện V1 (scripts/v1/) xử lý.

signal message(text: String)

## Bốn ô trên thanh chiêu: J nguồn chính, K Công Pháp/Pháp Bảo còn lại, U Công phụ, Space Thân Pháp (Y, H là phím mở bảng); tên, chi phí, hồi chiêu được V1 cập nhật khi đổi trang bị.
const SKILLS := [
	{"id": "slash", "name": "Công Pháp", "key": "J", "cost": 0.0, "cd": 1.0, "need": 0, "desc": ""},
	{"id": "storm", "name": "Pháp Bảo", "key": "K", "cost": 0.0, "cd": 1.0, "need": 0, "desc": ""},
	{"id": "slash", "name": "Công phụ", "key": "U", "cost": 0.0, "cd": 1.0, "need": 0, "desc": ""},
	{"id": "qi", "name": "Thân Pháp", "key": "Space", "cost": 0.0, "cd": 1.0, "need": 0, "desc": ""},
]
# vị trí gốc chuôi, góc (độ), có nằm trước thân không
const SHEATH_POSE := {
	"north": [Vector2(3, -29), 126.0, true],
	"north-east": [Vector2(2, -29), 118.0, true],
	"north-west": [Vector2(5, -29), 134.0, true],
	"south": [Vector2(-4, -30), 50.0, false],
	"south-east": [Vector2(-5, -30), 55.0, false],
	"south-west": [Vector2(-2, -30), 45.0, false],
	"east": [Vector2(-6, -31), 108.0, false],
	"west": [Vector2(6, -31), 72.0, false],
}
const LAYER_NAMES := ["HairBack", "Body", "Clothes", "Shoes", "HairFront"]
const LAYER_BASE := Vector2(0, -29)   # trùng vị trí trong hd/base_character.tscn

var joined := false
var host: Node            # main: có biến `direction` (front/back/left/right)
var player: Node2D
var cult: Cultivation
var hud
var fx_layer: Node2D
var skills: Array = SKILLS
var _hold: SwordVisual
var _sheath: SwordVisual
var _flash_rect: ColorRect
var _hitstop_active := false
var _swinging := 0.0


func setup(p_host: Node, p_player: Node2D, p_cult: Cultivation, p_hud, p_fx: Node2D) -> void:
	host = p_host
	player = p_player
	cult = p_cult
	hud = p_hud
	fx_layer = p_fx
	_hold = SwordVisual.new()
	_hold.length = 32.0
	_hold.visible = false
	player.add_child(_hold)
	_sheath = SwordVisual.new()
	_sheath.length = 26.0
	_sheath.sheath = true
	_sheath.visible = false
	player.add_child(_sheath)
	hud.build_skillbar(skills)


func step_unlocked(i: int) -> bool:
	return cult.step_index() >= int(skills[i]["need"])


func _process(_delta: float) -> void:
	_update_sheath()


## Kiếm đeo sau lưng khi không chiến đấu.
func _weapon_id() -> String:
	if host == null or host.get("wardrobe") == null:
		return ""
	return str(host.wardrobe.equipped.get("sword", ""))


## Kiếm cầm tay đổi hình dạng theo binh khí đang đeo (đao, thương, xà kiếm, liêm).
func _sync_weapon() -> void:
	var w: Dictionary = Wardrobe.ITEMS.get(_weapon_id(), {})
	var shape := str(w.get("shape", "kiem"))
	if shape != _hold.shape:
		_hold.shape = shape
		_hold.length = SwordVisual.length_of(shape) + 6.0
	_hold.blade_color = w.get("blade", SwordVisual.BLADE)
	if w.has("glow"):
		_hold.glow_color = w["glow"]
		_hold.glow = 0.35
	else:
		_hold.glow = 0.0


func _update_sheath() -> void:
	_sync_weapon()
	player.set_meta("sword_drawn", _swinging > 0.0)   # BackSword (thoi trang) an khi kiem dang o tren tay
	_sheath.visible = joined and _swinging <= 0.0 and player.get_node_or_null("BackSword") == null
	if not _sheath.visible:
		return
	# Kiếm đeo chéo trên lưng, chuôi nhô qua vai phải, vỏ chạy xuống hông trái (toạ độ so với chân; vai ~ -28, hông ~ -14).
	# Nhìn từ phía bắc: thấy lưng nên kiếm nằm TRƯỚC thân; các hướng nam: kiếm nằm SAU thân (chỉ thấy chuôi và mũi vỏ).
	var dname := Dir.normalize(host.direction)
	var pose: Array = SHEATH_POSE.get(dname, SHEATH_POSE["south"])
	_sheath.position = (pose[0] as Vector2) + Vector2(0, -float(player.get_meta("fly_lift", 0.0)))   # đang ngự không: kiếm lên cao cùng thân người
	_sheath.rotation = deg_to_rad(float(pose[1]))
	if pose[2]:
		player.move_child(_sheath, player.get_child_count() - 1)
	else:
		player.move_child(_sheath, 0)

## Phím chiêu cũ: chuyển cho V1 (0 = chiêu chính, 1 = Thân Pháp).
func cast(i: int) -> void:
	if host != null and host.get("cultivation_v1") != null and host.cultivation_v1.active():
		host.cultivation_v1.cast("than" if i == 1 else "")


var dmg_mult := 1.0   # thưởng bộ trang phục


## Hiệu ứng trúng đòn: dấu X, vòng sóng, quầng sáng, tia lửa.
func impact(pos: Vector2, col: Color, big := false) -> void:
	Fx.cross(fx_layer, pos, col, 42.0 if big else 30.0)
	Fx.ring(fx_layer, pos + Vector2(0, 28), 4.0, 58.0 if big else 38.0, col, 0.3, 0.55, 3.0)
	Fx.glow(fx_layer, pos, 14.0, 92.0 if big else 60.0, Color(1, 1, 1), 0.2)
	Fx.burst(fx_layer, pos, col, 18 if big else 12, 150.0 if big else 110.0, 0.4)


func spark(pos: Vector2) -> void:
	Fx.burst(fx_layer, pos, Color(0.55, 0.92, 1.0), 12, 130.0, 0.35)


## Rung màn hình, giảm dần về 0.
func shake(strength: float, dur: float) -> void:
	if host == null or host.camera == null:
		return
	var tw := create_tween()
	tw.tween_method(_apply_shake.bind(strength), 1.0, 0.0, dur)


func _apply_shake(k: float, strength: float) -> void:
	host.camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k


## Loé sáng toàn màn hình rồi tắt.
func flash(col: Color, alpha: float, dur: float) -> void:
	if _flash_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 15
		add_child(layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.color = Color(1, 1, 1, 0)
		layer.add_child(_flash_rect)
	_flash_rect.color = Color(col, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, dur)


## Khựng hình một thoáng khi trúng đòn mạnh.
func hitstop(dur: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	get_tree().create_timer(dur, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	Engine.time_scale = float(host.debug_speed) if host != null else 1.0
	_hitstop_active = false

func to_dict() -> Dictionary:
	return {"joined": joined}


func from_dict(d: Dictionary) -> void:
	joined = bool(d.get("joined", false))
