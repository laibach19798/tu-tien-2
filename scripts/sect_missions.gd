extends Node
class_name SectMissions
## Nhiệm vụ tông môn sinh từ nhu cầu thật của kho (Tông môn & Thế lực V1.0, bước 2).
## Bảy nhóm: collect (thu thập) · guard (trấn thủ) · escort (hộ tống) · investigate (điều tra) · envoy (ngoại giao)
##          · exam (khảo hạch) · hunt (truy bắt).
## Mỗi tông tự sinh nhiệm vụ cho chính mình theo nhu cầu; NPC của tông có thể hoàn thành trước (trạng thái "đã được giải quyết").
## Thưởng: cống hiến (không giới hạn bởi kho) + linh thạch lấy từ ngân quỹ tông (bị cắt theo kho, SectTreasury.pay_player).

const KIND_NAMES := {
	"collect": "Thu thập", "guard": "Trấn thủ", "escort": "Hộ tống", "investigate": "Điều tra",
	"envoy": "Ngoại giao", "exam": "Khảo hạch", "hunt": "Truy bắt",
}
const MAX_OPEN_PER_SECT := 3
const MAX_TAKEN := 3
const DEADLINE_DAYS := 12
const CATCHUP_CAP := 30
## Mức kho mong muốn của từng vật liệu; thấp hơn thì tông phát nhiệm vụ thu thập.
const TARGET_STOCK := 12
const NEED_ITEMS := ["linh_thao", "thiet_tinh", "yeu_dan", "da_yeu", "soi_nanh", "han_thuy_thach", "hoang_tho_tinh", "xich_hoa_thach", "linh_mach_tinh"]

var main: Node
var missions: Array = []       # mọi nhiệm vụ (mọi trạng thái, mới nhất ở cuối)
var next_id := 1
var kills: Dictionary = {}     # nhiệm vụ id -> số quái người chơi đã hạ cho nhiệm vụ đó
var _last_day := 0
var _check_t := 0.0


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


# ---------------------------------------------------------------- truy vấn
func get_mission(mid: String) -> Dictionary:
	for m in missions:
		if str(m["id"]) == mid:
			return m
	return {}


func open_for(sect: String) -> Array:
	var out: Array = []
	for m in missions:
		if str(m["sect"]) == sect and str(m["status"]) == "open":
			out.append(m)
	return out


func mine() -> Array:
	var out: Array = []
	for m in missions:
		if str(m["status"]) == "taken" and str(m.get("by", "")) == "player":
			out.append(m)
	return out


func describe(m: Dictionary) -> String:
	var t := "%s: %s" % [str(KIND_NAMES.get(str(m["kind"]), "?")), str(m["text"])]
	var left := int(m["deadline"]) - today()
	if str(m["status"]) in ["open", "taken"]:
		t += " · còn %d ngày" % maxi(0, left)
	return t


func status_text(m: Dictionary) -> String:
	return {"open": "đang mở", "taken": "đang làm", "done": "đã hoàn thành", "solved": "đã được người khác giải quyết", "expired": "quá hạn", "failed": "thất bại"}.get(str(m["status"]), str(m["status"]))


# ---------------------------------------------------------------- sinh nhiệm vụ
func _post(sect: String, kind: String, text: String, extra: Dictionary) -> Dictionary:
	var m := {"id": "m%d" % next_id, "sect": sect, "kind": kind, "text": text, "status": "open", "posted": today(),
		"deadline": today() + DEADLINE_DAYS, "by": "", "progress": 0}
	for k in extra:
		m[k] = extra[k]
	next_id += 1
	missions.append(m)
	_trim()
	return m


func _trim() -> void:
	# giữ lịch sử có hạn: bỏ nhiệm vụ đã kết thúc cũ nhất khi quá nhiều
	while missions.size() > 120:
		var cut := -1
		for i in missions.size():
			if str(missions[i]["status"]) not in ["open", "taken"]:
				cut = i
				break
		if cut < 0:
			break
		missions.remove_at(cut)


func _has(sect: String, kind: String, key := "", val := "") -> bool:
	for m in missions:
		if str(m["sect"]) == sect and str(m["kind"]) == kind and str(m["status"]) in ["open", "taken"]:
			if key == "" or str(m.get(key, "")) == val:
				return true
	return false


