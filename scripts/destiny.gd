extends Node
class_name Destiny
## Cơ duyên và động phủ tiên nhân (thiết kế: docs/CO_DUYEN_DONG_PHU.md; dữ liệu: data/destiny.json).
##  - `duyên` ẩn 0–100: cơ duyên ngẫu nhiên xuất hiện theo xác suất phụ thuộc duyên; lựa chọn đổi duyên.
##  - Mảnh bản đồ → cổng động phủ → bản đồ phụ (rune, bẫy, thủ hộ, truyền thừa, sụp đổ).
##  - Động phủ dùng một lần, tái tạo sau 10–20 năm game (1 năm = Hell.DAYS_PER_YEAR ngày game).
##  - Tông địch có thể mở động phủ trước nếu người chơi quá chậm.

const DATA_PATH := "res://data/destiny.json"
const CATALOG := preload("res://scripts/v1/catalog.gd")

var main: Node
var duyen := 20.0                  # ẩn: không hiển thị thành số
var flags: Dictionary = {}
var fragments: Dictionary = {}     # id động phủ -> số mảnh bản đồ
var dp_state: Dictionary = {}      # id động phủ -> {"state": sealed|open|destroyed, "regen_day": int}
var scheduled: Array = []          # [{"id": kỳ ngộ, "day": ngày game}]
var buffs: Dictionary = {}         # id -> giây còn lại (linh_vu, oan_khi)
var rng := RandomNumberGenerator.new()

var log: Array = []                # nhật ký: [{day, map, title, text}], mới nhất ở cuối
const LOG_LIMIT := 150

var _data: Dictionary = {}
var _timer := 1.0
var _explore_left := -1.0          # giây KHÁM PHÁ (ngoài đồng, ngoài vùng an toàn) còn lại trước cơ duyên kế tiếp
var _spawned_in_visit := false     # mỗi lần ghé một bản đồ chỉ một cơ duyên
var _last_day := 0
var _duyen_today := 0.0
var _med_run := 0.0
var _last_id := ""
var _last_map := ""
var _nodes: Array = []             # EncounterNode đang có trên bản đồ hiện tại
var _run: Dictionary = {}          # trạng thái lần vào động phủ hiện tại


func _ready() -> void:
	add_to_group("destiny")
	rng.randomize()
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)
	_last_map = main.current_map


# ---------------------------------------------------------------- truy cập
func balance(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func encounters() -> Dictionary:
	return _data.get("encounters", {})


func dong_phu() -> Dictionary:
	return _data.get("dong_phu", {})


func density_mult() -> float:
	return 2.0 if buffs.has("linh_vu") else 1.0


func meditate_mult() -> float:
	return 0.7 if buffs.has("oan_khi") else 1.0


func add_duyen(n: float) -> void:
	if n > 0.0:
		var room := maxf(0.0, balance("duyen_per_day_cap", 10.0) - _duyen_today)
		n = minf(n, room)
		_duyen_today += n
	duyen = clampf(duyen + n, 0.0, 100.0)


func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))


## Ghi một dòng vào nhật ký cơ duyên (hiển thị ở sổ tay, tab Nhật ký).
func note(title: String, text: String) -> void:
	log.append({"day": int(main.sect_life.day) if main != null else 0, "map": main.current_map if main != null else "", "title": title, "text": text})
	while log.size() > LOG_LIMIT:
		log.pop_front()


## Dữ liệu cho tab Nhật ký: động phủ đã biết, dấu ấn nhân quả, linh cảm (việc sẽ xảy ra, không nói ngày).
func diary() -> Dictionary:
	var day := int(main.sect_life.day)
	var places: Array = []
	for id in dong_phu():
		var info: Dictionary = dong_phu()[id]
		var st: Dictionary = dp_state.get(id, {"state": "sealed", "regen_day": 0})
		var n := int(fragments.get(id, 0))
		var where := Maps.map_name(str(info["region"]))
		match str(st["state"]):
			"sealed":
				if n <= 0:
					continue
				if n >= int(info["fragments"]):
					places.append({"name": str(info["name"]), "line": "Đã đủ mảnh bản đồ: cổng động phủ lộ ra ở %s. Đừng chậm trễ, tông địch cũng đang tìm." % where})
				else:
					places.append({"name": "Một động phủ ở %s" % where, "line": "Mới có %d/%d mảnh bản đồ." % [n, int(info["fragments"])]})
			"open":
				places.append({"name": str(info["name"]), "line": "Cấm chế cửa đã phá; còn có thể vào lại ở %s." % where})
			"destroyed":
				var years := int(ceil(float(int(st["regen_day"]) - day) / float(Hell.DAYS_PER_YEAR)))
				places.append({"name": str(info["name"]), "line": "Đã không còn (đã dùng hoặc bị tông địch mở). Nghe đồn sẽ lộ lại sau khoảng %d năm." % maxi(1, years)})
	var marks: Array = []
	var ft: Dictionary = _data.get("flag_text", {})
	for id in flags:
		if bool(flags[id]) and ft.has(id):
			marks.append(str(ft[id]))
	var hunches: Array = []
	for s in scheduled:
		var e: Dictionary = encounters().get(str(s["id"]), {})
		hunches.append(str(e.get("hunch", "Ngươi có linh cảm sẽ còn gặp lại: %s." % str(e.get("name", "một người")))))
	return {"places": places, "marks": marks, "hunches": hunches, "log": log}


