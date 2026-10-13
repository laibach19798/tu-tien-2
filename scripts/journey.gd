extends Node
class_name Journey
## Di chuyển đại vực có thời gian (Thế Giới Mở V1 §1): chọn điểm đến và tuyến, đi qua từng chặng tốn ngày game,
## có cơ hội gặp biến cố trên đường (cướp đường / thú chặn, gặp người đi đường, phát hiện manh mối), rồi tới nơi.
##  - Tuyến chính an toàn hơn nhưng chậm; đường tắt nhanh hơn, rủi ro cao và có cơ duyên. Đường tắt phải được phát hiện mới dùng được
##    (trạng thái lưu trong World.routes_found).
##  - Thời gian trôi bằng đồng hồ chung (sect_life.day); các hệ NPC / sự kiện / tài nguyên tự bắt kịp theo ngày.
##  - Biến cố giải quyết ở mức trừu tượng (không dựng cảnh chiến đấu); thua thì phải quay lại điểm xuất phát.

signal finished(ok: bool)

var main: Node
var active := false
var _path: Array = []          # các cạnh theo thứ tự: {"from", "to", "route": Dictionary}
var _leg := 0
var _day_in_leg := 0
var _start := ""
var _dest := ""
var _spent_days := 0
var _log: Array = []


func setup(p_main: Node) -> void:
	main = p_main


func cfg(key: String, fallback := 0.0) -> float:
	return float((main.province._data.get("travel", {}) as Dictionary).get(key, fallback))


# ---------------------------------------------------------------- điểm xuất phát và đích
## Địa điểm người chơi đang đứng ("" nếu không xác định).
func here() -> String:
	if main.player == null:
		return ""
	var map_id := str(main.current_map)
	var loc: String = main.province.location_at(map_id, main.player.position)
	if loc == "" and map_id == "overworld":
		var best := ""
		var best_d := INF
		for id in main.province.locations():
			var d: Dictionary = main.province.locations()[id]
			if str(d.get("map", "")) == "overworld" and d.has("at"):
				var dist := Vector2(float(d["at"][0]), float(d["at"][1])).distance_to(main.player.position)
				if dist < best_d:
					best_d = dist
					best = str(id)
		loc = best
	return loc


## Có thể chọn làm điểm đến không (đã phát hiện, không phải động phủ / sơn môn đối địch).
func can_travel_to(id: String) -> bool:
	var d: Dictionary = main.province.info(id)
	if d.is_empty() or main.province.state_of(id) != World.DISCOVERED:
		return false
	var excluded: Array = (main.province._data.get("travel", {}) as Dictionary).get("excluded_kinds", [])
	if str(d.get("kind", "")) in excluded and id != str((main.province._data.get("travel", {}) as Dictionary).get("allow_sect_own", "")):
		return false
	return not bool(d.get("dong_phu", false))


func blocked_reason() -> String:
	if active:
		return "Đang trên đường."
	if main._dead or main.traveling:
		return "Lúc này chưa đi được."
	if bool(main.map_def.get("dong_phu", false)) or not main.destiny._run.is_empty():
		return "Không thể rời đi giữa lúc ở trong động phủ."
	if here() == "":
		return "Chưa xác định được ngươi đang ở đâu."
	return ""


# ---------------------------------------------------------------- tìm tuyến
func _edges_from(node: String) -> Array:
	var out: Array = []
	for r in main.province.routes():
		if not main.province.route_known(r):
			continue
		var other := ""
		if str(r["a"]) == node:
			other = str(r["b"])
		elif str(r["b"]) == node:
			other = str(r["a"])
		if other == "" or main.province.state_of(other) == World.UNKNOWN:
			continue
		out.append({"from": node, "to": other, "route": r})
	return out


