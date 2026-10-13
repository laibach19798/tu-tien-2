extends Node
class_name WorldEvents
## Sự kiện thế giới có điều kiện + vòng đời (Thế Giới Mở V1 §6). Dữ liệu: data/world_events.json.
##   CHƯA ĐỦ ĐIỀU KIỆN → DẤU HIỆU / TIN ĐỒN (sign) → ĐANG DIỄN RA (active) → ĐƯỢC GIẢI QUYẾT (resolved) → HẬU QUẢ / DẤU VẾT (trace)
##  - Mỗi lượt có ID riêng (ev_N), mẫu, khu vực, ngày bắt đầu / hạn xử lý, bên tham gia, kết cục và cách xử lý khi người chơi
##    tham gia hoặc bỏ qua. Tối đa 2 sự kiện đồng thời (tránh ngập thông báo).
##  - Sáu mẫu: động phủ cổ tu xuất hiện · thương đội gặp nạn · linh thảo quý trưởng thành · yêu thú tinh anh xuất hiện ·
##    xung đột giữa đệ tử ngoại viện · linh mạch biến động.
##  - NPC tham gia và giải quyết qua NpcWorld (cùng trạng thái, sở hữu vật phẩm đi qua sổ độc nhất); tài nguyên qua ResourceWorld.
##  - Hậu quả để lại "dấu vết" trên khu vực (hiện ở bản đồ đại vực) và tin tức; mọi thứ lưu/tải được.

signal changed

const DATA_PATH := "res://data/world_events.json"

var main: Node
var events: Array = []             # các lượt đang diễn ra (state: sign | active)
var history: Array = []            # các lượt đã giải quyết
var traces: Array = []             # dấu vết: [{loc, text, day, until}]
var cooldown: Dictionary = {}      # mẫu -> ngày được phép lặp lại
var next_id := 1
var next_spawn := 0

var _data: Dictionary = {}
var _last_day := 0
var _timer := 0.0
var _sync_map := ""
var _dirty := true
var _runtime: Dictionary = {}      # iid -> {"nodes": [], "guards": []} (chỉ trong phiên chơi, tái dựng theo trạng thái)


func _ready() -> void:
	add_to_group("world_events")
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)


# ---------------------------------------------------------------- truy cập
func templates() -> Dictionary:
	return _data.get("templates", {})


func tpl(id: String) -> Dictionary:
	return templates().get(id, {})