# ---------------------------------------------------------------- vòng lặp
func _process(delta: float) -> void:
	if main == null or _data.is_empty():
		return
	for id in buffs.keys():
		buffs[id] = float(buffs[id]) - delta
		if float(buffs[id]) <= 0.0:
			buffs.erase(id)
			if id == "linh_vu":
				main.hud.toast("Mưa linh khí đã tạnh.")
	if int(main.sect_life.day) != _last_day:
		_on_new_days()
	if main.current_map != _last_map:
		_last_map = main.current_map
		_on_map_changed()
	if main.meditating:
		_med_run += delta
		if _med_run >= balance("meditate_duyen_seconds", 360.0):
			_med_run = 0.0
			add_duyen(1.0)
	else:
		_med_run = 0.0
	if not _run.is_empty():
		_tick_dong_phu(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_tick_second()


func _on_new_days() -> void:
	var day := int(main.sect_life.day)
	if day < _last_day:
		_last_day = day   # tải bản lưu cũ hơn
		return
	for d in range(_last_day + 1, day + 1):
		_duyen_today = 0.0
		for id in dong_phu():
			var st: Dictionary = dp_state.get(id, {"state": "sealed", "regen_day": 0})
			match str(st["state"]):
				"destroyed":
					if d >= int(st["regen_day"]):
						dp_state[id] = {"state": "sealed", "regen_day": 0}
						fragments[id] = 0
						main.npc_world.new_generation(str(id))   # bản truyền thừa mới, không phải bản gốc cũ
						main.hud.toast("Nghe đồn: %s lại lộ ra sau nhiều năm." % str(dong_phu()[id]["name"]))
						note(str(dong_phu()[id]["name"]), "Sau nhiều năm, động phủ lại lộ ra. Cần tìm đủ mảnh bản đồ một lần nữa.")
				"sealed":
					if int(fragments.get(id, 0)) >= int(dong_phu()[id]["fragments"]) and rng.randf() < balance("rival_chance_per_day", 0.08):
						_rival_takes(str(id), d)
	_last_day = day


func _rival_takes(id: String, day: int) -> void:
	var rivals: Array = []
	for sid in SectWar.SECTS:
		if str(sid) != SectWar.PLAYER:
			rivals.append(str(sid))
	var who: String = SectWar.sect_name(rivals[rng.randi_range(0, rivals.size() - 1)])
	var hunter: String = main.npc_world.on_rival_takes(id, day)   # kẻ tầm bảo cụ thể giành truyền thừa
	if hunter != "":
		who = hunter
	dp_state[id] = {"state": "destroyed", "regen_day": day + _regen_days()}
	fragments[id] = 0
	main.hud.toast("Tin đồn: %s đã mở %s trước ngươi. Cơ duyên này không còn." % [who, str(dong_phu()[id]["name"])])
	note(str(dong_phu()[id]["name"]), "%s đã mở trước ngươi. Cơ duyên này đã mất." % who)
	_clear_gate()


func _regen_days() -> int:
	var yr: Array = (_data.get("balance", {}) as Dictionary).get("regen_years", [10, 20])
	return int(rng.randi_range(int(yr[0]), int(yr[1])) * Hell.DAYS_PER_YEAR)


# ---------------------------------------------------------------- kỳ ngộ ngẫu nhiên
func _has_due() -> bool:
	var day := int(main.sect_life.day)
	for s in scheduled:
		if day >= int(s["day"]):
			return true
	return false


func _eligible() -> bool:
	if main._dead or main.traveling or main._ui_blocked():
		return false
	if not _run.is_empty() or bool(main.map_def.get("dong_phu", false)):
		return false
	if int(main.map_def.get("tier", 0)) <= 0:
		return false
	if main.is_safe(main.player.position):
		return false
	for n in _nodes:
		if is_instance_valid(n) and not str(n.enc_id).begins_with("dp_"):
			return false   # đang có một kỳ ngộ chờ
	return true


## Nhịp 1 giây: cơ duyên theo "ngân sách khám phá" (HIẾM, có khoảng cách tối thiểu) thay vì xác suất liên tục.
func _tick_second() -> void:
	if not _eligible():
		return
	if _has_due():
		_roll(true)   # việc đã hẹn trước (trả ơn, lời nhắn) tới hạn thì hiện ngay khi có chỗ
		return
	if _spawned_in_visit:
		return
	if _explore_left < 0.0:
		_explore_left = balance("first_gap_seconds", 2400.0)
	var dark := float(main.atmo.darkness) > 0.7
	_explore_left -= 1.5 if dark else 1.0   # đêm khuya điềm lạ dễ hiện hơn
	if _explore_left <= 0.0:
		_explore_left = _next_gap()
		_roll(false)


## Khoảng cách tới cơ duyên kế tiếp (giây khám phá): duyên cao thì đến sớm hơn, duyên thấp thì muộn hơn.
func _next_gap() -> float:
	var span: Array = (_data.get("balance", {}) as Dictionary).get("duyen_gap_scale", [1.4, 0.8])
	var scale := lerpf(float(span[0]), float(span[1]), clampf(duyen / 100.0, 0.0, 1.0))
	return rng.randf_range(balance("gap_min_seconds", 3600.0), balance("gap_max_seconds", 9000.0)) * scale


func _roll(due_only: bool) -> void:
	var enc_id := ""
	var due_entry = null
	var day := int(main.sect_life.day)
	for s in scheduled:
		if day >= int(s["day"]):
			enc_id = str(s["id"])
			due_entry = s
			break
	if enc_id == "" and not due_only:
		enc_id = _pick()
	if enc_id != "" and _spawn(enc_id) != null:
		_spawned_in_visit = true
		if due_entry != null:
			scheduled.erase(due_entry)


func _pick() -> String:
	var tier := int(main.map_def.get("tier", 0))
	var dark := float(main.atmo.darkness) > 0.7
	var pool: Array = []
	var total := 0.0
	for id in encounters():
		var e: Dictionary = encounters()[id]
		var w := float(e.get("weight", 0))
		if w <= 0.0 or bool(e.get("scheduled_only", false)) or str(id) == _last_id:
			continue
		var tr: Array = e.get("tier", [0, 99])
		if tier < int(tr[0]) or tier > int(tr[1]):
			continue
		if bool(e.get("night_only", false)) and not dark:
			continue
		pool.append([str(id), w])
		total += w
	if pool.is_empty():
		return ""
	var r := rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			return str(e[0])
	return str(pool[0][0])


func _spawn(enc_id: String, at := Vector2.ZERO, fixed := false) -> EncounterNode:
	var e: Dictionary = encounters().get(enc_id, {})
	if e.is_empty():
		return null
	var node := _make_node(enc_id, e, at, fixed)
	if node != null:
		node.life = balance("despawn_seconds", 480.0)
		_last_id = enc_id
		main.hud.toast("Có điều gì lạ ở gần đây…")
		Sfx.play("ui_open")
	return node


func _make_node(id: String, e: Dictionary, at: Vector2, fixed: bool) -> EncounterNode:
	var pos := at
	if not fixed:
		pos = Vector2.ZERO
		for i in 16:
			var a := rng.randf() * TAU
			var cand: Vector2 = main.player.position + Vector2(cos(a), sin(a)) * rng.randf_range(170.0, 280.0)
			var ms: Vector2 = main.map_size
			if cand.x < 160.0 or cand.y < 160.0 or cand.x > ms.x - 160.0 or cand.y > ms.y - 160.0:
				continue
			if main.is_safe(cand) or main._is_blocked(Rect2(cand.x - 30, cand.y - 30, 60, 50)):
				continue
			pos = cand
			break
		if pos == Vector2.ZERO:
			return null
	var node := EncounterNode.new()
	node.setup(id, e)
	node.position = pos
	main.world.add_child(node)
	main.npcs.append(node)
	_nodes.append(node)
	return node


func expire(node: EncounterNode) -> void:
	_consume(node)


func _consume(node: EncounterNode) -> void:
	_nodes.erase(node)
	main.npcs.erase(node)
	if is_instance_valid(node):
		node.queue_free()


# ---------------------------------------------------------------- tương tác
func open(node: EncounterNode) -> void:
	var id := node.enc_id
	if id.begins_with("wnpc_"):
		main.npc_world.talk(node)
		return
	if id.begins_with("wev_"):
		main.events.open(node)
		return
	if id.begins_with("wseclude_"):
		main.npc_world.talk_seclusion(node)
		return
	if id.begins_with("dp_"):
		_dp_interact(node)
		return
	var e: Dictionary = node.data
	var text := str(e.get("intro", ""))
	if duyen >= 65.0 and e.has("intro_high"):
		text = str(e["intro_high"])
	var opts: Array = []
	if e.has("riddle"):
		var rd: Dictionary = e["riddle"]
		var answers: Array = [[str(rd["right"]), true]]
		for w in rd["wrong"]:
			answers.append([str(w), false])
		answers.shuffle()
		for a in answers:
			opts.append({"text": a[0], "call": _answer_riddle.bind(node, bool(a[1]))})
	else:
		for c in e.get("choices", []):
			if _choice_visible(c):
				opts.append({"text": str(c["text"]), "call": _choose.bind(node, c)})
	opts.append({"text": "Rời đi", "call": Callable()})
	main.meditating = false
	main.dialogue.choose(node.display_name, text, opts)


func _choice_visible(c: Dictionary) -> bool:
	return duyen >= float(c.get("min_duyen", 0)) and duyen <= float(c.get("max_duyen", 100))


func _can_pay(cost: Dictionary) -> String:
	if cost.has("item") and main.inv.count(str(cost["item"])) < int(cost.get("n", 1)):
		return "Thiếu %s." % str(Items.DATA.get(str(cost["item"]), {}).get("name", cost["item"]))
	if cost.has("stones_frac") and main.inv.stones <= 0:
		return "Không có linh thạch."
	return ""


func _pay(cost: Dictionary) -> void:
	if cost.has("item"):
		main.inv.remove(str(cost["item"]), int(cost.get("n", 1)))
	if cost.has("stones_frac"):
		main.inv.spend_stones(maxi(1, int(main.inv.stones * float(cost["stones_frac"]))))


func _choose(node: EncounterNode, c: Dictionary) -> void:
	var cost: Dictionary = c.get("cost", {})
	var why := _can_pay(cost)
	if why != "":
		main.hud.toast(why)
		return
	_pay(cost)
	for e in c.get("effects", []):
		_apply(e, node)
	var res := str(c.get("result", ""))
	if res != "":
		main.dialogue.say(node.display_name, [res])
	note(node.display_name, "%s%s" % [str(c.get("text", "")), (" — " + res) if res != "" else ""])
	_consume(node)


func _answer_riddle(node: EncounterNode, right: bool) -> void:
	var rd: Dictionary = node.data["riddle"]
	for e in rd["right_effects" if right else "wrong_effects"]:
		_apply(e, node)
	main.dialogue.say(node.display_name, [str(rd["right_result" if right else "wrong_result"])])
	note(node.display_name, str(rd["right_result" if right else "wrong_result"]))
	_consume(node)


# ---------------------------------------------------------------- hiệu ứng (bộ nhỏ dùng chung)
func _apply(e: Dictionary, node: Node2D) -> void:
	match str(e.get("type", "")):
		"item":
			main.inv.add(str(e["id"]), int(e.get("n", 1)))
			main.hud.toast("+%d %s" % [int(e.get("n", 1)), str(Items.DATA.get(str(e["id"]), {}).get("name", e["id"]))])
		"stones":
			main.inv.add_stones(int(e["n"]))
			main.hud.toast("+%d linh thạch" % int(e["n"]))
		"merit":
			main.inv.add_merit(int(e["n"]))
			main.hud.toast("+%d cống hiến" % int(e["n"]))
		"duyen":
			add_duyen(float(e["n"]))
		"flag":
			flags[str(e["id"])] = true
		"xp_frac":
			var tier := int(main.map_def.get("tier", 0))
			var gain: float = main.cult.xp_needed() * float(e["n"]) * Hell.reward_factor(main.cult.step_index(), tier)
			gain = minf(gain, main.cult.xp_needed() * 0.30)   # trần 30% tu vi tầng (docs/CO_DUYEN_DONG_PHU.md §6)
			main.cult.add_xp(gain)
			main.hud.toast("+%d tu vi" % int(gain))
		"heal_frac":
			main.vitals.heal(main.vitals.max_hp * float(e["n"]))
		"damage_frac":
			main.vitals.hp = maxf(1.0, main.vitals.hp - main.vitals.max_hp * float(e["n"]))
			main.vitals.changed.emit()
			main.hud.flash_hurt()
		"chance":
			if rng.randf() < float(e["p"]):
				for sub in e.get("effects", []):
					_apply(sub, node)
		"toast":
			main.hud.toast(str(e["text"]))
		"map_fragment":
			_give_fragment()
		"book_fragment":
			var books: Array = _data.get("books", [])
			var id := str(books[rng.randi_range(0, books.size() - 1)])
			main.cultivation_v1.state.acquire(id, "dong_phu", "linh", true)
			main.hud.toast("Tàn quyển: %s (Y → Bí tịch, cần tham ngộ)" % str(CATALOG.definition(id).get("name", id)))
		"reroll_affix":
			var st = main.cultivation_v1.state
			var uid := str(st.equipped.get("cong", ""))
			if uid == "" or not st.reroll_one(uid):
				main.hud.toast("Chưa có bí tịch phù hợp để ngộ.")
			else:
				main.hud.toast("Một dòng phụ của bí tịch đang dùng đã biến đổi.")
		"buff":
			buffs[str(e["id"])] = float(e["seconds"])
		"schedule":
			scheduled.append({"id": str(e["id"]), "day": int(main.sect_life.day) + int(e["days"])})
		"bond":
			var keys: Array = main.sect_life.bonds.keys()
			var who := str(e.get("who", "any"))
			if who == "any":
				who = str(keys[rng.randi_range(0, keys.size() - 1)])
			if main.sect_life.bonds.has(who):
				main.sect_life.bonds[who] = clampi(int(main.sect_life.bonds[who]) + int(e["n"]), -100, 100)
				main.sect_life.changed.emit()
		"spawn":
			main.spawn_monster_groups([[str(e["kind"]), node.position + Vector2(100, 0), int(e.get("n", 1))]])


## Mảnh bản đồ: chọn một động phủ chưa mở còn thiếu mảnh.
func _give_fragment() -> void:
	var pool: Array = []
	for id in dong_phu():
		var st: Dictionary = dp_state.get(id, {"state": "sealed"})
		# chỉ dẫn tới động phủ không quá xa tầm tu vi hiện tại (3 tầng nhìn trước)
		if int(main.cult.step_index()) + 3 < int(dong_phu()[id].get("min_step", 0)):
			continue
		if str(st["state"]) == "sealed" and int(fragments.get(id, 0)) < int(dong_phu()[id]["fragments"]):
			pool.append(str(id))
	if pool.is_empty():
		main.hud.toast("Mảnh bản đồ cũ kỹ, không còn dẫn tới đâu.")
		return
	var id: String = pool[rng.randi_range(0, pool.size() - 1)]
	fragments[id] = int(fragments.get(id, 0)) + 1
	var need := int(dong_phu()[id]["fragments"])
	var info: Dictionary = dong_phu()[id]
	if int(fragments[id]) >= need:
		main.hud.toast("Đủ mảnh bản đồ! Cửa %s lộ ra ở %s." % [str(info["name"]), Maps.map_name(str(info["region"]))])
		_spawn_gate_if_here()
	else:
		main.hud.toast("Mảnh bản đồ (%d/%d): một động phủ ở %s." % [int(fragments[id]), need, Maps.map_name(str(info["region"]))])


# ---------------------------------------------------------------- động phủ
func _on_map_changed() -> void:
	_spawned_in_visit = false
	_nodes = _nodes.filter(func(n): return is_instance_valid(n))
	for id in dong_phu():
		var info: Dictionary = dong_phu()[id]
		if not _run.is_empty() and str(_run.get("id", "")) == str(id) and main.current_map != str(info["map"]):
			_run = {}   # rời động phủ: không còn đếm sụp / bẫy
	_spawn_gate_if_here()
	for id in dong_phu():
		if main.current_map == str(dong_phu()[id]["map"]) and not _run.is_empty() and str(_run["id"]) == str(id):
			_populate(str(id))


func _clear_gate() -> void:
	for n in _nodes.duplicate():
		if is_instance_valid(n) and str(n.enc_id) == "dp_gate":
			_consume(n)


func _spawn_gate_if_here() -> void:
	if main == null:
		return
	_clear_gate()
	for id in dong_phu():
		var info: Dictionary = dong_phu()[id]
		if main.current_map != str(info["region"]):
			continue
		var st: Dictionary = dp_state.get(id, {"state": "sealed"})
		var has_key := str(st["state"]) == "open" or (str(st["state"]) == "sealed" and int(fragments.get(id, 0)) >= int(info["fragments"]))
		if not has_key:
			continue
		var pos := Vector2.ZERO
		for c in info["gate_candidates"]:
			var p := Vector2(float(c[0]), float(c[1]))
			if not main._is_blocked(Rect2(p.x - 40, p.y - 40, 80, 60)):
				pos = p
				break
		if pos == Vector2.ZERO:
			var c0: Array = info["gate_candidates"][0]
			pos = Vector2(float(c0[0]), float(c0[1]))
		var node := _make_node("dp_gate", {"name": str(info["name"]), "kind": "gate", "prompt": "Vào động phủ", "glow": [0.7, 0.85, 1.0], "dp": str(id)}, pos, true)
		if node != null:
			node.data["dp"] = str(id)


func _open_gate(node: EncounterNode) -> void:
	var id := str(node.data.get("dp", ""))
	var info: Dictionary = dong_phu().get(id, {})
	if info.is_empty():
		return
	var st: Dictionary = dp_state.get(id, {"state": "sealed"})
	var opts: Array = []
	var enter := func():
		if str(st["state"]) == "sealed":
			fragments[id] = 0   # tín vật tan thành bụi khi phá cấm chế
		dp_state[id] = {"state": "open", "regen_day": 0}
		note(str(info["name"]), "Ngươi bước vào động phủ.")
		_run = {"id": id, "order": [], "progress": 0, "done": false, "trap_t": 0.0, "collapse": -1.0, "taken": false}
		main.travel_to(str(info["map"]), Vector2(float(info["entry"][0]), float(info["entry"][1])))
	if str(st["state"]) == "sealed":
		opts.append({"text": "Phá cấm chế bằng ba mảnh bản đồ (tín vật tan biến)", "call": enter})
	else:
		opts.append({"text": "Vào lại động phủ", "call": enter})
	opts.append({"text": "Chưa vào", "call": Callable()})
	main.dialogue.choose(node.display_name, str(info["intro"]), opts)


func _populate(id: String) -> void:
	var info: Dictionary = dong_phu()[id]
	var trial := str(info.get("trial", "runes"))
	_run["progress"] = 0
	_run["done"] = false
	_run["heart"] = false
	_run["guards"] = []
	_run["clone"] = null
	if trial in ["runes", "swords"]:
		var ids: Array = []
		for r in info["runes"]:
			ids.append(str(r["id"]))
		if trial == "runes":
			ids = ["kiem", "hoa", "thuy"]
		ids.shuffle()
		_run["order"] = ids.slice(0, int(info.get("rune_count", ids.size())))
		var s: Dictionary = info["stele"]
		_make_node("dp_stele", {"name": str(s["name"]), "kind": "stone", "prompt": "Đọc bia", "glow": [0.8, 0.85, 1.0]}, Vector2(float(s["pos"][0]), float(s["pos"][1])), true)
		for r in info["runes"]:
			_make_node("dp_rune_" + str(r["id"]), {"name": str(r["name"]), "kind": "stone", "prompt": "Kích hoạt rune", "glow": [1.0, 0.8, 0.5], "rune": str(r["id"])},
				Vector2(float(r["pos"][0]), float(r["pos"][1])), true)
	if info.has("heart"):
		var h: Dictionary = info["heart"]
		_make_node("dp_heart", {"name": str(h["name"]), "kind": "stone", "prompt": "Soi tâm", "glow": [0.6, 0.9, 1.0]}, Vector2(float(h["pos"][0]), float(h["pos"][1])), true)
	if trial == "blood":
		var pl: Dictionary = info["pool"]
		_make_node("dp_pool", {"name": str(pl["name"]), "kind": "pool", "prompt": "Quan sát huyết trì", "glow": [1.0, 0.25, 0.3], "r": float(pl["r"])}, Vector2(float(pl["pos"][0]), float(pl["pos"][1])), true)
	if trial == "mirror":
		var m: Dictionary = info["mirror"]
		_make_node("dp_mirror", {"name": str(m["name"]), "kind": "stone", "prompt": "Soi vào gương", "glow": [0.75, 0.9, 1.0]}, Vector2(float(m["pos"][0]), float(m["pos"][1])), true)
	var lg: Dictionary = info["legacy"]
	_make_node("dp_legacy", {"name": str(lg["name"]), "kind": "sitter", "prompt": "Nhìn kỹ di hài", "glow": [0.9, 0.95, 1.0]},
		Vector2(float(lg["pos"][0]), float(lg["pos"][1])), true)
	var glist: Array = (info.get("guards_list", []) as Array).duplicate()
	if info.has("guards"):
		glist.append(info["guards"])
	for g in glist:
		_spawn_guards(str(g["kind"]), Vector2(float(g["pos"][0]), float(g["pos"][1])), int(g["n"]))
	var hint := {"runes": "trận rune ở phía trước, hành lang bẫy phía sau.", "swords": "trận chín kiếm ở phía trước, tâm kính ở phía sau.",
		"blood": "huyết trì hồi sức ở giữa, khôi lỗi thủ hộ phía sau.", "mirror": "gương Thiên Mạch ở phía trước."}
	main.hud.toast("%s: %s" % [str(info["name"]), str(hint.get(trial, ""))])


## Sinh quái thủ hộ động phủ và ghi lại để biết khi nào đã hạ hết.
func _spawn_guards(kind: String, at: Vector2, n: int) -> void:
	var made := 0
	var tries := 0
	while made < n and tries < 120:
		tries += 1
		var p: Vector2 = at + Vector2(rng.randf_range(-80, 80), rng.randf_range(-60, 60)) if made > 0 or tries > 1 else at
		if main._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)):
			continue
		var mon := Monster.new()
		mon.setup(main, kind, p)
		main.world.add_child(mon)
		main.monsters.append(mon)
		(_run["guards"] as Array).append(mon)
		made += 1


