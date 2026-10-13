extends RefCounted
## Pipeline thuần dữ liệu; không biết Node, map, sprite hay tên một cặp bí tịch.
const Data = preload("res://scripts/v1/catalog.gd")
var progression
var qi := 100.0
var max_qi := 100.0
var hp := 100.0
var max_hp := 100.0
var cooldowns := {"cong":0.0,"cong2":0.0,"than":0.0,"artifact":0.0}
var statuses: Dictionary = {}
var logs: Array = []
var damage_requests: Array = []
var clock := 0.0
var _serial := 0
var _icd: Dictionary = {}
var _chain_counts: Dictionary = {}

## "cong2" (Công phụ) hành xử như "cong" ở mọi điều kiện/công thức; chỉ khác ô trang bị và phím.
static func kind(slot: String) -> String:
	return "cong" if slot == "cong2" else slot

func context(slot: String, tags: Array = []) -> Dictionary:
	_serial += 1
	return {"chain":_serial,"depth":0,"trace":[],"actor":"player","target":"","source_uid":progression.equipped.get(slot,""),"source_slot":slot,"tags":tags.duplicate(),"event":0}

func _log(text: String) -> void:
	logs.append(text)
	if logs.size() > int(Data.balance("log_limit")):
		logs.pop_front()

func bindings() -> Array:
	var result: Array = []
	var fate = Data.data().fates.get(str(progression.origin.get("fate", "")), {})
	for id in fate.get("effects", []):
		result.append({"effect":id,"uid":"fate:" + progression.origin.fate,"slot":"fate"})
	for slot in progression.equipped:
		var item: Dictionary = progression.item_for(slot)
		if item.is_empty():
			continue
		var ids: Array = progression.def_for(slot).get("effects", []).duplicate()
		for affix in item.affixes:
			ids.append_array(Data.data().affixes.get(affix, {}).get("effects", []))
		for id in ids:
			result.append({"effect":id,"uid":item.uid,"slot":slot})
	return result

func cost(slot: String) -> Dictionary:
	var d: Dictionary = progression.def_for(slot)
	var base := float(d.get("cost", 0))
	var reduction := 0.0
	var multiplier := 1.0
	var selected: Array = [slot, "tam", "armor"]
	if kind(slot) == "cong":
		selected.append("weapon")
	for part in selected:
		var item: Dictionary = progression.item_for(part)
		if item.is_empty():
			continue
		multiplier *= float(progression.def_for(part).get("cost_mult", 1))
		for a in item.affixes:
			var affix: Dictionary = Data.data().affixes.get(a, {})
			reduction += float(affix.get("cost_reduction", 0))
			multiplier *= float(affix.get("cost_mult", 1))
	var element := str(d.get("element", ""))
	if progression.origin.get("roots", {}).has(element):
		reduction += (float(progression.origin.roots[element]) - 20.0) * Data.balance("root_cost_scale")
	if kind(slot) == "cong" and has_status("player", "discount"):
		reduction += float(Data.data().statuses.discount.cost_reduction)
	var actual := maxf(0.0, base * multiplier * (1.0 - clampf(reduction, -1.0, 0.8)))
	return {"base":base,"actual":actual,"reduction":reduction,"multiplier":multiplier}

func cooldown_for(slot: String) -> float:
	var value := float(progression.def_for(slot).get("cooldown", 0))
	for part in [slot,"tam","armor"]:
		for a in progression.item_for(part).get("affixes", []):
			value *= float(Data.data().affixes.get(a, {}).get("cooldown_mult", 1))
	return maxf(0.0, value)