## Các phương án tuyến từ `from` tới `to` (tối đa 3, mỗi phương án khác nhau về ngày/rủi ro).
## Mỗi phương án: {"path", "days", "risk", "max_risk", "shortcuts", "signs", "label"}.
func plan(from: String, to: String) -> Array:
	var found: Array = []
	_dfs(from, to, [from], [], found, 4)
	var options: Array = []
	for p in found:
		var days := 0
		var risk := 0
		var score := 0
		var mx := 0
		var sc := 0
		var signs: Array = []
		for e in p:
			var r: Dictionary = e["route"]
			days += int(r.get("days", 1))
			var rk := int(r.get("risk", 0))
			risk += rk
			score += rk * rk   # bình phương: một chặng rất dữ nguy hiểm hơn nhiều chặng vừa
			mx = maxi(mx, rk)
			if str(r.get("kind", "")) == "shortcut":
				sc += 1
				if str(r.get("sign", "")) != "":
					signs.append(str(r["sign"]))
		options.append({"path": p, "days": days, "risk": risk, "score": score, "max_risk": mx, "shortcuts": sc, "signs": signs})
	# bỏ trùng (cùng ngày + rủi ro + số đường tắt), sắp theo mức nguy hiểm rồi số ngày
	options.sort_custom(func(a, b): return int(a["score"]) < int(b["score"]) or (int(a["score"]) == int(b["score"]) and int(a["days"]) < int(b["days"])))
	var out: Array = []
	var seen := {}
	for o in options:
		var key := "%d|%d|%d" % [int(o["days"]), int(o["risk"]), int(o["shortcuts"])]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(o)
	# gắn nhãn
	if out.size() >= 1:
		out[0]["label"] = "Đường an toàn"
	var fastest := 0
	for i in out.size():
		if int(out[i]["days"]) < int(out[fastest]["days"]):
			fastest = i
	if out.size() > 1 and fastest != 0:
		out[fastest]["label"] = "Đường nhanh"
	for i in out.size():
		if not out[i].has("label"):
			out[i]["label"] = "Đường khác"
	return out.slice(0, 3)


func _dfs(node: String, goal: String, visited: Array, path: Array, found: Array, depth: int) -> void:
	if node == goal and not path.is_empty():
		found.append(path.duplicate())
		return
	if depth <= 0:
		return
	for e in _edges_from(node):
		var nx := str(e["to"])
		if nx in visited:
			continue
		visited.append(nx)
		path.append(e)
		_dfs(nx, goal, visited, path, found, depth - 1)
		path.pop_back()
		visited.pop_back()


func risk_text(risk: int, legs: int) -> String:
	var per := float(risk) / float(maxi(legs, 1))
	if risk == 0:
		return "rất an toàn"
	if per < 1.0:
		return "thấp"
	if per < 2.0:
		return "vừa"
	if per < 3.0:
		return "cao"
	return "rất cao"


# ---------------------------------------------------------------- thực hiện chuyến đi
func begin(option: Dictionary, from: String) -> bool:
	if active or blocked_reason() != "":
		return false
	_path = (option["path"] as Array).duplicate()
	if _path.is_empty():
		return false
	_start = from
	_dest = str(_path[_path.size() - 1]["to"])
	_leg = 0
	_day_in_leg = 0
	_spent_days = 0
	_log.clear()
	active = true
	main.meditating = false
	var signs: Array = option.get("signs", [])
	var lines: Array = ["Ngươi lên đường từ %s tới %s (%d chặng, khoảng %d ngày)." % [main.province.display_name(_start), main.province.display_name(_dest), _path.size(), int(option.get("days", 0))]]
	if not signs.is_empty():
		lines.append("Biển báo và dấu hiệu phía trước: " + "; ".join(PackedStringArray(signs)) + ".")
	main.dialogue.say("Lên đường", lines, _run_day)
	return true


func _edge() -> Dictionary:
	return _path[_leg]["route"]


func _run_day() -> void:
	if not active:
		return
	var r: Dictionary = _edge()
	main.sect_life.day += 1
	_spent_days += 1
	_day_in_leg += 1
	var kind := str(r.get("kind", "main"))
	var risk := int(r.get("risk", 0))
	var rr := RandomNumberGenerator.new()
	rr.seed = absi(("%s|%s|%d|%d" % [str(r["a"]), str(r["b"]), int(main.sect_life.day), _leg]).hash())
	var chance := float((main.province._data.get("travel", {}) as Dictionary).get("incident_base", {}).get(kind, 0.1)) + float((main.province._data.get("travel", {}) as Dictionary).get("incident_per_risk", {}).get(kind, 0.06)) * float(risk)
	# nguy hiểm thực tế của đích chặng (cả yêu thú sự kiện) cũng làm đường dữ hơn
	var dest_leg := str(_path[_leg]["to"])
	var danger_here: int = main.events.danger_of(dest_leg, int(main.province.info(dest_leg).get("danger", 1)))
	chance += 0.02 * float(maxi(0, danger_here - 1))
	if rr.randf() < chance:
		_incident(r, rr, danger_here)
	else:
		_after_day()