func _dp_interact(node: EncounterNode) -> void:
	var id: String = str(_run.get("id", ""))
	match node.enc_id:
		"dp_gate":
			_open_gate(node)
		"dp_stele":
			var o: Array = _run.get("order", [])
			var names: Array = []
			var rn := {"kiem": "Kiếm", "hoa": "Hỏa", "thuy": "Thủy"}
			for r in dong_phu().get(id, {}).get("runes", []):
				rn[str(r["id"])] = str(r["name"]).trim_prefix("Kiếm ").trim_prefix("Rune ")
			for rid in o:
				names.append(str(rn.get(str(rid), rid)))
			if not names.is_empty():
				main.dialogue.say(node.display_name, ["Kệ cổ: \"Theo thứ tự: %s. Trái thứ tự, cấm chế phản chấn.\"" % ", rồi ".join(names)])
		"dp_heart":
			_heart_trial(node)
		"dp_pool":
			main.dialogue.say(node.display_name, ["Máu cổ cuồn cuộn mà không tanh. Đứng trong trì, khí huyết hồi dần; nhưng khôi lỗi thủ hộ sẽ không để ngươi yên."])
		"dp_mirror":
			_summon_mirror(node)
		"dp_legacy":
			if not bool(_run.get("done", false)):
				var lt := str(dong_phu().get(id, {}).get("legacy", {}).get("locked_text", "Cấm chế vẫn bao phủ di hài."))
				main.dialogue.say(node.display_name, [lt])
			elif bool(_run.get("taken", false)):
				main.hud.toast("Động phủ đang sụp đổ, mau thoát ra!")
			else:
				_open_legacy(node)
		_:
			if node.enc_id.begins_with("dp_rune_"):
				_press_rune(str(node.data.get("rune", "")), node)
	if id == "":
		return


