extends RefCounted
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
signal changed

var origin: Dictionary = {}
var sect := ""
var reputation := 0
var merit := 0
var legacy_rank_floor := 0
var inner_exam_passed := true
var relations: Dictionary = {}
var npc_relations: Dictionary = {}
var wanted: Dictionary = {}
var instances: Dictionary = {}
var equipped := {"cong":"", "cong2":"", "tam":"", "than":"", "weapon":"", "armor":"", "artifact":""}
var primary := "cong"
var sequence := 0
var seed_value := 1101
var research: Dictionary = {}
var claimed: Dictionary = {}
var ruin_kills := 0
var legacy: Dictionary = {}

func acquire(definition_id: String, source: String, quality := "thuong", fragment := false) -> String:
	var d = Data.definition(definition_id)
	if d.is_empty() or not Data.data().qualities.has(quality):
		return ""
	sequence += 1
	var uid := "v1_%d_%d" % [seed_value, sequence]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + sequence * 7919
	var affixes: Array = []
	var pool: Array = d.get("affix_pool", [])
	for i in int(Data.data().qualities[quality].affixes):
		affixes.append(Data.weighted_affix(rng, affixes, pool))
	instances[uid] = {"uid":uid,"definition":definition_id,"quality":quality,"secrecy":d.get("secrecy", "public"),"affixes":affixes,"hidden_affix":Data.weighted_affix(rng, affixes, pool),"source":source,"fragment":fragment,"learned":d.slot in ["weapon","armor","artifact"],"refinement":0,"seed":rng.seed,"owner":"player","research_count":0}
	if source == "seized":
		var faction = d.get("sect", "")
		wanted[faction] = int(wanted.get(faction, 0)) + 1
		relations[faction] = "hostile"
	changed.emit()
	return uid

## step: step_index() hiện tại của người chơi; mặc định không kiểm tra cảnh giới (bản lưu cũ, test).
func learn(uid: String, step := 9999) -> bool:
	if not instances.has(uid):
		return false
	var item: Dictionary = instances[uid]
	var d = Data.definition(item.definition)
	if item.fragment or step < int(d.get("need", 0)):
		return false
	item.learned = true
	changed.emit()
	return true

## into: ô đích; mặc định là ô đúng loại. Công Pháp có thể vào "cong2" (Công phụ); một bản không đứng ở cả hai ô.
func equip(uid: String, into := "") -> bool:
	if not instances.has(uid) or not bool(instances[uid].learned):
		return false
	var d = Data.definition(instances[uid].definition)
	var slot: String = str(d.slot)
	if into == "cong2" and slot == "cong":
		slot = "cong2"
	if slot == "cong" or slot == "cong2":
		for s in ["cong", "cong2"]:
			if s != slot and str(equipped.get(s, "")) == uid:
				equipped[s] = ""
	equipped[slot] = uid
	changed.emit()
	return true

func item_for(slot: String) -> Dictionary:
	return instances.get(equipped.get(slot, ""), {})

func def_for(slot: String) -> Dictionary:
	return Data.definition(str(item_for(slot).get("definition", "")))

func rank() -> int:
	if not inner_exam_passed:
		return legacy_rank_floor
	var result := 0
	var thresholds: Array = Data.data().balance.rank_thresholds
	for i in thresholds.size():
		if merit >= int(thresholds[i]):
			result = i
	return maxi(legacy_rank_floor, result)

func join(id: String) -> bool:
	if not sect.is_empty() or not Data.data().sects.has(id):
		return false
	sect = id
	for d in Data.data().books:
		if d.sect == id and d.secrecy == "public" and equipped[d.slot] == "":
			var uid = acquire(d.id, "sect_starter")
			learn(uid)
			equip(uid)
	changed.emit()
	return true