func cast(slot: String) -> Dictionary:
	var d: Dictionary = progression.def_for(slot)
	if d.is_empty() or slot not in cooldowns or float(cooldowns[slot]) > 0.0 or hp <= 0.0:
		return {"ok":false,"reason":"Ô pháp trống, đang hồi chiêu hoặc đã trọng thương."}
	var costs := cost(slot)
	var missing := maxf(0.0, float(costs.actual) - qi)
	var blood := 0.0
	if missing > 0.0:
		var fate: Dictionary = Data.data().fates[progression.origin.fate]
		if not fate.get("blood_payment", false) or missing > Data.balance("blood_cast_cap"):
			return {"ok":false,"reason":"Không đủ linh lực sau biến đổi chi phí."}
		blood = missing * Data.balance("blood_ratio")
		if hp - blood < max_hp * Data.balance("blood_floor"):
			return {"ok":false,"reason":"Huyết Nghịch phải giữ ít nhất 35% khí huyết."}
	var spent := minf(qi, float(costs.actual))
	qi -= spent
	hp -= blood
	if kind(slot) == "cong" and has_status("player", "discount"):
		statuses.player.erase("discount")
	cooldowns[slot] = cooldown_for(slot)
	var tags: Array = ["direct", "artifact" if slot == "artifact" else "spell"]
	if d.get("shape", "") == "cone":
		tags.append("melee")
	else:
		tags.append("ranged")
	var ctx := context(slot, tags)
	emit_event("skill_cast_started", ctx, {"skill_type":slot})
	_log("%s [%s] → chi phí gốc %.2f → sau biến đổi %.2f → thực trả %.2f linh lực / %.2f khí huyết" % [d.name,ctx.source_uid,costs.base,costs.actual,spent,blood])
	emit_event("resource_spent", ctx, {"resource":"qi","amount":spent,"skill_type":slot})
	if blood > 0.0:
		emit_event("resource_spent", ctx, {"resource":"hp","amount":blood,"skill_type":slot})
	return {"ok":true,"context":ctx,"qi_spent":spent,"hp_spent":blood,"cost":costs,"definition":d.duplicate(true)}

func completed(ctx: Dictionary) -> void:
	emit_event("skill_cast_completed", ctx)

func has_status(target: String, id: String) -> bool:
	return statuses.get(target, {}).has(id)

func has_family(target: String, family: String) -> bool:
	for id in statuses.get(target, {}):
		if str(Data.data().statuses[id].get("family", "")) == family:
			return true
	return false


func stack_count(target: String, harmful_only := true) -> int:
	var count := 0
	for id in statuses.get(target, {}):
		if not harmful_only or Data.data().statuses[id].harmful:
			count += int(statuses[target][id].stacks)
	return count

func _matches(condition: Dictionary, event: Dictionary) -> bool:
	for key in ["resource", "skill_type", "status", "harmful"]:
		if condition.has(key) and event.get(key) != condition[key]:
			return false
	if float(event.get("amount", 0)) < float(condition.get("min_amount", 0)):
		return false
	if int(event.get("stacks", 0)) < int(condition.get("min_stacks", 0)):
		return false
	if stack_count(str(event.get("target", ""))) < int(condition.get("min_total_stacks", 0)):
		return false
	if condition.has("target_status") and not has_status(str(event.target), str(condition.target_status)):
		return false
	# Họ trạng thái (mark/dot/control/debuff): một hiệu ứng nhận mọi trạng thái cùng họ, bất kể phái nào gây ra.
	if condition.has("family"):
		var sd: Dictionary = Data.data().statuses.get(str(event.get("status", "")), {})
		if str(sd.get("family", "")) != str(condition.family):
			return false
	if condition.has("families"):
		var fam: String = str(Data.data().statuses.get(str(event.get("status", "")), {}).get("family", ""))
		if fam not in condition.families:
			return false
	if condition.has("target_family") and not has_family(str(event.get("target", "")), str(condition.target_family)):
		return false
	for tag in condition.get("tags_all", []):
		if tag not in event.tags:
			return false
	return true