func _press_rune(rune: String, node: EncounterNode) -> void:
	if bool(_run.get("done", false)):
		main.hud.toast("Cấm chế đã mở.")
		return
	var o: Array = _run["order"]
	var p := int(_run["progress"])
	if rune == str(o[p]):
		_run["progress"] = p + 1
		if p + 1 >= o.size():
			_run["done"] = true
			main.hud.toast("Ba rune cùng sáng. Cấm chế mở!")
			note("Vô Danh Thạch Động", "Ngươi kích hoạt đủ ba rune theo đúng thứ tự, cấm chế mở ra.")
		else:
			main.hud.toast("Rune sáng lên (%d/%d)." % [p + 1, o.size()])
	else:
		_run["progress"] = 0
		main.hud.toast("Sai thứ tự! Cấm chế phản chấn, các rune tối lại.")
		var strike := TribulationStrike.new()
		strike.main = main
		strike.damage = Hell.tribulation_damage(1)
		strike.position = main.player.position
		main.world.add_child(strike)


## Khảo nghiệm tâm: lần lượt trả lời các câu hỏi; sai một câu bị phản phệ (mất tu vi tầng) nhưng được thử lại.
func _heart_trial(node: EncounterNode) -> void:
	var id := str(_run.get("id", ""))
	var h: Dictionary = dong_phu().get(id, {}).get("heart", {})
	if h.is_empty():
		return
	if bool(_run.get("heart", false)):
		main.dialogue.say(node.display_name, ["Tâm kính lặng như nước. Ngươi đã qua khảo nghiệm."])
		return
	_heart_ask(node, 0)


