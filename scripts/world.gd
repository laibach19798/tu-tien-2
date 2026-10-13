extends Node
class_name World
## Thế giới mở V1 (thiết kế: Thiet_Ke_The_Gioi_Mo_V1_0): hồ sơ khu vực + khám phá ba mức + bản đồ đại vực.
##  - Dữ liệu: data/world.json (địa điểm, tuyến đường, linh khí, nguy hiểm, tài nguyên, tin đồn).
##  - Ba mức thông tin cho mỗi địa điểm: Chưa biết / Tin đồn (vị trí gần đúng) / Đã phát hiện (xác nhận, quay lại được).
##  - Phát hiện: vào map đó (hoặc vào vùng của map gốc), đủ mảnh bản đồ động phủ, hoặc quan sát từ nơi đã biết.
##  - Tin đồn: mỗi ngày game có cơ hội nhận một tin về nơi kề tuyến đường đã biết; độ tin cậy quyết định độ sai lệch vị trí.
##  - Lưu/tải tương thích ngược; đồng hồ dùng chung (sect_life.day), không có đồng hồ thứ hai.

signal changed
signal discovered_location(id: String)

const DATA_PATH := "res://data/world.json"
const UNKNOWN := "unknown"
const RUMOR := "rumor"
const DISCOVERED := "discovered"

var main: Node
var states: Dictionary = {}        # id -> "rumor" | "discovered" (thiếu = chưa biết)
var rumors: Dictionary = {}        # id -> {"text", "source", "day", "reliability", "off": [x, y]}
var log: Array = []                # [{day, id, text}]
var routes_found: Dictionary = {}  # "a|b" -> true: đường tắt đã được phát hiện (đường chính hiện khi cả hai đầu đã biết)
var rng := RandomNumberGenerator.new()

var _data: Dictionary = {}
var _last_day := 0
var _timer := 0.0
var _loaded := false


func _ready() -> void:
	add_to_group("world")
	rng.randomize()
	_load_data()
	_apply_defaults()


func _load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	_loaded = not _data.is_empty()


func setup(p_main: Node) -> void:
	main = p_main
	_last_day = int(main.sect_life.day)


# ---------------------------------------------------------------- truy cập dữ liệu
func locations() -> Dictionary:
	return _data.get("locations", {})


func routes() -> Array:
	return _data.get("routes", [])


func province() -> Dictionary:
	return _data.get("province", {})


func balance(key: String, fallback := 0.0) -> float:
	return float((_data.get("balance", {}) as Dictionary).get(key, fallback))


func info(id: String) -> Dictionary:
	return locations().get(id, {})


func display_name(id: String) -> String:
	var d: Dictionary = info(id)
	if str(d.get("kind", "")) == "sect" and str(d.get("faction", "")) != "" and SectWar.SECTS.has(str(d["faction"])) and str(d.get("map", "")).begins_with("sect_"):
		return str(SectWar.SECTS[str(d["faction"])]["name"])
	return str(d.get("name", id))


func state_of(id: String) -> String:
	return str(states.get(id, UNKNOWN))


func count(state: String) -> int:
	var n := 0
	for id in locations():
		if state_of(str(id)) == state:
			n += 1
	return n


## Id địa điểm ứng với map hiện tại (map gốc dùng vị trí người chơi); "" nếu không có.
func location_at(map_id: String, pos := Vector2.ZERO) -> String:
	var best := ""
	var best_d := INF
	for id in locations():
		var d: Dictionary = locations()[id]
		if str(d.get("map", "")) != map_id:
			continue
		if d.has("at"):
			var at := Vector2(float(d["at"][0]), float(d["at"][1]))
			var dist := at.distance_to(pos)
			if dist <= float(d.get("r", 400.0)) and dist < best_d:
				best = str(id)
				best_d = dist
		elif best == "":
			best = str(id)
	return best


## Vị trí hiển thị trên bản đồ đại vực: đã phát hiện = chính xác; tin đồn = lệch theo độ tin cậy.
func map_pos(id: String) -> Vector2:
	var d: Dictionary = info(id)
	var p := Vector2(float(d["pos"][0]), float(d["pos"][1]))
	if state_of(id) == RUMOR and rumors.has(id):
		var off: Array = rumors[id].get("off", [0, 0])
		p += Vector2(float(off[0]), float(off[1]))
	return p


## Bán kính bất định (px bản đồ) của một tin đồn.
func rumor_radius(id: String) -> float:
	match str(rumors.get(id, {}).get("reliability", "medium")):
		"high":
			return 22.0
		"low":
			return 56.0
	return 38.0


# ---------------------------------------------------------------- trạng thái ban đầu
func _apply_defaults() -> void:
	for id in locations():
		var d: Dictionary = locations()[id]
		if str(d.get("start", "")) == DISCOVERED and not states.has(id):
			states[str(id)] = DISCOVERED