func _after_day() -> void:
	if not active:
		return
	var r: Dictionary = _edge()
	if _day_in_leg >= int(r.get("days", 1)):
		# tới cuối chặng: ghi nhận phát hiện nơi tới (nếu chưa), mở đường tắt kề
		var node := str(_path[_leg]["to"])
		if main.province.state_of(node) == World.RUMOR:
			main.province.discover(node, "đi tới trong chuyến đi")
		_leg += 1
		_day_in_leg = 0
		if _leg >= _path.size():
			_arrive()
			return
	_run_day()


func _arrive() -> void:
	active = false
	var dest := _dest
	var info: Dictionary = main.province.info(dest)
	var pos := _arrive_pos(info)
	var map_id := str(info.get("map", "overworld"))
	var lines: Array = ["Sau %d ngày đi đường, ngươi tới %s." % [_spent_days, main.province.display_name(dest)]]
	main.dialogue.say("Tới nơi", lines, _finish_arrival.bind(map_id, pos))


func _finish_arrival(map_id: String, pos: Vector2) -> void:
	_teleport(map_id, pos)
	finished.emit(true)


func _arrive_pos(info: Dictionary) -> Vector2:
	if info.has("arrive"):
		return Vector2(float(info["arrive"][0]), float(info["arrive"][1]))
	var map_id := str(info.get("map", ""))
	if map_id != "" and map_id != "overworld" and Maps.DEFS.has(map_id):
		return Maps.DEFS[map_id]["entry"] as Vector2
	return Vector2(1280, 1100)


func _teleport(map_id: String, pos: Vector2) -> void:
	if str(main.current_map) == map_id:
		main.player.position = pos
		main.camera.position = pos
	else:
		main.travel_to(map_id, pos)


func _abort_to_start(reason: String) -> void:
	active = false
	var info: Dictionary = main.province.info(_start)
	var pos := _arrive_pos(info)
	var map_id := str(info.get("map", "overworld"))
	main.dialogue.say("Quay lại", [reason, "Ngươi lui về %s, mất %d ngày." % [main.province.display_name(_start), _spent_days]], _finish_abort.bind(map_id, pos))


func _finish_abort(map_id: String, pos: Vector2) -> void:
	_teleport(map_id, pos)
	finished.emit(false)


# ---------------------------------------------------------------- biến cố trên đường
func _incident(r: Dictionary, rr: RandomNumberGenerator, danger: int) -> void:
	var risk := int(r.get("risk", 0))
	var shortcut := str(r.get("kind", "")) == "shortcut"
	var weights := {"ambush": 1.0 + float(risk), "wanderer": 2.0, "find": 1.0 + (2.0 if shortcut else 0.0)}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rr.randf() * total
	var kind := "wanderer"
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			kind = str(k)
			break
	match kind:
		"ambush":
			_incident_ambush(r, rr, danger)
		"find":
			_incident_find(r, rr, shortcut)
		_:
			_incident_wanderer(r, rr)


func _incident_ambush(r: Dictionary, rr: RandomNumberGenerator, danger: int) -> void:
	var risk := int(r.get("risk", 0))
	var foe := "yêu thú" if rr.randf() < 0.6 else "bọn cướp đường"
	var cost := int(cfg("pay_off_cost", 30.0))
	var opts: Array = [{"text": "Giao chiến", "call": _ambush_fight.bind(risk, danger, rr.randi())}]
	if main.inv.stones >= cost:
		opts.append({"text": "Nộp %d linh thạch mua đường" % cost, "call": _ambush_pay.bind(cost)})
	opts.append({"text": "Bỏ chạy, quay về điểm xuất phát", "call": _abort_to_start.bind("Ngươi bỏ chạy, vứt lại vài thứ trên đường.")})
	main.dialogue.choose("Chặn đường", "Giữa đường, %s chặn lối: %s. Linh áp ở đây %s." % [foe, str(r.get("note", "")), "rất nặng" if risk >= 3 else "khá nặng"], opts)