func balance(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


func _seeded(key: String, day: int, salt := "") -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(("%s|%d|%s" % [key, day, salt]).hash())
	return r


func active_at(loc: String) -> Array:
	var out: Array = []
	for e in events:
		if str(e["loc"]) == loc:
			out.append(e)
	return out


func active_of(tpl_id: String) -> Array:
	var out: Array = []
	for e in events:
		if str(e["tpl"]) == tpl_id and str(e["state"]) == "active":
			out.append(e)
	return out


func traces_at(loc: String) -> Array:
	var out: Array = []
	for t in traces:
		if str(t["loc"]) == loc and (int(t.get("until", 0)) <= 0 or int(t["until"]) >= today()):
			out.append(t)
	return out


## Nguy hiểm hiệu lực của một địa điểm (tính cả yêu thú tinh anh đang uy hiếp).
func danger_of(loc: String, base: int) -> int:
	var d := base
	for e in events:
		if str(e["loc"]) == loc and str(e["tpl"]) == "yeu_thu_tinh_anh" and str(e["state"]) == "active":
			d += 1
	return d


## Linh mạch biến động: lệch mức linh khí của địa điểm (±1) khi sự kiện đang diễn ra.
func qi_mod(loc: String) -> int:
	for e in events:
		if str(e["loc"]) == loc and str(e["tpl"]) == "linh_mach_bien_dong" and str(e["state"]) == "active":
			return int(e["data"].get("mod", 1))
	return 0


## Hệ số thời gian tái sinh tài nguyên của một map: linh khí dồi dào thì nhanh hơn, suy giảm thì chậm hơn.
func regrow_mult(map_id: String) -> float:
	for e in events:
		if str(e["tpl"]) == "linh_mach_bien_dong" and str(e["state"]) == "active" and str(main.province.info(str(e["loc"])).get("map", "")) == map_id:
			return 0.5 if int(e["data"].get("mod", 1)) > 0 else 2.0
	return 1.0


func _loc_name(loc: String) -> String:
	return main.province.display_name(loc)


func _note_news(text: String) -> void:
	main.province.add_news(text)


# ---------------------------------------------------------------- vòng lặp
func _process(delta: float) -> void:
	if main == null or _data.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var day := today()
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		for d in range(_last_day + 1, day + 1):
			_daily(d)
		_last_day = day
		_dirty = true
	_poll()
	if _dirty or str(main.current_map) != _sync_map:
		_sync_scene()


func _daily(day: int) -> void:
	# tiến triển các lượt đang chạy
	for e in events.duplicate():
		if str(e["state"]) == "sign" and day >= int(e["active_from"]):
			_activate(e, day)
		if str(e["state"]) == "active":
			if not _progress(e, day) and day >= int(e["deadline"]):
				_expire(e, day)
	# sinh lượt mới
	if events.size() < int(balance("max_active", 2.0)) and day >= maxi(int(balance("first_day", 2.0)), next_spawn):
		_try_spawn(day)
		var gap: Array = (_data.get("balance", {}) as Dictionary).get("gap_days", [4, 8])
		var r := _seeded("gap", day)
		next_spawn = day + r.randi_range(int(gap[0]), int(gap[1]))


func _try_spawn(day: int) -> void:
	if events.size() >= int(balance("max_active", 2.0)):
		return
	var pool: Array = []
	var total := 0.0
	for id in templates():
		var t: Dictionary = templates()[id]
		if day < int(t.get("min_day", 0)) or day < int(cooldown.get(id, 0)):
			continue
		if _running(str(id)):
			continue
		if _pick_location(str(id), day) == "":
			continue
		pool.append(str(id))
		total += float(t.get("weight", 1))
	if pool.is_empty():
		return
	var r := _seeded("spawn", day)
	var roll := r.randf() * total
	var chosen: String = pool[0]
	for id in pool:
		roll -= float(templates()[id].get("weight", 1))
		if roll <= 0.0:
			chosen = str(id)
			break
	spawn(chosen, day)


func _running(tpl_id: String) -> bool:
	for e in events:
		if str(e["tpl"]) == tpl_id:
			return true
	return false


## Chọn địa điểm hợp lệ cho mẫu ("" nếu chưa có).
func _pick_location(tpl_id: String, day: int) -> String:
	var t: Dictionary = tpl(tpl_id)
	var r := _seeded(tpl_id, day, "loc")
	if tpl_id == "co_tu_dong_phu":
		var dp := _pick_dong_phu(day)
		return str(dp.get("loc", "")) if not dp.is_empty() else ""
	var zones: Array = t.get("zones", [])
	if zones.is_empty():
		return ""
	var cand: Array = []
	for z in zones:
		if main.province.locations().has(str(z)):
			# không dồn hai sự kiện vào cùng một nơi
			var busy := false
			for e in events:
				busy = busy or str(e["loc"]) == str(z)
			if not busy:
				cand.append(str(z))
	if cand.is_empty():
		return ""
	if tpl_id == "xung_dot_de_tu" and _pick_pair().is_empty():
		return ""
	return cand[r.randi_range(0, cand.size() - 1)]


func _pick_dong_phu(day: int) -> Dictionary:
	var dest = main.destiny
	var step: int = main.cult.step_index()
	var cand: Array = []
	for id in dest.dong_phu():
		var info: Dictionary = dest.dong_phu()[id]
		var st: Dictionary = dest.dp_state.get(id, {"state": "sealed"})
		if str(st["state"]) != "sealed":
			continue
		if int(info.get("min_step", 0)) > step + 3:
			continue
		var taken := false
		for e in events:
			taken = taken or (str(e["tpl"]) == "co_tu_dong_phu" and str(e["data"].get("dp", "")) == str(id))
		if taken:
			continue
		var region := str(info.get("region", ""))
		var loc := ""
		for lid in main.province.locations():
			if str(main.province.info(str(lid)).get("map", "")) == region and not bool(main.province.info(str(lid)).get("dong_phu", false)):
				loc = str(lid)
				break
		if loc != "":
			cand.append({"dp": str(id), "loc": loc})
	if cand.is_empty():
		return {}
	var r := _seeded("dp", day)
	return cand[r.randi_range(0, cand.size() - 1)]


func _pick_pair() -> Array:
	var ids: Array = []
	for id in main.npc_world.roster():
		var d: Dictionary = main.npc_world.roster()[id]
		if str(d.get("sect", "")) != "" and str(main.npc_world.states[id].get("status", "ok")) == "ok":
			ids.append(str(id))
	for a in ids:
		for b in ids:
			if str(main.npc_world.roster()[a].get("sect", "")) != str(main.npc_world.roster()[b].get("sect", "")):
				return [a, b]
	return []


# ---------------------------------------------------------------- tạo lượt và các pha
func spawn(tpl_id: String, day: int, loc_override := "") -> Dictionary:
	var t: Dictionary = tpl(tpl_id)
	if t.is_empty():
		return {}
	var loc := loc_override if loc_override != "" else _pick_location(tpl_id, day)
	if loc == "":
		return {}
	var e := {
		"id": "ev_%d" % next_id, "tpl": tpl_id, "state": "sign", "loc": loc, "start": day,
		"active_from": day + int(t.get("sign_days", 0)), "deadline": day + int(t.get("sign_days", 0)) + int(t.get("active_days", 2)),
		"data": {}, "outcome": "", "participants": [],
	}
	next_id += 1
	match tpl_id:
		"co_tu_dong_phu":
			var dp := _pick_dong_phu(day) if loc_override == "" else {}
			if loc_override != "":
				for id in main.destiny.dong_phu():
					if str(main.destiny.dong_phu()[id].get("region", "")) == str(main.province.info(loc).get("map", "")):
						dp = {"dp": str(id), "loc": loc}
						break
			if dp.is_empty():
				return {}
			e["data"] = {"dp": str(dp["dp"])}
		"xung_dot_de_tu":
			var pair := _pick_pair()
			if pair.is_empty():
				return {}
			e["data"] = {"a": pair[0], "b": pair[1]}
		"linh_mach_bien_dong":
			var r := _seeded(str(e["id"]), day, "mod")
			e["data"] = {"mod": 1 if r.randf() < 0.65 else -1}
		"thuong_doi_nan":
			e["data"] = {"started": false}
	events.append(e)
	_announce_sign(e)
	if int(e["active_from"]) <= day:
		_activate(e, day)
	_dirty = true
	changed.emit()
	return e


func _announce_sign(e: Dictionary) -> void:
	var t: Dictionary = tpl(str(e["tpl"]))
	var text := str(t.get("sign_text", "")) % _loc_name(str(e["loc"]))
	_note_news(text)
	var loc := str(e["loc"])
	if str(e["tpl"]) == "co_tu_dong_phu":
		var dp := str(e["data"]["dp"])
		main.province.add_rumor(dp, str(main.province.info(dp).get("rumor", "")), "dị tượng", "medium")
	elif main.province.state_of(loc) == World.UNKNOWN and not bool(main.province.info(loc).get("hidden", false)):
		main.province.add_rumor(loc, "", "tin đồn trên đường", "medium")
	if main.hud != null:
		main.hud.toast("Tin tức: " + str(tpl(str(e["tpl"])).get("name", "")))


func _activate(e: Dictionary, day: int) -> void:
	e["state"] = "active"
	var t: Dictionary = tpl(str(e["tpl"]))
	var loc := str(e["loc"])
	_note_news(str(t.get("active_text", "")) % _loc_name(loc))
	match str(e["tpl"]):
		"co_tu_dong_phu":
			var dp := str(e["data"]["dp"])
			var info: Dictionary = main.destiny.dong_phu()[dp]
			# thương hội biết tin: kẻ tầm bảo kéo tới; cửa động mở trong hạn
			for id in main.npc_world.roster():
				if bool(main.npc_world.roster()[id].get("treasure_hunter", false)):
					var st: Dictionary = main.npc_world.states[id]
					if str(st["status"]) == "ok":
						st["loc"] = loc
						st["act"] = "hunt"
						st["until"] = int(e["deadline"])
						(e["participants"] as Array).append(str(id))
						main.npc_world._note(str(id), "Nghe tin %s sắp mở, kéo tới %s." % [str(info["name"]), _loc_name(loc)], false, day)
			main.destiny.fragments[dp] = int(info["fragments"])
			main.province.discover(dp, "động phủ lộ ra")
			if str(main.current_map) == str(info["region"]):
				main.destiny._spawn_gate_if_here()
		"xung_dot_de_tu":
			for k in ["a", "b"]:
				var id := str(e["data"][k])
				var st: Dictionary = main.npc_world.states[id]
				st["loc"] = loc
				st["act"] = "rest"
				st["until"] = int(e["deadline"])
				(e["participants"] as Array).append(id)
				main.npc_world._note(id, "Tranh cãi gay gắt với một đệ tử phái khác ở %s." % _loc_name(loc), false, day)
		"linh_thao_quy":
			e["data"]["node_id"] = "%s:linh_thao_quy:%s" % [str(main.province.info(loc).get("map", "")), str(e["id"])]
		"thuong_doi_nan":
			if main.npc_world.states.has("phu_quy"):
				var st2: Dictionary = main.npc_world.states["phu_quy"]
				st2["loc"] = loc
				st2["act"] = "trade"
				st2["until"] = int(e["deadline"]) + 1
				(e["participants"] as Array).append("phu_quy")
	_dirty = true
	changed.emit()


## Tiến triển mỗi ngày của lượt đang diễn ra. Trả true nếu đã tự giải quyết.
func _progress(e: Dictionary, day: int) -> bool:
	var loc := str(e["loc"])
	var danger: int = danger_of(loc, int(main.province.info(loc).get("danger", 1)))
	match str(e["tpl"]):
		"co_tu_dong_phu":
			var dp := str(e["data"]["dp"])
			var st: Dictionary = main.destiny.dp_state.get(dp, {"state": "sealed"})
			if str(st["state"]) == "open":
				resolve(e, "player_entered", "player")
				return true
			if str(st["state"]) == "destroyed":
				resolve(e, "npc_took", "npc")
				return true
		"thuong_doi_nan", "yeu_thu_tinh_anh":
			# NPC đủ mạnh có mặt ở đó thì ra tay giải quyết (người chơi chưa kịp tới)
			if day <= int(e["active_from"]):
				return false
			var need := danger + (1 if str(e["tpl"]) == "thuong_doi_nan" else 2)
			for id in main.npc_world.roster():
				var st: Dictionary = main.npc_world.states[id]
				if str(st["loc"]) != loc or str(st["status"]) != "ok" or str(id) == "phu_quy":
					continue
				if int(main.npc_world.roster()[id].get("strength", 2)) >= need and _seeded(str(e["id"]), day, str(id)).randf() < 0.3:
					e["data"]["by"] = str(id)
					resolve(e, "npc_rescued" if str(e["tpl"]) == "thuong_doi_nan" else "npc_killed", "npc:" + str(id))
					return true
		"linh_thao_quy":
			var nid := str(e["data"].get("node_id", ""))
			if main.resources.states.has(nid):
				var by := str(main.resources.states[nid].get("by", ""))
				resolve(e, "claimed", by)
				return true
	return false


func _expire(e: Dictionary, day: int) -> void:
	var out := {
		"co_tu_dong_phu": "npc_took", "thuong_doi_nan": "lost", "linh_thao_quy": "withered",
		"yeu_thu_tinh_anh": "retreated", "xung_dot_de_tu": "fought", "linh_mach_bien_dong": "settled",
	}
	if str(e["tpl"]) == "co_tu_dong_phu":
		# người chơi bỏ lỡ: kẻ tầm bảo mở cửa trước
		var dp := str(e["data"]["dp"])
		var st: Dictionary = main.destiny.dp_state.get(dp, {"state": "sealed"})
		if str(st["state"]) == "open":
			resolve(e, "player_entered", "player")
			return
		if str(st["state"]) == "sealed":
			main.destiny._rival_takes(dp, day)
	resolve(e, str(out.get(str(e["tpl"]), "ended")), "time")


# ---------------------------------------------------------------- giải quyết + hậu quả
func resolve(e: Dictionary, outcome: String, by := "") -> void:
	if str(e["state"]) == "resolved":
		return
	e["state"] = "resolved"
	e["outcome"] = outcome
	e["by"] = by
	e["end_day"] = today()
	_consequence(e)
	history.append({"id": e["id"], "tpl": e["tpl"], "loc": e["loc"], "start": e["start"], "end": today(), "outcome": outcome, "by": by})
	while history.size() > int(balance("history_limit", 40.0)):
		history.pop_front()
	events.erase(e)
	var cd := int(tpl(str(e["tpl"])).get("cooldown_days", 10))
	cooldown[str(e["tpl"])] = today() + cd
	_free_runtime(str(e["id"]))
	_dirty = true
	changed.emit()


func _trace(loc: String, text: String, days := -1) -> void:
	var d := today()
	traces.append({"loc": loc, "text": text, "day": d, "until": d + (days if days > 0 else int(balance("trace_days", 20.0)))})
	while traces.size() > int(balance("trace_limit", 24.0)):
		traces.pop_front()


func _npc_name(id: String) -> String:
	return main.npc_world.display_name(id.trim_prefix("npc:"))


func _consequence(e: Dictionary) -> void:
	var loc := str(e["loc"])
	var nm := _loc_name(loc)
	var out := str(e["outcome"])
	var by := str(e.get("by", ""))
	match str(e["tpl"]):
		"co_tu_dong_phu":
			var dpn := str(main.destiny.dong_phu()[str(e["data"]["dp"])].get("name", ""))
			if out == "player_entered":
				_note_news("Có người đã vào %s trước hạn, tranh đoạt không còn." % dpn)
				_trace(loc, "%s đã được mở. Dấu chân tu sĩ in đầy cửa động." % dpn)
			else:
				_note_news("Truyền thừa %s đã bị đoạt trước; kẻ giành được đang bế quan." % dpn)
				_trace(loc, "%s sập đổ sau khi bị người khác mở trước." % dpn)
		"thuong_doi_nan":
			match out:
				"rescued":
					_note_news("Thương đội ở %s được người chơi cứu thoát." % nm)
					_trace(loc, "Dấu xe thương đội đã yên; yêu thú bị đẩy lui.")
				"looted":
					_note_news("Thương đội ở %s bị cướp sạch." % nm)
					_trace(loc, "Hàng hoá thương đội vương vãi khắp nơi; lời đồn về kẻ cướp lan ra.")
					_adjust_rel("phu_quy", -15)
				"npc_rescued":
					_note_news("%s đã giải cứu thương đội ở %s." % [_npc_name(by), nm])
					_adjust_rel("phu_quy", 5)
					_npc_reward(by, 60, {"da_yeu": 2})
				_:
					_note_news("Thương đội ở %s bị yêu thú nuốt chửng, không ai cứu." % nm)
					_trace(loc, "Xác xe và hàng hoá vỡ nát nằm lại bên đường.")
					if main.npc_world.states.has("phu_quy"):
						var st: Dictionary = main.npc_world.states["phu_quy"]
						st["assets"] = {}
						st["status"] = "injured"
						st["status_until"] = today() + 3
						st["loc"] = "van_khe"
						main.npc_world._note("phu_quy", "Bị yêu thú vây ở %s, mất sạch hàng hoá và phải dưỡng thương." % nm, false)
		"linh_thao_quy":
			if out == "claimed":
				if by == "player":
					_note_news("Có người đã hái được linh thảo quý ở %s." % nm)
				else:
					_note_news("%s đã hái được linh thảo quý ở %s." % [_npc_name(by), nm])
				_trace(loc, "Chỗ linh thảo quý đã trống; chỉ còn rễ cũ.", 10)
			else:
				var nid := str(e["data"].get("node_id", ""))
				main.resources.states[nid] = {"regrow_day": today() + 9999, "gone": true, "by": "wither", "day": today()}
				_note_news("Linh thảo quý ở %s héo úa vì không ai thu hái kịp." % nm)
				_trace(loc, "Một mảng linh thảo héo úa vì không ai hái kịp.", 10)
		"yeu_thu_tinh_anh":
			if out == "player_killed":
				_note_news("Yêu thú tinh anh ở %s đã bị hạ; tuyến đường lại thông." % nm)
				_trace(loc, "Xác yêu thú tinh anh đã bị xử lý; vết móng còn lại ven đường.")
			elif out == "npc_killed":
				_note_news("%s đã săn được yêu thú tinh anh ở %s." % [_npc_name(by), nm])
				_npc_reward(by, 80, {"yeu_dan": 3, "da_yeu": 2})
				_trace(loc, "Nơi yêu thú tinh anh từng chiếm lĩnh đã yên.")
			else:
				_note_news("Yêu thú tinh anh ở %s đã bỏ đi; chưa rõ nó đi đâu." % nm)
				_trace(loc, "Dấu chân lớn dẫn ra xa; yêu thú tinh anh đã rời vùng.", 10)
		"xung_dot_de_tu":
			var a := str(e["data"].get("a", ""))
			var b := str(e["data"].get("b", ""))
			match out:
				"mediated":
					_note_news("Hai đệ tử tranh cãi ở %s được người chơi hoà giải." % nm)
					_adjust_rel(a, 3)
					_adjust_rel(b, 3)
				"side_a", "side_b":
					var win := a if out == "side_a" else b
					var lose := b if out == "side_a" else a
					_adjust_rel(win, 6)
					_adjust_rel(lose, -6)
					_note_news("%s được người chơi đứng về phía mình trong cuộc tranh cãi ở %s." % [main.npc_world.display_name(win), nm])
				_:
					for id in [a, b]:
						var st: Dictionary = main.npc_world.states[id]
						st["status"] = "injured"
						st["status_until"] = today() + 2
						main.npc_world._note(id, "Đánh nhau với đệ tử phái khác ở %s, cả hai đều bị thương." % nm, false)
					_note_news("Hai đệ tử ở %s đánh nhau trọng thương; danh tiếng ngoại viện hai phái bị tổn hại." % nm)
					_trace(loc, "Vết máu và dụng cụ vỡ sau cuộc ẩu đả giữa hai đệ tử.", 8)
		"linh_mach_bien_dong":
			var mod := int(e["data"].get("mod", 1))
			_note_news("Linh mạch ở %s đã lắng xuống%s." % [nm, " (linh khí dồi dào hơn trước)" if mod > 0 else " (linh khí cạn bớt)"])
			_trace(loc, "Linh mạch lắng lại; vết dao động còn lưu trong vách đá.", 12)
			if out != "observed":
				_clue(loc)


## Dao động linh mạch để lộ manh mối: tin đồn về một nơi còn ẩn.
func _clue(loc: String) -> void:
	var hidden: Array = []
	for id in main.province.locations():
		if bool(main.province.info(str(id)).get("hidden", false)) and main.province.state_of(str(id)) == World.UNKNOWN:
			hidden.append(str(id))
	if hidden.is_empty():
		return
	hidden.sort()
	var r := _seeded(loc, today(), "clue")
	var pick: String = hidden[r.randi_range(0, hidden.size() - 1)]
	main.province.add_rumor(pick, "Dao động linh mạch ở %s để lộ một dấu vết dẫn tới nơi chưa ai tới." % _loc_name(loc), "dao động linh mạch", "medium")


func _adjust_rel(id: String, n: int, text := "") -> void:
	if main.npc_world.states.has(id):
		main.npc_world.adjust_affinity(id, n, text if text != "" else ("Ngươi đứng về phía ta trong một sự kiện." if n > 0 else "Ngươi làm ta thiệt thòi trong một sự kiện."))


func _npc_reward(by: String, money: int, items: Dictionary) -> void:
	var id := by.trim_prefix("npc:")
	if not main.npc_world.states.has(id):
		return
	var st: Dictionary = main.npc_world.states[id]
	st["money"] = int(st["money"]) + money
	for k in items:
		st["assets"][k] = int(st["assets"].get(k, 0)) + int(items[k])
	main.npc_world._note(id, "Được thưởng %d linh thạch và vật liệu sau khi giải quyết sự kiện." % money, false)


# ---------------------------------------------------------------- hiện trong scene
func _anchor(loc: String) -> Vector2:
	var li: Dictionary = main.province.info(loc)
	if li.has("at"):
		return Vector2(float(li["at"][0]), float(li["at"][1]))
	return main.map_def.get("entry", Vector2(400, 400)) as Vector2


func _find_spot(anchor: Vector2, seed_key: String, lo := 140.0, hi := 320.0) -> Vector2:
	var r := _seeded(seed_key, 0, "spot")
	for i in 40:
		var p := anchor + Vector2.from_angle(r.randf() * TAU) * r.randf_range(lo, hi)
		if not main._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 50)):
			return p
	return anchor