func _heart_ask(node: EncounterNode, i: int) -> void:
	var h: Dictionary = dong_phu()[str(_run["id"])]["heart"]
	var qs: Array = h["questions"]
	if i >= qs.size():
		_run["heart"] = true
		main.hud.toast("Tâm kính sáng lên. Ngươi qua khảo nghiệm tâm.")
		note(str(dong_phu()[str(_run["id"])]["name"]), "Ngươi vượt qua khảo nghiệm tâm.")
		return
	var q: Dictionary = qs[i]
	var answers: Array = [[str(q["right"]), true]]
	for w in q["wrong"]:
		answers.append([str(w), false])
	answers.shuffle()
	var opts: Array = []
	for a in answers:
		opts.append({"text": a[0], "call": _heart_answer.bind(node, i, bool(a[1]))})
	opts.append({"text": "Chưa dám trả lời", "call": Callable()})
	main.dialogue.choose(node.display_name, "(%d/%d) %s" % [i + 1, qs.size(), str(q["text"])], opts)


func _heart_answer(node: EncounterNode, i: int, right: bool) -> void:
	if right:
		_heart_ask(node, i + 1)
		return
	var h: Dictionary = dong_phu()[str(_run["id"])]["heart"]
	var loss: float = main.cult.xp_needed() * float(h.get("penalty_xp_frac", 0.03))
	main.cult.xp = maxf(0.0, main.cult.xp - loss)
	main.cult.changed.emit()
	main.hud.flash_hurt()
	main.hud.toast("Tâm ma phản phệ! Mất %d tu vi. Có thể soi lại." % int(loss))


