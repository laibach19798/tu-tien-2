extends Node
class_name ResourceWorld
## Tài nguyên có ID và trạng thái (thiết kế thế giới mở §8; dữ liệu: data/resources.json).
##  - Ba loại: Tái sinh (linh thảo, khoáng thấp) · Khan hiếm (cần điều kiện xuất hiện, tái sinh rất chậm) · Độc nhất (hái một lần, không tái sinh).
##  - Mỗi điểm khai thác có ID ổn định "<map>:<loại>:<số thứ tự>"; vị trí sinh bằng hạt giống cố định nên ID giữ nguyên qua các lần vào map và lưu/tải.
##  - Trạng thái chỉ lưu cho điểm đã bị lấy: {regrow_day, gone, by}. Thời hạn tái sinh tính bằng NGÀY GAME (đồng hồ sect_life.day),
##    nên rời map, bế quan, tua nhanh hay lưu/tải đều nhất quán; người chơi hay NPC lấy đều đi qua cùng một hàm (harvest / npc_take).

const DATA_PATH := "res://data/resources.json"
const NODE := preload("res://scripts/resource_node.gd")

var main: Node
var states: Dictionary = {}        # id -> {"regrow_day": int, "gone": bool, "by": String, "day": int}
var permits: Dictionary = {}       # tông (id SectWar) -> ngày hết hạn giấy phép khai thác
var _node_owner: Dictionary = {}   # node_id -> {"sect": s} hoặc {"territory": t}; dựng lại khi dựng map
var _data: Dictionary = {}
var _counters: Dictionary = {}     # "map|kind" -> số thứ tự đã cấp trong lần dựng map hiện tại


func _ready() -> void:
	add_to_group("resources")
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed


func setup(p_main: Node) -> void:
	main = p_main


# ---------------------------------------------------------------- dữ liệu
func kinds() -> Dictionary:
	return _data.get("kinds", {})


func kind_def(id: String) -> Dictionary:
	return kinds().get(id, {})


func map_specs(map_id: String) -> Array:
	return (_data.get("maps", {}) as Dictionary).get(map_id, [])


func class_name_of(kind_id: String) -> String:
	var c := str(kind_def(kind_id).get("class", ""))
	return str((_data.get("classes", {}) as Dictionary).get(c, c))


func today() -> int:
	return int(main.sect_life.day) if main != null else 1


# ---------------------------------------------------------------- dựng map
## Gọi khi bắt đầu dựng một map: đặt lại bộ đếm ID của map đó.
func begin_map(map_id: String) -> void:
	for k in _counters.keys():
		if str(k).begins_with(map_id + "|"):
			_counters.erase(k)
	for k in _node_owner.keys():
		if str(k).begins_with(map_id + ":"):
			_node_owner.erase(k)


func next_id(map_id: String, kind: String) -> String:
	var key := "%s|%s" % [map_id, kind]
	var n := int(_counters.get(key, 0))
	_counters[key] = n + 1
	return "%s:%s:%d" % [map_id, kind, n]


## Tạo một điểm khai thác tại pos (chưa add vào cây). Linh thảo cũ của map cũng đi qua đây.
func make_node(map_id: String, kind: String, pos: Vector2) -> Node2D:
	if not kinds().has(kind):
		return null
	var n: Node2D = NODE.new()
	n.node_id = next_id(map_id, kind)
	n.kind_id = kind
	n.res = self
	n.position = pos
	var h := absi(n.node_id.hash())
	n.grade = 1 + h % 3
	return n


## Tạo một điểm khai thác với ID chỉ định (dùng cho tài nguyên do sự kiện sinh ra).
func make_node_id(node_id: String, kind: String, pos: Vector2) -> Node2D:
	if not kinds().has(kind):
		return null
	var n: Node2D = NODE.new()
	n.node_id = node_id
	n.kind_id = kind
	n.res = self
	n.position = pos
	n.grade = 1 + absi(node_id.hash()) % 3
	return n