func _free_runtime(iid: String) -> void:
	var rt: Dictionary = _runtime.get(iid, {})
	for n in rt.get("nodes", []):
		if is_instance_valid(n):
			main.npcs.erase(n)
			main.herbs.erase(n)
			n.queue_free()
	for g in rt.get("guards", []):
		if is_instance_valid(g) and g.alive and bool(g.get_meta("world_event_guard", false)):
			g.queue_free()
			main.monsters.erase(g)
	_runtime.erase(iid)


func _sync_scene() -> void:
	_dirty = false
	_sync_map = str(main.current_map)
	if main.player == null:
		return
	for e in events:
		var iid := str(e["id"])
		var rt: Dictionary = _runtime.get(iid, {"nodes": [], "guards": []})
		rt["nodes"] = (rt["nodes"] as Array).filter(func(n): return is_instance_valid(n) and n.is_inside_tree())
		rt["guards"] = (rt["guards"] as Array).filter(func(g): return is_instance_valid(g) and g.is_inside_tree())
		_runtime[iid] = rt
		if str(e["state"]) != "active":
			continue
		var loc := str(e["loc"])
		if str(main.province.info(loc).get("map", "")) != _sync_map:
			continue
		var anchor := _anchor(loc)
		var li: Dictionary = main.province.info(loc)
		if li.has("at") and anchor.distance_to(main.player.position) > float(li.get("r", 600.0)) + 1200.0:
			continue
		match str(e["tpl"]):
			"thuong_doi_nan", "xung_dot_de_tu", "linh_mach_bien_dong":
				if (rt["nodes"] as Array).is_empty():
					var label: String = {"thuong_doi_nan": "Thương đội bị phục kích", "xung_dot_de_tu": "Hai đệ tử đang tranh cãi", "linh_mach_bien_dong": "Điểm linh mạch dao động"}[str(e["tpl"])]
					var prompt: String = {"thuong_doi_nan": "Xem tình hình thương đội", "xung_dot_de_tu": "Can thiệp vụ tranh cãi", "linh_mach_bien_dong": "Quan sát dao động"}[str(e["tpl"])]
					var glow: Array = {"thuong_doi_nan": [1.0, 0.7, 0.3], "xung_dot_de_tu": [1.0, 0.45, 0.45], "linh_mach_bien_dong": [0.5, 0.95, 1.0]}[str(e["tpl"])]
					var node := EncounterNode.new()
					node.setup("wev_" + iid, {"name": label, "kind": "prop", "sprite": "res://assets/events/%s.png" % str(e["tpl"]), "prompt": prompt, "glow": glow})
					node.position = _find_spot(anchor, iid)
					main.world.add_child(node)
					main.npcs.append(node)
					(rt["nodes"] as Array).append(node)
				if str(e["tpl"]) == "thuong_doi_nan" and bool(e["data"].get("started", false)) and (rt["guards"] as Array).is_empty() and not bool(e["data"].get("cleared", false)):
					_spawn_guards(e, rt)
			"linh_thao_quy":
				if (rt["nodes"] as Array).is_empty() and not main.resources.states.has(str(e["data"].get("node_id", ""))):
					var rn: Node2D = main.resources.make_node_id(str(e["data"]["node_id"]), "linh_thao_quy", _find_spot(anchor, iid, 100.0, 280.0))
					if rn != null:
						main.world.add_child(rn)
						main.herbs.append(rn)
						(rt["nodes"] as Array).append(rn)
			"yeu_thu_tinh_anh":
				var alive := false
				for g in rt["guards"]:
					alive = alive or (is_instance_valid(g) and g.alive)
				if not alive and not bool(e["data"].get("spawned_dead", false)):
					var kind_map: Dictionary = tpl("yeu_thu_tinh_anh").get("elite_kind", {})
					var kind := str(kind_map.get(loc, "wolf_alpha"))
					if Monster.KINDS.has(kind):
						var m := Monster.new()
						m.setup(main, kind, _find_spot(anchor, iid, 220.0, 420.0))
						m.tier = maxi(m.tier, Hell.ELITE_MIN_TIER)
						var tries := 0
						while not m.elite and tries < 400:
							MonsterBehaviors._roll_elite(m)
							tries += 1
						m.set_meta("world_event", iid)
						main.world.add_child(m)
						main.monsters.append(m)
						(rt["guards"] as Array).append(m)
						main.hud.toast("Yêu thú tinh anh đang canh giữ vùng này!")


