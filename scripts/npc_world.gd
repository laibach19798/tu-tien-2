extends Node
class_name NpcWorld
## NPC trong thế giới mở (thiết kế Thế Giới Mở V1 §7) và quyền sở hữu vật phẩm độc nhất. Dữ liệu: data/npcs.json.
##  - Hai cấp mô phỏng: NPC TRONG scene (nút EncounterNode kiểu "figure", nói chuyện/giao dịch được) và NPC NGOÀI scene
##    (chỉ cập nhật theo lịch hoạt động + ngày game, không đi từng bước). Cùng một trạng thái; nút chỉ là hình chiếu.
##  - Mỗi NPC có vị trí (id địa điểm của World), hoạt động đang làm (thu thập / săn / buôn / nghỉ), tài sản, linh thạch,
##    quan hệ với người chơi, lịch sử có nguyên nhân rõ ràng. Mọi thay đổi trạng thái đều ghi lý do.
##  - Vật phẩm độc nhất (truyền thừa động phủ, di vật cổ tu) đi qua sổ đăng ký: một ID gốc chỉ có MỘT chủ ở một thời điểm,
##    chuyển chủ phải khai báo chủ cũ nên không nhân bản qua chuyển scene hay lưu/tải.
##  - Tài nguyên NPC lấy đi qua ResourceWorld.npc_take (cùng trạng thái với người chơi).

signal changed

const DATA_PATH := "res://data/npcs.json"
const CATALOG := preload("res://scripts/v1/catalog.gd")

var main: Node
var states: Dictionary = {}        # npc id -> trạng thái (xem _fresh_state)
var uniques: Dictionary = {}       # uid -> {"name", "owner", "origin", "day", "history": []}
var legacy_gen: Dictionary = {}    # động phủ -> số thế hệ truyền thừa (tăng khi động phủ tái tạo)
var _duels: Dictionary = {}        # npc id -> Monster đang giao đấu thật với người chơi (NpcCombat)
var deeds: Array = []              # việc người chơi đã làm mà thế giới có thể biết (xem report_deed)
var next_deed := 1

var _data: Dictionary = {}
var _profiles: Dictionary = {}     # npc id -> Progression (RefCounted) (bộ pháp V1 đã dựng, cache từ states[id]["v1"])
var _last_day := 0
var _timer := 0.0
var _nodes: Dictionary = {}        # map id -> {npc id -> EncounterNode}; map gốc được main giữ lại, map phụ bị giải phóng khi rời đi
var _scene_map := ""
var _dirty := true


func _ready() -> void:
	add_to_group("npc_world")
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	_ensure_states()


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)


# ---------------------------------------------------------------- dữ liệu
func roster() -> Dictionary:
	return _data.get("npcs", {})


func residents() -> Dictionary:
	return _data.get("residents", {})


