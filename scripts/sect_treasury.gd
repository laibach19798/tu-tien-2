extends Node
class_name SectTreasury
## Ngân quỹ và kho của năm đại tông môn (thiết kế Tông môn & Thế lực V1.0, bước 1).
## Mỗi tông có một kho thật: linh thạch + vật liệu. Mỗi ngày game:
##   thu  = linh thạch từ các địa bàn đang kiểm soát (SectWar) + sản vật chuyên biệt của tông + cống nộp từ NPC của tông
##   chi  = nuôi đệ tử (linh thạch theo số người) + tiêu hao vật tư (linh thảo...)
## Phần thưởng chỉ được trả trong phạm vi kho (có dự trữ giữ lại); kho không bao giờ âm; không sụp đổ hoàn toàn.
## Khoá tông = id tông trong SectWar.SECTS (kiem_tong, xich_viem, han_bang, doc_mon, huyen_minh).

const DATA_PATH := "res://data/sect_economy.json"
const STONES := "stones"
const STATUS_NAMES := {"rich": "Dồi dào", "ok": "Đủ dùng", "tight": "Eo hẹp", "empty": "Cạn kiệt"}

var main: Node
var stocks: Dictionary = {}     # sect -> {item: qty}
var ledger: Array = []           # {day, sect, item, qty, cause} (mới nhất ở cuối)
var last_net: Dictionary = {}    # sect -> linh thạch ròng của ngày gần nhất
var donated: Dictionary = {}     # ngày -> cống hiến đã nhận từ hiến tặng hôm đó
var _data: Dictionary = {}
var _last_day := 0


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	if stocks.is_empty():
		reset()


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)
	if _data.is_empty():
		_load()


func reset() -> void:
	stocks.clear()
	ledger.clear()
	last_net.clear()
	donated.clear()
	for s in SectWar.SECTS:
		var st: Dictionary = (cfg(str(s)).get("start", {}) as Dictionary).duplicate()
		stocks[str(s)] = {}
		for k in st:
			stocks[str(s)][str(k)] = int(st[k])


func cfg(sect: String) -> Dictionary:
	return (_data.get("sects", {}) as Dictionary).get(sect, {})