## Quái canh thương đội bị bắt đầu cứu: rải quanh node thương đội.
func _spawn_guards(e: Dictionary, rt: Dictionary) -> void:
	var loc := str(e["loc"])
	var pos: Vector2 = _anchor(loc)
	if not (rt["nodes"] as Array).is_empty() and is_instance_valid(rt["nodes"][0]):
		pos = (rt["nodes"][0] as Node2D).position
	var kinds := {"soi_linh": "wolf", "hac_lam": "wolf_dark", "dam_lay": "goblin"}
	var kind: String = str(kinds.get(loc, "wolf"))
	for i in 3:
		var m := Monster.new()
		m.setup(main, kind, pos + Vector2.from_angle(TAU * float(i) / 3.0) * 110.0)
		m.set_meta("world_event_guard", true)
		m.set_meta("world_event", str(e["id"]))
		main.world.add_child(m)
		main.monsters.append(m)
		m.state = "chase"
		(rt["guards"] as Array).append(m)


# ---------------------------------------------------------------- người chơi tương tác
func open(node: EncounterNode) -> void:
	var iid := node.enc_id.trim_prefix("wev_")
	var e: Dictionary = {}
	for x in events:
		if str(x["id"]) == iid:
			e = x
	if e.is_empty():
		return
	main.meditating = false
	match str(e["tpl"]):
		"thuong_doi_nan":
			_open_caravan(e)
		"xung_dot_de_tu":
			_open_dispute(e)
		"linh_mach_bien_dong":
			_open_surge(e)


