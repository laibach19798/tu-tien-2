extends Node
class_name SectWar
## Chiến sự Tiểu Thế Giới: 5 tông môn tranh 12 địa bàn. Các tông môn AI tự giao tranh theo thời gian; người chơi (Kiếm Tông)
## chiếm địa bàn bằng cách hạ lính canh rồi cắm cờ, và phải giữ địa bàn khi bị tập kích. Trạng thái nằm ở đây (map chỉ là hình ảnh),
## nên vẫn chạy khi người chơi ở map khác và được lưu cùng file lưu.

signal changed
signal message(text: String)
signal income(merit: int, stones: int)
signal attack_started(tid: String)        # một địa bàn của người chơi bị tập kích (cần dựng quân xâm lược nếu đang ở map)
signal territory_changed(tid: String)     # đổi chủ (cần cập nhật cờ, lính canh nếu đang ở map)
signal victory

const PLAYER := "kiem_tong"
const ATTACK_INTERVAL := 90.0     # giây giữa hai đợt giao tranh
const INCOME_INTERVAL := 60.0
const DEFEND_TIME := 120.0        # thời gian để đánh lui quân xâm lược
const WIN_COUNT := 8              # nắm giữ chừng này địa bàn là bá chủ

# hq: căn cứ (không chiếm được); outfit: trang phục đệ tử / trưởng lão
const SECTS := {
	"kiem_tong": {
		"name": "Kiếm Tông", "color": Color(0.40, 0.78, 1.0), "hq": Vector2(560, 2560), "theme": "meadow",
		"disciple": {"hair": "hair_topknot_black", "clothes": "outfit_trang", "shoes": "shoes_cloth_white", "head": "head_band_white"},
		"elder": {"hair": "hair_long_silver", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black", "head": "head_crown_gold"},
	},
	"xich_viem": {
		"name": "Xích Viêm Tông", "color": Color(1.0, 0.45, 0.25), "hq": Vector2(560, 700), "theme": "lava",
		"disciple": {"hair": "hair_topknot_black", "clothes": "outfit_do", "shoes": "shoes_boot_black", "head": "head_band_red"},
		"elder": {"hair": "hair_topknot_silver", "clothes": "outfit_do", "shoes": "shoes_boot_black", "head": "head_crown_gold"},
	},
	"han_bang": {
		"name": "Hàn Băng Cung", "color": Color(0.65, 0.9, 1.0), "hq": Vector2(2240, 380), "theme": "snow",
		"disciple": {"hair": "hair_long_silver", "clothes": "outfit_thanh", "shoes": "shoes_cloth_white", "head": "head_pin_jade"},
		"elder": {"hair": "hair_long_silver", "clothes": "outfit_thanh", "shoes": "shoes_cloth_white", "head": "head_halo"},
	},
	"doc_mon": {
		"name": "Độc Môn", "color": Color(0.55, 0.9, 0.35), "hq": Vector2(3900, 760), "theme": "swamp",
		"disciple": {"hair": "hair_ponytail_black", "clothes": "outfit_luc", "shoes": "shoes_boot_black", "head": "head_mask_fox"},
		"elder": {"hair": "hair_ponytail_black", "clothes": "outfit_luc", "shoes": "shoes_boot_black", "head": "head_crown_gold"},
	},
	"huyen_minh": {
		"name": "Huyền Minh Giáo", "color": Color(0.75, 0.5, 1.0), "hq": Vector2(3900, 2560), "theme": "cave",
		"disciple": {"hair": "hair_topknot_black", "clothes": "outfit_tim", "shoes": "shoes_boot_black", "head": "head_band_red"},
		"elder": {"hair": "hair_topknot_black", "clothes": "tien_bao_tu_dien", "shoes": "shoes_boot_black", "head": "head_crown_gold"},
	},
}

# type: loại địa bàn; income: nộp mỗi INCOME_INTERVAL giây khi thuộc về Kiếm Tông; guards: lính canh khi vô chủ
const TERRITORIES := [
	{"id": "t_linh_tuyen", "name": "Linh Tuyền Nam Sơn", "pos": Vector2(1500, 2450), "owner": "kiem_tong", "theme": "meadow", "type": "Suối linh", "income": {"merit": 2, "stones": 20}},
	{"id": "t_truc_lam", "name": "Trúc Lâm Biên Giới", "pos": Vector2(1050, 1650), "owner": "kiem_tong", "theme": "meadow", "type": "Rừng trúc", "income": {"merit": 2, "stones": 25}},
	{"id": "t_hoa_tinh", "name": "Mỏ Hỏa Tinh", "pos": Vector2(1350, 900), "owner": "xich_viem", "theme": "lava", "type": "Mỏ khoáng", "income": {"merit": 3, "stones": 40}},
	{"id": "t_dia_hoa", "name": "Lò Địa Hỏa", "pos": Vector2(1250, 1400), "owner": "xich_viem", "theme": "lava", "type": "Hỏa mạch", "income": {"merit": 3, "stones": 30}},
	{"id": "t_bang_tuyen", "name": "Băng Tuyền", "pos": Vector2(1700, 520), "owner": "han_bang", "theme": "snow", "type": "Suối băng", "income": {"merit": 3, "stones": 30}},
	{"id": "t_tuyet_dinh", "name": "Tuyết Đỉnh", "pos": Vector2(2800, 600), "owner": "han_bang", "theme": "snow", "type": "Đỉnh núi", "income": {"merit": 3, "stones": 35}},
	{"id": "t_dam_doc", "name": "Đầm Độc", "pos": Vector2(3300, 1300), "owner": "doc_mon", "theme": "swamp", "type": "Đầm lầy", "income": {"merit": 3, "stones": 30}},
	{"id": "t_doc_thao", "name": "Vườn Độc Thảo", "pos": Vector2(3600, 1850), "owner": "doc_mon", "theme": "swamp", "type": "Vườn thuốc", "income": {"merit": 4, "stones": 30}},
	{"id": "t_huyet_tri", "name": "Huyết Trì", "pos": Vector2(3100, 2400), "owner": "huyen_minh", "theme": "cave", "type": "Ao máu", "income": {"merit": 3, "stones": 40}},
	{"id": "t_am_phu", "name": "Âm Phủ Động", "pos": Vector2(3500, 2950), "owner": "huyen_minh", "theme": "cave", "type": "Hang động", "income": {"merit": 4, "stones": 35}},
	{"id": "t_thien_mach", "name": "Thiên Mạch", "pos": Vector2(2240, 1600), "owner": "", "theme": "cave", "type": "Linh mạch lớn", "income": {"merit": 6, "stones": 60},
		"guards": [["goblin_elite", 3], ["wolf_dark", 3]]},
	{"id": "t_co_chien", "name": "Cổ Chiến Trường", "pos": Vector2(2200, 2600), "owner": "", "theme": "meadow", "type": "Chiến trường cổ", "income": {"merit": 4, "stones": 45},
		"guards": [["goblin", 4], ["wolf", 3]]},
]

var owners := {}            # tid -> id tông ("" = vô chủ)
var under_attack := {}      # tid -> {by, left}
var log: Array = []         # nhật ký chiến sự (mới nhất ở cuối)
var won := false
var _t_attack := ATTACK_INTERVAL * 0.6
var _t_income := INCOME_INTERVAL
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	owners = {}
	for t in TERRITORIES:
		owners[t["id"]] = t["owner"]
	under_attack = {}
	log = []
	won = false


static func territory(tid: String) -> Dictionary:
	for t in TERRITORIES:
		if t["id"] == tid:
			return t
	return {}


static func sect_name(id: String) -> String:
	return str((SECTS.get(id, {}) as Dictionary).get("name", "Vô chủ"))


static func sect_color(id: String) -> Color:
	return (SECTS.get(id, {}) as Dictionary).get("color", Color(0.7, 0.7, 0.7))


func owner_of(tid: String) -> String:
	return str(owners.get(tid, ""))


func count(sect: String) -> int:
	var n := 0
	for tid in owners:
		if owners[tid] == sect:
			n += 1
	return n


func owned_by_player() -> Array:
	var out: Array = []
	for t in TERRITORIES:
		if owners[t["id"]] == PLAYER:
			out.append(t["id"])
	return out


## Sức mạnh một tông: nền + theo số địa bàn đang giữ.
func power(sect: String) -> float:
	return 24.0 + 12.0 * count(sect)


func _log(text: String) -> void:
	log.append(text)
	if log.size() > 24:
		log.pop_front()
	message.emit(text)
	changed.emit()


func _process(delta: float) -> void:
	_t_attack -= delta
	_t_income -= delta
	for tid in under_attack.keys():
		under_attack[tid]["left"] = float(under_attack[tid]["left"]) - delta
		if float(under_attack[tid]["left"]) <= 0.0:
			_lose(tid)
	if _t_attack <= 0.0:
		_t_attack = ATTACK_INTERVAL * rng.randf_range(0.8, 1.2)
		_ai_attack()
	if _t_income <= 0.0:
		_t_income = INCOME_INTERVAL
		_pay_income()


func _pay_income() -> void:
	var m := 0
	var s := 0
	for tid in owned_by_player():
		var inc: Dictionary = territory(tid).get("income", {})
		m += int(inc.get("merit", 0))
		s += int(inc.get("stones", 0))
	if m > 0 or s > 0:
		income.emit(m, s)


## Một tông AI tấn công một địa bàn lân cận.
func _ai_attack() -> void:
	var sects := SECTS.keys()
	sects.erase(PLAYER)
	var att: String = sects[rng.randi() % sects.size()]
	var targets: Array = []
	for t in TERRITORIES:
		var tid: String = t["id"]
		if owners[tid] == att or under_attack.has(tid):
			continue
		var near := (SECTS[att]["hq"] as Vector2).distance_to(t["pos"]) < 1500.0
		for t2 in TERRITORIES:
			if owners[t2["id"]] == att and (t2["pos"] as Vector2).distance_to(t["pos"]) < 1500.0:
				near = true
		if near:
			# địa bàn của Kiếm Tông bị nhắm nhiều hơn một chút để người chơi luôn có việc làm
			targets.append(t)
			if owners[tid] == PLAYER:
				targets.append(t)
	if targets.is_empty():
		return
	var tgt: Dictionary = targets[rng.randi() % targets.size()]
	var tid: String = tgt["id"]
	var def := owner_of(tid)
	if def == PLAYER:
		under_attack[tid] = {"by": att, "left": DEFEND_TIME}
		_log("%s tập kích %s! Về phòng thủ trong %d giây." % [sect_name(att), tgt["name"], int(DEFEND_TIME)])
		attack_started.emit(tid)
		return
	var a := power(att) * rng.randf_range(0.6, 1.4)
	var d := (power(def) if def != "" else 20.0) * rng.randf_range(0.6, 1.4)
	if a > d:
		owners[tid] = att
		_log("%s chiếm %s từ %s." % [sect_name(att), tgt["name"], sect_name(def) if def != "" else "vô chủ"])
		territory_changed.emit(tid)
	else:
		_log("%s tấn công %s nhưng bị %s đẩy lui." % [sect_name(att), tgt["name"], sect_name(def) if def != "" else "lính canh"])
	changed.emit()


func _lose(tid: String) -> void:
	var by: String = under_attack[tid]["by"]
	under_attack.erase(tid)
	if owners[tid] != PLAYER:
		return
	owners[tid] = by
	_log("Mất %s vào tay %s!" % [str(territory(tid)["name"]), sect_name(by)])
	territory_changed.emit(tid)


## Người chơi đánh lui quân xâm lược.
func defended(tid: String) -> void:
	if not under_attack.has(tid):
		return
	under_attack.erase(tid)
	_log("Đã bảo vệ %s, đánh lui quân xâm lược." % str(territory(tid)["name"]))
	changed.emit()


## Người chơi cắm cờ chiếm địa bàn. Trả false nếu đã là của Kiếm Tông.
func claim(tid: String) -> bool:
	if owners.get(tid, "") == PLAYER:
		return false
	var prev := owner_of(tid)
	owners[tid] = PLAYER
	under_attack.erase(tid)
	_log("Kiếm Tông chiếm %s từ %s!" % [str(territory(tid)["name"]), sect_name(prev) if prev != "" else "vô chủ"])
	territory_changed.emit(tid)
	if not won and count(PLAYER) >= WIN_COUNT:
		won = true
		victory.emit()
	return true


func to_dict() -> Dictionary:
	return {"owners": owners, "under": under_attack, "log": log, "won": won, "ta": _t_attack, "ti": _t_income}


func from_dict(d: Dictionary) -> void:
	reset()
	var o: Dictionary = d.get("owners", {})
	for tid in o:
		if owners.has(tid) and (str(o[tid]) == "" or SECTS.has(str(o[tid]))):
			owners[tid] = str(o[tid])
	var u: Dictionary = d.get("under", {})
	for tid in u:
		if owners.has(tid) and owners[tid] == PLAYER:
			under_attack[tid] = {"by": str(u[tid].get("by", "")), "left": float(u[tid].get("left", DEFEND_TIME))}
	log = (d.get("log", []) as Array).duplicate()
	won = bool(d.get("won", false))
	_t_attack = float(d.get("ta", ATTACK_INTERVAL * 0.6))
	_t_income = float(d.get("ti", INCOME_INTERVAL))
	changed.emit()