func balance(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


## Định nghĩa của một NPC (lang thang hoặc cư dân).
func def_of(id: String) -> Dictionary:
	if roster().has(id):
		return roster()[id]
	return residents().get(id, {})


## Mọi NPC tham gia mô phỏng ngoài scene (lang thang + cư dân có lịch làm việc).
func agent_ids() -> Array:
	var out: Array = roster().keys()
	for id in residents():
		if (residents()[id] as Dictionary).has("routine"):
			out.append(id)
	return out


func _ensure_states() -> void:
	for id in agent_ids():
		if not states.has(id):
			states[str(id)] = _fresh_state(str(id))


func _fresh_state(id: String) -> Dictionary:
	var d: Dictionary = def_of(id)
	return {
		"traits": NpcProfile.traits_of(id, d),
		"bonds": {"player": NpcBonds.empty()}, "memory": [], "last_wrong": 0,
		"step": int(d.get("step", 0)), "xp": 0.0, "develop": [], "last_change": -99, "learned_unique": [],
		"seek": {}, "request": {}, "last_seek": -99,
		"loc": str(d.get("home", "van_khe")), "act": "rest", "until": 1, "status": "ok", "status_until": 0,
		"assets": (d.get("assets", {}) as Dictionary).duplicate(), "money": int(d.get("money", 0)),
		"rel": 0, "history": [], "talk_day": 0, "planned_day": 0, "stats": {},
	}


func _bump(st: Dictionary, key: String, n := 1) -> void:
	if not st.has("stats"):
		st["stats"] = {}
	st["stats"][key] = int(st["stats"].get(key, 0)) + n


# ---------------------------------------------------------------- hồ sơ V1 (tính cách + bộ pháp)
## Bộ pháp V1 của NPC (Progression). Dựng tất định từ id lần đầu rồi lưu trong trạng thái (bản lưu cũ tự bổ sung).
func profile_of(id: String) -> RefCounted:
	if _profiles.has(id):
		return _profiles[id]
	var st: Dictionary = states.get(id, {})
	var d: Dictionary = def_of(id)
	if st.is_empty() or d.is_empty():
		return null
	var p
	if st.has("v1"):
		p = NpcProfile.from_dict(st["v1"])
	else:
		var dd := d.duplicate()
		dd["step"] = step_of(id)
		p = NpcProfile.build(id, dd)
		st["v1"] = p.to_dict()
	_profiles[id] = p
	return p


# ---------------------------------------------------------------- NPC chủ động tìm người chơi (bước 6)
## Ý định của NPC với người chơi, sinh từ quan hệ và nhu cầu thật (không phải lịch cố định):
##   revenge_demand (thù hận): đòi bồi thường · repay_gift (mắc ơn): mang quà báo đáp · bring_material (thiếu vật liệu họ cần): nhờ mang giúp
##   invite_event (hiếu kỳ, tin cậy): rủ đi nơi có sự kiện · share_tip (thân thiết): chỉ một manh mối.
## NPC phải mất thời gian đi tới nơi người chơi đang ở (tính theo tuyến đường thật), không dịch chuyển tức thời.
const SEEK_KINDS := ["revenge_demand", "repay_gift", "bring_material", "invite_event", "share_tip"]


func seek_of(id: String) -> Dictionary:
	return states.get(id, {}).get("seek", {})


func request_of(id: String) -> Dictionary:
	return states.get(id, {}).get("request", {})


## Số ngày đi đường của NPC giữa hai địa điểm theo mạng tuyến thật (NPC biết đường, không phụ thuộc người chơi đã khám phá chưa).
func _travel_days(from: String, to: String) -> int:
	if from == to:
		return 0
	if main == null or main.province == null:
		return -1
	var dist := {from: 0}
	var open: Array = [from]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if int(dist[open[i]]) < int(dist[open[best]]):
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if cur == to:
			return int(dist[cur])
		for r in main.province.routes():
			var other := ""
			if str(r["a"]) == cur:
				other = str(r["b"])
			elif str(r["b"]) == cur:
				other = str(r["a"])
			if other == "":
				continue
			var nd := int(dist[cur]) + maxi(1, int(r.get("days", 1)))
			if not dist.has(other) or nd < int(dist[other]):
				dist[other] = nd
				if other not in open:
					open.append(other)
	return -1


## Ý định hiện có của NPC (hoặc {}), theo thứ tự ưu tiên.
func _intent(id: String, day: int) -> Dictionary:
	var st: Dictionary = states[id]
	var b: Dictionary = bond(id)
	var t: Dictionary = traits_of(id)
	var d: Dictionary = def_of(id)
	if int(b["hate"]) >= 50 and int(t.get("aggression", 50)) >= 40 and day - int(st.get("last_wrong", 0)) >= 2:
		return {"kind": "revenge_demand", "stones": clampi(20 + int(b["hate"]), 30, 120)}
	if int(b["debt"]) >= 25 and int(t.get("righteous", 50)) >= 50 and day - int(st.get("repay_day", -99)) >= 10:
		return {"kind": "repay_gift"}
	if int(b["affinity"]) >= 5 and int(b["trust"]) >= 0:
		for n in d.get("needs", []):
			if int((st["assets"] as Dictionary).get(str(n), 0)) <= 0:
				var worth := int(Items.DATA.get(str(n), {}).get("sell", 10))
				return {"kind": "bring_material", "item": str(n), "qty": 2, "reward": worth * 4 + 20}
	if int(b["affinity"]) >= 15 and int(t.get("curiosity", 50)) >= 55:
		var evs := known_events(id, day)
		if not evs.is_empty():
			var e: Dictionary = evs[0]
			return {"kind": "invite_event", "event_id": str(e["id"]), "loc": str(e["loc"])}
	if int(b["affinity"]) >= 20 and int(b["trust"]) >= 10:
		var pool: Array = []
		for lid in main.province.locations():
			if main.province.state_of(str(lid)) == World.UNKNOWN and not bool(main.province.info(str(lid)).get("hidden", false)):
				pool.append(str(lid))
		if not pool.is_empty():
			pool.sort()
			return {"kind": "share_tip", "loc": str(pool[absi((id + str(day)).hash()) % pool.size()])}
	return {}


func _initiatives(day: int) -> void:
	if main == null or main.journey == null or main.province == null:
		return
	var here := str(main.journey.here())
	if here == "":
		return
	var active := 0
	for id in roster():
		if not seek_of(str(id)).is_empty():
			active += 1
	var cap := int(balance("max_seekers", 2.0))
	for id in roster():
		if active >= cap:
			break
		var st: Dictionary = states[id]
		if not seek_of(str(id)).is_empty() or not request_of(str(id)).is_empty():
			continue
		if str(st.get("status", "ok")) != "ok" or day - int(st.get("last_seek", -99)) < 8:
			continue
		var intent := _intent(str(id), day)
		if intent.is_empty():
			continue
		if _seeded(str(id), day, "seek").randf() > 0.35:
			continue
		var days := _travel_days(str(st["loc"]), here)
		if days < 0:
			continue
		intent["target"] = here
		intent["arrive"] = day + days
		intent["since"] = day
		intent["arrived"] = false
		st["seek"] = intent
		st["last_seek"] = day
		st["act"] = "seek"
		st["until"] = day + days + 4
		active += 1
		_note(str(id), "Lên đường tìm người chơi ở %s (%s)." % [main.province.display_name(here), str(intent["kind"])], false, day)


## Đến nơi thì hiện ra; chờ 4 ngày không gặp thì bỏ về (và buồn lòng).
func _seek_tick(day: int) -> void:
	for id in roster():
		var st: Dictionary = states[id]
		var sk: Dictionary = st.get("seek", {})
		if sk.is_empty():
			continue
		if not bool(sk["arrived"]) and day >= int(sk["arrive"]):
			sk["arrived"] = true
			st["loc"] = str(sk["target"])
			_dirty = true
			if main != null and main.hud != null:
				main.hud.toast("%s đang tìm ngươi ở %s." % [display_name(str(id)), main.province.display_name(str(sk["target"]))])
			if main != null and main.province != null:
				main.province.add_news("%s đến %s tìm người chơi." % [display_name(str(id)), main.province.display_name(str(sk["target"]))])
		elif bool(sk["arrived"]) and day > int(sk["arrive"]) + 4:
			st["seek"] = {}
			st["act"] = "rest"
			st["until"] = day
			st["loc"] = str(def_of(str(id)).get("home", "van_khe"))
			_dirty = true
			_note(str(id), "Chờ mãi không gặp người chơi, đành quay về.", false, day)
			var b: Dictionary = bond(str(id))
			b["trust"] = clampi(int(b["trust"]) - 2, -100, 100)


## Hội thoại khi NPC đã tới tìm người chơi.
func _seek_dialog(id: String) -> void:
	var sk: Dictionary = states[id]["seek"]
	var nm := display_name(id)
	var kind := str(sk["kind"])
	match kind:
		"repay_gift":
			states[id]["seek"] = {}
			main.dialogue.say(nm, ["Ta cất công đi tìm ngươi: ơn trước ta chưa quên."])
			_repay(id)
		"revenge_demand":
			var n := int(sk["stones"])
			main.dialogue.choose(nm, "Ngươi còn nhớ món nợ giữa chúng ta chứ? Đền cho ta %d linh thạch, hoặc chúng ta giải quyết bằng nắm đấm." % n, [
				{"text": "Nộp %d linh thạch" % n, "call": _seek_pay.bind(id)},
				{"text": "Giao đấu", "call": _seek_fight.bind(id)},
			])
		"bring_material":
			var item := str(sk["item"])
			main.dialogue.choose(nm, "Ta đang cần %d %s mà tìm mãi chưa có. Ngươi mang giúp ta, ta sẽ trả %d linh thạch." % [int(sk["qty"]), Items.item_name(item), int(sk["reward"])], [
				{"text": "Nhận lời", "call": _seek_accept.bind(id)},
				{"text": "Từ chối", "call": _seek_decline.bind(id)},
			])
		"invite_event":
			main.dialogue.choose(nm, "Nghe nói ở %s có chuyện lạ. Ta sắp đi xem, ngươi có muốn nghe rõ hơn không?" % main.province.display_name(str(sk["loc"])), [
				{"text": "Nghe ta kể", "call": _seek_tip.bind(id)},
				{"text": "Để sau", "call": _seek_decline.bind(id)},
			])
		"share_tip":
			main.dialogue.choose(nm, "Ta mới biết một chỗ có thể ngươi muốn tới. Ta nói cho ngươi nghe nhé?", [
				{"text": "Nghe ta kể", "call": _seek_tip.bind(id)},
				{"text": "Để sau", "call": _seek_decline.bind(id)},
			])


func _seek_end(id: String) -> void:
	var st: Dictionary = states[id]
	st["seek"] = {}
	st["act"] = "rest"
	st["until"] = today()
	_dirty = true


func _seek_pay(id: String) -> void:
	var n := int(states[id]["seek"].get("stones", 30))
	if not main.inv.spend_stones(n):
		main.dialogue.say(display_name(id), ["Không có đủ à? Vậy thì chỉ còn cách kia."])
		_seek_fight(id)
		return
	states[id]["money"] = int(states[id]["money"]) + n
	var b: Dictionary = bond(id)
	b["hate"] = maxi(0, int(b["hate"]) - 25)
	b["trust"] = clampi(int(b["trust"]) + 3, -100, 100)
	_note(id, "Nhận %d linh thạch bồi thường từ người chơi, bớt giận." % n, false)
	_seek_end(id)
	main.dialogue.say(display_name(id), ["Coi như chúng ta tạm hết nợ. Đừng để ta phải tìm lần nữa."])


func _seek_fight(id: String) -> void:
	_seek_end(id)
	if start_duel(id, "revenge"):
		main.dialogue.say(display_name(id), ["Vậy thì để binh khí nói chuyện!"])
		return
	# không dựng được trận thật (thiếu dữ liệu): giải quyết nhanh theo chênh lệch cảnh giới
	var chance := clampf(0.5 + float(main.cult.step_index() - step_of(id)) * 0.06, 0.1, 0.9)
	var b: Dictionary = bond(id)
	if _seeded(id, today(), "revenge").randf() < chance:
		b["hate"] = maxi(0, int(b["hate"]) - 10)
		b["fear"] = clampi(int(b["fear"]) + 20, 0, 100)
		main.dialogue.say(display_name(id), ["(Gục xuống) Khụ... ngươi mạnh hơn ta tưởng."])
	else:
		main.vitals.take(maxf(8.0, main.vitals.max_hp * 0.15), main.player.position)
		main.dialogue.say(display_name(id), ["(Ngươi bị đánh trọng thương) Nhớ lấy bài học này."])


# ---------------------------------------------------------------- giao đấu thật (bộ pháp V1 → chiến đấu)
## Dựng NPC thành một đối thủ thật trong cảnh, mang đúng chiêu và thủ pháp theo hồ sơ V1 của họ. reason: revenge | rob.
func start_duel(id: String, reason: String) -> bool:
	if not _duels.is_empty() or main == null or main.player == null or bool(main.map_def.get("war", false)):
		return false
	var pos: Vector2 = main.player.position + Dir.to_vector(main.direction) * 150.0
	var m: Monster = NpcCombat.spawn(main, id, pos)
	if m == null:
		return false
	main.world.add_child(m)
	main.monsters.append(m)
	m.state = "chase"
	_duels[id] = m
	states[id]["duel"] = reason
	m.killed.connect(_duel_won.bind(id, reason))
	if main.hud != null:
		main.hud.toast("%s giao đấu với ngươi!" % display_name(id))
	return true


func duel_active(id: String) -> bool:
	return _duels.has(id) and is_instance_valid(_duels[id])


func _duel_won(_kind: String, id: String, reason: String) -> void:
	_duels.erase(id)
	var st: Dictionary = states[id]
	st.erase("duel")
	if reason == "debug":
		return   # trận thử từ menu F1: không để lại hậu quả
	var b: Dictionary = bond(id)
	st["status"] = "injured"
	st["status_until"] = today() + 3
	st["loc"] = str(def_of(id).get("home", "van_khe"))
	st["act"] = "rest"
	st["until"] = today() + 3
	_dirty = true
	match reason:
		"revenge":
			b["hate"] = maxi(0, int(b["hate"]) - 15)
			b["fear"] = clampi(int(b["fear"]) + 20, 0, 100)
			_note(id, "Giao đấu với người chơi để đòi nợ và thua cuộc, bị thương.", false)
		"rob":
			var taken := _rob_take(id)
			b["fear"] = clampi(int(b["fear"]) + 10, 0, 100)
			_note(id, "Bị người chơi đánh bại khi phản kháng và bị lấy %s." % (", ".join(taken) if not taken.is_empty() else "chẳng còn gì"), false)
			if main.hud != null and not taken.is_empty():
				main.hud.toast("Lấy được: " + ", ".join(taken))


## Dọn các trận không còn (người chơi rời map, đối thủ bị xoá): NPC bỏ đi, trận coi như huỷ.
func _duel_tick(_day: int) -> void:
	for id in _duels.keys():
		var m = _duels[id]
		if not is_instance_valid(m) or not m.is_inside_tree():
			_duels.erase(id)
			states[id].erase("duel")


func _seek_accept(id: String) -> void:
	var st: Dictionary = states[id]
	var sk: Dictionary = st["seek"]
	st["request"] = {"kind": "bring_material", "item": str(sk["item"]), "qty": int(sk["qty"]), "reward": int(sk["reward"]), "day": today(), "until": today() + 12}
	_seek_end(id)
	main.dialogue.say(display_name(id), ["Ta tạ ơn trước. Có được thì tìm ta ở quanh đây trong vòng 12 ngày."])


func _seek_decline(id: String) -> void:
	_seek_end(id)
	main.dialogue.say(display_name(id), ["Không sao, để dịp khác."])


func _seek_tip(id: String) -> void:
	var sk: Dictionary = states[id]["seek"]
	var loc := str(sk["loc"])
	if main.province.state_of(loc) == World.UNKNOWN:
		main.province.add_rumor(loc, "", display_name(id), "high")
	record(id, "favor", "Ta kể cho ngươi một manh mối quan trọng.")
	_seek_end(id)
	var line := str(main.province.info(loc).get("rumor", "")) if main.province.state_of(loc) != World.DISCOVERED else ""
	main.dialogue.say(display_name(id), [line if line != "" else "Nghe bảo ở %s sắp có chuyện, ngươi nên để ý." % main.province.display_name(loc)])


## Giao vật liệu theo lời nhờ. Nếu NPC đã tự kiếm đủ từ nơi khác thì lời nhờ coi như đã được giải quyết (không bắt giao).
func turn_in_request(id: String) -> void:
	var st: Dictionary = states[id]
	var rq: Dictionary = st.get("request", {})
	if rq.is_empty():
		return
	var item := str(rq["item"])
	var qty := int(rq["qty"])
	if int((st["assets"] as Dictionary).get(item, 0)) >= qty:
		st["request"] = {}
		_note(id, "Đã tự kiếm đủ %s, lời nhờ người chơi không còn cần." % Items.item_name(item), false)
		main.dialogue.say(display_name(id), ["Ta vừa kiếm đủ %s từ chỗ khác rồi. Không cần phiền ngươi nữa, cảm ơn lòng tốt." % Items.item_name(item)])
		return
	if main.inv.count(item) < qty:
		main.hud.toast("Chưa đủ %d %s." % [qty, Items.item_name(item)])
		return
	main.inv.remove(item, qty)
	st["assets"][item] = int((st["assets"] as Dictionary).get(item, 0)) + qty
	var pay := mini(int(rq["reward"]), int(st["money"]))
	st["money"] = int(st["money"]) - pay
	main.inv.add_stones(pay)
	st["request"] = {}
	record(id, "help", "Ngươi mang vật liệu giúp ta đúng lúc cần.")
	_note(id, "Nhận %d %s từ người chơi, trả %d linh thạch." % [qty, Items.item_name(item), pay], false)
	main.dialogue.say(display_name(id), ["Đúng thứ ta cần! Đây là %d linh thạch, mong ngươi nhận cho." % pay])


## Lời nhờ quá hạn thì bỏ; lời nhờ đã được giải quyết nơi khác thì chuyển trạng thái.
func _expire_requests(day: int) -> void:
	for id in roster():
		var st: Dictionary = states[id]
		var rq: Dictionary = st.get("request", {})
		if rq.is_empty():
			continue
		if day > int(rq["until"]):
			st["request"] = {}
			_note(str(id), "Lời nhờ người chơi đã quá hạn, tự tìm cách khác.", false, day)


# ---------------------------------------------------------------- lan truyền thông tin (bước 5)
## Ba mức hiểu biết về một việc: 0 chưa biết · 1 nghe đồn · 2 có bằng chứng (tận mắt hoặc nạn nhân).
const KNOW_NAMES := ["chưa biết", "nghe đồn", "có bằng chứng"]
const DEED_KINDS := {
	"robbery": {"name": "cướp đoạt", "bad": true, "sev": 3, "text": "cướp đồ của %s"},
	"theft": {"name": "trộm cắp", "bad": true, "sev": 2, "text": "lén lấy tài nguyên của %s"},
	"threat": {"name": "đe doạ", "bad": true, "sev": 2, "text": "ra tay đe doạ %s"},
	"rescue": {"name": "cứu giúp", "bad": false, "sev": 2, "text": "ra tay cứu %s"},
}


func know_of(id: String) -> Dictionary:
	var st: Dictionary = states.get(id, {})
	if not st.has("know"):
		return {}
	return st["know"]


func know_level(id: String, deed_id: String) -> int:
	return int(know_of(id).get(deed_id, {}).get("lvl", 0))


func deed_by_id(deed_id: String) -> Dictionary:
	for dd in deeds:
		if str(dd["id"]) == deed_id:
			return dd
	return {}


## Ghi một việc của người chơi. victim: id NPC bị ảnh hưởng ("" nếu không phải NPC, "sect:<id>" nếu cả một tông).
## Người chứng kiến = NPC khác đang ở đúng địa điểm (và tỉnh táo); nạn nhân luôn biết (mức 2). Không ai chứng kiến và nạn nhân
## không phải NPC thì chuyện hoàn toàn bí mật: không ai biết, không lan ra. extra_witnesses: nhân chứng ngoài danh sách NPC (lính canh...).
func report_deed(kind: String, victim := "", loc := "", detail := "", extra_witnesses := 0) -> Dictionary:
	if not DEED_KINDS.has(kind):
		return {}
	var day := today()
	var wit: Array = []
	for id in agent_ids():
		var st: Dictionary = states[id]
		if str(id) == victim or str(st.get("status", "ok")) != "ok":
			continue
		if loc != "" and str(st.get("loc", "")) == loc:
			wit.append(str(id))
	var deed := {"id": "d%d" % next_deed, "kind": kind, "victim": victim, "loc": loc, "day": day, "witnesses": wit.duplicate(),
		"detail": detail, "extra": extra_witnesses, "reported": []}
	next_deed += 1
	deeds.append(deed)
	if victim != "" and states.has(victim):
		_learn(victim, deed, 2, true)
	for w in wit:
		_learn(str(w), deed, 2, true)
	if extra_witnesses > 0 and victim.begins_with("sect:"):   # bị bắt gặp tại chỗ: tông biết ngay
		_report_to_sect(NpcProfile.v1_sect(victim.trim_prefix("sect:")), deed)
	return deed


## `attr`: có nhận ra người chơi là thủ phạm không (tin đồn có thể không nêu tên).
func _learn(id: String, deed: Dictionary, level: int, attr: bool) -> void:
	var st: Dictionary = states[id]
	if not st.has("know"):
		st["know"] = {}
	var cur: Dictionary = st["know"].get(str(deed["id"]), {"lvl": 0, "attr": false})
	if level <= int(cur["lvl"]):
		return
	var was_attr := bool(cur["attr"])
	st["know"][str(deed["id"])] = {"lvl": level, "attr": attr or was_attr, "day": today()}
	if not (attr or was_attr):
		return
	var k: Dictionary = DEED_KINDS[str(deed["kind"])]
	var is_victim := str(deed.get("victim", "")) == id
	if is_victim:
		return   # nạn nhân đã bị ghi qua record() ở nơi gây ra việc
	var bk := ""
	if bool(k["bad"]):
		bk = "known_wrong" if level >= 2 else "heard_wrong"
	else:
		bk = "known_good" if level >= 2 else "heard_good"
	var text := "Ngày %d: %s %s." % [int(deed["day"]), "nghe đồn người chơi" if level < 2 else "biết chắc người chơi", str(k["text"]) % _victim_name(str(deed.get("victim", "")))]
	record(id, bk, text)
	if level >= 2 and bool(k["bad"]):
		var sect := NpcProfile.sect_of(def_of(id))
		if sect != "":
			_report_to_sect(sect, deed)


func _victim_name(victim: String) -> String:
	if victim.begins_with("sect:"):
		return "tông " + str(CATALOG.data().sects.get(NpcProfile.v1_sect(victim.trim_prefix("sect:")), {"name": victim}).name)
	if victim == "":
		return "một người lạ"
	return display_name(victim)


## Đệ tử có bằng chứng thì báo lên tông: tông ghi người chơi vào sổ truy nã và coi là thù địch (một lần mỗi việc).
func _report_to_sect(sect: String, deed: Dictionary) -> void:
	if sect == "" or sect in (deed["reported"] as Array) or not bool(DEED_KINDS[str(deed["kind"])]["bad"]):
		return
	(deed["reported"] as Array).append(sect)
	if main != null and main.get("cultivation_v1") != null:
		var cs = main.cultivation_v1.state
		cs.wanted[sect] = int(cs.wanted.get(sect, 0)) + 1
		cs.relations[sect] = "hostile"
		if main.province != null:
			main.province.add_news("%s ghi người chơi vào sổ truy nã vì %s." % [str(CATALOG.data().sects.get(sect, {"name": sect}).name), str(DEED_KINDS[str(deed["kind"])]["name"])])


## Mỗi ngày: người biết kể cho người cùng địa điểm. Có bằng chứng chỉ truyền nguyên cho người cùng tông (báo cáo);
## người ngoài chỉ nghe đồn (và có thể nghe không rõ ai làm). Tin đồn phai sau 45 ngày; việc cũ quá 120 ngày thì bỏ.
func _spread_deeds(day: int) -> void:
	if deeds.is_empty():
		return
	var keep: Array = []
	for dd in deeds:
		if day - int(dd["day"]) > 120:
			continue
		keep.append(dd)
	deeds = keep
	var ids: Array = agent_ids()
	for dd in deeds:
		var did := str(dd["id"])
		var age := day - int(dd["day"])
		var informed: Array = []
		for id in ids:
			var info: Dictionary = know_of(str(id)).get(did, {})
			if info.is_empty():
				continue
			if int(info["lvl"]) == 1 and age > 45:
				(states[id]["know"] as Dictionary).erase(did)
				continue
			informed.append(str(id))
		if age > 45:
			continue   # chuyện đã cũ: không còn ai kể nữa, tin đồn tự phai
		for g in informed:
			var gs: Dictionary = states[g]
			if str(gs.get("status", "ok")) != "ok":
				continue
			var glvl := know_level(g, did)
			var gsect := NpcProfile.sect_of(def_of(g))
			var gossip := float(traits_of(g).get("curiosity", 50)) / 100.0 * 0.4 + (1.0 - float(traits_of(g).get("caution", 50)) / 100.0) * 0.15
			for o in ids:
				if str(o) == g or know_level(str(o), did) >= glvl or str(states[o].get("status", "ok")) != "ok":
					continue
				if str(states[o].get("loc", "")) != str(gs.get("loc", "")):
					continue
				var r := _seeded(g + ">" + str(o), day, did)
				if r.randf() >= 0.25 + gossip:
					continue
				var osect := NpcProfile.sect_of(def_of(str(o)))
				var lvl := 2 if (glvl >= 2 and gsect != "" and gsect == osect) else 1
				_learn(str(o), dd, lvl, r.randf() < 0.75)


## "Tiếng xấu" của người chơi: tổng độ nặng các việc xấu nhân với tỉ lệ NPC đã biết chắc, cộng nửa với tỉ lệ nghe đồn.
func notoriety() -> float:
	var ids: Array = agent_ids()
	if ids.is_empty():
		return 0.0
	var total := 0.0
	for dd in deeds:
		var k: Dictionary = DEED_KINDS[str(dd["kind"])]
		if not bool(k["bad"]):
			continue
		var sure := 0
		var heard := 0
		for id in ids:
			var inf: Dictionary = know_of(str(id)).get(str(dd["id"]), {})
			if inf.is_empty() or not bool(inf.get("attr", false)):
				continue
			if int(inf["lvl"]) >= 2:
				sure += 1
			else:
				heard += 1
		total += float(k["sev"]) * (float(sure) + 0.5 * float(heard)) / float(ids.size())
	return total


## Phân trần: người nghe đồn (mức 1) có thể tin lại; thành công hay không tuỳ tín nhiệm và thiện cảm.
func _explain(id: String) -> void:
	var st: Dictionary = states[id]
	var b: Dictionary = bond(id)
	var chance := clampf(0.3 + float(b["trust"]) / 200.0 + float(b["affinity"]) / 300.0 - float(b["hate"]) / 200.0, 0.1, 0.9)
	var r := _seeded(id, today(), "explain")
	var cleared := 0
	if r.randf() < chance:
		for did in (st.get("know", {}) as Dictionary).keys():
			var inf: Dictionary = st["know"][did]
			var dd := deed_by_id(str(did))
			if int(inf["lvl"]) == 1 and not dd.is_empty() and bool(DEED_KINDS[str(dd["kind"])]["bad"]):
				st["know"].erase(did)
				cleared += 1
		if cleared > 0:
			b["trust"] = clampi(int(b["trust"]) + 3, -100, 100)
			main.dialogue.say(display_name(id), ["Hừm... nghe ngươi nói cũng có lý. Có lẽ tin đồn đã bị thổi phồng."])
			return
	b["trust"] = clampi(int(b["trust"]) - 2, -100, 100)
	main.dialogue.say(display_name(id), ["Ngươi nói thế nào cũng được. Ta vẫn còn nghi ngờ." if cleared == 0 else "..."])


## Cướp hành trang NPC. Thành công tuỳ chênh lệch cảnh giới; thất bại thì bị phản kháng. Cả hai đều để lại dấu vết (nhân chứng).
func rob(id: String) -> Dictionary:
	var st: Dictionary = states[id]
	var my_step: int = main.cult.step_index()
	var chance := clampf(0.5 + float(my_step - step_of(id)) * 0.06, 0.1, 0.9)
	var r := _seeded(id, today(), "rob")
	var loc := str(st.get("loc", ""))
	var out := {"ok": false, "items": [], "duel": false}
	if r.randf() < chance:
		out["ok"] = true
		var taken := _rob_take(id)
		out["items"] = taken
		record(id, "robbed")
		_note(id, "Bị người chơi cướp hành trang (%s)." % (", ".join(taken) if not taken.is_empty() else "chẳng còn gì"), false)
	else:
		record(id, "threat")
		_note(id, "Phản kháng khi bị người chơi ra tay cướp.", false)
		if start_duel(id, "rob"):
			out["duel"] = true
		else:
			main.vitals.take(maxf(5.0, main.vitals.max_hp * 0.1), main.player.position)
	report_deed("robbery" if out["ok"] else "threat", id, loc, "")
	return out


## Lấy hành trang của NPC (tối đa 2 loại + một vật độc nhất) chuyển sang người chơi; trả danh sách mô tả.
func _rob_take(id: String) -> Array:
	var st: Dictionary = states[id]
	var taken: Array = []
	for k in (st["assets"] as Dictionary).keys():
		if taken.size() >= 2:
			break
		if int(st["assets"][k]) > 0:
			var n := mini(int(st["assets"][k]), 2)
			st["assets"][k] = int(st["assets"][k]) - n
			if int(st["assets"][k]) <= 0:
				st["assets"].erase(k)
			main.inv.add(str(k), n)
			taken.append("%d %s" % [n, Items.item_name(str(k))])
	for u in owned_by("npc:" + id):
		transfer(str(u), "npc:" + id, "player", "Bị người chơi cướp")
		taken.append(str(uniques[u]["name"]))
		break
	return taken


## Có phải đang nghi ngờ người chơi (nghe đồn việc xấu) không.
func suspicion_of(id: String) -> int:
	var n := 0
	for did in know_of(id):
		var inf: Dictionary = know_of(id)[did]
		var dd := deed_by_id(str(did))
		if dd.is_empty() or not bool(DEED_KINDS[str(dd["kind"])]["bad"]):
			continue
		if int(inf["lvl"]) == 1 and bool(inf.get("attr", false)):
			n += 1
	return n


func _confirm_rob(id: String) -> void:
	main.dialogue.choose(display_name(id), "(Ngươi định ra tay cướp hành trang của người này. Việc này sẽ không bị quên.)", [
		{"text": "Ra tay", "call": _do_rob.bind(id)},
		{"text": "Thôi", "call": Callable()},
	])


func _do_rob(id: String) -> void:
	var r := rob(id)
	if bool(r["ok"]):
		var items: Array = r["items"]
		main.dialogue.say(display_name(id), ["(Ngươi giật lấy hành trang)", "Lấy được: " + (", ".join(items) if not items.is_empty() else "chẳng có gì đáng giá") + "."])
	elif bool(r.get("duel", false)):
		main.dialogue.say(display_name(id), ["(Hắn rút binh khí phản kháng! Hạ được hắn thì mới lấy được đồ.)"])
	else:
		main.dialogue.say(display_name(id), ["(Bị phản kháng, ngươi bị thương và phải lùi lại.)"])


# ---------------------------------------------------------------- tự phát triển (bước 4)
## Cảnh giới hiện tại (tăng dần khi đột phá; mặc định theo dữ liệu).
func step_of(id: String) -> int:
	return int(states.get(id, {}).get("step", def_of(id).get("step", 0)))


func xp_of(id: String) -> float:
	return float(states.get(id, {}).get("xp", 0.0))


func step_cap(id: String) -> int:
	return int(def_of(id).get("step", 0)) + NpcGrowth.MAX_STEP_GAIN


func develop_log(id: String) -> Array:
	return states.get(id, {}).get("develop", [])


func _log_dev(id: String, day: int, kind: String, text: String, news := false) -> void:
	var st: Dictionary = states[id]
	if not st.has("develop"):
		st["develop"] = []
	(st["develop"] as Array).append({"day": day, "kind": kind, "text": text})
	while (st["develop"] as Array).size() > 12:
		(st["develop"] as Array).pop_front()
	_note(id, text, news, day)


## Một ngày phát triển: tích tu vi theo việc đang làm, thử đột phá, thỉnh thoảng cân nhắc đổi bí tịch / trang bị.
func _develop(id: String, day: int) -> void:
	var st: Dictionary = states[id]
	var p = profile_of(id)
	if p == null:
		return
	var act := str(st.get("act", "rest")) if str(st.get("status", "ok")) == "ok" else "rest"
	var gain := NpcGrowth.xp_gain(act, float(p.origin.attributes.meridians))
	if str(st.get("status", "ok")) == "seclusion":
		gain *= 2.0
	st["xp"] = float(st.get("xp", 0.0)) + gain
	_try_breakthrough(id, day)
	if str(st.get("status", "ok")) == "ok" and (day + absi(str(id).hash()) % NpcGrowth.CONSIDER_EVERY) % NpcGrowth.CONSIDER_EVERY == 0:
		_consider_growth(id, day)


func _try_breakthrough(id: String, day: int) -> void:
	var st: Dictionary = states[id]
	var step := step_of(id)
	if step >= step_cap(id) or str(st.get("status", "ok")) != "ok":
		return
	var need := NpcGrowth.xp_need(step)
	if float(st["xp"]) < need:
		return
	var cost := NpcGrowth.break_cost(step)
	if int(st["money"]) < cost:
		return   # đủ tu vi nhưng thiếu linh thạch: chờ kiếm đủ
	st["money"] = int(st["money"]) - cost
	var p = profile_of(id)
	var insight := float(p.origin.attributes.insight)
	var r := _seeded(id, day, "break")
	if r.randf() < NpcGrowth.break_chance(insight, step):
		st["step"] = step + 1
		st["xp"] = maxf(0.0, float(st["xp"]) - need)
		_bump(st, "breakthrough")
		var realm_change := (step + 1) % 9 == 0
		_log_dev(id, day, "breakthrough", "Đột phá lên %s (tốn %d linh thạch)." % [CATALOG.step_name(step + 1), cost], realm_change)
		_consider_growth(id, day, true)
	else:
		st["xp"] = float(st["xp"]) - need * 0.35
		st["status"] = "injured"
		st["status_until"] = day + 3
		st["loc"] = str(def_of(id).get("home", "van_khe"))
		_bump(st, "break_failed")
		_log_dev(id, day, "break_failed", "Đột phá %s thất bại, kinh mạch tổn thương; mất %d linh thạch." % [CATALOG.step_name(step + 1), cost], false)


## Cân nhắc nâng cấp bộ pháp: truyền thừa đang giữ, rồi bí tịch mua được, rồi trang bị. Mỗi lần đổi cách nhau tối thiểu vài ngày.
func _consider_growth(id: String, day: int, force := false) -> void:
	var st: Dictionary = states[id]
	var p = profile_of(id)
	if p == null:
		return
	if not force and day - int(st.get("last_change", -99)) < NpcGrowth.CHANGE_COOLDOWN:
		return
	var d: Dictionary = def_of(id)
	var step := step_of(id)
	var sect := NpcProfile.sect_of(d)
	var elder := bool(d.get("elder", false)) or step >= 25
	var traits := traits_of(id)
	var insight := float(p.origin.attributes.insight)
	var r := _seeded(id, day, "study")
	var changed := false
	# 1) truyền thừa động phủ đang giữ
	for uid in owned_by("npc:" + id):
		if not str(uid).begins_with("legacy:") or str(uid) in st["learned_unique"]:
			continue
		var dp_id := str(uid).split(":")[1]
		var book := ""
		if main != null and main.destiny.dong_phu().has(dp_id):
			book = str(main.destiny.dong_phu()[dp_id].get("legacy", {}).get("book", ""))
		var bd: Dictionary = CATALOG.definition(book)
		if bd.is_empty() or step < int(bd.get("need", 0)):
			continue   # chưa đủ cảnh giới để lĩnh ngộ: giữ lại chờ đột phá
		var slot := str(bd.slot)
		var nu: String = p.acquire(book, "legacy", "huyen")
		p.learn(nu, step)
		var ev := NpcGrowth.evaluate(p, slot, bd, traits, sect, insight, r)
		(st["learned_unique"] as Array).append(str(uid))
		if float(ev["gain"]) + 0.6 > 0.0:   # thứ họ đã liều mạng giành: thiên vị giữ lại dùng
			var others := _others_defs(p, slot)
			p.equip(nu)
			_log_dev(id, day, "legacy", "Lĩnh ngộ truyền thừa %s, đổi sang dùng (%s)." % [str(bd.get("name", "")), NpcGrowth.why_text(bd, others, traits)], true)
		else:
			_log_dev(id, day, "legacy", "Lĩnh ngộ truyền thừa %s nhưng thấy không hợp lối đánh, giữ bí tịch cũ." % str(bd.get("name", "")), false)
		changed = true
		break
	# 2) mua / học bí tịch
	if not changed:
		changed = _try_buy_book(id, day, p, step, sect, elder, traits, insight, r)
	# 3) trang bị
	if not changed:
		changed = _try_buy_gear(id, day, p, step, sect, elder, r)
	if changed:
		st["last_change"] = day
		st["v1"] = p.to_dict()


func _others_defs(p, slot: String) -> Array:
	var out: Array = []
	for sl in ["cong", "cong2", "tam", "than"]:
		if sl != slot:
			var od: Dictionary = p.def_for(sl)
			if not od.is_empty():
				out.append(od)
	return out


func _owned_ids(p) -> Array:
	var out: Array = []
	for uid in p.instances:
		out.append(str(p.instances[uid].definition))
	return out


func _try_buy_book(id: String, day: int, p, step: int, sect: String, elder: bool, traits: Dictionary, insight: float, r: RandomNumberGenerator) -> bool:
	var st: Dictionary = states[id]
	var money := int(st["money"])
	var base := CATALOG.balance("book_price") * balance("npc_price_mult", 0.4)
	var owned := _owned_ids(p)
	var threshold := clampf(0.25 + float(traits.get("caution", 50)) / 100.0 * 0.2 - float(traits.get("curiosity", 50)) / 100.0 * 0.15, 0.1, 0.5)
	var best := {}
	var best_gain := threshold
	var slots: Array = ["cong", "tam", "than"]
	if step >= 12:
		slots.append("cong2")
	for slot in slots:
		var kind: String = "cong" if slot == "cong2" else str(slot)
		for bd in CATALOG.data().books:
			if str(bd.slot) != kind or str(bd.id) in owned or not NpcProfile.legal(bd, sect, step, elder):
				continue
			if str(bd.get("secrecy", "public")) == "secret":
				continue   # Trấn Phái không bán
			var price := int(base * (1.0 if str(bd.get("secrecy", "public")) == "public" else 1.6))
			if money < price + 20:
				continue
			var ev := NpcGrowth.evaluate(p, slot, bd, traits, sect, insight, r)
			if float(ev["gain"]) > best_gain:
				best_gain = float(ev["gain"])
				best = {"slot": slot, "def": bd, "price": price}
	if best.is_empty():
		return false
	var bd2: Dictionary = best["def"]
	var slot2: String = best["slot"]
	var old_name := str(p.def_for(slot2).get("name", ""))
	var others := _others_defs(p, slot2)
	var quality := "thuong" if str(bd2.get("secrecy", "public")) == "public" else "linh"
	var uid: String = p.acquire(str(bd2.id), "npc_market", quality)
	p.learn(uid, step)
	p.equip(uid, "cong2" if slot2 == "cong2" else "")
	st["money"] = money - int(best["price"])
	_bump(st, "learned")
	var verb := "Thay %s bằng" % old_name if old_name != "" else "Học thêm"
	_log_dev(id, day, "book", "%s %s (tốn %d linh thạch) vì %s." % [verb, str(bd2.get("name", "")), int(best["price"]), NpcGrowth.why_text(bd2, others, traits)], false)
	return true


func _try_buy_gear(id: String, day: int, p, step: int, sect: String, elder: bool, r: RandomNumberGenerator) -> bool:
	var st: Dictionary = states[id]
	var money := int(st["money"])
	var base := CATALOG.balance("gear_price") * balance("npc_price_mult", 0.4)
	for slot in ["weapon", "armor", "artifact"]:
		var cur: Dictionary = p.def_for(slot)
		var cur_need := int(cur.get("need", -1))
		var best: Dictionary = {}
		for gd in CATALOG.data().equipment:
			if str(gd.slot) != slot or not NpcProfile.legal(gd, sect, step, elder):
				continue
			if int(gd.get("need", 0)) > cur_need and (best.is_empty() or int(gd.get("need", 0)) > int(best.get("need", 0))):
				best = gd
		if best.is_empty():
			continue
		var price := int(base)
		if money < price + 20 or r.randf() > 0.6:
			continue
		var uid: String = p.acquire(str(best.id), "npc_market", "thuong")
		p.equip(uid)
		st["money"] = money - price
		_bump(st, "gear")
		_log_dev(id, day, "gear", "Sắm %s (%s) vì cảnh giới đã đủ để dùng (tốn %d linh thạch)." % [str(best.get("name", "")), str(NpcProfile.SLOT_NAMES.get(slot, slot)), price], false)
		return true
	return false


func traits_of(id: String) -> Dictionary:
	var st: Dictionary = states.get(id, {})
	if st.has("traits"):
		return st["traits"]
	return NpcProfile.traits_of(id, def_of(id))


# ---------------------------------------------------------------- quan hệ 4 chỉ số và ký ức
## Quan hệ của NPC với `who` (mặc định người chơi): {affinity, trust, debt, hate, fear}. Thiện cảm chính là `rel`.
func bond(id: String, who := "player") -> Dictionary:
	var st: Dictionary = states.get(id, {})
	if st.is_empty():
		return {"affinity": 0, "trust": 0, "debt": 0, "hate": 0, "fear": 0}
	if not st.has("bonds"):
		st["bonds"] = {}
	var all: Dictionary = st["bonds"]
	if not all.has(who):
		all[who] = NpcBonds.empty()
	var b: Dictionary = all[who]
	for k in NpcBonds.empty():
		if not b.has(k):
			b[k] = 0
	if who == "player":
		b["affinity"] = int(st.get("rel", 0))
	elif not b.has("affinity"):
		b["affinity"] = 0
	return b


func memories_of(id: String) -> Array:
	var st: Dictionary = states.get(id, {})
	if not st.has("memory"):
		return []
	return st["memory"]


## Ghi một sự kiện vào quan hệ và ký ức của NPC. Trả về các thay đổi chỉ số thực tế (đã tính tính cách).
func record(id: String, kind: String, cause := "", who := "player") -> Dictionary:
	if not states.has(id) or not NpcBonds.KINDS.has(kind):
		return {}
	var st: Dictionary = states[id]
	var k: Dictionary = NpcBonds.KINDS[kind]
	var dl: Dictionary = NpcBonds.scaled(kind, traits_of(id))
	var b: Dictionary = bond(id, who)
	for stat in dl:
		var nv := NpcBonds.clamp_stat(str(stat), int(b.get(stat, 0)) + int(dl[stat]))
		b[stat] = nv
		if who == "player" and stat == "affinity":
			st["rel"] = nv
	if bool(k.get("wrong", false)):
		st["last_wrong"] = today()
	_remember(id, kind, who, str(k.get("mem", "")) if cause == "" else cause, int(k.get("imp", 0)), dl)
	return dl


## Chỉ chỉnh thiện cảm (cho các hệ thống cũ như sự kiện thế giới) nhưng vẫn để lại ký ức.
func adjust_affinity(id: String, n: int, text := "", who := "player") -> void:
	if not states.has(id) or n == 0:
		return
	var st: Dictionary = states[id]
	var b: Dictionary = bond(id, who)
	var nv := clampi(int(b["affinity"]) + n, -100, 100)
	b["affinity"] = nv
	if who == "player":
		st["rel"] = nv
	if text != "":
		_remember(id, "favor" if n > 0 else "slight", who, text, 1 if absi(n) >= 5 else 0, {"affinity": n})


func _remember(id: String, kind: String, who: String, text: String, imp: int, dl: Dictionary) -> void:
	var st: Dictionary = states[id]
	if not st.has("memory"):
		st["memory"] = []
	var mem: Array = st["memory"]
	mem.append({"day": today(), "kind": kind, "who": who, "loc": str(st.get("loc", "")), "src": "witness", "imp": imp, "text": text, "d": dl})
	# phai nhạt: ký ức thường quá 30 ngày bị quên; tổng tối đa 16, bỏ bớt cái nhạt và cũ nhất
	var limit := int(balance("memory_limit", 16.0))
	var keep: Array = []
	for m in mem:
		if int(m["imp"]) == 0 and today() - int(m["day"]) > int(balance("memory_fade_days", 30.0)):
			continue
		keep.append(m)
	while keep.size() > limit:
		var worst := 0
		for i in keep.size():
			var a: Dictionary = keep[i]
			var w: Dictionary = keep[worst]
			if int(a["imp"]) < int(w["imp"]) or (int(a["imp"]) == int(w["imp"]) and int(a["day"]) < int(w["day"])):
				worst = i
		keep.remove_at(worst)
	st["memory"] = keep


## Phai nhạt theo ngày: thù hận 8 ngày bớt 1 (nếu không có việc xấu mới), sợ hãi 5 ngày bớt 1, thiện cảm nhỏ dần về 0.
## Ân nghĩa và tín nhiệm không tự phai.
func _decay_bonds(id: String, day: int) -> void:
	var st: Dictionary = states[id]
	var b: Dictionary = bond(id)
	if day % 8 == 0 and day - int(st.get("last_wrong", 0)) >= 8 and int(b["hate"]) > 0:
		b["hate"] = int(b["hate"]) - 1
	if day % 5 == 0 and int(b["fear"]) > 0:
		b["fear"] = int(b["fear"]) - 1
	if day % 10 == 0 and absi(int(st["rel"])) <= 20 and int(st["rel"]) != 0:
		st["rel"] = int(st["rel"]) - signi(int(st["rel"]))


## Hệ số giá khi người chơi mua: thù hận làm đắt, tín nhiệm và thiện cảm làm rẻ.
func price_mult(id: String) -> float:
	var b: Dictionary = bond(id)
	return clampf(1.0 + float(b["hate"]) / 200.0 - minf(float(b["trust"]), 50.0) / 250.0 - minf(float(b["affinity"]), 40.0) / 400.0, 0.6, 1.8)


## NPC có chịu bán cho người chơi không (kẻ thù hiếu chiến thì không).
func will_trade(id: String) -> bool:
	var b: Dictionary = bond(id)
	return not (int(b["hate"]) >= 60 and int(traits_of(id).get("aggression", 50)) >= 50)


## Mô tả quan hệ bằng lời.
func bond_text(id: String) -> String:
	var b: Dictionary = bond(id)
	var parts: Array = []
	parts.append("thiện cảm: %s (%+d)" % [NpcBonds.words("affinity", int(b["affinity"])), int(b["affinity"])])
	parts.append("tín nhiệm: %s" % NpcBonds.words("trust", int(b["trust"])))
	for stat in ["debt", "hate", "fear"]:
		var w := NpcBonds.words(stat, int(b[stat]))
		if w != "":
			parts.append("%s: %s" % [str(NpcBonds.NAMES[stat]).to_lower(), w])
	return "; ".join(parts)


## Lối đánh (khoá trong NpcProfile.STYLES).
func style_of(id: String) -> String:
	var p := profile_of(id)
	return NpcProfile.style_of(p, traits_of(id)) if p != null else "approach"


## id tông (khoá SectWar) của NPC: trường `sect` hoặc nơi ở "sect_<tông>"; "" nếu tán tu.
func sect_legacy_of(id: String) -> String:
	var d: Dictionary = def_of(id)
	var s := str(d.get("sect", ""))
	if s == "" and str(d.get("home", "")).begins_with("sect_"):
		s = str(d.get("home")).trim_prefix("sect_")
	return s if SectWar.SECTS.has(s) else ""


func display_name(id: String) -> String:
	if roster().has(id):
		return str(roster()[id]["name"])
	if residents().has(id):
		return str(residents()[id]["name"])
	return id


func state_of(id: String) -> Dictionary:
	return states.get(id, {})


## Mô tả ngắn họ đang làm gì.
func activity_text(id: String) -> String:
	var st: Dictionary = state_of(id)
	if st.is_empty():
		return ""
	var where: String = main.province.display_name(str(st["loc"])) if main != null else str(st["loc"])
	match str(st.get("status", "ok")):
		"injured":
			return "đang dưỡng thương ở %s" % where
		"seclusion":
			return "đang bế quan ở %s" % where
	match str(st.get("act", "rest")):
		"gather":
			return "đang tìm vật liệu ở %s" % where
		"hunt":
			return "đang săn yêu thú ở %s" % where
		"trade":
			return "đang buôn bán ở %s" % where
		"cultivate":
			return "đang tu luyện ở %s" % where
		"event":
			return "đang chạy theo một tin đồn ở %s" % where
	return "đang nghỉ ngơi ở %s" % where


# ---------------------------------------------------------------- sổ đăng ký vật phẩm độc nhất
func register_unique(uid: String, name: String, owner: String, origin := "") -> bool:
	if uniques.has(uid):
		return false   # đã có chủ: không đăng ký lại (chống nhân bản)
	uniques[uid] = {"name": name, "owner": owner, "origin": origin, "day": today(), "history": []}
	return true


func owner_of(uid: String) -> String:
	return str(uniques.get(uid, {}).get("owner", ""))


## Chuyển chủ: bắt buộc khai đúng chủ hiện tại. Trả false nếu chủ cũ không khớp hoặc vật không tồn tại.
func transfer(uid: String, from_owner: String, to_owner: String, cause: String) -> bool:
	if not uniques.has(uid) or str(uniques[uid]["owner"]) != from_owner:
		return false
	uniques[uid]["owner"] = to_owner
	(uniques[uid]["history"] as Array).append({"day": today(), "from": from_owner, "to": to_owner, "cause": cause})
	changed.emit()
	return true


func owned_by(owner: String) -> Array:
	var out: Array = []
	for uid in uniques:
		if str(uniques[uid]["owner"]) == owner:
			out.append(str(uid))
	return out


func legacy_uid(dp_id: String) -> String:
	return "legacy:%s:%d" % [dp_id, int(legacy_gen.get(dp_id, 0))]


## Bí tịch truyền thừa của một động phủ (thế hệ hiện tại) thuộc về động phủ cho tới khi có người lấy.
func ensure_legacy(dp_id: String) -> String:
	var uid := legacy_uid(dp_id)
	var nm := dp_id
	if main != null and main.destiny.dong_phu().has(dp_id):
		var lg: Dictionary = main.destiny.dong_phu()[dp_id].get("legacy", {})
		nm = str(CATALOG.definition(str(lg.get("book", ""))).get("name", dp_id))
	register_unique(uid, "Truyền thừa: %s" % nm, "world:" + dp_id, "dong_phu")
	return uid


func new_generation(dp_id: String) -> void:
	legacy_gen[dp_id] = int(legacy_gen.get(dp_id, 0)) + 1


## Người chơi kế thừa / lấy tài vật / chôn cất tiên nhân.
func on_player_legacy(dp_id: String, how: String) -> void:
	var uid := ensure_legacy(dp_id)
	var cur := owner_of(uid)
	if not cur.begins_with("world:"):
		return   # đã có chủ khác (NPC giành trước, đã chôn...): không có bản thứ hai để lấy
	match how:
		"inherit":
			transfer(uid, cur, "player", "Người chơi kế thừa truyền thừa")
		"loot":
			transfer(uid, cur, "lost:" + dp_id, "Người chơi chỉ lấy tài vật, truyền thừa bị bỏ lại")
		"bury":
			transfer(uid, cur, "buried:" + dp_id, "Người chơi chôn cất tiên nhân cùng truyền thừa")


## Tông địch / kẻ tầm bảo mở động phủ trước: truyền thừa chuyển sang một NPC tầm bảo, NPC đó bế quan. Trả tên NPC ("" nếu không có).
func on_rival_takes(dp_id: String, day: int) -> String:
	var hunters: Array = []
	for id in roster():
		if bool(roster()[id].get("treasure_hunter", false)) and str(states[id].get("status", "ok")) != "seclusion":
			hunters.append(str(id))
	if hunters.is_empty():
		return ""
	var pick: String = hunters[absi(("%s|%d" % [dp_id, day]).hash()) % hunters.size()]
	var uid := ensure_legacy(dp_id)
	var cur := owner_of(uid)
	if not transfer(uid, cur, "npc:" + pick, "Giành truyền thừa khi người chơi chậm chân"):
		return ""
	var st: Dictionary = states[pick]
	st["status"] = "seclusion"
	st["status_until"] = day + int(balance("seclusion_days", 8.0))
	st["loc"] = str(roster()[pick].get("home", "van_khe"))
	st["rel"] = int(st["rel"]) - 5
	var nm := display_name(pick)
	_note(pick, "Giành được %s và bế quan để lĩnh ngộ." % str(uniques[uid]["name"]), true, day)
	_dirty = true
	return nm


## Di vật cổ tu hay vật độc nhất khác lấy được từ thế giới: đăng ký chủ.
func claim_relic(node_id: String, name: String, owner: String) -> void:
	var uid := "relic:" + node_id
	if register_unique(uid, name, owner, "resource"):
		pass


# ---------------------------------------------------------------- nhật ký có nguyên nhân
func _note(id: String, text: String, news := false, day := -1) -> void:
	var st: Dictionary = states[id]
	var d := day if day >= 0 else today()
	(st["history"] as Array).append({"day": d, "text": text})
	while (st["history"] as Array).size() > int(balance("history_limit", 12.0)):
		(st["history"] as Array).pop_front()
	if news and main != null and main.province != null:
		main.province.add_news("%s: %s" % [display_name(id), text])


# ---------------------------------------------------------------- vòng lặp ngày
func _process(delta: float) -> void:
	if main == null or _data.is_empty():
		return
	_wander(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var day := today()
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		var from := maxi(_last_day + 1, day - int(balance("catchup_days_cap", 40.0)) + 1)
		for d in range(from, day + 1):
			_advance_day(d)
		_last_day = day
		_dirty = true
	if _dirty or str(main.current_map) != _scene_map:
		_sync_scene()


## NPC trong scene đi lại quanh chỗ đứng (đứng yên khi người chơi lại gần hoặc đang hội thoại).
func _wander(delta: float) -> void:
	var here: Dictionary = _nodes.get(str(main.current_map), {})
	if here.is_empty() or main.player == null:
		return
	var pp: Vector2 = main.player.position
	for id in here.keys():
		var n = here[id]
		if not is_instance_valid(n) or not n.has_method("set_walk"):
			continue
		var w: Dictionary = n.get_meta("wander", {})
		if w.is_empty():
			w = {"anchor": n.position, "target": n.position, "wait": randf_range(1.0, 4.0)}
			n.set_meta("wander", w)
		var near: bool = (n.position as Vector2).distance_to(pp) < 90.0
		if bool(main.dialogue.open) or near:
			if near:
				n.set_walk(pp - n.position, false)
			continue
		if float(w["wait"]) > 0.0:
			w["wait"] = float(w["wait"]) - delta
			n.set_walk(Vector2.ZERO, false)
			continue
		var to: Vector2 = (w["target"] as Vector2) - n.position
		if to.length() < 5.0:
			w["wait"] = randf_range(2.0, 6.0)
			var cand: Vector2 = (w["anchor"] as Vector2) + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 120.0)
			if not main._is_blocked(Rect2(cand.x - 26, cand.y - 26, 52, 44)):
				w["target"] = cand
			continue
		var step := to.normalized() * 38.0 * delta
		var np: Vector2 = (n.position as Vector2) + step
		if main._is_blocked(Rect2(np.x - 26, np.y - 26, 52, 44)):
			w["target"] = n.position
			w["wait"] = 0.6
			continue
		n.position = np
		n.set_walk(to, true)


## Một ngày game trôi qua cho mọi NPC ngoài scene (và trong scene: cùng trạng thái).
func _advance_day(day: int) -> void:
	_spread_deeds(day)
	_seek_tick(day)
	_duel_tick(day)
	_expire_requests(day)
	_initiatives(day)
	for id in agent_ids():
		var st: Dictionary = states[id]
		_decay_bonds(str(id), day)
		# hết trạng thái đặc biệt
		if str(st["status"]) != "ok" and day >= int(st.get("status_until", 0)):
			if str(st["status"]) == "seclusion":
				_note(str(id), "Xuất quan, tinh thần phấn chấn.", false, day)
			else:
				_note(str(id), "Vết thương đã lành.", false, day)
			st["status"] = "ok"
			st["act"] = "rest"
			st["until"] = day
		_develop(str(id), day)
		if str(st["status"]) != "ok":
			continue
		if day >= int(st["until"]):
			_resolve(str(id), day)
			_plan(str(id), day)


func _seeded(id: String, day: int, salt := "") -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(("%s|%d|%s" % [id, day, salt]).hash())
	return r


## Chọn hoạt động kế tiếp (NpcMind): chấm điểm từng hành động ở từng nơi họ BIẾT theo tính cách, mục tiêu, nhu cầu và rủi ro.
## `routine` trong dữ liệu chỉ còn là thiên hướng nghề nghiệp. Lý do chọn được ghi vào st["why"].
func _plan(id: String, day: int) -> void:
	var d: Dictionary = def_of(id)
	var st: Dictionary = states[id]
	var r := _seeded(id, day, "plan")
	var cands := _candidates(id, day)
	var holding := 0
	for k in (st["assets"] as Dictionary):
		holding += int(st["assets"][k])
	var act := "rest"
	var loc := str(d.get("home", "van_khe"))
	var why := ""
	var eid := ""
	if holding >= 6:
		# đủ hàng thì đi bán trước (không tích trữ mãi)
		act = "trade"
		loc = str(d.get("trade_at", "van_khe"))
		why = "đang giữ nhiều hàng"
	else:
		var pick: Dictionary = NpcMind.choose(cands, r)
		if int(pick.get("index", -1)) >= 0:
			act = str(pick["act"])
			loc = str(pick["loc"])
			why = str(pick["why"])
			eid = str((cands[int(pick["index"])] as Dictionary).get("event_id", ""))
	st["act"] = act
	st["loc"] = loc
	st["event_id"] = eid
	st["why"] = why
	st["until"] = day + (1 if act == "trade" else r.randi_range(1, 3))
	st["planned_day"] = day
	# nhớ nơi vừa đi để lần sau không lặp mãi một chỗ
	if act in ["gather", "hunt", "event"]:
		if str(st.get("last_loc", "")) == loc:
			st["streak"] = int(st.get("streak", 0)) + 1
		else:
			st["streak"] = 0
		st["last_loc"] = loc
	else:
		st["streak"] = 0


## Mục tiêu của NPC (khoá trong NpcMind.GOAL_NAMES).
func goal_kind(id: String) -> String:
	return str(def_of(id).get("goal_kind", "wealth"))


## Những địa điểm NPC biết: nơi ở, nơi làm việc, nơi buôn bán trong dữ liệu (không biết trước bí cảnh, địa điểm ẩn).
func known_places(id: String) -> Array:
	var d: Dictionary = def_of(id)
	var out: Array = [str(d.get("home", "van_khe"))]
	for k in ["gather_at", "hunt_at"]:
		for l in d.get(k, []):
			if str(l) not in out:
				out.append(str(l))
	var t := str(d.get("trade_at", ""))
	if t != "" and t not in out:
		out.append(t)
	for l in states.get(id, {}).get("known_extra", []):
		if str(l) not in out:
			out.append(str(l))
	return out


## Vật phẩm có thể thu ở địa điểm (theo điểm khai thác của map đó).
func materials_at(loc: String) -> Array:
	var out: Array = ["linh_thao"]
	if main == null or main.province == null:
		return out
	var li: Dictionary = main.province.info(loc)
	var map_id := str(li.get("map", ""))
	for s in main.resources.map_specs(map_id):
		if map_id == "overworld" and not _spec_near(s, li):
			continue
		var item := str(main.resources.kind_def(str(s.get("kind", ""))).get("item", ""))
		if item != "" and item not in out:
			out.append(item)
	return out


## Sự kiện đang diễn ra mà NPC biết: đã qua ít nhất 1 ngày (tin lan ra) và nằm trong vùng họ quen (cùng map với nơi họ biết).
func known_events(id: String, day: int) -> Array:
	var out: Array = []
	if main == null or main.events == null or main.province == null:
		return out
	var maps := {}
	for l in known_places(id):
		maps[str(main.province.info(str(l)).get("map", ""))] = true
	for e in main.events.events:
		if str(e["state"]) != "active":
			continue
		var loc := str(e["loc"])
		if int(e.get("start", e.get("day", day))) >= day:
			continue   # vừa xảy ra, chưa ai kịp nghe
		if str(e["tpl"]) not in ["thuong_doi_nan", "xung_dot_de_tu", "linh_thao_quy", "yeu_thu_tinh_anh", "linh_mach_bien_dong"]:
			continue
		if maps.has(str(main.province.info(loc).get("map", ""))):
			out.append(e)
	return out


## Danh sách ứng viên {act, loc, ctx[, event_id]} cho NpcMind.
func _candidates(id: String, day: int) -> Array:
	var d: Dictionary = def_of(id)
	var st: Dictionary = states[id]
	var traits: Dictionary = traits_of(id)
	var routine: Dictionary = d.get("routine", {"rest": 1.0})
	var total := 0.0
	for k in routine:
		total += float(routine[k])
	total = maxf(total, 0.001)
	var holding := 0
	for k in (st["assets"] as Dictionary):
		if str(k) != "co_tu_di_vat":
			holding += int(st["assets"][k])
	var goal := goal_kind(id)
	var goal_money := float(d.get("goal_money", 120))
	var need := clampf(1.0 - float(st["money"]) / maxf(goal_money, 1.0), 0.0, 1.0)
	var strength := int(d.get("strength", 2))
	var needs: Array = d.get("needs", [])
	var injured_days: int = day - int(st.get("injured_day", -999))
	var base := {
		"traits": traits, "strength": strength, "money_need": need, "holding": holding, "goal": goal,
		"injured_days": injured_days, "streak": 0,
	}
	var home := str(d.get("home", "van_khe"))
	var out: Array = []
	var c := base.duplicate()
	c["prior"] = float(routine.get("rest", 0.0)) / total
	c["danger"] = 1
	out.append({"act": "rest", "loc": home, "ctx": c})
	c = base.duplicate()
	c["prior"] = float(routine.get("rest", 0.0)) / total * 0.3
	c["danger"] = 1
	out.append({"act": "cultivate", "loc": home, "ctx": c})
	if holding > 0:
		c = base.duplicate()
		c["prior"] = float(routine.get("trade", 0.0)) / total
		c["danger"] = 1
		out.append({"act": "trade", "loc": str(d.get("trade_at", "van_khe")), "ctx": c})
	for kind in ["gather", "hunt"]:
		var places: Array = d.get(kind + "_at", [])
		for l in places:
			var li: Dictionary = main.province.info(str(l))
			c = base.duplicate()
			c["prior"] = float(routine.get(kind, 0.0)) / total / maxf(1.0, float(places.size()) * 0.5)
			c["danger"] = main.events.danger_of(str(l), int(li.get("danger", 1)))
			c["streak"] = int(st.get("streak", 0)) if str(st.get("last_loc", "")) == str(l) else 0
			if kind == "gather" and not needs.is_empty():
				var mats := materials_at(str(l))
				for n in needs:
					if str(n) in mats:
						c["place_has_need"] = true
			out.append({"act": kind, "loc": str(l), "ctx": c})
	for e in known_events(id, day):
		var li2: Dictionary = main.province.info(str(e["loc"]))
		c = base.duplicate()
		c["prior"] = 0.0
		c["danger"] = main.events.danger_of(str(e["loc"]), int(li2.get("danger", 1)))
		c["event_tpl"] = str(e["tpl"])
		c["righteous_help"] = str(e["tpl"]) in ["thuong_doi_nan", "xung_dot_de_tu"]
		c["streak"] = int(st.get("streak", 0)) if str(st.get("last_loc", "")) == str(e["loc"]) else 0
		out.append({"act": "event", "loc": str(e["loc"]), "ctx": c, "event_id": str(e["id"])})
	return out


## Kết thúc hoạt động đang làm: nhận kết quả hoặc gặp nạn (đều có lý do).
func _resolve(id: String, day: int) -> void:
	var st: Dictionary = states[id]
	var d: Dictionary = def_of(id)
	var act := str(st["act"])
	var loc := str(st["loc"])
	var r := _seeded(id, day, "res")
	var li: Dictionary = main.province.info(loc)
	if act == "event":
		# chạy theo sự kiện: yêu thú tinh anh thì đi săn, còn lại thì đi tìm vật liệu / quan sát
		act = "gather"
		for e in main.events.events:
			if str(e["id"]) == str(st.get("event_id", "")) and str(e["tpl"]) == "yeu_thu_tinh_anh":
				act = "hunt"
		_bump(st, "event_trips")
	match act:
		"cultivate":
			_bump(st, "cultivate")
		"gather", "hunt":
			var danger: int = main.events.danger_of(loc, int(li.get("danger", 1)))
			var gap := danger - int(d.get("strength", 2))
			_bump(st, "trips")
			if gap > 0 and r.randf() < float(gap) * balance("injury_per_danger_gap", 0.18):
				_bump(st, "injured")
				st["injured_day"] = day
				st["status"] = "injured"
				st["status_until"] = day + int(balance("injury_rest_days", 2.0))
				st["loc"] = str(d.get("home", "van_khe"))
				_note(id, "Bị trọng thương khi %s ở %s (nguy hiểm %d, sức %d). Về nhà dưỡng thương." % ["tìm vật liệu" if act == "gather" else "săn yêu thú", main.province.display_name(loc), danger, int(d.get("strength", 2))], gap >= 2, day)
				return
			var got := _loot(id, act, loc, li, r, day)
			if not got.is_empty() and main.get("treasury") != null:
				got = main.treasury.tithe(sect_legacy_of(str(id)), got, display_name(str(id)))   # nộp một phần cho kho tông
			if got.is_empty():
				_note(id, "Đi %s ở %s nhưng không tìm thấy gì." % ["tìm vật liệu" if act == "gather" else "săn", main.province.display_name(loc)], false, day)
			else:
				var parts: Array = []
				for k in got:
					st["assets"][k] = int(st["assets"].get(k, 0)) + int(got[k])
					_bump(st, "loot", int(got[k]))
					parts.append("%d %s" % [int(got[k]), Items.item_name(str(k))])
				var rare := got.has("co_tu_di_vat") or got.has("huyen_thiet") or got.has("linh_mach_tinh") or got.has("ngan_nien_thao")
				_note(id, "Thu được %s ở %s." % [", ".join(parts), main.province.display_name(loc)], rare, day)
		"trade":
			var sum := 0
			var sold: Array = []
			for k in (st["assets"] as Dictionary).keys():
				if str(k) == "co_tu_di_vat":
					continue   # vật độc nhất không đem bán rẻ
				var n := int(st["assets"][k])
				var price: int = int(Items.DATA.get(str(k), {}).get("sell", 1))
				sum += n * price
				sold.append("%d %s" % [n, Items.item_name(str(k))])
				st["assets"].erase(k)
			if sum > 0:
				_bump(st, "earned", sum)
				st["money"] = int(st["money"]) + sum
				_note(id, "Bán %s ở %s, được %d linh thạch." % [", ".join(sold), main.province.display_name(loc), sum], false, day)
		_:
			pass


## Quyết định vật phẩm thu được (lấy từ ResourceWorld thật để dùng chung trạng thái với người chơi).
func _loot(id: String, act: String, loc: String, li: Dictionary, r: RandomNumberGenerator, day: int) -> Dictionary:
	var out := {}
	var map_id := str(li.get("map", ""))
	if act == "hunt":
		var table: Array = ["soi_nanh", "da_yeu"]
		if int(li.get("danger", 1)) >= 3:
			table = ["da_yeu", "yeu_dan", "yeu_dan"]
		if int(li.get("danger", 1)) >= 4:
			table = ["yeu_dan", "yeu_dan", "lang_vuong_nanh"] if r.randf() < 0.15 else ["yeu_dan", "da_yeu"]
		var n := r.randi_range(1, 2)
		for i in n:
			var k: String = table[r.randi_range(0, table.size() - 1)]
			out[k] = int(out.get(k, 0)) + 1
		return out
	# thu thập: chỉ lấy điểm khai thác có thật trong map của địa điểm đó
	var cand: Array = []
	for s in main.resources.map_specs(map_id):
		if map_id == "overworld" and not _spec_near(s, li):
			continue
		for i in int(s.get("count", 1)):
			cand.append("%s:%s:%d" % [map_id, str(s["kind"]), i])
	# linh thảo quý do sự kiện sinh ra ở nơi họ đang có mặt
	for ev in main.events.active_of("linh_thao_quy"):
		if str(ev["loc"]) == loc and ev["data"].has("node_id"):
			cand.append(str(ev["data"]["node_id"]))
	# linh thảo thường (không nằm trong danh sách rải mà do dựng map sinh ra): lấy theo số điểm đã dựng
	for i in mini(int(main.resources.known_count(map_id, "linh_thao")), 12):
		cand.append("%s:linh_thao:%d" % [map_id, i * 3 % maxi(1, int(main.resources.known_count(map_id, "linh_thao")))])
	_shuffle(cand, r)
	var want := r.randi_range(1, 2)
	for nid in cand:
		if want <= 0:
			break
		var kind: String = main.resources.node_kind(str(nid))
		if kind == "" or not main.resources.npc_can_take(str(nid)):
			continue
		var cls := str(main.resources.kind_def(kind).get("class", ""))
		if cls == "unique" and (int(def_of(id).get("strength", 2)) < 3 or r.randf() > 0.08):
			continue   # di vật độc nhất: chỉ kẻ đủ mạnh, và hiếm khi tìm ra (không để NPC vét sạch cơ duyên của người chơi)
		var got: Dictionary = main.resources.npc_take(str(nid), id)
		if got.is_empty():
			continue
		out[str(got["item"])] = int(out.get(str(got["item"]), 0)) + int(got["amount"])
		want -= 1
	return out


## Trong map gốc: chỉ lấy điểm có vùng rải giao với vùng của địa điểm (±300 điểm thế giới).
func _spec_near(spec: Dictionary, li: Dictionary) -> bool:
	var rects: Array = spec.get("rects", [])
	if rects.is_empty() or not li.has("at"):
		return true
	var at := Vector2(float(li["at"][0]), float(li["at"][1]))
	var rad := float(li.get("r", 400.0)) + 300.0
	for rc in rects:
		var rect := Rect2(float(rc[0]), float(rc[1]), float(rc[2]), float(rc[3]))
		var nearest := Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
		if nearest.distance_to(at) <= rad:
			return true
	return false


## Xáo trộn cố định theo hạt giống (không dùng RNG toàn cục).
func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---------------------------------------------------------------- hiện trong scene
## Cư dân đang đi việc ở ngoài mà người chơi vào map nhà của họ: họ trở về ngay (hệ sinh hoạt cũ sẽ hiện họ như thường).
func _recall_residents() -> void:
	for id in residents():
		if not states.has(id):
			continue
		var st: Dictionary = states[id]
		var home := str(residents()[id].get("home", ""))
		if str(st["loc"]) == home:
			continue
		if str(main.province.info(home).get("map", "")) == _scene_map:
			st["loc"] = home
			st["act"] = "rest"
			st["until"] = today()
			if str(st["status"]) == "injured":
				st["status"] = "ok"
			_note(str(id), "Nghe có người tới, trở về %s." % main.province.display_name(home), false)


## Bia/cửa động ở nơi NPC đang bế quan: người chơi tới tìm thì có thể gõ cửa hoặc để lại lễ vật.
func _spawn_seclusions(here: Dictionary) -> void:
	for id in roster():
		var st: Dictionary = states[id]
		if str(st["status"]) != "seclusion":
			continue
		var li: Dictionary = main.province.info(str(st["loc"]))
		if str(li.get("map", "")) != _scene_map:
			continue
		var anchor := _scene_anchor(str(st["loc"]))
		var r := _seeded(str(id), int(st.get("seclude_seed", 0)), "seclude")
		var pos := anchor
		var placed := false
		for i in 40:
			pos = anchor + Vector2.from_angle(r.randf() * TAU) * r.randf_range(140.0, 300.0)
			if not main._is_blocked(Rect2(pos.x - 30, pos.y - 30, 60, 50)):
				placed = true
				break
		if not placed:
			continue
		var node := EncounterNode.new()
		node.setup("wseclude_" + str(id), {"name": "Nơi bế quan của %s" % display_name(str(id)), "kind": "stone", "prompt": "Gõ cửa động", "glow": [0.8, 0.6, 1.0]})
		node.position = pos
		main.world.add_child(node)
		main.npcs.append(node)
		here["seclude_" + str(id)] = node


func talk_seclusion(node: EncounterNode) -> void:
	var id := node.enc_id.trim_prefix("wseclude_")
	if not states.has(id):
		return
	var st: Dictionary = states[id]
	var left := maxi(0, int(st.get("status_until", 0)) - today())
	var nm := display_name(id)
	main.meditating = false
	main.dialogue.choose("Nơi bế quan của %s" % nm, "Cấm chế bao phủ cửa động; bên trong có linh khí nén chặt. %s còn bế quan khoảng %d ngày nữa." % [nm, left], [
		{"text": "Gõ cửa gọi", "call": _knock.bind(id)},
		{"text": "Để lại 20 linh thạch làm lễ vật", "call": _gift.bind(id)},
		{"text": "Lặng lẽ rời đi", "call": Callable()},
	])


func _knock(id: String) -> void:
	var st: Dictionary = states[id]
	record(id, "disturb")
	st["status_until"] = int(st["status_until"]) + 1
	_note(id, "Bị người chơi gõ cửa giữa lúc bế quan, tâm thần xao động; kéo dài thêm 1 ngày.", false)
	main.dialogue.say(display_name(id), ["(Từ trong vọng ra) Ai quấy rầy ta thế! Đi đi!"])


func _gift(id: String) -> void:
	if not main.inv.spend_stones(20):
		main.hud.toast("Không đủ linh thạch.")
		return
	var st: Dictionary = states[id]
	record(id, "gift")
	st["money"] = int(st["money"]) + 20
	_note(id, "Nhận lễ vật 20 linh thạch từ người chơi để ngoài cửa động.", false)
	main.dialogue.say(display_name(id), ["(Giọng khẽ vọng ra) Ta nhận tấm lòng. Chờ ta xuất quan sẽ gặp lại."])


func _scene_anchor(loc: String) -> Vector2:
	var li: Dictionary = main.province.info(loc)
	if li.has("at"):
		return Vector2(float(li["at"][0]), float(li["at"][1]))
	return main.map_def.get("entry", Vector2(400, 400)) as Vector2


func _sync_scene() -> void:
	_dirty = false
	_scene_map = str(main.current_map)
	# dọn nút của map hiện tại (dựng lại theo trạng thái mới) và bỏ ghi nhận các nút của map phụ đã bị giải phóng
	for m in _nodes.keys():
		var group: Dictionary = _nodes[m]
		for id in group.keys():
			var n = group[id]
			if not is_instance_valid(n):
				group.erase(id)
			elif str(m) == _scene_map:
				main.npcs.erase(n)
				n.queue_free()
				group.erase(id)
		if group.is_empty():
			_nodes.erase(m)
	if main.player == null or bool(main.map_def.get("war", false)):
		return
	_recall_residents()
	var here: Dictionary = {}
	_nodes[_scene_map] = here
	_spawn_seclusions(here)
	var shown := 0
	var cap := int(balance("max_scene_npcs", 3.0))
	for id in roster():
		if shown >= cap:
			break
		var st: Dictionary = states[id]
		if str(st["status"]) == "seclusion":
			continue
		var li: Dictionary = main.province.info(str(st["loc"]))
		if str(li.get("map", "")) != _scene_map:
			continue
		var anchor := _scene_anchor(str(st["loc"]))
		if li.has("at") and anchor.distance_to(main.player.position) > float(li.get("r", 600.0)) + 900.0:
			continue
		var r := _seeded(str(id), today(), "pos")
		var pos := Vector2.ZERO
		var ok := false
		for i in 30:
			var ang := r.randf() * TAU
			pos = anchor + Vector2.from_angle(ang) * r.randf_range(120.0, 360.0)
			if not main._is_blocked(Rect2(pos.x - 30, pos.y - 30, 60, 50)):
				ok = true
				break
		if not ok:
			continue
		var d: Dictionary = roster()[id]
		var node := EncounterNode.new()
		node.setup("wnpc_" + str(id), {"name": str(d["name"]), "kind": "figure", "outfit": d.get("outfit", {}), "prompt": "Trò chuyện với %s" % str(d["name"]), "glow": [0.9, 0.9, 0.6]})
		node.position = pos
		main.world.add_child(node)
		main.npcs.append(node)
		here[str(id)] = node
		shown += 1


# ---------------------------------------------------------------- trò chuyện / giao dịch
func talk(node: EncounterNode) -> void:
	var id := node.enc_id.trim_prefix("wnpc_")
	if not roster().has(id):
		return
	var d: Dictionary = roster()[id]
	var st: Dictionary = states[id]
	var sk: Dictionary = st.get("seek", {})
	if not sk.is_empty() and bool(sk.get("arrived", false)):
		main.meditating = false
		_seek_dialog(id)
		return
	var rel := int(st["rel"])
	var b := bond(id)
	var tone := "Ngươi cần gì ở ta?" if rel < 15 else "Lại gặp đạo hữu! Hôm nay thế nào?"
	if int(b["hate"]) >= 40:
		tone = "Ngươi còn dám xuất hiện trước mặt ta sao?" if int(traits_of(id).get("aggression", 50)) >= 50 else "...Ngươi đến làm gì?"
	elif int(b["fear"]) >= 40:
		tone = "(Lùi nửa bước) Ngươi... cần gì ở ta?"
	elif int(b["debt"]) >= 15:
		tone = "Đạo hữu! Ơn của ngươi ta vẫn khắc ghi trong lòng."
	if suspicion_of(id) > 0 and int(b["hate"]) < 40:
		tone = "Ta nghe đồn ngươi làm chuyện chẳng hay... Ta chưa rõ thực hư, nhưng sẽ để ý."
	var text := "%s — %s.\n%s %s." % [str(d["name"]), str(d["role"]), tone, "Ta " + activity_text(id)]
	var opts: Array = [
		{"text": "Hỏi thăm tin tức", "call": _ask_news.bind(id)},
		{"text": "Xem họ đang mang gì", "call": _show_assets.bind(id)},
		{"text": "Quan sát tu vi và tính cách", "call": _observe.bind(id)},
		{"text": "Nhắc chuyện cũ", "call": _recall.bind(id)},
	]
	if suspicion_of(id) > 0:
		opts.append({"text": "Phân trần về tin đồn", "call": _explain.bind(id)})
	var rq: Dictionary = st.get("request", {})
	if not rq.is_empty():
		opts.append({"text": "Giao %d %s theo lời nhờ (%d linh thạch)" % [int(rq["qty"]), Items.item_name(str(rq["item"])), int(rq["reward"])], "call": turn_in_request.bind(id)})
	opts.append({"text": "Cướp hành trang (nguy hiểm, bị ghi nhớ)", "call": _confirm_rob.bind(id)})
	if str(st["status"]) == "injured" and _heal_item() != "":
		opts.append({"text": "Đưa %s chữa thương" % Items.item_name(_heal_item()), "call": _rescue.bind(id)})
	if int(b["debt"]) >= 15 and today() - int(st.get("repay_day", -99)) >= 10 and int(traits_of(id).get("righteous", 50)) >= 50:
		opts.append({"text": "Nhận lời báo đáp", "call": _repay.bind(id)})
	for k in (st["assets"] as Dictionary):
		if not will_trade(id):
			break
		if int(st["assets"][k]) > 0 and str(k) != "co_tu_di_vat":
			var price := _buy_price(str(k), id)
			opts.append({"text": "Mua 1 %s (%d linh thạch)" % [Items.item_name(str(k)), price], "call": _buy.bind(id, str(k))})
			if opts.size() >= 5:
				break
	opts.append({"text": "Rời đi", "call": Callable()})
	main.meditating = false
	main.dialogue.choose(str(d["name"]), text, opts)


const HEAL_ITEMS := ["dan_ho_the", "dan_hoi_huyet"]


func _heal_item() -> String:
	for it in HEAL_ITEMS:
		if main.inv.count(it) > 0:
			return it
	return ""


## Đưa đan dược chữa thương cho NPC đang bị thương: vết thương lành ngay, họ ghi nhớ ơn cứu giúp.
func _rescue(id: String) -> void:
	var it := _heal_item()
	var st: Dictionary = states[id]
	if it == "" or str(st["status"]) != "injured":
		main.hud.toast("Không còn gì để giúp.")
		return
	main.inv.remove(it, 1)
	st["status"] = "ok"
	st["act"] = "rest"
	st["until"] = today()
	_note(id, "Được người chơi đưa %s chữa thương, vết thương lành ngay." % Items.item_name(it), false)
	record(id, "rescue")
	_dirty = true
	main.dialogue.say(display_name(id), ["(Vết thương dịu hẳn) Ơn này ta xin ghi nhớ. Sau này ngươi cần gì cứ nói."])


## NPC mắc ơn, trọng nghĩa thì tự báo đáp bằng một món hàng của họ (hoặc linh thạch). Mỗi 10 ngày một lần.
func _repay(id: String) -> void:
	var st: Dictionary = states[id]
	var best := ""
	var best_v := -1
	for k in (st["assets"] as Dictionary):
		if int(st["assets"][k]) > 0 and str(k) != "co_tu_di_vat":
			var v := int(Items.DATA.get(k, {}).get("sell", 0))
			if v > best_v:
				best = str(k)
				best_v = v
	st["repay_day"] = today()
	if best != "":
		st["assets"][best] = int(st["assets"][best]) - 1
		if int(st["assets"][best]) <= 0:
			st["assets"].erase(best)
		main.inv.add(best, 1)
		_note(id, "Báo đáp ơn người chơi bằng 1 %s." % Items.item_name(best), false)
		main.dialogue.say(display_name(id), ["Ta chẳng có gì quý, xin nhận 1 %s coi như chút lòng." % Items.item_name(best)])
	else:
		var pay := mini(int(st["money"]), 30)
		st["money"] = int(st["money"]) - pay
		main.inv.add_stones(pay)
		_note(id, "Báo đáp ơn người chơi bằng %d linh thạch." % pay, false)
		main.dialogue.say(display_name(id), ["Trong túi chỉ còn chừng này, ngươi nhận lấy %d linh thạch." % pay])
	record(id, "repay")


## Nhắc chuyện cũ: NPC kể lại vài ký ức quan trọng nhất về người chơi (theo thứ tự quan trọng rồi gần đây).
func _recall(id: String) -> void:
	var mem: Array = memories_of(id).duplicate()
	var about: Array = []
	for m in mem:
		if str(m["who"]) == "player":
			about.append(m)
	about.sort_custom(func(a, b): return int(a["imp"]) > int(b["imp"]) or (int(a["imp"]) == int(b["imp"]) and int(a["day"]) > int(b["day"])))
	var lines: Array = []
	for i in mini(4, about.size()):
		var m: Dictionary = about[i]
		var place := str(main.province.info(str(m.get("loc", ""))).get("name", "")) if main.province != null else ""
		lines.append("Ngày %d%s: %s" % [int(m["day"]), (" tại " + place) if place != "" else "", str(m["text"])])
	if lines.is_empty():
		lines.append("Ta chưa có chuyện gì đáng nhớ về ngươi.")
	else:
		lines.append("Với ngươi, ta " + bond_text(id) + ".")
	main.dialogue.say(display_name(id), lines)


## Quan sát một NPC: tính cách nhìn qua lời nói, hành vi; tu vi và bộ pháp chỉ thấy rõ khi người chơi không kém họ quá xa.
func _observe(id: String) -> void:
	var d: Dictionary = def_of(id)
	var p := profile_of(id)
	var lines: Array = []
	var words := NpcProfile.trait_words(traits_of(id))
	lines.append("Tính cách: " + (", ".join(words) if not words.is_empty() else "bình thường, khó đoán") + ".")
	lines.append("Họ với ngươi: " + bond_text(id) + ".")
	var know := know_of(id)
	if not know.is_empty():
		var bits: Array = []
		for did in know:
			var dd := deed_by_id(str(did))
			if not dd.is_empty():
				bits.append("%s (%s)" % [str(DEED_KINDS[str(dd["kind"])]["name"]), str(KNOW_NAMES[int(know[did]["lvl"])])])
		if not bits.is_empty():
			lines.append("Họ biết về ngươi: " + ", ".join(bits) + ".")
	if p == null:
		main.dialogue.say(display_name(id), lines)
		return
	var my_step: int = main.cult.step_index()
	var step := step_of(id)
	var gap := step - my_step
	if gap > 5:
		lines.append("Khí tức thâm sâu khó dò: cảnh giới cao hơn ngươi nhiều, không nhìn thấu pháp môn.")
	else:
		var sect_name := str(CATALOG.data().sects.get(p.sect, {"name": "Tán tu"}).name)
		var fate: Dictionary = CATALOG.data().fates.get(str(p.origin.get("fate", "")), {})
		lines.append("%s · %s · mệnh cách %s." % [sect_name, CATALOG.step_name(step), str(fate.get("name", "?"))])
		lines.append("Đang dùng: " + "; ".join(NpcProfile.loadout_text(p)) + ".")
		lines.append("Lối đánh: %s." % str(NpcProfile.STYLES.get(style_of(id), "?")))
		var dev := develop_log(id)
		if not dev.is_empty():
			var last: Dictionary = dev[dev.size() - 1]
			lines.append("Gần đây (ngày %d): %s" % [int(last["day"]), str(last["text"])])
	main.dialogue.say(display_name(id), lines)


func _buy_price(item: String, id := "") -> int:
	var mult := price_mult(id) if id != "" else 1.0
	return maxi(10, int(float(Items.DATA.get(item, {}).get("sell", 5)) * balance("buy_markup", 2.0) * mult))


func _show_assets(id: String) -> void:
	var st: Dictionary = states[id]
	var parts: Array = []
	for k in (st["assets"] as Dictionary):
		if int(st["assets"][k]) > 0:
			parts.append("%d %s" % [int(st["assets"][k]), Items.item_name(str(k))])
	var owned := owned_by("npc:" + id)
	for u in owned:
		parts.append(str(uniques[u]["name"]))
	var line := "Hành trang: " + (", ".join(parts) if not parts.is_empty() else "không có gì đáng kể") + ". Linh thạch: %d." % int(st["money"])
	var goal := str(roster()[id].get("goal", ""))
	var why := str(st.get("why", ""))
	var lines: Array = [line, "Mục tiêu: " + goal + " (" + str(NpcMind.GOAL_NAMES.get(goal_kind(id), "")) + ")"]
	if why != "":
		lines.append("Việc đang làm: %s — vì %s." % [activity_text(id), why])
	main.dialogue.say(display_name(id), lines)


func _ask_news(id: String) -> void:
	var st: Dictionary = states[id]
	if int(st["talk_day"]) == today():
		main.dialogue.say(display_name(id), ["Ta vừa kể hết những gì ta biết rồi. Mai quay lại xem."])
		return
	st["talk_day"] = today()
	record(id, "chat")
	var pool: Array = []
	for lid in main.province.locations():
		if main.province.state_of(str(lid)) == World.UNKNOWN and not bool(main.province.info(str(lid)).get("hidden", false)):
			pool.append(str(lid))
	var lines: Array = []
	if not pool.is_empty():
		var r := _seeded(id, today(), "news")
		var pick: String = pool[r.randi_range(0, pool.size() - 1)]
		var rel := "high" if int(st["rel"]) >= 15 else "medium"
		main.province.add_rumor(pick, "", display_name(id), rel)
		lines.append(str(main.province.info(pick).get("rumor", "Ta nghe loáng thoáng một nơi lạ.")))
	else:
		lines.append("Quanh vùng này ta chẳng còn gì lạ để kể.")
	if main.province.reveal_shortcut_from_npc(display_name(id)):
		lines.append("Ta còn biết một lối tắt; ghi vào sổ của ngươi rồi đó (R → Đại vực).")
	var h: Array = st["history"]
	if not h.is_empty():
		lines.append("Gần đây: " + str(h[h.size() - 1]["text"]))
	main.dialogue.say(display_name(id), lines)


func _buy(id: String, item: String) -> void:
	var st: Dictionary = states[id]
	if int(st["assets"].get(item, 0)) <= 0:
		main.hud.toast("%s không còn thứ đó." % display_name(id))
		return
	if not will_trade(id):
		main.dialogue.say(display_name(id), ["Ta không bán cho kẻ đã gây thù với ta."])
		return
	var price := _buy_price(item, id)
	if not main.inv.spend_stones(price):
		main.hud.toast("Không đủ linh thạch.")
		return
	st["assets"][item] = int(st["assets"][item]) - 1
	if int(st["assets"][item]) <= 0:
		st["assets"].erase(item)
	st["money"] = int(st["money"]) + price
	record(id, "trade")
	main.inv.add(item, 1)
	_note(id, "Bán lại 1 %s cho người chơi với giá %d linh thạch." % [Items.item_name(item), price], false)
	main.hud.toast("+1 %s" % Items.item_name(item))


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "states": states.duplicate(true), "uniques": uniques.duplicate(true), "legacy_gen": legacy_gen.duplicate(), "last_day": _last_day,
		"deeds": deeds.duplicate(true), "next_deed": next_deed}


func from_dict(d: Dictionary) -> void:
	states = (d.get("states", {}) as Dictionary).duplicate(true)
	uniques = (d.get("uniques", {}) as Dictionary).duplicate(true)
	legacy_gen = (d.get("legacy_gen", {}) as Dictionary).duplicate()
	_last_day = int(d.get("last_day", 0))
	deeds = (d.get("deeds", []) as Array).duplicate(true)
	next_deed = int(d.get("next_deed", 1))
	# NPC mới trong dữ liệu mà bản lưu cũ chưa có: bổ sung trạng thái khởi đầu; NPC bị xoá khỏi dữ liệu: bỏ
	for id in states.keys():
		if def_of(str(id)).is_empty():
			states.erase(id)
	_ensure_states()
	_dirty = true