func _open_caravan(e: Dictionary) -> void:
	var nm := _loc_name(str(e["loc"]))
	var started := bool(e["data"].get("started", false))
	var opts: Array = []
	if not started:
		opts.append({"text": "Ra tay cứu thương đội (có giao chiến)", "call": _caravan_rescue.bind(str(e["id"]))})
	else:
		opts.append({"text": "Bọn yêu thú vẫn chưa bị hạ hết…", "call": Callable()})
	opts.append({"text": "Nhân lúc hỗn loạn cướp hàng hoá (duyên giảm)", "call": _caravan_loot.bind(str(e["id"]))})
	opts.append({"text": "Bỏ mặc, đi tiếp", "call": Callable()})
	main.dialogue.choose("Thương đội bị phục kích", "Xe hàng của thương đội đổ nghiêng ở %s, người đánh xe nấp sau hòm hàng, yêu thú đang vây quanh." % nm, opts)


func _event_by_id(iid: String) -> Dictionary:
	for x in events:
		if str(x["id"]) == iid:
			return x
	return {}


func _caravan_rescue(iid: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty() or bool(e["data"].get("started", false)):
		return
	e["data"]["started"] = true
	_dirty = true
	_sync_scene()
	main.hud.toast("Yêu thú ập tới! Hạ hết chúng để cứu thương đội.")


func _caravan_loot(iid: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty():
		return
	main.inv.add_stones(120)
	main.inv.add("da_yeu", 3)
	main.inv.add("soi_nanh", 2)
	main.destiny.add_duyen(-5.0)
	main.hud.toast("+120 linh thạch, +3 da yêu, +2 nanh sói. Ngươi thấy có gì đó nặng trĩu trong lòng.")
	resolve(e, "looted", "player")


func _open_dispute(e: Dictionary) -> void:
	var a := str(e["data"]["a"])
	var b := str(e["data"]["b"])
	var an: String = main.npc_world.display_name(a)
	var bn: String = main.npc_world.display_name(b)
	main.dialogue.choose("Tranh cãi", "%s và %s đang cãi nhau về chuyện phân chia vật liệu thu được; lời qua tiếng lại, sắp ra tay." % [an, bn], [
		{"text": "Hoà giải hai bên", "call": _dispute_mediate.bind(str(e["id"]))},
		{"text": "Đứng về phía %s" % an, "call": _dispute_side.bind(str(e["id"]), "side_a")},
		{"text": "Đứng về phía %s" % bn, "call": _dispute_side.bind(str(e["id"]), "side_b")},
		{"text": "Mặc kệ", "call": Callable()},
	])


func _dispute_mediate(iid: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty():
		return
	main.destiny.add_duyen(2.0)
	main.dialogue.say("Hoà giải", ["Ngươi nói vài lời phải trái. Hai bên hậm hực nhưng cuối cùng cũng thôi."])
	resolve(e, "mediated", "player")


func _dispute_side(iid: String, outcome: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty():
		return
	main.dialogue.say("Đứng về một phía", ["Bên bị bỏ rơi trừng mắt nhìn ngươi, nhưng không dám ra tay."])
	resolve(e, outcome, "player")


func _open_surge(e: Dictionary) -> void:
	main.dialogue.choose("Linh mạch dao động", "Linh khí quanh đây cuộn thành sóng, đá và rễ cây như đang thở. Có thể quan sát kỹ hoặc hấp thu tại chỗ.", [
		{"text": "Quan sát kỹ (có thể ra manh mối)", "call": _surge_observe.bind(str(e["id"]))},
		{"text": "Ngồi thiền hấp thu (một lần)", "call": _surge_absorb.bind(str(e["id"]))},
		{"text": "Rời đi", "call": Callable()},
	])


func _surge_observe(iid: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty():
		return
	main.destiny.add_duyen(1.0)
	_clue(str(e["loc"]))
	main.dialogue.say("Quan sát", ["Ngươi lần theo nhịp dao động, thấy nó chỉ về một hướng chưa ai để ý."])
	resolve(e, "observed", "player")


func _surge_absorb(iid: String) -> void:
	var e := _event_by_id(iid)
	if e.is_empty() or bool(e["data"].get("absorbed", false)):
		main.hud.toast("Chỗ này ngươi đã hấp thu rồi.")
		return
	e["data"]["absorbed"] = true
	var tier := int(main.map_def.get("tier", 0))
	var gain: float = main.cult.xp_needed() * 0.01 * Hell.reward_factor(main.cult.step_index(), tier) * (1.0 if int(e["data"].get("mod", 1)) > 0 else 0.5)
	main.cult.add_xp(gain)
	main.hud.toast("Hấp thu dao động linh mạch: +%d tu vi." % int(gain))


## Người chơi hạ được yêu thú sự kiện hoặc quái canh thương đội.
func on_monster_killed(m: Node) -> void:
	if not m.has_meta("world_event"):
		return
	var e := _event_by_id(str(m.get_meta("world_event")))
	if e.is_empty():
		return
	if str(e["tpl"]) == "yeu_thu_tinh_anh":
		e["data"]["spawned_dead"] = true
		main.inv.add("yeu_dan", 2)
		main.inv.add("da_yeu", 2)
		main.hud.toast("+2 yêu đan, +2 da yêu từ yêu thú tinh anh.")
		resolve(e, "player_killed", "player")
	elif str(e["tpl"]) == "thuong_doi_nan":
		var rt: Dictionary = _runtime.get(str(e["id"]), {})
		var left := 0
		for g in rt.get("guards", []):
			if is_instance_valid(g) and g != m and g.alive:
				left += 1
		if left == 0 and bool(e["data"].get("started", false)):
			e["data"]["cleared"] = true
			main.inv.add_stones(90)
			main.inv.add("linh_thao", 2)
			main.inv.add("da_yeu", 2)
			main.destiny.add_duyen(4.0)
			_adjust_rel("phu_quy", 10)
			main.hud.toast("Thương đội được cứu! +90 linh thạch, +2 linh thảo, +2 da yêu.")
			resolve(e, "rescued", "player")


func _poll() -> void:
	# kiểm tra các lượt cần người chơi/thế giới thay đổi trạng thái giữa hai ngày
	for e in events.duplicate():
		if str(e["state"]) != "active":
			continue
		if str(e["tpl"]) == "linh_thao_quy" or str(e["tpl"]) == "co_tu_dong_phu":
			_progress(e, today())


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "events": events.duplicate(true), "history": history.duplicate(true), "traces": traces.duplicate(true),
		"cooldown": cooldown.duplicate(), "next_id": next_id, "next_spawn": next_spawn, "last_day": _last_day}


func from_dict(d: Dictionary) -> void:
	for iid in _runtime.keys():
		_free_runtime(str(iid))
	events = (d.get("events", []) as Array).duplicate(true)
	history = (d.get("history", []) as Array).duplicate(true)
	traces = (d.get("traces", []) as Array).duplicate(true)
	cooldown = (d.get("cooldown", {}) as Dictionary).duplicate()
	next_id = int(d.get("next_id", 1))
	next_spawn = int(d.get("next_spawn", 0))
	_last_day = int(d.get("last_day", 0))
	# lượt thuộc mẫu đã bị xoá khỏi dữ liệu thì bỏ
	events = events.filter(func(x): return templates().has(str(x.get("tpl", ""))))
	_dirty = true