func _recent(sect: String, kind: String, days: int) -> bool:
	for m in missions:
		if str(m["sect"]) == sect and str(m["kind"]) == kind and today() - int(m["posted"]) < days:
			return true
	return false


## Sinh nhiệm vụ cho một tông theo nhu cầu hiện có (gọi mỗi ngày).
func generate(sect: String, day: int) -> void:
	if open_for(sect).size() >= MAX_OPEN_PER_SECT:
		return
	var T = main.treasury
	# 1) thu thập: kho thiếu vật liệu mà tông cần dùng / sản xuất
	var needs: Array = []
	var cfg: Dictionary = T.cfg(sect)
	for u in cfg.get("consume", []):
		needs.append(str(u["item"]))
	for p in cfg.get("produce", []):
		needs.append(str(p["item"]))
	for it in needs:
		if it in NEED_ITEMS and T.stock(sect, it) < TARGET_STOCK / 2 and not _has(sect, "collect", "item", it) and not _recent(sect, "collect", 5):
			var qty: int = clampi(TARGET_STOCK - T.stock(sect, it), 3, 8)
			var worth := int(Items.DATA.get(it, {}).get("sell", 6))
			_post(sect, "collect", "Kho thiếu %s, cần %d." % [Items.item_name(it), qty], {
				"item": it, "qty": qty, "target_stock": T.stock(sect, it) + qty,
				"merit": maxi(2, worth * qty / 4), "stones": int(worth * qty * 0.6)})
			return
	# 2) trấn thủ: địa bàn của tông đang bị tấn công
	if main.war != null:
		for tid in main.war.under_attack:
			if main.war.owner_of(str(tid)) == sect and not _has(sect, "guard", "tid", str(tid)):
				var tname := str(SectWar.territory(str(tid)).get("name", tid))
				_post(sect, "guard", "Địa bàn %s đang bị tấn công, cần người trấn thủ (hạ 3 kẻ xâm lấn)." % tname, {
					"tid": str(tid), "need": 3, "merit": 14, "stones": 40})
				return
	# 3) hộ tống: kho dư vật liệu (gấp đôi mức mong muốn) cần đem bán ở Vân Khê
	for k in T.items_of(sect):
		var item := str(k)
		if item in NEED_ITEMS and T.stock(sect, item) >= TARGET_STOCK * 2 and not _has(sect, "escort") and not _recent(sect, "escort", 8):
			var cargo: int = T.stock(sect, item) - TARGET_STOCK
			var w := int(Items.DATA.get(item, {}).get("sell", 6))
			_post(sect, "escort", "Hộ tống %d %s tới Làng Vân Khê để bán bớt." % [cargo, Items.item_name(item)], {
				"loc": "van_khe", "item": item, "cargo": cargo, "merit": 10, "stones": 25, "sale": int(cargo * w * 0.8)})
			return
	# 4) điều tra: có dị tượng / sự kiện đang diễn ra ở một địa điểm
	if main.events != null and not _recent(sect, "investigate", 6):
		for e in main.events.events:
			if str(e["state"]) in ["sign", "active"] and not _has(sect, "investigate", "ev", str(e["id"])):
				_post(sect, "investigate", "Có dị tượng ở %s, cần người tới xem xét." % main.province.display_name(str(e["loc"])), {
					"loc": str(e["loc"]), "ev": str(e["id"]), "merit": 12, "stones": 30})
				return
	# 5) ngoại giao: định kỳ gửi thư tới một tông khác
	if day % 10 == 0 and not _recent(sect, "envoy", 10):
		var others: Array = []
		for s in SectWar.SECTS:
			if str(s) != sect:
				others.append(str(s))
		others.sort()
		var to: String = others[absi((sect + str(day)).hash()) % others.size()]
		_post(sect, "envoy", "Đưa thư thăm hỏi tới %s." % SectWar.sect_name(to), {"loc": "sect_" + to, "to": to, "merit": 12, "stones": 20})
		return
	# 6) truy bắt: tán tu gây rối quanh vùng
	if day % 6 == 0 and not _recent(sect, "hunt", 12):
		_post(sect, "hunt", "Có tán tu cướp bóc quanh vùng, hạ 2 tên.", {"need": 2, "merit": 10, "stones": 35, "kinds": ["rogue_weak", "rogue_master"]})
		return
	# 7) khảo hạch: người chơi đủ cống hiến cho bậc kế
	if sect == SectWar.PLAYER and not _has(sect, "exam"):
		var cur: int = main.inv.sect_rank()
		if cur < Sect.RANKS.size() - 1 and main.inv.merit_total >= int(Sect.RANKS[cur + 1]["need"]) and not main.inv.inner_exam_passed:
			_post(sect, "exam", "Đủ cống hiến, có thể dự khảo hạch thăng cấp.", {"merit": 0, "stones": 0})