func emit_event(trigger: String, ctx: Dictionary, extra: Dictionary = {}) -> void:
	var event := ctx.duplicate(true)
	event.merge(extra, true)
	event.trigger = trigger
	var queue: Array = [event]
	var rules := bindings()
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var chain := str(current.chain)
		_chain_counts[chain] = int(_chain_counts.get(chain, 0)) + 1
		if int(current.depth) > int(Data.balance("chain_depth")) or int(_chain_counts[chain]) > int(Data.balance("chain_events")):
			_log("Chuỗi %s → dừng tại giới hạn an toàn." % chain)
			continue
		for binding in rules:
			var effect: Dictionary = Data.effect(binding.effect)
			if effect.get("trigger", "") != current.trigger:
				continue
			var key := str(binding.uid) + ":" + str(binding.effect)
			var allowed := true
			if key in current.trace or ("secondary" in current.tags and not effect.get("inherit_secondary", false)):
				allowed = false
			if "summon" in current.tags and not effect.get("inherit_summon", false):
				allowed = false
			if binding.slot == "weapon" and ("artifact" in current.tags or "summon" in current.tags):
				allowed = false
			if kind(str(binding.slot)) == "cong" and current.source_uid != binding.uid:
				allowed = false
			if binding.slot == "than" and current.source_slot != "than":
				allowed = false
			var ready := float(_icd.get(key, -1.0)) <= clock
			var matches := allowed and _matches(effect.get("conditions", {}), current)
			_log("%s → %s → điều kiện %s → giới hạn %s" % [key,current.trigger,"đúng" if matches else "sai","sẵn sàng" if ready else "hồi nội bộ"])
			if not matches or not ready:
				continue
			_icd[key] = clock + float(effect.get("limits", {}).get("icd", 0))
			var child := current.duplicate(true)
			child.trace.append(key)
			child.depth = int(child.depth) + 1
			child.effect_source = key
			for action in effect.get("actions", []):
				_apply(action, child, queue)
	while _chain_counts.size() > 256:
		_chain_counts.erase(_chain_counts.keys()[0])

func _apply(action: Dictionary, ctx: Dictionary, queue: Array) -> void:
	# amount cố định + scale × lượng của sự kiện gốc (linh lực thực chi, sát thương gây ra...).
	var amount := float(action.get("amount", 0)) + float(action.get("scale", 0)) * float(ctx.get("amount", 0))
	match str(action.type):
		"restore_qi":
			qi = minf(max_qi, qi + amount * (max_qi if action.get("pct", false) else 1.0))
		"heal":
			hp = minf(max_hp, hp + amount * (max_hp if action.get("pct", false) else 1.0))
		"reduce_cooldown":
			cooldowns[action.slot] = maxf(0.0, float(cooldowns.get(action.slot, 0)) - amount)
		"damage":
			if str(ctx.get("target", "")) not in ["", "player"]:
				var child := ctx.duplicate(true)
				child.tags = ["secondary"]
				damage_requests.append({"target":ctx.target,"amount":amount,"context":child})
		"status":
			var target := "player" if action.get("target", "") == "self" else str(ctx.get("target", ""))
			if target == "":
				return
			var id := str(action.status)
			var definition: Dictionary = Data.data().statuses[id]
			if not statuses.has(target):
				statuses[target] = {}
			var previous := int(statuses[target].get(id, {}).get("stacks", 0))
			var stacks := mini(int(definition.max_stacks), previous + int(action.get("stacks", 1)))
			statuses[target][id] = {"stacks":stacks,"remaining":float(definition.duration),"tick":1.0,"source":ctx.duplicate(true)}
			for trigger in ["status_applied", "status_stack_changed"]:
				var next := ctx.duplicate(true)
				next.merge({"trigger":trigger,"target":target,"status":id,"stacks":stacks,"harmful":definition.harmful}, true)
				queue.append(next)
			if id == "armor_break":
				var next := ctx.duplicate(true)
				next.trigger = "armor_broken"
				queue.append(next)
	_log("%s → hành động %s" % [ctx.get("effect_source", "cơ chế gốc"), action.type])

func apply_status(target: String, id: String, stacks: int, ctx: Dictionary) -> void:
	var queue: Array = []
	_apply({"type":"status","status":id,"stacks":stacks}, _with_target(ctx,target), queue)
	for event in queue:
		emit_event(event.trigger, event)

