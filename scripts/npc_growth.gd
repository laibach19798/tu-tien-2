extends RefCounted
class_name NpcGrowth
## NPC tự phát triển (thiết kế NPC Thông Minh V1.0, bước 4): tích tu vi, đột phá, đánh giá và đổi bí tịch / trang bị.
## Mọi thay đổi đều theo luật hệ tu luyện V1 (NpcProfile.legal) và có lý do ghi lại. Không có build tối ưu lập trình sẵn:
## NPC so sánh bí tịch mới với bí tịch đang dùng theo tương tác hiệu ứng, hợp tính cách, cùng tông, và có thể đánh giá sai
## (Ngộ Tính thấp nhiễu nhiều hơn). V1 chưa có tự sáng pháp hay tham ngộ nâng cao.

const MAX_STEP_GAIN := 10     # NPC không vượt quá cảnh giới khởi đầu + số bậc này (tránh chạy vượt người chơi vô hạn)
const CONSIDER_EVERY := 6     # ngày giữa hai lần cân nhắc đổi bí tịch
const CHANGE_COOLDOWN := 10   # ngày tối thiểu giữa hai lần đổi

## Cặp hiệu ứng cộng hưởng (một ở bí tịch này, một ở bí tịch kia).
const SYNERGY := [
	["sword_mark", "mark_burst"], ["status_qi", "sword_mark"], ["blade_bleed", "blood_heal"], ["blade_bleed", "kill_qi"],
	["break", "break_heal"], ["break", "guard_counter"], ["summon_mark", "soul_qi"], ["summon_mark", "summon_mark"],
	["elem_cycle", "fire"], ["elem_cycle", "water"], ["dodge_guard", "guard_counter"], ["dodge_heal", "blood_heal"],
	["soul", "soul_qi"], ["dodge_surge", "kill_qi"], ["cycle_cd", "summon_mark"],
]


static func xp_need(step: int) -> float:
	return 120.0 + 45.0 * float(step)


static func break_cost(step: int) -> int:
	return 30 + 12 * step


## Xác suất đột phá thành công theo Ngộ Tính và độ khó của bậc (mỗi 9 bậc là một cảnh giới lớn, khó hơn).
static func break_chance(insight: float, step: int) -> float:
	var major := 0.12 if (step + 1) % 9 == 0 else 0.0
	return clampf(0.72 + (insight - 50.0) / 250.0 - 0.01 * float(step % 9) - major, 0.35, 0.92)


## Tu vi nhận mỗi ngày theo việc đang làm; Kinh Mạch (meridians) nhanh chậm.
static func xp_gain(act: String, meridians: float) -> float:
	var base: float = float({"cultivate": 11.0, "gather": 3.0, "hunt": 4.0, "event": 4.0, "trade": 1.0, "rest": 1.5}.get(act, 1.0))
	return base * (0.8 + meridians / 250.0)


static func _effects(d: Dictionary) -> Array:
	return d.get("effects", [])


## Số cặp cộng hưởng giữa bí tịch `d` và các bí tịch khác đang dùng.
static func synergy_count(d: Dictionary, others: Array) -> int:
	var n := 0
	var mine := _effects(d)
	for o in others:
		var theirs := _effects(o)
		for pr in SYNERGY:
			if (pr[0] in mine and pr[1] in theirs) or (pr[1] in mine and pr[0] in theirs):
				n += 1
	return n


## Điểm "hợp" của bí tịch `d` đặt vào bộ pháp hiện tại (`others` = các bí tịch đang dùng ở ô khác).
static func fit_score(d: Dictionary, others: Array, traits: Dictionary, sect: String) -> float:
	var s := 0.5
	s += NpcProfile._affinity(d, traits)
	s += 0.7 * float(synergy_count(d, others))
	if sect != "" and str(d.get("sect", "")) == sect:
		s += 0.5
	if str(d.get("slot", "")) in ["cong", "cong2"]:
		s += minf(float(d.get("damage", 0.0)) / 150.0, 1.0) * 0.6
	s += float(d.get("need", 0)) / 12.0 * 0.3
	return s


## Cân nhắc đổi sang `cand` ở ô `slot`. Trả {gain, old, new}: gain > 0 nghĩa là bí tịch mới hợp hơn (có nhiễu theo Ngộ Tính).
static func evaluate(prog: RefCounted, slot: String, cand: Dictionary, traits: Dictionary, sect: String, insight: float, rng: RandomNumberGenerator) -> Dictionary:
	var others: Array = []
	for s in ["cong", "cong2", "tam", "than"]:
		if s != slot:
			var od: Dictionary = prog.def_for(s)
			if not od.is_empty():
				others.append(od)
	var cur: Dictionary = prog.def_for(slot)
	var old_s := fit_score(cur, others, traits, sect) if not cur.is_empty() else 0.0
	var new_s := fit_score(cand, others, traits, sect)
	var noise := (rng.randf() - 0.5) * (80.0 - insight) / 60.0
	return {"gain": new_s - old_s + noise, "old": old_s, "new": new_s}


## Lý do vì sao hợp: nêu cặp cộng hưởng hoặc đặc điểm tính cách đóng góp lớn nhất.
static func why_text(cand: Dictionary, others: Array, traits: Dictionary) -> String:
	var parts: Array = []
	var mine := _effects(cand)
	for o in others:
		for pr in SYNERGY:
			var theirs := _effects(o)
			if (pr[0] in mine and pr[1] in theirs) or (pr[1] in mine and pr[0] in theirs):
				parts.append("cộng hưởng với %s" % str(o.get("name", "?")))
				break
	var best := ""
	var best_v := 0.0
	for e in mine:
		var t := str(NpcProfile.EFFECT_TRAITS.get(str(e), ""))
		if t != "" and float(traits.get(t, 50)) > best_v and float(traits.get(t, 50)) >= 60.0:
			best = t
			best_v = float(traits.get(t, 50))
	if best != "":
		parts.append("hợp tính %s" % str(NpcProfile.TRAIT_WORDS[best][1]))
	if parts.is_empty():
		parts.append("mạnh hơn bí tịch cũ")
	return ", ".join(parts)