# ---------------------------------------------------------------- tương tác của người chơi
func accept(mid: String) -> bool:
	var m := get_mission(mid)
	if m.is_empty() or str(m["status"]) != "open" or str(m["sect"]) != SectWar.PLAYER:
		return false
	if mine().size() >= MAX_TAKEN:
		main.hud.toast("Ngươi đang làm quá nhiều việc tông môn (tối đa %d)." % MAX_TAKEN)
		return false
	m["status"] = "taken"
	m["by"] = "player"
	m["progress"] = 0
	if str(m["kind"]) in ["guard", "hunt"]:
		kills[mid] = 0
	main.hud.toast("Nhận việc: " + describe(m))
	return true


func abandon(mid: String) -> void:
	var m := get_mission(mid)
	if m.is_empty() or str(m["status"]) != "taken" or str(m.get("by", "")) != "player":
		return
	m["status"] = "open"
	m["by"] = ""
	kills.erase(mid)


## Giao vật liệu cho nhiệm vụ thu thập (chuyển thẳng vào kho tông).
func turn_in(mid: String) -> bool:
	var m := get_mission(mid)
	if m.is_empty() or str(m["kind"]) != "collect" or str(m["status"]) != "taken":
		return false
	var item := str(m["item"])
	var qty := int(m["qty"])
	# đã có người khác lấp đủ kho: nhiệm vụ coi như được giải quyết, không bắt giao
	if main.treasury.stock(str(m["sect"]), item) >= int(m["target_stock"]):
		_solved(m, "kho đã đủ")
		return false
	if main.inv.count(item) < qty:
		main.hud.toast("Chưa đủ %d %s." % [qty, Items.item_name(item)])
		return false
	main.inv.remove(item, qty)
	main.treasury.add(str(m["sect"]), item, qty, "Giao nhiệm vụ thu thập")
	_complete(m, "player")
	return true


## Hạ một quái: tính cho nhiệm vụ trấn thủ / truy bắt người chơi đang làm.
func on_kill(kind_id: String, map_id: String) -> void:
	for m in mine():
		var mid := str(m["id"])
		var ok := false
		if str(m["kind"]) == "hunt":
			ok = kind_id in (m.get("kinds", []) as Array)
		elif str(m["kind"]) == "guard":
			ok = kind_id != "" and main.war != null and main.war.under_attack.has(str(m.get("tid", "")))   # đang bảo vệ địa bàn bị tấn công
		if ok:
			kills[mid] = int(kills.get(mid, 0)) + 1
			m["progress"] = int(kills[mid])
			if int(kills[mid]) >= int(m.get("need", 1)):
				_complete(m, "player")


## Mỗi giây: nhiệm vụ cần tới một địa điểm tự hoàn thành khi người chơi tới nơi.
func _process(delta: float) -> void:
	if main == null:
		return
	var day := today()
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		var from := maxi(_last_day + 1, day - CATCHUP_CAP + 1)
		for d in range(from, day + 1):
			advance_day(d)
		_last_day = day
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 1.0
	check_arrivals()


func check_arrivals() -> void:
	if main.journey == null or main.player == null:
		return
	var here := str(main.journey.here())
	for m in mine():
		if str(m["kind"]) in ["escort", "investigate", "envoy"] and here != "" and here == str(m.get("loc", "")):
			_complete(m, "player")
		elif str(m["kind"]) == "exam" and main.inv.inner_exam_passed:
			_complete(m, "player")


