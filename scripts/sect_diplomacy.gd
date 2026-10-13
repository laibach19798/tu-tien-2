extends Node
class_name SectDiplomacy
## Ngoại giao giữa năm đại tông môn (Tông môn & Thế lực V1.0, bước 3): 10 cặp quan hệ, 4 trạng thái, 3 loại hiệp ước.
##  - Quan hệ -100..100 theo cặp (khoá "a|b" đã sắp xếp). Trạng thái: hữu hảo ≥ 30 · trung lập ≥ -20 · cảnh giác ≥ -50 · đối địch.
##  - Hiệp ước (giao thương / giao lưu / hợp tác) có điều kiện quan hệ, chi phí từ kho, thời hạn; tự huỷ nếu quan hệ sụp.
##  - Hành vi cá nhân KHÔNG tự thành chiến tranh: chỉ gây tranh chấp (dispute) giữa tông của kẻ làm và tông bị hại;
##    chỉ khi tông bao che hoặc không giải quyết trong hạn thì quan hệ cả hai tông mới bị ảnh hưởng mạnh.
## Khoá tông = id SectWar (kiem_tong, xich_viem, han_bang, doc_mon, huyen_minh).

const DATA_PATH := "res://data/sect_diplomacy.json"
const STATE_NAMES := {"friendly": "Hữu hảo", "neutral": "Trung lập", "wary": "Cảnh giác", "hostile": "Đối địch"}

var main: Node
var rel: Dictionary = {}          # "a|b" -> int
var treaties: Array = []          # {id, kind, a, b, start, end}
var disputes: Array = []          # {id, culprit, victim, sev, cause, day, open}
var events: Array = []            # nhật ký thay đổi quan hệ {day, a, b, delta, cause}
var next_id := 1
var _data: Dictionary = {}
var _drift := 0.0                 # phần thập phân tích luỹ của quan hệ (thay đổi theo ngày nhỏ hơn 1)
var _frac: Dictionary = {}
var _last_day := 0


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	if rel.is_empty():
		reset()


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)
	if _data.is_empty():
		_load()


func reset() -> void:
	rel.clear()
	treaties.clear()
	disputes.clear()
	events.clear()
	_frac.clear()
	next_id = 1
	for k in (_data.get("initial", {}) as Dictionary):
		rel[str(k)] = int(_data["initial"][k])