## Gương Thiên Mạch: dựng bản thân với đúng các chiêu đang trang bị; chiêu nào bản thân thuộc lòng thì ít sát thương hơn.
func _summon_mirror(node: EncounterNode) -> void:
	var id := str(_run.get("id", ""))
	var info: Dictionary = dong_phu().get(id, {})
	if info.is_empty():
		return
	if bool(_run.get("done", false)):
		main.dialogue.say(node.display_name, ["Gương đã vỡ vụn. Không còn gì để soi."])
		return
	var clone = _run.get("clone", null)
	if clone != null and is_instance_valid(clone) and clone.alive:
		main.hud.toast("Bản thân ngươi đang đứng trước mặt, ngươi còn muốn soi gì nữa?")
		return
	var st = main.cultivation_v1.state
	var defs: Array = []
	var ids: Array = []
	for slot in ["cong", "cong2", "artifact"]:
		var d: Dictionary = st.def_for(slot)
		if not d.is_empty() and d.has("shape"):
			defs.append(d)
			ids.append(str(d["id"]))
	if defs.is_empty():
		defs.append(CATALOG.definition("kiem_cut"))
	var mr: Dictionary = info["mirror"]
	var mon := Monster.new()
	mon.outfit = (main.wardrobe.equipped as Dictionary).duplicate()
	mon.display_name = "Bản thân"
	mon.setup(main, "mirror_self", Vector2(float(mr["spawn"][0]), float(mr["spawn"][1])))
	mon.set_meta("npc_skills", defs)
	mon.set_meta("mirror_ids", ids)
	mon.set_meta("mirror_resist", float(mr.get("resist", 0.25)))
	if not ("skills" in mon.behaviors):
		mon.behaviors.append("skills")
	main.world.add_child(mon)
	main.monsters.append(mon)
	mon.state = "chase"
	_run["clone"] = mon
	main.hud.toast("Gương nứt ra: bản thân ngươi bước ra, thuộc lòng mọi chiêu ngươi đang dùng.")
	note(str(info["name"]), "Ngươi soi vào gương Thiên Mạch; bản thân bước ra giao đấu.")