func balance(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


# ---------------------------------------------------------------- kho
func stock(sect: String, item: String = STONES) -> int:
	return int((stocks.get(sect, {}) as Dictionary).get(item, 0))


func items_of(sect: String) -> Dictionary:
	return (stocks.get(sect, {}) as Dictionary).duplicate()


func add(sect: String, item: String, qty: int, cause := "") -> void:
	if qty <= 0 or not stocks.has(sect):
		return
	stocks[sect][item] = stock(sect, item) + qty
	_log(sect, item, qty, cause)


## Lấy ra tối đa qty (không vượt kho). Trả số đã lấy.
func take(sect: String, item: String, qty: int, cause := "") -> int:
	if qty <= 0 or not stocks.has(sect):
		return 0
	var n := mini(qty, stock(sect, item))
	if n <= 0:
		return 0
	stocks[sect][item] = stock(sect, item) - n
	if int(stocks[sect][item]) <= 0:
		(stocks[sect] as Dictionary).erase(item)
	_log(sect, item, -n, cause)
	return n


func _log(sect: String, item: String, qty: int, cause: String) -> void:
	ledger.append({"day": today(), "sect": sect, "item": item, "qty": qty, "cause": cause})
	var lim := int(balance("ledger_limit", 60.0))
	while ledger.size() > lim:
		ledger.pop_front()


# ---------------------------------------------------------------- chi tiêu cố định, trạng thái, thưởng
func upkeep(sect: String) -> int:
	var c := cfg(sect)
	return int(ceil(float(c.get("members", 40)) * float(c.get("upkeep_per_member", 1.0))))


## Dự trữ không được dùng để thưởng (đủ nuôi đệ tử vài ngày).
func reserve(sect: String) -> int:
	return upkeep(sect) * int(balance("reserve_days", 3.0))


func payable(sect: String) -> int:
	return maxi(0, stock(sect) - reserve(sect))


## rich | ok | tight | empty theo số ngày nuôi được.
func status(sect: String) -> String:
	var s := stock(sect)
	if s <= 0:
		return "empty"
	var days := float(s) / maxf(float(upkeep(sect)), 1.0)
	if days >= balance("status_rich", 1.5) * 10.0:
		return "rich"
	if days >= balance("status_ok", 0.6) * 10.0:
		return "ok"
	return "tight"


func status_name(sect: String) -> String:
	return str(STATUS_NAMES.get(status(sect), "?"))


## Số ngày nuôi được với kho hiện tại.
func runway_days(sect: String) -> float:
	return float(stock(sect)) / maxf(float(upkeep(sect)), 1.0)


## Trả thưởng linh thạch cho người/NPC từ kho tông: tối đa phần còn lại sau dự trữ. Trả số thực trả.
func pay(sect: String, stones: int, cause := "") -> int:
	if stones <= 0:
		return 0
	var n := mini(stones, payable(sect))
	return take(sect, STONES, n, cause) if n > 0 else 0


## Trả thưởng cho người chơi (tông của người chơi). Thiếu kho thì chỉ trả phần có và báo rõ.
func pay_player(stones: int, cause := "") -> int:
	var sect := SectWar.PLAYER
	var paid := pay(sect, stones, cause)
	if main != null and main.inv != null and paid > 0:
		main.inv.add_stones(paid)
	if paid < stones and main != null and main.hud != null:
		main.hud.toast("Ngân quỹ %s eo hẹp: chỉ phát %d / %d linh thạch." % [SectWar.sect_name(sect), paid, stones])
	return paid


# ---------------------------------------------------------------- cống nộp và hiến tặng
## NPC của tông nộp một phần chiến lợi phẩm (làm tròn xuống). Trả phần NPC được giữ.
func tithe(sect: String, loot: Dictionary, who := "") -> Dictionary:
	if not stocks.has(sect) or loot.is_empty():
		return loot
	var rate := balance("tithe_rate", 0.25)
	var kept := {}
	for k in loot:
		var n := int(loot[k])
		var give := int(floor(float(n) * rate))
		if str(k) == "co_tu_di_vat":
			give = 0   # vật độc nhất thuộc sổ sở hữu riêng, không nộp thuế
		if give > 0:
			add(sect, str(k), give, "Cống nộp từ %s" % who if who != "" else "Cống nộp")
		if n - give > 0:
			kept[k] = n - give
	return kept


## Người chơi hiến vật liệu cho tông của mình. Nhận cống hiến theo giá trị, có trần mỗi ngày. Trả {ok, merit, taken}.
func donate(item: String, qty: int) -> Dictionary:
	var sect := SectWar.PLAYER
	if qty <= 0 or main == null or main.inv.count(item) < qty or not stocks.has(sect) or item == "co_tu_di_vat":
		return {"ok": false, "merit": 0, "taken": 0}
	var worth := int(Items.DATA.get(item, {}).get("sell", 0))
	if worth <= 0:
		return {"ok": false, "merit": 0, "taken": 0}
	var day := today()
	var cap := int(balance("donation_merit_cap_per_day", 40.0))
	var used := int(donated.get(str(day), 0))
	var per := maxi(1, int(worth / int(balance("donation_merit_div", 5.0))))
	var merit := mini(per * qty, maxi(0, cap - used))
	main.inv.remove(item, qty)
	add(sect, item, qty, "Người chơi hiến tặng")
	if merit > 0:
		main.inv.add_merit(merit)
		donated.clear()
		donated[str(day)] = used + merit
	return {"ok": true, "merit": merit, "taken": qty}


# ---------------------------------------------------------------- vòng lặp ngày
func _process(_delta: float) -> void:
	if main == null or _data.is_empty():
		return
	var day := today()
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		var from := maxi(_last_day + 1, day - int(balance("catchup_days_cap", 40.0)) + 1)
		for d in range(from, day + 1):
			advance_day(d)
		_last_day = day


## Thu chi một ngày cho cả năm tông. Công khai để test gọi trực tiếp.
func advance_day(day: int) -> void:
	for s in SectWar.SECTS:
		var sect := str(s)
		var c := cfg(sect)
		var before := stock(sect)
		# thu: địa bàn đang kiểm soát (theo hệ số thu nhập đặc điểm của tông)
		var k := float(SectWar.SECTS[sect].get("trait", {}).get("income", 1.0))
		var terr := 0
		if main.war != null:
			for t in SectWar.TERRITORIES:
				if main.war.owner_of(str(t["id"])) == sect:
					terr += int(round(float((t.get("income", {}) as Dictionary).get("stones", 0)) * k))
		if terr > 0:
			add(sect, STONES, terr, "Thu từ địa bàn")
		# sản vật chuyên biệt
		for p in c.get("produce", []):
			if day % maxi(1, int(p.get("every", 1))) == 0:
				add(sect, str(p["item"]), int(p.get("qty", 1)), "Sản vật tông môn")
		# chi: nuôi đệ tử và tiêu hao vật tư (không âm, thiếu thì ghi nhận thiếu hụt)
		var cost := upkeep(sect)
		var paid := take(sect, STONES, cost, "Nuôi đệ tử")
		if paid < cost:
			_log(sect, STONES, 0, "Thiếu %d linh thạch nuôi đệ tử" % (cost - paid))
		for u in c.get("consume", []):
			if day % maxi(1, int(u.get("every", 1))) == 0:
				take(sect, str(u["item"]), int(u.get("qty", 1)), "Tiêu hao vật tư")
		# chi mở rộng: phần vượt quá kho dự phòng (surplus_cap_days ngày nuôi) được dùng cho đào tạo / công trình mỗi ngày,
		# nên kho tiến tới một mức cân bằng thay vì tích luỹ vô hạn
		var cap := upkeep(sect) * int(balance("surplus_cap_days", 20.0))
		var over := stock(sect) - cap
		if over > 0:
			take(sect, STONES, maxi(1, int(float(over) * balance("surplus_spend", 0.1))), "Đầu tư đào tạo và công trình")
		last_net[sect] = stock(sect) - before


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "stocks": stocks.duplicate(true), "ledger": ledger.duplicate(true), "last_net": last_net.duplicate(), "donated": donated.duplicate(), "last_day": _last_day}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	stocks = (d.get("stocks", {}) as Dictionary).duplicate(true)
	ledger = (d.get("ledger", []) as Array).duplicate(true)
	last_net = (d.get("last_net", {}) as Dictionary).duplicate()
	donated = (d.get("donated", {}) as Dictionary).duplicate()
	_last_day = int(d.get("last_day", 0))
	for s in SectWar.SECTS:
		if not stocks.has(str(s)):
			stocks[str(s)] = (cfg(str(s)).get("start", {}) as Dictionary).duplicate()