func bal(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func treaty_cfg(kind: String) -> Dictionary:
	return (_data.get("treaties", {}) as Dictionary).get(kind, {})


func treaty_kinds() -> Array:
	return (_data.get("treaties", {}) as Dictionary).keys()


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


static func key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


# ---------------------------------------------------------------- quan hệ
func relation(a: String, b: String) -> int:
	if a == b:
		return 100
	return int(rel.get(key(a, b), 0))


func state(a: String, b: String) -> String:
	var r := relation(a, b)
	var th: Dictionary = _data.get("thresholds", {})
	if r >= int(th.get("friendly", 30)):
		return "friendly"
	if r >= int(th.get("neutral", -20)):
		return "neutral"
	if r >= int(th.get("wary", -50)):
		return "wary"
	return "hostile"


func state_name(a: String, b: String) -> String:
	return str(STATE_NAMES.get(state(a, b), "?"))


func change(a: String, b: String, delta: float, cause: String) -> void:
	if a == b or a == "" or b == "":
		return
	var k := key(a, b)
	var acc := float(_frac.get(k, 0.0)) + delta
	var whole := int(acc)   # cắt về 0: phần lẻ giữ lại cho lần sau
	_frac[k] = acc - float(whole)
	if whole == 0:
		return
	var before := state(a, b)
	rel[k] = clampi(int(rel.get(k, 0)) + whole, -100, 100)
	events.append({"day": today(), "a": a, "b": b, "delta": whole, "cause": cause})
	while events.size() > int(bal("events_limit", 40.0)):
		events.pop_front()
	var after := state(a, b)
	if after != before and main != null and main.province != null:
		main.province.add_news("Quan hệ %s – %s chuyển sang %s (%s)." % [SectWar.sect_name(a), SectWar.sect_name(b), str(STATE_NAMES[after]).to_lower(), cause])
	_break_invalid_treaties()


# ---------------------------------------------------------------- hiệp ước
func treaty_between(a: String, b: String, kind := "") -> Dictionary:
	for t in treaties:
		if key(str(t["a"]), str(t["b"])) == key(a, b) and (kind == "" or str(t["kind"]) == kind):
			return t
	return {}


func has_treaty(a: String, b: String, kind: String) -> bool:
	return not treaty_between(a, b, kind).is_empty()


## Lý do không ký được ("" nếu được).
func why_not(kind: String, a: String, b: String) -> String:
	var c := treaty_cfg(kind)
	if c.is_empty() or a == b:
		return "Hiệp ước không hợp lệ."
	if has_treaty(a, b, kind):
		return "Đã có hiệp ước này."
	if state(a, b) == "hostile":
		return "Hai tông đang đối địch, không thể đàm phán."
	if relation(a, b) < int(c.get("min_rel", 0)):
		return "Quan hệ chưa đủ (cần từ %d)." % int(c.get("min_rel", 0))
	if treaties.size() >= int(bal("max_treaties", 4.0)):
		return "Đã có quá nhiều hiệp ước đang hiệu lực."
	for d in disputes:
		if bool(d["open"]) and key(str(d["culprit"]), str(d["victim"])) == key(a, b):
			return "Còn tranh chấp chưa giải quyết giữa hai tông."
	return ""


func ratify(kind: String, a: String, b: String, cause := "") -> bool:
	if why_not(kind, a, b) != "":
		return false
	var c := treaty_cfg(kind)
	treaties.append({"id": "tr%d" % next_id, "kind": kind, "a": a, "b": b, "start": today(), "end": today() + int(c.get("days", 60))})
	next_id += 1
	if main != null and main.province != null:
		main.province.add_news("%s và %s ký hiệp ước %s%s." % [SectWar.sect_name(a), SectWar.sect_name(b), str(c.get("name", kind)).to_lower(), (" (" + cause + ")") if cause != "" else ""])
	return true


## Người chơi đề nghị (thay mặt tông của mình). Cần chức vị Chân Truyền trở lên và kho đủ chi phí.
func propose(kind: String, other: String) -> String:
	var me := SectWar.PLAYER
	if main.inv.sect_rank() < int(bal("propose_rank", 3.0)):
		return "Địa vị chưa đủ để thay mặt tông môn đàm phán (cần Chân Truyền trở lên)."
	var why := why_not(kind, me, other)
	if why != "":
		return why
	var cost := int(treaty_cfg(kind).get("cost", 0))
	if main.treasury.take(me, SectTreasury.STONES, cost, "Chi phí đàm phán hiệp ước") < cost:
		return "Ngân quỹ không đủ chi phí đàm phán (%d linh thạch)." % cost
	ratify(kind, me, other, "do người chơi đề nghị")
	change(me, other, 3.0, "Ký hiệp ước")
	return ""


func _break_invalid_treaties() -> void:
	var keep: Array = []
	for t in treaties:
		var c := treaty_cfg(str(t["kind"]))
		var floor_rel := int(c.get("min_rel", 0)) - int(bal("break_margin", 30.0))
		if relation(str(t["a"]), str(t["b"])) < floor_rel or state(str(t["a"]), str(t["b"])) == "hostile":
			if main != null and main.province != null:
				main.province.add_news("Hiệp ước %s giữa %s và %s bị huỷ vì quan hệ xấu đi." % [str(c.get("name", "")).to_lower(), SectWar.sect_name(str(t["a"])), SectWar.sect_name(str(t["b"]))])
			continue
		keep.append(t)
	treaties = keep


# ---------------------------------------------------------------- tranh chấp do hành vi cá nhân
## Một cá nhân của tông `culprit` gây hại cho tông `victim`. Mặc định chỉ tạo tranh chấp cần giải quyết; nếu tông bao che
## (covered) thì quan hệ giảm mạnh ngay. sev 1..3.
func incident(culprit: String, victim: String, sev: int, cause: String, covered := false) -> void:
	if culprit == victim or culprit == "" or victim == "" or not SectWar.SECTS.has(culprit) or not SectWar.SECTS.has(victim):
		return
	if covered:
		change(culprit, victim, -4.0 * float(sev), cause + " (bị bao che)")
		return
	change(culprit, victim, -1.0 * float(sev), cause)
	disputes.append({"id": "dp%d" % next_id, "culprit": culprit, "victim": victim, "sev": sev, "cause": cause, "day": today(), "open": true})
	next_id += 1


func open_disputes(sect := "") -> Array:
	var out: Array = []
	for d in disputes:
		if bool(d["open"]) and (sect == "" or str(d["culprit"]) == sect or str(d["victim"]) == sect):
			out.append(d)
	return out


## Đền bù từ kho của tông gây ra: quan hệ phục hồi một phần. Trả "" nếu thành công.
func settle(did: String) -> String:
	for d in disputes:
		if str(d["id"]) == did and bool(d["open"]):
			var cost := 40 * int(d["sev"])
			if main.treasury.take(str(d["culprit"]), SectTreasury.STONES, cost, "Đền bù tranh chấp") < cost:
				return "Ngân quỹ không đủ để đền bù (%d linh thạch)." % cost
			main.treasury.add(str(d["victim"]), SectTreasury.STONES, cost, "Nhận đền bù")
			d["open"] = false
			change(str(d["culprit"]), str(d["victim"]), 3.0 * float(d["sev"]), "Đền bù, hoà giải")
			return ""
	return "Không có tranh chấp đó."


# ---------------------------------------------------------------- hiệu lực lên các hệ khác
## Cách xin phép khai thác ở khu của `owner` đối với tông của người chơi: free | half | normal | refused.
func permit_mode(owner: String) -> String:
	var me := SectWar.PLAYER
	if owner == "" or owner == me:
		return "free"
	if has_treaty(me, owner, "trade") or has_treaty(me, owner, "cooperation"):
		return "free"
	match state(me, owner):
		"friendly":
			return "half"
		"hostile":
			return "refused"
	return "normal"


## Tông `att` có tấn công được tông `def` không (có hiệp ước giao thương / hợp tác thì không).
func can_attack(att: String, def: String) -> bool:
	return not (has_treaty(att, def, "trade") or has_treaty(att, def, "cooperation"))


## Hệ số nhắm vào tông def của tông att khi chọn mục tiêu tấn công.
func target_weight(att: String, def: String) -> float:
	if def == "":
		return 1.0
	if not can_attack(att, def):
		return 0.0
	return {"hostile": 2.0, "wary": 1.4, "neutral": 1.0, "friendly": 0.5}.get(state(att, def), 1.0)


## Đối tác hợp tác của tông `sect` (danh sách id).
func partners(sect: String) -> Array:
	var out: Array = []
	for t in treaties:
		if str(t["kind"]) == "cooperation":
			if str(t["a"]) == sect:
				out.append(str(t["b"]))
			elif str(t["b"]) == sect:
				out.append(str(t["a"]))
	return out


## Sự kiện chiến sự (gọi từ SectWar): att tấn công địa bàn của def; taken = chiếm được.
func on_attack(att: String, def: String, taken: bool) -> void:
	if def == "" or att == def:
		return
	change(att, def, -6.0 if taken else -3.0, "Tranh giành địa bàn")


# ---------------------------------------------------------------- vòng lặp ngày
func _process(_delta: float) -> void:
	if main == null or _data.is_empty():
		return
	var day := today()
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		var from := maxi(_last_day + 1, day - 30 + 1)
		for d in range(from, day + 1):
			advance_day(d)
		_last_day = day


func advance_day(day: int) -> void:
	# hiệu lực hiệp ước theo ngày
	var keep: Array = []
	for t in treaties:
		var c := treaty_cfg(str(t["kind"]))
		if day > int(t["end"]):
			if main != null and main.province != null:
				main.province.add_news("Hiệp ước %s giữa %s và %s hết hạn." % [str(c.get("name", "")).to_lower(), SectWar.sect_name(str(t["a"])), SectWar.sect_name(str(t["b"]))])
			continue
		keep.append(t)
		change(str(t["a"]), str(t["b"]), float(c.get("daily_rel", 0.0)), "Hợp tác theo hiệp ước")
		if str(t["kind"]) == "trade":
			_trade(str(t["a"]), str(t["b"]))
	treaties = keep
	# tranh chấp bị bỏ mặc quá hạn: coi như bao che
	for d in disputes:
		if bool(d["open"]) and day - int(d["day"]) > int(bal("dispute_days", 10.0)):
			d["open"] = false
			change(str(d["culprit"]), str(d["victim"]), -3.0 * float(d["sev"]), "Không giải quyết tranh chấp: " + str(d["cause"]))
	# quan hệ tự dịu dần về 0 khi không có biến cố
	if day % int(bal("drift_every_days", 10.0)) == 0:
		for k in rel.keys():
			var v := int(rel[k])
			if v != 0 and absi(v) < 60:
				rel[k] = v - signi(v)
	# AI ký hiệp ước với nhau khi quan hệ đủ tốt
	_ai_treaties(day)


func _ai_treaties(day: int) -> void:
	var sects: Array = SectWar.SECTS.keys()
	sects.sort()
	var r := RandomNumberGenerator.new()
	r.seed = absi(("dip|%d" % day).hash())
	if r.randf() > float(bal("ai_sign_chance", 0.08)) * float(sects.size()):
		return
	var pairs: Array = []
	for i in sects.size():
		for j in range(i + 1, sects.size()):
			var a: String = sects[i]
			var b: String = sects[j]
			if a == SectWar.PLAYER or b == SectWar.PLAYER:
				continue   # hiệp ước của người chơi do người chơi quyết định
			pairs.append([a, b])
	if pairs.is_empty():
		return
	var p: Array = pairs[r.randi_range(0, pairs.size() - 1)]
	var best := ""
	var best_min := -1
	for kd in treaty_kinds():
		var mr := int(treaty_cfg(str(kd)).get("min_rel", 0))
		if why_not(str(kd), str(p[0]), str(p[1])) == "" and mr > best_min:
			best = str(kd)
			best_min = mr
	if best != "":
		ratify(best, str(p[0]), str(p[1]), "hai tông tự thoả thuận")


## Giao thương: bên dư vật liệu bán cho bên thiếu, bên thiếu trả linh thạch (trong phạm vi phát được).
func _trade(a: String, b: String) -> void:
	var T = main.treasury
	var units := int(bal("trade_exchange_units", 2.0))
	for pair in [[a, b], [b, a]]:
		var seller: String = pair[0]
		var buyer: String = pair[1]
		for it in SectMissions.NEED_ITEMS:
			if T.stock(seller, it) >= SectMissions.TARGET_STOCK and T.stock(buyer, it) < SectMissions.TARGET_STOCK / 2:
				var price := int(Items.DATA.get(it, {}).get("sell", 6)) * units
				var paid: int = T.pay(buyer, price, "Mua vật liệu theo hiệp ước giao thương")
				if paid > 0:
					var n: int = T.take(seller, it, units, "Bán vật liệu theo hiệp ước giao thương")
					if n > 0:
						T.add(buyer, it, n, "Nhận vật liệu theo hiệp ước giao thương")
						T.add(seller, SectTreasury.STONES, paid, "Bán vật liệu theo hiệp ước giao thương")
					else:
						T.add(buyer, SectTreasury.STONES, paid, "Hoàn tiền")
				break


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "rel": rel.duplicate(), "treaties": treaties.duplicate(true), "disputes": disputes.duplicate(true), "events": events.duplicate(true),
		"next_id": next_id, "last_day": _last_day, "frac": _frac.duplicate()}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	rel = (d.get("rel", {}) as Dictionary).duplicate()
	treaties = (d.get("treaties", []) as Array).duplicate(true)
	disputes = (d.get("disputes", []) as Array).duplicate(true)
	events = (d.get("events", []) as Array).duplicate(true)
	next_id = int(d.get("next_id", 1))
	_last_day = int(d.get("last_day", 0))
	_frac = (d.get("frac", {}) as Dictionary).duplicate()
	for k in (_data.get("initial", {}) as Dictionary):
		if not rel.has(str(k)):
			rel[str(k)] = int(_data["initial"][k])