func _open_legacy(node: EncounterNode) -> void:
	var id := str(_run["id"])
	var lg: Dictionary = dong_phu()[id]["legacy"]
	var opts: Array = [
		{"text": "Kế thừa truyền thừa", "call": _legacy.bind(id, "inherit")},
		{"text": "Lấy tài vật rồi đi (duyên giảm)", "call": _legacy.bind(id, "loot")},
		{"text": "Chôn cất tiên nhân, để lại động phủ", "call": _legacy.bind(id, "bury")},
		{"text": "Chưa quyết", "call": Callable()},
	]
	main.dialogue.choose(str(lg["name"]), "Bên di hài là một cuốn bí tịch cũ, vài vật phẩm, và một mảnh giấy: \"Người có duyên thì lấy đạo, kẻ vô duyên chỉ lấy của.\"", opts)


func _legacy(id: String, how: String) -> void:
	var info: Dictionary = dong_phu()[id]
	var inherited_ok := how == "inherit" and (duyen >= float((info["legacy"] as Dictionary).get("min_duyen", 0)) or bool(_run.get("heart", false)))
	var lg: Dictionary = info["legacy"]
	match how:
		"inherit":
			var worthy: bool = duyen >= float(lg.get("min_duyen", 0)) or bool(_run.get("heart", false))
			if bool(lg.get("needs_heart", false)) and not bool(_run.get("heart", false)) and duyen < float(lg.get("min_duyen", 0)):
				worthy = false
			if worthy:
				main.cultivation_v1.state.acquire(str(lg["book"]), "dong_phu", str(lg.get("book_quality", "linh")), true)
				for it in (lg.get("items", {"dan_hoi_huyet": 2}) as Dictionary):
					main.inv.add(str(it), int(lg["items"][it]) if lg.has("items") else 2)
				if lg.has("xp_frac"):
					_apply({"type": "xp_frac", "n": float(lg["xp_frac"])}, null)
				main.hud.toast("Truyền thừa: %s (Y → Bí tịch, cần tham ngộ để bổ khuyết)." % str(CATALOG.definition(str(lg["book"])).get("name", "")))
			else:
				main.inv.add("dan_hoi_huyet", 1)
				main.hud.toast("Tiên nhân không nhận kẻ thiếu duyên. Ngươi chỉ lấy được một viên đan.")
				add_duyen(-1.0)
		"loot":
			var lt: Dictionary = lg.get("loot", {"stones": 180, "items": {"yeu_dan": 2}})
			main.inv.add_stones(int(lt.get("stones", 180)))
			for it in (lt.get("items", {}) as Dictionary):
				main.inv.add(str(it), int(lt["items"][it]))
			add_duyen(-6.0)
			main.hud.toast("+%d linh thạch và tài vật. Ngươi cảm thấy có gì đó bị bỏ lại phía sau." % int(lt.get("stones", 180)))
		"bury":
			add_duyen(8.0)
			flags[str(lg.get("bury_flag", "buried_immortal"))] = true
			scheduled.append({"id": "hermit_will", "day": int(main.sect_life.day) + 7})
			main.hud.toast("Ngươi chôn cất tiên nhân. Động phủ lặng đi.")
	# sổ sở hữu: một bản truyền thừa chỉ có một chủ
	main.npc_world.on_player_legacy(id, how if (how != "inherit" or inherited_ok) else "loot")
	var how_text := {"inherit": "Ngươi kế thừa truyền thừa của tiên nhân.", "loot": "Ngươi lấy tài vật của tiên nhân rồi rời đi.", "bury": "Ngươi chôn cất tiên nhân và để lại động phủ."}
	note(str(info["name"]), str(how_text.get(how, "")))
	_run["taken"] = true
	_run["collapse"] = float(info.get("collapse_seconds", 90.0))
	dp_state[id] = {"state": "destroyed", "regen_day": int(main.sect_life.day) + _regen_days()}
	main.hud.toast("Động phủ bắt đầu sụp đổ! Thoát ra trong %d giây." % int(_run["collapse"]))


