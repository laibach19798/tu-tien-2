extends Node
class_name Breakthrough
## Đột phá cảnh giới thành chuỗi quyết định (độ khó địa ngục): chuẩn bị trợ lực → thử thách → kết quả.
##   Luyện Khí → Trúc Cơ: tâm ma (3 câu hỏi đạo tâm, trả lời sai mất khí huyết).
##   Trúc Cơ trở lên: thiên kiếp (sét giáng có dấu báo trước; tránh bằng Thân Pháp, trụ hết thời gian).
## Tỉ lệ cuối = Hell.breakthrough_chance(cảnh giới) + trợ lực + thử thách. Chết trong thử thách = thất bại.

signal finished(success: bool)

const AIDS := [
	{"item": "dan_truc_co", "name": "Trúc Cơ Linh Đan", "bonus": 0.15, "realms": [1]},
	{"item": "dan_ho_the", "name": "Hộ Thể Đan (hộ mạch)", "bonus": 0.05, "realms": [1, 2, 3, 4]},
	{"item": "dan_kiem_y", "name": "Kiếm Ý Đan (ổn định đạo tâm)", "bonus": 0.05, "realms": [1, 2, 3, 4]},
	{"item": "linh_tuyen_binh", "name": "Bình linh tuyền", "bonus": 0.04, "realms": [1, 2, 3, 4]},
]

## Mỗi câu: "q" mô tả cảnh tượng; "good" là lựa chọn giữ vững đạo tâm, các lựa chọn còn lại sai.
const DEMONS := [
	{"q": "Ảo ảnh người thân đã khuất van ngươi dừng lại: \"Đừng đột phá nữa, về với ta.\"", "good": "Nhắm mắt, giữ vững đạo tâm", "bad": ["Đáp lời, hỏi họ muốn gì", "Chạy khỏi tĩnh thất"]},
	{"q": "Một thanh âm hứa cho ngươi tu vi gấp mười, chỉ cần quên đi người đã từng giúp ngươi.", "good": "Từ chối, nhớ ơn người", "bad": ["Hỏi giá phải trả", "Im lặng suy nghĩ"]},
	{"q": "Hiện ra chính ngươi lúc còn yếu đuối, cười nhạo: \"Ngươi chỉ là kẻ may mắn.\"", "good": "Chấp nhận, rồi bước tiếp", "bad": ["Giận dữ xuất kiếm", "Phủ nhận mọi điều"]},
	{"q": "Ngọn lửa tâm ma thiêu đốt kinh mạch, mỗi hơi thở đều đau.", "good": "Thở đều, để lửa đi qua", "bad": ["Vận hết linh khí chống lại", "Ngừng tu luyện"]},
	{"q": "Một đồng môn ngã xuống ngay trước mặt, cầu ngươi cứu thay vì tiếp tục.", "good": "Đỡ họ dậy rồi quay lại tĩnh tọa", "bad": ["Bỏ mặc, tiếp tục đột phá", "Ở lại, bỏ dở đột phá"]},
	{"q": "Bóng tối thì thầm: \"Đạo là gì? Mọi thứ đều vô nghĩa.\"", "good": "Hỏi lại chính lòng mình", "bad": ["Tin lời bóng tối", "Cố quên câu hỏi"]},
]
const DEMON_ROUNDS := 3
const DEMON_GOOD := 0.06
const DEMON_BAD := -0.06
const DEMON_BAD_HP := 0.15

var main: Node
var active := false
var _aid_bonus := 0.0
var _trial_bonus := 0.0
var _rounds_left := 0
var _demons: Array = []
var _trib_left := 0.0
var _next_wave := 0.0
var _trib_total := 1.0
var _trib_realm := 1
var _rng := RandomNumberGenerator.new()


func setup(p_main: Node) -> void:
	main = p_main
	_rng.randomize()
	main.vitals.died.connect(_on_died)