func _with_target(ctx: Dictionary, target: String) -> Dictionary:
	var result := ctx.duplicate(true)
	result.target = target
	return result

func hit(target: String, amount: float, ctx: Dictionary, killed := false, critical := false) -> void:
	var event := _with_target(ctx, target)
	emit_event("damage_applied", event, {"amount":amount})
	if critical:
		emit_event("critical_hit", event, {"amount":amount})
	emit_event("summon_hit" if "summon" in ctx.tags else "attack_hit", event, {"amount":amount})
	if killed:
		emit_event("target_killed", event, {"amount":amount})
		statuses.erase(target)

func incoming(amount: float, target: String) -> float:
	var ctx := context("armor", ["incoming"])
	ctx.target = target
	emit_event("incoming_hit", ctx, {"amount":amount})
	var reduction := float(progression.def_for("armor").get("reduction", 0))
	if has_status("player", "guard"):
		reduction += float(Data.data().statuses.guard.reduction) * int(statuses.player.guard.stacks)
		emit_event("guard_success", ctx)
	if has_status(target, "weaken"):
		amount *= float(Data.data().statuses.weaken.attack_mult)
	return amount * (1.0 - clampf(reduction, 0.0, Data.balance("armor_cap")))

## Nhân sát thương có điều kiện: mục tiêu mang trạng thái thuộc họ yêu cầu và/hoặc đủ tổng số tầng bất lợi.
func _conditional(cond: Dictionary, target: String) -> float:
	if cond.is_empty():
		return 1.0
	if cond.has("families"):
		var hit := false
		for family in cond.families:
			hit = hit or has_family(target, str(family))
		if not hit:
			return 1.0
	if stack_count(target) < int(cond.get("min_total_stacks", 0)):
		return 1.0
	return float(cond.get("damage_mult", 1))


func damage_multiplier(slot: String, target: String, summon := false) -> float:
	var value := 1.0
	var selected: Array = [slot,"tam","armor"]
	if kind(slot) == "cong" and not summon:
		selected.append("weapon")
	for part in selected:
		var definition: Dictionary = progression.def_for(part)
		value *= float(definition.get("damage_mult", 1))
		value *= _conditional(definition.get("conditional", {}), target)
		for a in progression.item_for(part).get("affixes", []):
			var affix: Dictionary = Data.data().affixes.get(a, {})
			value *= float(affix.get("damage_mult", 1))
			value *= _conditional(affix.get("conditional", {}), target)
	if has_status(target, "armor_break"):
		value *= 1.0 + float(Data.data().statuses.armor_break.vulnerability) * float(statuses[target].armor_break.stacks)
	if kind(slot) in ["cong", "artifact"] and has_status("player", "surge"):
		value *= 1.0 + float(Data.data().statuses.surge.damage_bonus)
	return value

func tick(delta: float) -> void:
	clock += delta
	for slot in cooldowns:
		cooldowns[slot] = maxf(0.0, float(cooldowns[slot]) - delta)
	for target in statuses.keys():
		for id in statuses[target].keys():
			var state: Dictionary = statuses[target][id]
			state.remaining = float(state.remaining) - delta
			state.tick = float(state.tick) - delta
			if state.remaining <= 0.0:
				statuses[target].erase(id)
				emit_event("status_expired", state.source, {"target":target,"status":id})
			elif state.tick <= 0.0 and Data.data().statuses[id].has("tick_damage"):
				state.tick = 1.0
				var ctx: Dictionary = state.source.duplicate(true)
				ctx.tags = ["secondary", "dot"]
				damage_requests.append({"target":target,"amount":float(Data.data().statuses[id].tick_damage) * int(state.stacks),"context":ctx})
		if statuses[target].is_empty():
			statuses.erase(target)

func clear_transient() -> void:
	statuses.clear()
	damage_requests.clear()
	_icd.clear()
	_chain_counts.clear()
	for slot in cooldowns:
		cooldowns[slot] = 0.0