func _tick_dong_phu(delta: float) -> void:
	var id := str(_run.get("id", ""))
	var info: Dictionary = dong_phu().get(id, {})
	if info.is_empty() or main.current_map != str(info["map"]):
		return
	# hành lang bẫy: trong vùng, mỗi nhịp một tia sét rơi gần người chơi
	if info.has("trap"):
		var tr: Dictionary = info["trap"]
		var r: Array = tr["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if rect.has_point(main.player.position) and not main._dead:
			_run["trap_t"] = float(_run.get("trap_t", 0.0)) - delta
			if float(_run["trap_t"]) <= 0.0:
				_run["trap_t"] = float(tr["interval"])
				var strike := TribulationStrike.new()
				strike.main = main
				strike.damage = Hell.tribulation_damage(1) * float(tr.get("damage_mult", 1.0))
				strike.position = main.player.position + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-24.0, 24.0))
				main.world.add_child(strike)
	var trial := str(info.get("trial", "runes"))
	if trial == "blood" and info.has("pool") and not main._dead:
		# huyết trì: đứng trong vòng thì hồi khí huyết dần
		var pl: Dictionary = info["pool"]
		var pc := Vector2(float(pl["pos"][0]), float(pl["pos"][1]))
		var d: Vector2 = main.player.position - pc
		var rr := float(pl["r"])
		if (d.x / rr) * (d.x / rr) + (d.y / (rr * 0.5)) * (d.y / (rr * 0.5)) <= 1.0:
			main.vitals.heal(main.vitals.max_hp * float(pl.get("heal_frac_per_sec", 0.015)) * delta)
	if (trial == "blood" or trial == "mirror") and not bool(_run.get("done", false)):
		var all_dead := true
		var any := false
		for g in (_run.get("guards", []) as Array):
			any = true
			if is_instance_valid(g) and g.alive:
				all_dead = false
		var clone = _run.get("clone", null)
		if trial == "mirror":
			any = clone != null
			if clone != null and is_instance_valid(clone) and clone.alive:
				all_dead = false
		if any and all_dead:
			_run["done"] = true
			main.hud.toast("Thủ hộ đã bị hạ. Truyền thừa hiện ra.")
			note(str(info["name"]), "Ngươi hạ hết thủ hộ của động phủ.")
	if float(_run.get("collapse", -1.0)) > 0.0:
		var before := float(_run["collapse"])
		_run["collapse"] = before - delta
		for mark in [60.0, 30.0, 10.0]:
			if before > mark and float(_run["collapse"]) <= mark:
				main.hud.toast("Động phủ sắp sập: còn %d giây!" % int(mark))
		if float(_run["collapse"]) <= 0.0:
			_collapse(info)


func _collapse(info: Dictionary) -> void:
	_run = {}
	main.hud.toast("Động phủ sụp đổ! Ngươi bị hất ra ngoài, mất một phần nguyên liệu mang theo.")
	note(str(info["name"]), "Động phủ sụp đổ khi ngươi chưa kịp thoát. Ngươi bị hất ra ngoài, mất một phần nguyên liệu.")
	var held: Array = []
	for mid in Hell.DEATH_MATERIALS:
		if main.inv.count(str(mid)) > 0:
			held.append(str(mid))
	if not held.is_empty():
		var pick: String = held[rng.randi_range(0, held.size() - 1)]
		main.inv.remove(pick, maxi(1, main.inv.count(pick) / 2))
	var region: String = str(info["region"])
	var gp: Array = info["gate_candidates"][0]
	main.travel_to(region, Vector2(float(gp[0]), float(gp[1]) + 120.0))


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "duyen": duyen, "flags": flags.duplicate(), "fragments": fragments.duplicate(), "dp_state": dp_state.duplicate(true),
		"scheduled": scheduled.duplicate(true), "buffs": buffs.duplicate(), "log": log.duplicate(true), "explore_left": _explore_left, "duyen_today": _duyen_today, "last_day": _last_day}


func from_dict(d: Dictionary) -> void:
	duyen = clampf(float(d.get("duyen", 20.0)), 0.0, 100.0)
	flags = (d.get("flags", {}) as Dictionary).duplicate()
	fragments = (d.get("fragments", {}) as Dictionary).duplicate()
	dp_state = (d.get("dp_state", {}) as Dictionary).duplicate(true)
	scheduled = (d.get("scheduled", []) as Array).duplicate(true)
	buffs = (d.get("buffs", {}) as Dictionary).duplicate()
	log = (d.get("log", []) as Array).duplicate(true)
	_explore_left = float(d.get("explore_left", -1.0))
	_duyen_today = float(d.get("duyen_today", 0.0))
	_last_day = int(d.get("last_day", 0))