## Rải các điểm theo danh sách trong data/resources.json cho map đang dựng (vị trí lấy từ hạt giống cố định).
func populate(m: Node, map_id: String) -> void:
	for spec in map_specs(map_id):
		var kind := str(spec["kind"])
		var rects: Array = spec.get("rects", [])
		var xr := RandomNumberGenerator.new()
		var seed_key := "%s|%s" % [map_id, kind]
		if spec.has("territory"):
			seed_key += "|" + str(spec["territory"])
		elif spec.has("owner"):
			seed_key += "|" + str(spec["owner"])
		xr.seed = absi(seed_key.hash())
		var made := 0
		var tries := 0
		var want := int(spec.get("count", 1))
		while made < want and tries < want * 80:
			tries += 1
			var p := Vector2.ZERO
			if rects.is_empty():
				p = Vector2(xr.randf_range(150.0, m.map_size.x - 150.0), xr.randf_range(300.0, m.map_size.y - 120.0))
			else:
				var r: Array = rects[made % rects.size()]
				p = Vector2(float(r[0]) + xr.randf() * float(r[2]), float(r[1]) + xr.randf() * float(r[3]))
			if m.is_safe(p) or m._is_blocked(Rect2(p.x - 30, p.y - 30, 60, 40)):
				continue
			if map_id == "overworld" and not m._clear_spot(p, 40.0):
				continue
			var too_close := false
			for o in m.herbs:
				if is_instance_valid(o) and (o.position as Vector2).distance_to(p) < 70.0:
					too_close = true
					break
			if too_close:
				continue
			var node := make_node(map_id, kind, p)
			if spec.has("territory"):
				_node_owner[node.node_id] = {"territory": str(spec["territory"])}
			elif spec.has("owner"):
				_node_owner[node.node_id] = {"sect": str(spec["owner"])}
			m.world.add_child(node)
			m.herbs.append(node)
			made += 1


# ---------------------------------------------------------------- trạng thái
func _condition_ok(kind_id: String) -> bool:
	var w: Dictionary = kind_def(kind_id).get("when", {})
	if w.is_empty() or main == null:
		return true
	if bool(w.get("night", false)) and float(main.atmo.darkness) < 0.55:
		return false
	if int(w.get("min_day", 0)) > today():
		return false
	return true


## Điểm đang có thể lấy: chưa bị lấy (hoặc đã tới hạn tái sinh) và thoả điều kiện xuất hiện.
func is_available(node: Node2D) -> bool:
	return state_of(node.node_id, node.kind_id) == "ready"


## "ready" | "hidden" (chưa đủ điều kiện) | "taken" (đang chờ tái sinh) | "gone" (độc nhất đã mất)
func state_of(node_id: String, kind_id: String) -> String:
	var st: Dictionary = states.get(node_id, {})
	if not st.is_empty():
		if bool(st.get("gone", false)):
			return "gone"
		if int(st.get("regrow_day", 0)) > today():
			return "taken"
	if not _condition_ok(kind_id):
		return "hidden"
	return "ready"


func days_left(node_id: String) -> int:
	var st: Dictionary = states.get(node_id, {})
	return maxi(0, int(st.get("regrow_day", 0)) - today()) if not st.is_empty() else 0


## Số lượng cố định theo ID (cấp điểm khai thác quyết định trong khoảng [lo, hi]).
func amount_for(node: Node2D) -> int:
	var a: Array = kind_def(node.kind_id).get("amount", [1, 1])
	var lo := int(a[0])
	var hi := int(a[1])
	if hi <= lo:
		return lo
	return lo + (node.grade - 1) % (hi - lo + 1)


## Lấy tài nguyên. Trả {"item", "amount"}; rỗng nếu không lấy được. who: "player" hoặc "npc:<id>".
func take(node: Node2D, who := "player") -> Dictionary:
	if not is_available(node):
		return {}
	var kd: Dictionary = kind_def(node.kind_id)
	var amount := amount_for(node)
	var gone := str(kd.get("class", "")) == "unique" or int(kd.get("regrow_days", 0)) <= 0
	states[node.node_id] = {"regrow_day": today() + _regrow(node.node_id, kd), "gone": gone, "by": who, "day": today()}
	if str(kd.get("class", "")) == "unique" and main != null and main.get("npc_world") != null:
		main.npc_world.claim_relic(node.node_id, str(kd.get("name", "")), who)
	return {"item": str(kd["item"]), "amount": amount}


# ---------------------------------------------------------------- khu vực tông môn kiểm soát
## Tông đang kiểm soát điểm khai thác ("" nếu vô chủ): theo tông cố định hoặc theo chủ hiện tại của địa bàn chiến sự.
func owner_of_node(node_id: String) -> String:
	var o: Dictionary = _node_owner.get(node_id, {})
	if o.has("sect"):
		return str(o["sect"])
	if o.has("territory") and main != null and main.get("war") != null:
		return str(main.war.owner_of(str(o["territory"])))
	return ""