func _ambush_pay(cost: int) -> void:
	if not main.inv.spend_stones(cost):
		_abort_to_start("Không đủ linh thạch, ngươi đành quay về.")
		return
	main.hud.toast("-%d linh thạch" % cost)
	_log.append("mua đường")
	main.dialogue.say("Mua đường", ["Chúng nhận tiền rồi lùi lại. Ngươi đi tiếp."], _after_day)


func _ambush_fight(risk: int, danger: int, seed_value: int) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_value
	var step: int = main.cult.step_index()
	var power := step + 6
	var foe := (danger + risk) * 4 + 4
	var chance := clampf(0.5 + 0.04 * float(power - foe), 0.1, 0.9)
	if rr.randf() < chance:
		var gain: float = main.cult.xp_needed() * 0.01 * Hell.reward_factor(step, danger)
		main.cult.add_xp(gain)
		main.inv.add("da_yeu", 1 + risk / 2)
		main.inv.add("soi_nanh", 1)
		main.hud.toast("Hạ được chúng: +%d tu vi, +da yêu, +nanh sói." % int(gain))
		main.dialogue.say("Giao chiến", ["Ngươi đánh lui kẻ chặn đường và nhặt được chút đồ.", "(Xác suất thắng lúc đó: %d%%)" % int(chance * 100.0)], _after_day)
		return
	var loss := int(float(main.vitals.max_hp) * cfg("retreat_hp_loss", 0.3))
	main.vitals.hp = maxf(1.0, main.vitals.hp - float(loss))
	main.vitals.changed.emit()
	var lost_stones := int(float(main.inv.stones) * cfg("stones_loss", 0.1))
	if lost_stones > 0:
		main.inv.spend_stones(lost_stones)
	main.hud.flash_hurt()
	_abort_to_start("Ngươi bị đánh lui, mất %d khí huyết và %d linh thạch." % [loss, lost_stones])


func _incident_wanderer(r: Dictionary, rr: RandomNumberGenerator) -> void:
	var ids: Array = []
	var a := str(_path[_leg]["from"])
	var b := str(_path[_leg]["to"])
	for id in main.npc_world.roster():
		var st: Dictionary = main.npc_world.states[id]
		if (str(st["loc"]) == a or str(st["loc"]) == b) and str(st["status"]) == "ok":
			ids.append(str(id))
	if ids.is_empty():
		for id in main.npc_world.roster():
			if str(main.npc_world.states[id]["status"]) == "ok":
				ids.append(str(id))
	ids.sort()
	var pick: String = ids[rr.randi_range(0, ids.size() - 1)]
	var nm: String = main.npc_world.display_name(pick)
	main.dialogue.choose("Gặp người đi đường", "Trên đường, ngươi gặp %s — %s." % [nm, main.npc_world.activity_text(pick)], [
		{"text": "Hỏi thăm tin tức", "call": _wanderer_ask.bind(pick)},
		{"text": "Chào rồi đi tiếp", "call": _after_day},
	])


func _wanderer_ask(id: String) -> void:
	main.npc_world._ask_news(id)
	# _ask_news tự mở hội thoại; tiếp tục chặng khi người chơi đóng hội thoại
	var t := main.get_tree().create_timer(0.2)
	t.timeout.connect(_wait_dialogue_then_continue)


func _wait_dialogue_then_continue() -> void:
	if main.dialogue.open:
		main.get_tree().create_timer(0.2).timeout.connect(_wait_dialogue_then_continue)
		return
	_after_day()


func _incident_find(r: Dictionary, rr: RandomNumberGenerator, shortcut: bool) -> void:
	var opportunity := float(r.get("opportunity", 0.1))
	if shortcut and rr.randf() < opportunity * 2.5:
		# cơ duyên: manh mối bản đồ động phủ
		main.destiny._give_fragment()
		main.dialogue.say("Phát hiện", ["Trên lối tắt, ngươi nhặt được một mảnh da cũ vẽ nét bản đồ."], _after_day)
		return
	var pool := ["linh_thao", "truc_linh", "thiet_tinh", "han_thuy_thach", "hoang_tho_tinh"]
	var item: String = pool[rr.randi_range(0, pool.size() - 1)]
	main.inv.add(item, 1)
	main.hud.toast("+1 %s" % Items.item_name(item))
	main.dialogue.say("Phát hiện", ["Ven đường có %s mọc lộ ra, ngươi thu lấy." % Items.item_name(item)], _after_day)