# ---------------------------------------------------------------- khám phá
func discover(id: String, how := "") -> void:
	if not locations().has(id) or state_of(id) == DISCOVERED:
		return
	states[id] = DISCOVERED
	rumors.erase(id)
	var nm := display_name(id)
	_log(id, "Đã phát hiện: %s%s." % [nm, (" (%s)" % how) if how != "" else ""])
	if main != null and main.hud != null:
		main.hud.toast("Đã phát hiện: %s" % nm)
	discovered_location.emit(id)
	changed.emit()
	# thấy nơi mới thì có thể nhìn ra vài dấu hiệu về nơi kề đó (chỉ nâng lên tin đồn)
	for nb in _neighbours(id):
		if state_of(nb) == UNKNOWN and not bool(info(nb).get("hidden", false)) and rng.randf() < 0.35:
			add_rumor(nb, "Từ %s có thể nhìn ra hướng tới %s." % [nm, "một nơi lạ"], "quan sát", "high")


## Thêm tin đồn cho một địa điểm chưa biết. Trả true nếu thật sự thêm.
func add_rumor(id: String, text := "", source := "tin đồn", reliability := "") -> bool:
	if not locations().has(id) or state_of(id) != UNKNOWN:
		return false
	var d: Dictionary = info(id)
	if reliability == "":
		reliability = _roll_reliability()
	var rad := 22.0 if reliability == "high" else (56.0 if reliability == "low" else 38.0)
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * rad
	var body := text if text != "" else str(d.get("rumor", "Có tin đồn về một nơi chưa ai xác nhận."))
	states[id] = RUMOR
	rumors[id] = {"text": body, "source": source, "day": int(main.sect_life.day) if main != null else 0, "reliability": reliability, "off": [off.x, off.y]}
	_log(id, "Tin đồn (%s): %s" % [source, body])
	if main != null and main.hud != null:
		main.hud.toast("Nghe được một tin đồn mới (R → Đại vực).")
	changed.emit()
	return true


## Còn nơi chưa biết (không ẩn) kề một nơi đã biết?
func has_unknown_reachable() -> bool:
	for id in locations():
		if bool(info(str(id)).get("hidden", false)) or state_of(str(id)) != UNKNOWN:
			continue
		for nb in _neighbours(str(id)):
			if state_of(nb) != UNKNOWN:
				return true
	return false


## Bản đồ mua được: chi tiết = xác nhận hẳn một nơi + lộ một đường tắt; thường = tin đồn đáng tin về một nơi.
func reveal_by_map(detailed: bool) -> String:
	var pool: Array = []
	for id in locations():
		if bool(info(str(id)).get("hidden", false)) or state_of(str(id)) != UNKNOWN:
			continue
		for nb in _neighbours(str(id)):
			if state_of(nb) != UNKNOWN:
				pool.append(str(id))
				break
	if pool.is_empty():
		return ""
	pool.sort()
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	if detailed:
		discover(pick, "bản đồ chi tiết")
		reveal_shortcut_from_npc("bản đồ chi tiết")
	else:
		add_rumor(pick, "", "bản đồ cũ của thương hội", "high")
	return pick


## Tin tức chung (từ NPC, sự kiện...) hiện ở nhật ký đại vực.
func add_news(text: String) -> void:
	_log("", text)
	changed.emit()


func _roll_reliability() -> String:
	var w: Dictionary = (_data.get("balance", {}) as Dictionary).get("reliability", {"high": 0.25, "medium": 0.5, "low": 0.25})
	var r := rng.randf()
	var acc := 0.0
	for k in ["high", "medium", "low"]:
		acc += float(w.get(k, 0.0))
		if r <= acc:
			return k
	return "medium"


func _neighbours(id: String) -> Array:
	var out: Array = []
	for r in routes():
		if str(r["a"]) == id:
			out.append(str(r["b"]))
		elif str(r["b"]) == id:
			out.append(str(r["a"]))
	return out


func _log(id: String, text: String) -> void:
	log.append({"day": int(main.sect_life.day) if main != null else 0, "id": id, "text": text})
	var lim := int(balance("rumor_log_limit", 80.0))
	while log.size() > lim:
		log.pop_front()


# ---------------------------------------------------------------- vòng lặp
func _process(delta: float) -> void:
	if main == null or not _loaded:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	_check_here()
	_sync_dong_phu()
	var day := int(main.sect_life.day)
	if day < _last_day:
		_last_day = day
	elif day > _last_day:
		var from := maxi(_last_day + 1, day - 30)
		_last_day = day
		for d in range(from, day + 1):
			_daily()


func _check_here() -> void:
	if main.player == null:
		return
	var id := location_at(str(main.current_map), main.player.position)
	if id != "" and state_of(id) != DISCOVERED:
		discover(id, "đã đặt chân tới")


