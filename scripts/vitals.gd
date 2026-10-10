extends Node
class_name Vitals
## Khí huyết của nhân vật: nhận sát thương, hồi dần khi không bị đánh, có thời gian bất tử ngắn sau mỗi đòn.

signal changed
signal hurt(dmg: float, from: Vector2)
signal died

const INVULN := 0.7
const REGEN_DELAY := 5.0

var hp := 100.0
var max_hp := 100.0
var invuln := 0.0
var god := false   # menu thử nghiệm: bất tử
var _since_hit := 99.0
var cult: Cultivation


func setup(p_cult: Cultivation) -> void:
	cult = p_cult
	max_hp = _max_for(cult) * (1.0 + hp_bonus)
	hp = max_hp
	cult.changed.connect(_on_cult)
	changed.emit()


static func _max_for(c: Cultivation) -> float:
	return 100.0 + 24.0 * c.step_index()


var hp_bonus := 0.0   # thưởng bộ trang phục: khí huyết tối đa nhân (1 + hp_bonus)


func set_hp_bonus(b: float) -> void:
	if is_equal_approx(b, hp_bonus):
		return
	hp_bonus = b
	if cult != null:
		_on_cult()


func _on_cult() -> void:
	var m := _max_for(cult) * (1.0 + hp_bonus)
	if m != max_hp:
		hp += m - max_hp   # lên cảnh giới thì nhận thêm khí huyết
		max_hp = m
		hp = clampf(hp, 1.0, max_hp)
		changed.emit()


func alive() -> bool:
	return hp > 0.0


func take(dmg: float, from: Vector2) -> bool:
	if hp <= 0.0 or invuln > 0.0 or god:
		return false
	hp = maxf(hp - dmg, 0.0)
	invuln = INVULN
	_since_hit = 0.0
	hurt.emit(dmg, from)
	changed.emit()
	if hp <= 0.0:
		died.emit()
	return true


func heal(n: float) -> void:
	hp = minf(max_hp, hp + n)
	changed.emit()


func revive(fraction := 0.5) -> void:
	hp = max_hp * fraction
	invuln = 2.0
	_since_hit = 0.0
	changed.emit()


func _process(delta: float) -> void:
	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)
	_since_hit += delta
	if hp > 0.0 and hp < max_hp and _since_hit > REGEN_DELAY:
		hp = minf(max_hp, hp + max_hp * 0.02 * delta)
		changed.emit()


func to_dict() -> Dictionary:
	return {"hp": hp}


func from_dict(d: Dictionary) -> void:
	hp = clampf(float(d.get("hp", max_hp)), 1.0, max_hp)
	changed.emit()