# ---------------------------------------------------------------- kết thúc nhiệm vụ
func _complete(m: Dictionary, by: String) -> void:
	m["status"] = "done"
	m["by"] = by
	m["done_day"] = today()
	var sect := str(m["sect"])
	var merit := int(m.get("merit", 0))
	var stones := int(m.get("stones", 0))
	if by == "player":
		if merit > 0:
			main.inv.add_merit(merit)
		var paid: int = main.treasury.pay_player(stones, "Thưởng nhiệm vụ: " + str(KIND_NAMES.get(str(m["kind"]), ""))) if stones > 0 else 0
		main.hud.toast("Hoàn thành việc tông môn: +%d cống hiến, +%d linh thạch." % [merit, paid])
		kills.erase(str(m["id"]))
	if str(m["kind"]) == "escort":
		_sell_cargo(m)
	if str(m["kind"]) == "envoy" and main.get("diplomacy") != null and str(m.get("to", "")) != "":
		main.diplomacy.change(sect, str(m["to"]), 6.0 if by == "player" else 3.0, "Sứ giả thăm hỏi")
	if main.province != null:
		main.province.add_news("%s: việc \"%s\" đã hoàn thành." % [SectWar.sect_name(sect), str(m["text"])])


## Hàng hộ tống được bán ở nơi giao: kho tông nhận tiền, bớt vật liệu dư (dù người chơi hay NPC đã đưa tới).
func _sell_cargo(m: Dictionary) -> void:
	var sect := str(m["sect"])
	var n: int = main.treasury.take(sect, str(m["item"]), int(m["cargo"]), "Hàng hộ tống đem bán")
	if n > 0:
		main.treasury.add(sect, SectTreasury.STONES, int(float(m.get("sale", 0)) * float(n) / maxf(float(m["cargo"]), 1.0)), "Bán hàng hộ tống")


func _solved(m: Dictionary, why: String) -> void:
	if str(m["status"]) not in ["open", "taken"]:
		return
	var was_player := str(m.get("by", "")) == "player"
	m["status"] = "solved"
	m["why"] = why
	if str(m["kind"]) == "escort":
		_sell_cargo(m)   # NPC của tông đã đưa hàng tới nơi
	kills.erase(str(m["id"]))
	if was_player and main.hud != null:
		main.hud.toast("Việc đã được người khác giải quyết (%s): %s" % [why, str(m["text"])])


## Mỗi ngày: sinh nhiệm vụ mới, NPC của tông giải quyết trước, nhiệm vụ quá hạn.
func advance_day(day: int) -> void:
	_npc_progress(day)
	for m in missions:
		if str(m["status"]) in ["open", "taken"] and day > int(m["deadline"]):
			var taken := str(m["status"]) == "taken" and str(m.get("by", "")) == "player"
			m["status"] = "expired"
			if taken:
				var st = main.cultivation_v1.state
				st.reputation = maxi(0, int(st.reputation) - 1)   # đã nhận việc có hạn mà bỏ dở: mất một chút uy tín
				if main.hud != null:
					main.hud.toast("Việc tông môn quá hạn, uy tín giảm: " + str(m["text"]))
	for s in SectWar.SECTS:
		generate(str(s), day)


func _npc_progress(day: int) -> void:
	var nw = main.npc_world
	for m in missions:
		if str(m["status"]) not in ["open", "taken"]:
			continue
		var sect := str(m["sect"])
		match str(m["kind"]):
			"collect":
				if main.treasury.stock(sect, str(m["item"])) >= int(m["target_stock"]) and day > int(m["posted"]):
					_solved(m, "NPC đã nộp đủ")
			"guard", "hunt":
				var add := 0
				for id in nw.agent_ids():
					if nw.sect_legacy_of(str(id)) == sect and str(nw.states[id].get("act", "")) in ["hunt", "event"] and str(nw.states[id].get("status", "ok")) == "ok":
						add += 1
				if add > 0 and str(m.get("by", "")) != "player":
					m["npc_progress"] = float(m.get("npc_progress", 0.0)) + 0.5 * float(add)
					if float(m["npc_progress"]) >= float(m.get("need", 2)) * 2.0:
						_solved(m, "đệ tử đã xử lý")
			"escort", "investigate", "envoy":
				for id in nw.agent_ids():
					if nw.sect_legacy_of(str(id)) == sect and str(nw.states[id].get("loc", "")) == str(m.get("loc", "")) and str(nw.states[id].get("status", "ok")) == "ok" and day > int(m["posted"]):
						_solved(m, "%s đã tới nơi" % nw.display_name(str(id)))
						break


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "missions": missions.duplicate(true), "next_id": next_id, "kills": kills.duplicate(), "last_day": _last_day}


func from_dict(d: Dictionary) -> void:
	missions = (d.get("missions", []) as Array).duplicate(true)
	next_id = int(d.get("next_id", 1))
	kills = (d.get("kills", {}) as Dictionary).duplicate()
	_last_day = int(d.get("last_day", 0))