func bootstrap(old_save: Dictionary = {}) -> void:
	if not origin.is_empty():
		return
	origin = Origin.sample()
	origin.confirmed = false
	legacy = {"innate":old_save.get("innate", {}).duplicate(true),"school":old_save.get("school", {}).duplicate(true),"noi_cong":old_save.get("noicong", {}).duplicate(true)} if not old_save.is_empty() else {}
	if not old_save.is_empty():
		# Migration déterministe: giữ bản gốc, không tung lại tư chất mỗi lần tải.
		origin = Origin.migrate(old_save.get("innate",{}))
		origin.confirmed = true
		var total := int(old_save.get("inv", {}).get("merit_total", 0))
		var old_rank := 3 if total >= 1000 else (2 if total >= 400 else (1 if total >= 100 else 0))
		legacy_rank_floor = [0,1,3,4][mini(old_rank, 3)]
		join("kiem_tong")
		# Giữ quyền đã học; chuyển về định nghĩa V1, lưu toàn bộ công thức gốc trong legacy.
		for old_sect in old_save.get("inv",{}).get("manuals",[]):
			for sect_id in Data.data().sects:
				if Data.data().sects[sect_id].legacy == old_sect:
					for book in Data.data().books:
						if book.sect == sect_id:
							var uid = acquire(book.id,"legacy")
							learn(uid)
		var old_internal: String = str(old_save.get("noicong",{}).get("id",""))
		var migrated: String = str(Data.data().get("legacy_internal",{}).get(old_internal,""))
		if migrated != "":
			var uid = acquire(migrated,"legacy")
			learn(uid)
			equip(uid)
	for id in ["iron_sword", "cloth_robe", "qi_pearl"]:
		var uid = acquire(id, "starter")
		equip(uid)

func study_cost() -> int:
	return maxi(1, roundi(Data.balance("study_stones") / (1.0 + (float(origin.attributes.insight) - 25.0) * Data.balance("research_scale"))))

func study_time() -> float:
	return Data.balance("study_seconds") / (1.0 + (float(origin.attributes.insight) - 25.0) * Data.balance("research_scale"))

func begin_study(uid: String) -> bool:
	if not research.is_empty() or not instances.has(uid):
		return false
	research = {"uid":uid,"remaining":study_time()}
	changed.emit()
	return true

func advance_study(delta: float) -> bool:
	if research.is_empty():
		return false
	research.remaining = maxf(0.0, float(research.remaining) - delta)
	if research.remaining > 0.0:
		return false
	var item: Dictionary = instances[research.uid]
	if item.fragment:
		item.fragment = false
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(item.seed) + int(item.research_count) + 1
		var index := rng.randi_range(0, item.affixes.size() - 1)
		item.affixes[index] = item.hidden_affix
		item.hidden_affix = Data.weighted_affix(rng, item.affixes, Data.definition(item.definition).get("affix_pool", []))
	item.research_count = int(item.research_count) + 1
	research = {}
	changed.emit()
	return true

## Tầng ngộ theo số vòng mini game vượt qua (0-5): fail < 2 · ok 2-3 · good 4 · perfect 5.
static func study_tier(cleared: int) -> String:
	if cleared < 2:
		return "fail"
	if cleared < 4:
		return "ok"
	return "good" if cleared == 4 else "perfect"


## Ảnh hưởng của Ngộ Tính (tư chất) lên mini game Ngộ đạo. Tất cả đều tăng đơn điệu theo Ngộ Tính.
##   peeks: số lần xem lại chuỗi · mistakes: số lần bấm sai được tha · len_delta: chênh lệch độ dài chuỗi (thấp +1, rất cao -1)
##   flash: giây mỗi ký hiệu sáng (cao thì thấy rõ hơn) · hint_delay: giây nghĩ lâu thì ký hiệu đúng thoáng sáng (0 = không có)
##   reveal_good: tầng "ngộ sâu" cũng thấy trước dòng tiềm ẩn.
static func study_params(insight: float) -> Dictionary:
	return {
		"peeks": clampi(int((insight - 30.0) / 12.0), 0, 3),
		"mistakes": clampi(int((insight - 45.0) / 12.0), 0, 2),
		"len_delta": 1 if insight < 35.0 else (-1 if insight >= 65.0 else 0),
		"flash": clampf(0.30 + insight * 0.003, 0.32, 0.5),
		"hint_delay": 0.0 if insight < 50.0 else maxf(4.0, 9.0 - (insight - 50.0) * 0.25),
		"reveal_good": insight >= 60.0,
	}


## Hạt giống riêng mỗi lượt tham ngộ: cùng bản + cùng số lần thử thì cùng chuỗi (không lưu/tải để xin chuỗi dễ hơn).
func study_seed(uid: String) -> int:
	var item: Dictionary = instances[uid]
	return int(item.seed) + int(item.get("tries", 0)) * 7919 + int(item.research_count) * 104729