## Tông đang cấm người chơi khai thác điểm này ("" nếu tự do): đã có giấy phép còn hạn hoặc là tông của mình thì tự do.
func restricted_owner(node_id: String) -> String:
	var o := owner_of_node(node_id)
	if o == "" or o == SectWar.PLAYER:
		return ""
	if int(permits.get(o, 0)) >= today():
		return ""
	if main != null and main.get("diplomacy") != null and main.diplomacy.permit_mode(o) == "free":
		return ""   # hiệp ước giao thương / hợp tác: miễn xin phép
	return o


func permit_cfg(key: String, fallback := 0.0) -> float:
	return float((_data.get("permit", {}) as Dictionary).get(key, fallback))


## Người chơi muốn lấy điểm của tông khác: xin phép (trả phí) / lén lấy (có thể bị bắt gặp) / thôi.
func ask_permission(node: Node2D, owner: String) -> void:
	var nm := SectWar.sect_name(owner)
	var fee := int(permit_cfg("fee", 25.0))
	var days := int(permit_cfg("days", 3.0))
	var mode: String = main.diplomacy.permit_mode(owner) if main.get("diplomacy") != null else "normal"
	if mode == "half":
		fee = maxi(1, fee / 2)
	if mode == "refused":
		main.hud.toast("%s đối địch với tông ngươi: đệ tử trục xuất ngươi khỏi khu khai thác." % nm)
		return
	main.meditating = false
	main.dialogue.choose("Khu khai thác của %s" % nm, "Nơi này do %s kiểm soát. Đệ tử tuần tra thường chặn người lạ tới lấy vật liệu." % nm, [
		{"text": "Xin phép, nộp %d linh thạch (được khai thác %d ngày)" % [fee, days], "call": _permit_pay.bind(node, owner)},
		{"text": "Lén lấy (có thể bị bắt gặp, ảnh hưởng quan hệ)", "call": steal.bind(node, owner)},
		{"text": "Thôi, không lấy", "call": Callable()},
	])


func _permit_pay(node: Node2D, owner: String) -> void:
	var fee := int(permit_cfg("fee", 25.0))
	if main.get("diplomacy") != null and main.diplomacy.permit_mode(owner) == "half":
		fee = maxi(1, fee / 2)
	if not main.inv.spend_stones(fee):
		main.hud.toast("Không đủ linh thạch nộp phí.")
		return
	permits[owner] = today() + int(permit_cfg("days", 3.0))
	main.hud.toast("Đã nộp phí: được khai thác khu của %s trong %d ngày." % [SectWar.sect_name(owner), int(permit_cfg("days", 3.0))])
	harvest(node)


## Lén lấy: luôn được hàng; bị bắt gặp thì mất tiền phạt, tông đó coi là thù địch (cùng cơ chế với cướp bí tịch).
## force_caught: -1 = theo hạt giống ngày, 0/1 = ép kết quả (dùng cho kiểm thử).
func steal(node: Node2D, owner: String, force_caught := -1) -> void:
	harvest(node)
	main.destiny.add_duyen(-permit_cfg("duyen_penalty", 1.0))
	var r := RandomNumberGenerator.new()
	r.seed = absi(("%s|%d|steal" % [node.node_id, today()]).hash())
	var caught := r.randf() < permit_cfg("caught_chance", 0.45)
	if force_caught >= 0:
		caught = force_caught == 1
	var here := str(main.journey.here()) if main.get("journey") != null and main.journey != null else ""
	if not caught:
		# không bị bắt gặp: chỉ những NPC đang có mặt ở đó mới có thể thấy (nạn nhân là cả tông, không NPC cụ thể)
		if main.get("npc_world") != null:
			main.npc_world.report_deed("theft", "sect:" + owner, here, "")
		main.hud.toast("Không ai bắt gặp. Nhưng ngươi biết mình vừa lấy của người khác.")
		return
	var fine := mini(int(permit_cfg("fine", 30.0)), main.inv.stones)
	if fine > 0:
		main.inv.spend_stones(fine)
	var v1 := _v1_sect(owner)
	if v1 != "":
		var st = main.cultivation_v1.state
		st.wanted[v1] = int(st.wanted.get(v1, 0)) + 1
		st.relations[v1] = "hostile"
	main.hud.toast("Đệ tử %s bắt gặp! Bị phạt %d linh thạch; %s coi ngươi là kẻ trộm." % [SectWar.sect_name(owner), fine, SectWar.sect_name(owner)])
	if main.get("npc_world") != null:
		main.npc_world.report_deed("theft", "sect:" + owner, here, "", 1)
		main.province.add_news("Người chơi bị bắt gặp lén khai thác khu của %s." % SectWar.sect_name(owner))