func start() -> void:
	var cult: Cultivation = main.cult
	if active:
		return
	if not cult.ready_breakthrough or cult.realm >= Cultivation.REALMS.size() - 1:
		cult.try_breakthrough()   # phát đúng thông báo sẵn có (chưa đủ tu vi / cảnh giới cao nhất)
		return
	var base := clampf(Hell.breakthrough_chance(cult.realm) + cult.breakthrough_bonus, 0.03, 0.95)
	var trial := "tâm ma" if cult.realm == 1 else "thiên kiếp"
	var opts: Array = [{"text": "Đột phá tay không (nền %d%%)" % roundi(base * 100.0), "call": _prepared.bind(0.0, "")}]
	for a in AIDS:
		if cult.realm in a["realms"] and main.inv.count(str(a["item"])) > 0:
			opts.append({"text": "Dùng %s (+%d%%, còn %d)" % [a["name"], roundi(float(a["bonus"]) * 100.0), main.inv.count(str(a["item"]))],
				"call": _prepared.bind(float(a["bonus"]), str(a["item"]))})
	opts.append({"text": "Chưa sẵn sàng", "call": Callable()})
	var warn := "Cảnh giới tiếp theo cần vượt qua %s. Thất bại: tu vi chỉ còn %d%% và kinh mạch trọng thương %d phút." % [trial, roundi(Hell.FAIL_KEEP * 100.0), int(Hell.INJURY_SECONDS / 60.0)]
	main.dialogue.choose("Đột phá %s" % Cultivation.REALMS[cult.realm + 1], warn, opts)


func _prepared(bonus: float, item: String) -> void:
	if item != "":
		main.inv.remove(item)
	_aid_bonus = bonus
	_trial_bonus = 0.0
	active = true
	main.meditating = false
	if main.cult.realm == 1:
		_demons = DEMONS.duplicate()
		_demons.shuffle()
		_rounds_left = DEMON_ROUNDS
		_ask_demon()
	else:
		_begin_tribulation()


# ---------------------------------------------------------------- tâm ma
func _ask_demon() -> void:
	if _rounds_left <= 0:
		_resolve()
		return
	var d: Dictionary = _demons[_rounds_left % _demons.size()]
	var opts: Array = []
	opts.append({"text": str(d["good"]), "call": _answer.bind(true)})
	for b in d["bad"]:
		opts.append({"text": str(b), "call": _answer.bind(false)})
	opts.shuffle()
	main.dialogue.choose("Tâm ma (%d/%d)" % [DEMON_ROUNDS - _rounds_left + 1, DEMON_ROUNDS], str(d["q"]), opts)


func _answer(good: bool) -> void:
	_rounds_left -= 1
	if good:
		_trial_bonus += DEMON_GOOD
		main.hud.toast("Đạo tâm vững vàng.")
	else:
		_trial_bonus += DEMON_BAD
		main.vitals.hp = maxf(1.0, main.vitals.hp - main.vitals.max_hp * DEMON_BAD_HP)
		main.vitals.changed.emit()
		main.hud.toast("Tâm ma xâm nhập, khí huyết tổn hao!")
	_ask_demon()


# ---------------------------------------------------------------- thiên kiếp
func _begin_tribulation() -> void:
	_trib_realm = main.cult.realm
	_trib_total = Hell.tribulation_seconds(_trib_realm)
	_trib_left = _trib_total
	_next_wave = 2.5   # vài giây đầu để người chơi định thần
	main.hud.toast("THIÊN KIẾP! Tránh các vòng sét báo trước, trụ %d giây." % int(_trib_total))
	Sfx.play("qi")


func _process(delta: float) -> void:
	if not active or _trib_left <= 0.0 or main._dead:
		return
	_trib_left -= delta
	_next_wave -= delta
	if _next_wave <= 0.0:
		_next_wave = maxf(0.7, 1.4 - 0.1 * float(_trib_realm))
		_wave()
	if _trib_left <= 0.0:
		_trib_left = 0.0
		var hp_frac: float = clampf(main.vitals.hp / maxf(1.0, main.vitals.max_hp), 0.0, 1.0)
		_trial_bonus += 0.10 * hp_frac   # thưởng cho người trụ vững với nhiều khí huyết
		_resolve()


## Mỗi nhịp: một tia nhắm thẳng vào người chơi, cộng thêm vài tia rải quanh.
func _wave() -> void:
	var count := 1 + _trib_realm / 2
	var dmg := Hell.tribulation_damage(_trib_realm)
	for i in count + 1:
		var strike := TribulationStrike.new()
		strike.main = main
		strike.damage = dmg
		var jitter := Vector2.ZERO if i == 0 else Vector2(_rng.randf_range(-170.0, 170.0), _rng.randf_range(-110.0, 110.0))
		strike.position = main.player.position + jitter
		main.world.add_child(strike)


# ---------------------------------------------------------------- kết quả
func _resolve() -> void:
	active = false
	_trib_left = 0.0
	var extra := _aid_bonus + _trial_bonus
	var realm_before: int = main.cult.realm
	main.cult.try_breakthrough(extra)
	finished.emit(main.cult.realm > realm_before)


## Chết trong lúc thử thách (thiên kiếp) = đột phá thất bại thẳng tay.
func _on_died() -> void:
	if not active:
		return
	active = false
	_trib_left = 0.0
	main.cult.fail_breakthrough()
	finished.emit(false)