## Áp kết quả mini game Ngộ đạo. replace: -1 ngẫu nhiên, -2 giữ nguyên (chỉ tầng đốn ngộ), >=0 chỉ số dòng phụ bị thay.
## Trả về {ok, tier, repaired?, kept?, old?, new?}.
func resolve_study(uid: String, tier: String, replace := -1) -> Dictionary:
	if not instances.has(uid):
		return {"ok": false, "tier": tier}
	var item: Dictionary = instances[uid]
	item.tries = int(item.get("tries", 0)) + 1
	if tier == "fail":
		changed.emit()
		return {"ok": false, "tier": tier}
	if item.fragment:
		item.fragment = false
		item.research_count = int(item.research_count) + 1
		changed.emit()
		return {"ok": true, "tier": tier, "repaired": true}
	if replace == -2 and tier == "perfect":
		changed.emit()
		return {"ok": true, "tier": tier, "kept": true}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(item.seed) + int(item.research_count) + 1
	var index := rng.randi_range(0, item.affixes.size() - 1)
	if tier in ["good", "perfect"] and replace >= 0 and replace < item.affixes.size():
		index = replace
	var old: String = item.affixes[index]
	item.affixes[index] = item.hidden_affix
	var added: String = item.hidden_affix
	item.hidden_affix = Data.weighted_affix(rng, item.affixes, Data.definition(item.definition).get("affix_pool", []))
	item.research_count = int(item.research_count) + 1
	changed.emit()
	return {"ok": true, "tier": tier, "old": old, "new": added}


## Đổi ngẫu nhiên một dòng phụ của bản đã học ngay (không tốn thời gian/linh thạch): dùng cho cơ duyên ngộ đạo.
func reroll_one(uid: String) -> bool:
	if not instances.has(uid):
		return false
	var item: Dictionary = instances[uid]
	if item.fragment or item.affixes.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(item.seed) + int(item.research_count) + 1
	var index := rng.randi_range(0, item.affixes.size() - 1)
	item.affixes[index] = item.hidden_affix
	item.hidden_affix = Data.weighted_affix(rng, item.affixes, Data.definition(item.definition).get("affix_pool", []))
	item.research_count = int(item.research_count) + 1
	changed.emit()
	return true


func to_dict() -> Dictionary:
	return {"version":1,"origin":origin.duplicate(true),"sect":sect,"reputation":reputation,"merit":merit,"legacy_rank_floor":legacy_rank_floor,"inner_exam_passed":inner_exam_passed,"relations":relations.duplicate(),"npc_relations":npc_relations.duplicate(),"wanted":wanted.duplicate(),"instances":instances.duplicate(true),"equipped":equipped.duplicate(),"primary":primary,"sequence":sequence,"seed":seed_value,"research":research.duplicate(),"claimed":claimed.duplicate(),"ruin_kills":ruin_kills,"legacy":legacy.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	origin = d.get("origin", {}).duplicate(true)
	if not Origin.valid(origin):
		origin = Origin.sample()
	sect = str(d.get("sect", ""))
	if not Data.data().sects.has(sect):
		sect = ""
	reputation = int(d.get("reputation", 0))
	merit = int(d.get("merit", 0))
	legacy_rank_floor = clampi(int(d.get("legacy_rank_floor", 0)), 0, 4)
	inner_exam_passed = bool(d.get("inner_exam_passed",true))
	relations = d.get("relations", {}).duplicate()
	npc_relations = d.get("npc_relations", {}).duplicate()
	wanted = d.get("wanted", {}).duplicate()
	instances = {}
	for uid in d.get("instances", {}):
		var item: Dictionary = d.instances[uid].duplicate(true)
		if Data.definition(str(item.get("definition", ""))).is_empty():
			continue
		instances[uid] = item
	for slot in equipped:
		var uid = str(d.get("equipped", {}).get(slot, ""))
		equipped[slot] = uid if instances.has(uid) and instances[uid].learned and (Data.definition(instances[uid].definition).slot == slot or (slot == "cong2" and Data.definition(instances[uid].definition).slot == "cong")) else ""
	primary = "artifact" if d.get("primary", "cong") == "artifact" else "cong"
	sequence = maxi(int(d.get("sequence", 0)), instances.size())
	seed_value = int(d.get("seed", 1101))
	research = d.get("research", {}).duplicate()
	if not research.is_empty() and not instances.has(str(research.get("uid", ""))):
		research = {}
	claimed = d.get("claimed", {}).duplicate()
	ruin_kills = int(d.get("ruin_kills", 0))
	legacy = d.get("legacy", {}).duplicate(true)
	changed.emit()