## id tông của hệ tu luyện V1 ứng với id tông trong SectWar (qua trường legacy).
func _v1_sect(sw_id: String) -> String:
	var sects: Dictionary = preload("res://scripts/v1/catalog.gd").data().sects
	for k in sects:
		if str(sects[k].get("legacy", "")) == sw_id:
			return str(k)
	return ""


## NPC có thể lấy điểm này không (bỏ qua điều kiện ban đêm vì NPC chủ động đi đêm; vẫn tôn trọng ngày kết tinh/lộ ra).
func npc_can_take(node_id: String) -> bool:
	var kind_id := node_kind(node_id)
	if kind_id == "":
		return false
	var st: Dictionary = states.get(node_id, {})
	if not st.is_empty() and (bool(st.get("gone", false)) or int(st.get("regrow_day", 0)) > today()):
		return false
	var w: Dictionary = kind_def(kind_id).get("when", {})
	return int(w.get("min_day", 0)) <= today()


## Số điểm đã dựng cho (map, loại) trong lần dựng gần nhất.
func known_count(map_id: String, kind: String) -> int:
	return int(_counters.get("%s|%s" % [map_id, kind], 0))


## Người chơi hái: cộng vào túi và báo.
func harvest(node: Node2D) -> void:
	var got := take(node, "player")
	if got.is_empty():
		return
	main.inv.add(str(got["item"]), int(got["amount"]))
	main.hud.toast("+%d %s" % [int(got["amount"]), str(kind_def(node.kind_id).get("name", ""))])


## NPC lấy (dùng cho mô phỏng NPC ngoài scene): cập nhật cùng trạng thái, trả vật phẩm cho NPC.
func npc_take(node_id: String, npc_id: String) -> Dictionary:
	var kind_id := node_kind(node_id)
	if kind_id == "" or state_of(node_id, kind_id) != "ready":
		return {}
	var kd: Dictionary = kind_def(kind_id)
	var h := absi(node_id.hash())
	var a: Array = kd.get("amount", [1, 1])
	var amount := int(a[0]) + ((h % 3) % (int(a[1]) - int(a[0]) + 1))
	var gone := str(kd.get("class", "")) == "unique" or int(kd.get("regrow_days", 0)) <= 0
	states[node_id] = {"regrow_day": today() + _regrow(node_id, kd), "gone": gone, "by": "npc:" + npc_id, "day": today()}
	if str(kd.get("class", "")) == "unique" and main != null and main.get("npc_world") != null:
		main.npc_world.claim_relic(node_id, str(kd.get("name", "")), "npc:" + npc_id)
	return {"item": str(kd["item"]), "amount": amount}


## Số ngày tái sinh sau khi lấy, nhân hệ số của sự kiện linh mạch biến động (nếu có) ở map đó.
func _regrow(node_id: String, kd: Dictionary) -> int:
	var base := int(kd.get("regrow_days", 0))
	if base <= 0 or main == null or main.get("events") == null:
		return base
	var map_id := node_id.split(":")[0]
	return maxi(1, int(ceil(float(base) * float(main.events.regrow_mult(map_id)))))


## "<map>:<loại>:<n>" → loại.
func node_kind(node_id: String) -> String:
	var parts := node_id.split(":")
	return parts[1] if parts.size() >= 3 and kinds().has(parts[1]) else ""


# ---------------------------------------------------------------- lưu / tải
func to_dict() -> Dictionary:
	# chỉ giữ các điểm còn cần nhớ: độc nhất đã mất hoặc chưa tới hạn tái sinh
	var keep := {}
	for id in states:
		var st: Dictionary = states[id]
		if bool(st.get("gone", false)) or int(st.get("regrow_day", 0)) > today():
			keep[id] = st
	return {"version": 1, "states": keep, "permits": permits.duplicate()}


func from_dict(d: Dictionary) -> void:
	states = (d.get("states", {}) as Dictionary).duplicate(true)
	permits = (d.get("permits", {}) as Dictionary).duplicate()
