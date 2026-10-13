extends RefCounted
class_name NpcProfile
## Hồ sơ NPC thông minh (thiết kế NPC Thông Minh V1.0, bước 1): tính cách 6 đặc điểm + bộ pháp V1 thật.
##  - NPC dùng đúng hệ tu luyện V1 như người chơi: một `Progression` (tiên thiên, mệnh cách, bí tịch, trang bị) sinh tất định từ id.
##  - Bí tịch hợp lệ theo luật: Phổ Truyền ai cũng có thể có; Nội Truyền / Chân Truyền cần cùng tông và đủ cảnh giới;
##    Trấn Phái chỉ trưởng lão (`elder`) của tông đó. Cảnh giới chưa đủ thì không học được.
##  - Tính cách chỉ nghiêng xác suất chọn bí tịch và lối đánh, không quyết định tuyệt đối.

const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
const Progression = preload("res://scripts/v1/progression.gd")

const TRAIT_IDS := ["ambition", "greed", "righteous", "caution", "aggression", "curiosity"]
const TRAIT_NAMES := {"ambition": "Tham vọng", "greed": "Tham lam", "righteous": "Trọng nghĩa", "caution": "Thận trọng", "aggression": "Hiếu chiến", "curiosity": "Hiếu kỳ"}
## [mức thấp, mức cao] dùng khi mô tả bằng lời.
const TRAIT_WORDS := {
	"ambition": ["an phận", "đầy tham vọng"],
	"greed": ["thanh đạm", "tham lam"],
	"righteous": ["trọng lợi hơn nghĩa", "trọng tình nghĩa"],
	"caution": ["liều lĩnh", "thận trọng"],
	"aggression": ["hiền hoà", "hiếu chiến"],
	"curiosity": ["ít tò mò", "hiếu kỳ"],
}
const STYLES := {"approach": "Áp sát", "range": "Giữ khoảng cách", "counter": "Phản công", "stack": "Tích lũy", "burst": "Bạo phát", "survive": "Sinh tồn"}
const STYLE_ORDER := ["approach", "range", "counter", "stack", "burst", "survive"]
const SLOT_NAMES := {"cong": "Công Pháp", "cong2": "Công phụ", "tam": "Tâm Pháp", "than": "Thân Pháp", "weapon": "Vũ khí", "armor": "Giáp", "artifact": "Pháp bảo"}

## Hiệu ứng nào hợp với đặc điểm nào (tăng trọng số chọn bí tịch).
const EFFECT_TRAITS := {
	"dodge_surge": "aggression", "break": "aggression", "blade_bleed": "aggression", "kill_qi": "aggression", "blood_heal": "aggression",
	"dodge_guard": "caution", "guard_counter": "caution", "dodge_heal": "caution", "kim_than_guard": "caution", "kim_than_heal": "caution", "break_heal": "caution", "dodge_slow": "caution",
	"elem_cycle": "curiosity", "cycle_cd": "curiosity", "summon_mark": "curiosity", "soul_qi": "curiosity", "status_qi": "curiosity", "mark_burst": "curiosity", "soul": "curiosity",
}


# ---------------------------------------------------------------- dữ liệu cơ bản
static func seed_of(id: String) -> int:
	return (id.hash() & 0x3fffffff) + 1


## id tông V1 từ id tông cũ trong dữ liệu NPC ("" nếu tán tu).
static func v1_sect(legacy_id: String) -> String:
	if legacy_id == "":
		return ""
	for sid in Data.data().sects:
		if str(Data.data().sects[sid].legacy) == legacy_id or str(sid) == legacy_id:
			return str(sid)
	return ""


## Tông của NPC: `sect` trong dữ liệu, nếu thiếu thì lấy theo nơi ở ("sect_<tông>").
static func sect_of(def: Dictionary) -> String:
	var s := str(def.get("sect", ""))
	if s == "" and str(def.get("home", "")).begins_with("sect_"):
		s = str(def.get("home")).trim_prefix("sect_")
	return v1_sect(s)