## Động phủ: có mảnh bản đồ → tin đồn; đủ mảnh → xác nhận.
func _sync_dong_phu() -> void:
	var dest = main.get("destiny")
	if dest == null:
		return
	for id in locations():
		var d: Dictionary = locations()[id]
		if not bool(d.get("dong_phu", false)):
			continue
		var dp: Dictionary = dest.dong_phu().get(str(id), {})
		if dp.is_empty():
			continue
		var n := int(dest.fragments.get(str(id), 0))
		var need := int(dp.get("fragments", 3))
		var st := state_of(str(id))
		if n >= need and st != DISCOVERED:
			discover(str(id), "đủ %d mảnh bản đồ" % need)
		elif n > 0 and st == UNKNOWN:
			add_rumor(str(id), str(d.get("rumor", "")), "mảnh bản đồ", "medium")


func _daily() -> void:
	_reveal_shortcut(float((_data.get("travel", {}) as Dictionary).get("shortcut_reveal_per_day", 0.1)))
	if rng.randf() >= balance("rumor_chance_per_day", 0.25):
		return
	_add_daily_rumor()


# ---------------------------------------------------------------- tuyến đường
func route_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Tuyến đã biết để dùng: đường chính khi hai đầu đã nghe tin trở lên; đường tắt phải được phát hiện riêng.
func route_known(r: Dictionary) -> bool:
	if state_of(str(r["a"])) == UNKNOWN or state_of(str(r["b"])) == UNKNOWN:
		return false
	if str(r.get("kind", "main")) == "shortcut":
		return routes_found.has(route_key(str(r["a"]), str(r["b"])))
	return true


func discover_route(a: String, b: String, how := "") -> void:
	var key := route_key(a, b)
	if routes_found.has(key):
		return
	routes_found[key] = true
	_log("", "Phát hiện đường tắt giữa %s và %s%s." % [display_name(a), display_name(b), (" (%s)" % how) if how != "" else ""])
	changed.emit()


## Mỗi ngày có cơ hội lộ một đường tắt nối hai nơi đã phát hiện; trả true nếu lộ.
func _reveal_shortcut(chance: float) -> bool:
	if rng.randf() >= chance:
		return false
	var pool: Array = []
	for r in routes():
		if str(r.get("kind", "")) == "shortcut" and state_of(str(r["a"])) == DISCOVERED and state_of(str(r["b"])) == DISCOVERED and not route_known(r):
			pool.append(r)
	if pool.is_empty():
		return false
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	discover_route(str(pick["a"]), str(pick["b"]), "nghe người đi đường kể")
	if main != null and main.hud != null:
		main.hud.toast("Nghe nói có một đường tắt nối %s và %s." % [display_name(str(pick["a"])), display_name(str(pick["b"]))])
	return true


## Hỏi thăm NPC: chắc chắn lộ một đường tắt chưa biết nếu có.
func reveal_shortcut_from_npc(npc_name: String) -> bool:
	var pool: Array = []
	for r in routes():
		if str(r.get("kind", "")) == "shortcut" and state_of(str(r["a"])) != UNKNOWN and state_of(str(r["b"])) != UNKNOWN and not route_known(r):
			pool.append(r)
	if pool.is_empty():
		return false
	pool.sort_custom(func(x, y): return route_key(str(x["a"]), str(x["b"])) < route_key(str(y["a"]), str(y["b"])))
	var pick: Dictionary = pool[0]
	discover_route(str(pick["a"]), str(pick["b"]), "%s chỉ đường" % npc_name)
	return true


## Chỉ dùng cho menu thử nghiệm / test: bỏ qua xác suất ngày.
func _daily_force() -> void:
	_add_daily_rumor()


func _add_daily_rumor() -> void:
	var pool: Array = []
	for id in locations():
		var d: Dictionary = locations()[id]
		if bool(d.get("hidden", false)) or state_of(str(id)) != UNKNOWN:
			continue
		for nb in _neighbours(str(id)):
			if state_of(nb) != UNKNOWN:
				pool.append(str(id))
				break
	if pool.is_empty():
		return
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	var sources := ["thương hội", "lữ khách", "đệ tử ngoại viện", "người đi rừng"]
	add_rumor(pick, "", str(sources[rng.randi_range(0, sources.size() - 1)]))


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	return {"version": 1, "states": states.duplicate(), "rumors": rumors.duplicate(true), "log": log.duplicate(true), "last_day": _last_day, "routes_found": routes_found.duplicate()}


func from_dict(d: Dictionary) -> void:
	states = (d.get("states", {}) as Dictionary).duplicate()
	rumors = (d.get("rumors", {}) as Dictionary).duplicate(true)
	log = (d.get("log", []) as Array).duplicate(true)
	routes_found = (d.get("routes_found", {}) as Dictionary).duplicate()
	_last_day = int(d.get("last_day", 0))
	# bản lưu cũ không có địa điểm mới: chỉ giữ id còn tồn tại, và bổ sung nơi khởi đầu
	for id in states.keys():
		if not locations().has(id):
			states.erase(id)
	for id in rumors.keys():
		if not locations().has(id) or state_of(str(id)) != RUMOR:
			rumors.erase(id)
	_apply_defaults()
	# người chơi cũ đã từng tới nơi nào thì coi như đã phát hiện (map hiện tại sẽ được tự cập nhật ở nhịp kế)
	changed.emit()