## 6 đặc điểm 0–100: lấy từ dữ liệu, thiếu thì sinh tất định theo id (không bao giờ ngẫu nhiên giữa các lần chạy).
static func traits_of(id: String, def: Dictionary) -> Dictionary:
	var out := {}
	var given: Dictionary = def.get("traits", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(id) + 31
	for t in TRAIT_IDS:
		var v := rng.randi_range(20, 80)
		if given.has(t):
			v = int(given[t])
		out[t] = clampi(v, 0, 100)
	return out


## Mô tả tính cách bằng lời: chỉ nêu đặc điểm nổi bật (>= 65 hoặc <= 35).
static func trait_words(traits: Dictionary) -> Array:
	var out: Array = []
	for t in TRAIT_IDS:
		var v := int(traits.get(t, 50))
		if v >= 65:
			out.append(TRAIT_WORDS[t][1])
		elif v <= 35:
			out.append(TRAIT_WORDS[t][0])
	return out


# ---------------------------------------------------------------- luật bí tịch
## Bí tịch / trang bị `d` có hợp lệ để NPC (tông `sect`, cảnh giới `step`, trưởng lão `elder`) sở hữu và học không.
static func legal(d: Dictionary, sect: String, step: int, elder := false) -> bool:
	if step < int(d.get("need", 0)):
		return false
	var book_sect := str(d.get("sect", ""))
	match str(d.get("secrecy", "public")):
		"public":
			return true
		"inner", "true":
			return book_sect != "" and book_sect == sect
		"secret":
			return elder and book_sect == sect
	return false


static func _affinity(d: Dictionary, traits: Dictionary) -> float:
	var w := 0.0
	for e in d.get("effects", []):
		var t: String = str(EFFECT_TRAITS.get(str(e), ""))
		if t != "":
			w += float(traits.get(t, 50)) / 100.0 * 0.8
	if float(d.get("damage", 0.0)) >= 100.0:
		w += float(traits.get("ambition", 50)) / 100.0 * 0.8
	return w


static func _pick(cands: Array, sect: String, traits: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array = []
	var total := 0.0
	for d in cands:
		var w := 1.0 + _affinity(d, traits)
		if sect != "" and str(d.get("sect", "")) == sect:
			w += 6.0 + 0.5 * float(int(d.get("need", 0))) / 6.0   # đệ tử chuộng pháp của tông mình, càng cao cấp càng chuộng
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in cands.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


static func _quality(rng: RandomNumberGenerator, strength: int) -> String:
	var r := rng.randf()
	var huyen := 0.03 + 0.04 * float(strength)
	var linh := 0.2 + 0.07 * float(strength)
	if r < huyen:
		return "huyen"
	if r < huyen + linh:
		return "linh"
	return "thuong"


# ---------------------------------------------------------------- dựng hồ sơ
## Dựng Progression cho NPC: tiên thiên + mệnh cách + Công/Tâm/Thân (+ Công phụ) + vũ khí/giáp/pháp bảo, đều theo luật.
static func build(id: String, def: Dictionary) -> Progression:
	var step := int(def.get("step", 0))
	var strength := int(def.get("strength", 1))
	var sect := sect_of(def)
	var elder := bool(def.get("elder", false)) or str(def.get("role", "")).contains("Sư phụ") or step >= 25
	var traits := traits_of(id, def)
	var seed_v := seed_of(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var p := Progression.new()
	p.origin = Origin.roll(seed_v)
	p.sect = sect
	p.seed_value = seed_v
	p.inner_exam_passed = true
	var used: Array = []
	for slot in ["cong", "tam", "than"]:
		var cands: Array = []
		for d in Data.data().books:
			if str(d.slot) == slot and legal(d, sect, step, elder) and str(d.id) not in used:
				cands.append(d)
		if cands.is_empty():
			continue
		var d: Dictionary = _pick(cands, sect, traits, rng)
		used.append(str(d.id))
		var uid := p.acquire(str(d.id), "npc_start", _quality(rng, strength))
		p.learn(uid, step)
		p.equip(uid)
	# Công phụ: cần cảnh giới đủ cao và một Công Pháp khác hợp lệ.
	if step >= 12 and rng.randf() < 0.3 + 0.1 * float(strength):
		var c2: Array = []
		for d in Data.data().books:
			if str(d.slot) == "cong" and legal(d, sect, step, elder) and str(d.id) not in used:
				c2.append(d)
		if not c2.is_empty():
			var d2: Dictionary = _pick(c2, sect, traits, rng)
			used.append(str(d2.id))
			var uid2 := p.acquire(str(d2.id), "npc_start", _quality(rng, strength))
			p.learn(uid2, step)
			p.equip(uid2, "cong2")
	# Trang bị: vũ khí, giáp luôn có (món tốt nhất hợp lệ, đôi khi chọn món nhẹ hơn); pháp bảo tuỳ cảnh giới.
	for slot in ["weapon", "armor", "artifact"]:
		var gear: Array = []
		for d in Data.data().equipment:
			if str(d.slot) == slot and legal(d, sect, step, elder):
				gear.append(d)
		if gear.is_empty():
			continue
		if slot == "artifact" and rng.randf() > 0.25 + 0.15 * float(strength):
			continue
		var d3: Dictionary = _pick(gear, sect, traits, rng)
		var uid3 := p.acquire(str(d3.id), "npc_start", "thuong")
		p.equip(uid3)
	return p


static func from_dict(d: Dictionary) -> Progression:
	var p := Progression.new()
	p.from_dict(d)
	return p


# ---------------------------------------------------------------- lối đánh và mô tả
## Lối đánh suy ra từ bộ pháp đang trang bị và tính cách (một trong 6 phong cách của thiết kế).
static func style_of(p: Progression, traits: Dictionary) -> String:
	var s := {}
	for k in STYLE_ORDER:
		s[k] = 0.0
	var cong: Dictionary = p.def_for("cong")
	match str(cong.get("shape", "")):
		"cone", "ring":
			s["approach"] += 2.0
		"line", "single":
			s["range"] += 2.0
		"burst", "summon":
			s["range"] += 1.0
			s["burst"] += 1.0
	if float(cong.get("damage", 0.0)) >= 100.0 or float(cong.get("cooldown", 0.0)) >= 3.0:
		s["burst"] += 2.0
	for slot in ["cong", "tam", "than", "cong2"]:
		for e in p.def_for(slot).get("effects", []):
			var eid := str(e)
			if eid in ["dodge_guard", "guard_counter", "kim_than_guard"]:
				s["counter"] += 1.5
			elif eid in ["dodge_heal", "break_heal", "blood_heal", "kim_than_heal"]:
				s["survive"] += 1.2
			elif eid in ["sword_mark", "blade_bleed", "summon_mark", "mark_burst", "elem_cycle"]:
				s["stack"] += 1.2
			elif eid in ["dodge_surge", "break", "kill_qi"]:
				s["approach"] += 0.8
	s["approach"] += float(traits.get("aggression", 50)) / 100.0 * 1.5
	s["counter"] += float(traits.get("caution", 50)) / 100.0 * 1.0
	s["survive"] += float(traits.get("caution", 50)) / 100.0 * 0.8
	s["burst"] += float(traits.get("ambition", 50)) / 100.0 * 0.8
	s["stack"] += float(traits.get("curiosity", 50)) / 100.0 * 0.6
	var best: String = STYLE_ORDER[0]
	for k in STYLE_ORDER:
		if float(s[k]) > float(s[best]):
			best = k
	return best


## Tên bộ pháp đang dùng theo ô.
static func loadout_text(p: Progression) -> Array:
	var out: Array = []
	for slot in ["cong", "cong2", "tam", "than", "weapon", "armor", "artifact"]:
		var item: Dictionary = p.item_for(slot)
		if item.is_empty():
			continue
		var d: Dictionary = Data.definition(str(item.definition))
		var q: String = str(Data.data().qualities[item.quality].name)
		out.append("%s: %s (%s)" % [SLOT_NAMES[slot], str(d.get("name", "?")), q])
	return out
