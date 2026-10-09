extends Node
class_name QuestLog
## Chuỗi nhiệm vụ tân thủ. Mục tiêu được tính trực tiếp từ trạng thái game
## (thời gian thiền, số vật phẩm, cảnh giới) nên không cần theo dõi từng sự kiện.

signal changed
signal message(text: String)

const QUESTS := [
	{
		"id": "q1", "title": "Cảm ứng linh khí", "giver": "elder", "turn_in": "elder",
		"desc": "Ngồi thiền (phím F) tổng cộng 20 giây",
		"obj": {"type": "meditate", "target": 20},
		"intro": [
			"Ngươi tỉnh rồi à, tiểu tử? Ta là Vân Hạc, trưởng lão ở thôn này.",
			"Tu tiên bắt đầu từ việc cảm ứng linh khí. Hãy tìm chỗ yên tĩnh, nhấn F để ngồi thiền.",
			"Nơi có vầng sáng xanh quanh bờ ao hay rừng tre là linh mạch, tu luyện ở đó nhanh gấp ba. Thiền đủ 20 giây rồi quay lại gặp ta.",
		],
		"remind": "Cứ ngồi thiền đi, tâm phải tĩnh. Đủ 20 giây rồi hãy quay lại.",
		"ready": ["Tốt, ngươi đã cảm nhận được linh khí rồi. Cầm lấy ít linh thạch và đan dược này."],
		"reward": {"stones": 15, "items": {"dan_tu_khi": 2}},
	},
	{
		"id": "q2", "title": "Linh thảo cho thương nhân", "giver": "merchant", "turn_in": "merchant",
		"desc": "Hái 3 cây Linh thảo (phím E) đem cho thương nhân",
		"obj": {"type": "collect", "item": "linh_thao", "target": 3},
		"intro": [
			"Khách quan! Nghe nói ngươi mới bắt đầu tu luyện phải không? Ta có việc nhờ đây.",
			"Ta đang cần mấy cây Linh thảo để luyện đan, mà chân ta yếu không đi xa được.",
			"Linh thảo mọc rải rác quanh thôn, nhất là gần linh mạch. Hái giúp ta 3 cây, ta trả công hậu hĩnh.",
		],
		"remind": "Linh thảo mọc quanh làng, chỗ nào có ánh sáng lấp lánh ấy. Cần 3 cây nhé.",
		"ready": ["Ôi, đúng là Linh thảo thượng hạng! Đây là công của ngươi."],
		"reward": {"stones": 30, "items": {"dan_tu_vi": 1}},
	},
	{
		"id": "q3", "title": "Bước vào tầng ba", "giver": "elder", "turn_in": "elder",
		"desc": "Đạt Luyện Khí tầng 3 (dùng đan dược trong túi đồ - phím I để tăng tốc)",
		"obj": {"type": "reach", "target": 3},
		"intro": [
			"Có linh thảo và đan dược rồi, đã đến lúc ngươi tiến xa hơn.",
			"Hãy tu luyện đến Luyện Khí tầng ba. Đan dược trong túi đồ (phím I) sẽ giúp ích.",
		],
		"remind": "Tầng ba chưa đạt thì chưa về gặp ta. Chăm thiền và dùng đan dược đi.",
		"ready": ["Không tệ! Căn cơ của ngươi khá vững. Đây là phần thưởng."],
		"reward": {"stones": 50, "items": {"dan_tu_vi": 2}},
	},
	{
		"id": "q4", "title": "Đột phá Trúc Cơ", "giver": "elder", "turn_in": "elder",
		"desc": "Tu luyện viên mãn Luyện Khí tầng 9 và đột phá (phím B) lên Trúc Cơ",
		"obj": {"type": "reach", "target": 10},
		"intro": [
			"Giờ là thử thách thật sự: đột phá Trúc Cơ.",
			"Luyện Khí chín tầng viên mãn, nhấn B để xung phá. Thất bại sẽ tổn hao tu vi nên cứ bình tâm.",
		],
		"remind": "Chín tầng viên mãn rồi nhấn B. Đừng vội.",
		"ready": ["Trúc Cơ thành công! Ngươi đã thật sự bước vào con đường tu tiên. Ta chỉ dạy được đến đây."],
		"reward": {"stones": 200, "items": {"dan_tu_vi": 3}},
	},
	{
		"id": "q5", "title": "Luyện kiếm", "giver": "swordmaster", "turn_in": "swordmaster", "free": true,
		"desc": "Dùng kiếm (phím J) đánh trúng mộc nhân 10 lần",
		"obj": {"type": "hits", "target": 10},
		"intro": [
			"Học kiếm không thể chỉ nghe. Sân sau kia có mấy mộc nhân, ra đó mà luyện.",
			"Nhấn J để chém. Linh khí hao thì thiền một lát. Đánh trúng mười lần rồi quay lại gặp ta.",
		],
		"remind": "Mộc nhân ở sân bên kia. Nhấn J để chém, đủ mười lần mới về.",
		"ready": ["Tay kiếm đã ra dáng rồi. Cầm lấy phần thưởng, và nhớ: cảnh giới càng cao, kiếm chiêu càng nhiều."],
		"reward": {"stones": 40, "items": {"dan_tu_khi": 3}},
	},
	{
		"id": "q6", "title": "Diệt sói hoang", "giver": "swordmaster", "turn_in": "swordmaster", "free": true,
		"desc": "Hạ 3 con Sói hoang ngoài làng (phía tây và phía nam)",
		"obj": {"type": "kills", "mob": "wolf", "target": 3},
		"intro": [
			"Kiếm không dùng trên mộc nhân mãi được. Gần đây bầy sói hoang kéo xuống gần làng, dân làng không dám ra ruộng.",
			"Ra phía tây và phía nam làng, hạ giúp ta ba con. Cẩn thận: chúng nhanh, và hễ thấy ngươi là lao tới. Thấy dấu chấm than đỏ trên đầu thì tránh ra.",
			"Nhớ mang theo đan dược hồi huyết. Hết khí huyết là trọng thương đấy.",
		],
		"remind": "Sói ở phía tây và phía nam làng. Đủ ba con rồi hãy về.",
		"ready": ["Tốt lắm, ngươi đã biết đánh thật rồi. Nanh sói đem bán hay luyện đan đều được. Đây là phần thưởng."],
		"reward": {"stones": 80, "items": {"dan_tu_khi": 2}},
	},
	{
		"id": "q7", "title": "Mẻ đan đầu tiên", "giver": "merchant", "turn_in": "merchant", "free": true, "after": "q2",
		"desc": "Luyện thành công 1 viên đan ở lò luyện đan (phía tây nam quảng trường)",
		"obj": {"type": "craft", "target": 1},
		"intro": [
			"Khách quan, ngươi hái linh thảo khá đấy. Sao không tự luyện đan luôn?",
			"Gần tiệm may có một cái lò cũ. Bỏ ba cây linh thảo vào là ra Tụ Khí Đan. Có nanh sói thì luyện được Hồi Huyết Đan, có yêu đan thì luyện được Dưỡng Nguyên Đan.",
			"Luyện thử một viên đi, ta xem tay nghề ngươi thế nào.",
		],
		"remind": "Lò luyện đan ở gần tiệm may. Ba cây linh thảo là luyện được Tụ Khí Đan rồi.",
		"ready": ["Ha ha, có đan rồi à? Tay nghề không tệ. Đây, ta thưởng ngươi vài viên Hồi Huyết Đan."],
		"reward": {"stones": 60, "items": {"dan_hoi_huyet": 2}},
	},
	{
		"id": "q8", "title": "Tiến vào Kiếm Tông", "giver": "swordmaster", "turn_in": "sect_head", "free": true, "after": "q5",
		"desc": "Đến sân Kiếm Tông ở thung lũng phía nam (đi theo đường nam của quảng trường) và gặp Chưởng môn",
		"obj": {"type": "visit", "area": "sect", "target": 1},
		"intro": [
			"Ngươi đã ra dáng người luyện kiếm. Đã đến lúc nhìn thấy Kiếm Tông thật sự.",
			"Theo con đường phía nam quảng trường, qua cổng núi là tới thung lũng của tông môn. Chưởng môn Thanh Huyền đang chờ.",
			"Ngoài làng có sói hoang, nhớ mang đan dược hồi huyết theo.",
		],
		"remind": "Cứ đi thẳng đường nam của quảng trường, qua cổng núi là tới Kiếm Tông.",
		"ready": ["Ngươi tới rồi. Lăng Tiêu đã nhắn trước. Kiếm Tông rộng cửa đón người có tâm, lấy chút lộ phí này mà dùng."],
		"reward": {"stones": 100, "merit": 30, "items": {"dan_tu_vi": 2}},
	},
	{
		"id": "q9", "title": "Săn Hắc Lang Vương", "giver": "sect_head", "turn_in": "sect_head", "free": true, "after": "q8",
		"desc": "Hạ Hắc Lang Vương trong hang ổ ở sâu trong Hắc Lâm (phía đông làng)",
		"obj": {"type": "kills", "mob": "wolf_king", "target": 1},
		"intro": [
			"Phía đông làng là Hắc Lâm. Gần đây bầy hắc lang trong đó được một con yêu lang già cầm đầu, kéo cả đàn xuống quấy phá dân làng.",
			"Con vật ấy đã tu thành yêu, sức mạnh ngang cao thủ Trúc Cơ. Đừng liều một mình: chuẩn bị nhiều đan hồi huyết, tránh đòn gồng của nó.",
			"Hạ được nó, ta sẽ trọng thưởng. Ẩn sĩ Mặc Thạch ở trại ven rừng có thể chỉ cho ngươi đường.",
		],
		"remind": "Hắc Lang Vương ở hang ổ sâu trong Hắc Lâm, theo đường lớn phía đông. Nhớ mang đan hồi huyết.",
		"ready": ["Tin tức đã truyền về, ngươi quả không phụ sự kỳ vọng. Món này là của ngươi."],
		"reward": {"stones": 500, "merit": 150, "items": {"dan_tu_vi": 3, "yeu_dan": 2}},
	},
	{
		"id": "q10", "title": "Hang Linh Mạch", "giver": "hermit", "turn_in": "hermit", "free": true, "after": "q6",
		"desc": "Đến Hang Linh Mạch ở góc đông nam bản đồ (đi theo đường từ sân Kiếm Tông về phía đông)",
		"obj": {"type": "visit", "area": "cave", "target": 1},
		"intro": [
			"Lâu rồi mới có người lạ ghé trại ta. Ta là Mặc Thạch, sống ở đây đã ba mươi năm.",
			"Ở tít đông nam có một cái hang, linh khí dày đặc gấp sáu lần ngoài kia. Nhưng yêu tướng canh giữ, không dễ vào.",
			"Nếu ngươi tới được tận nơi và quay lại kể ta nghe, ta sẽ tặng ngươi ít yêu đan ta tích cóp.",
		],
		"remind": "Hang Linh Mạch ở góc đông nam, đường đi bắt đầu từ sân Kiếm Tông. Cẩn thận yêu tướng.",
		"ready": ["Ha, ngươi thật sự đã tới đó và về được! Cầm lấy, ta già rồi, chẳng cần mấy thứ này."],
		"reward": {"stones": 150, "items": {"yeu_dan": 2}},
	},
	{
		"id": "q11", "title": "Luyện kiếm trước sân", "giver": "sect_keeper", "turn_in": "sect_keeper", "free": true, "after": "q8", "since": true,
		"desc": "Chém trúng mộc nhân trong sân Kiếm Tông 20 lần",
		"obj": {"type": "hits", "target": 20},
		"intro": [
			"Chưởng môn nói ngươi mới vào tông. Ta là Mộ Dung, coi giữ Tàng Bảo Các, cũng lo việc sai bảo đệ tử.",
			"Người của Kiếm Tông lấy cống hiến làm gốc. Muốn đổi đan dược, trang phục ở chỗ ta thì phải có điểm cống hiến.",
			"Việc đầu tiên đơn giản thôi: ra mấy mộc nhân trong sân, chém trúng hai mươi nhát cho tay quen kiếm.",
		],
		"remind": "Mộc nhân ở sân phía nam, hai bên hàng cột. Chém trúng đủ hai mươi nhát rồi quay lại.",
		"ready": ["Tay kiếm đã vững. Đây là cống hiến đầu tiên của ngươi, cứ ghé Tàng Bảo Các đổi đồ."],
		"reward": {"stones": 40, "merit": 25},
	},
	{
		"id": "q12", "title": "Dẹp bầy hắc lang", "giver": "sect_keeper", "turn_in": "sect_keeper", "free": true, "after": "q11", "since": true,
		"desc": "Hạ 8 Hắc lang trong Hắc Lâm (phía đông làng)",
		"obj": {"type": "kills", "mob": "wolf_dark", "target": 8},
		"intro": [
			"Hắc lang trong Hắc Lâm sinh sôi quá nhanh, dân làng ven rừng không dám ra khỏi nhà.",
			"Tông môn treo thưởng: hạ tám con hắc lang, mỗi con đều là một điểm cống hiến sau này nữa. Nhớ mang đan hồi huyết.",
		],
		"remind": "Hắc lang ở Hắc Lâm, phía đông làng. Hạ đủ tám con rồi báo ta.",
		"ready": ["Gọn gàng. Tông môn ghi công cho ngươi, thêm chút đan dược dưỡng thương."],
		"reward": {"stones": 120, "merit": 60, "items": {"dan_hoi_huyet": 2}},
	},
	{
		"id": "q13", "title": "Trừ yêu tướng", "giver": "sect_keeper", "turn_in": "sect_keeper", "free": true, "after": "q12", "since": true,
		"desc": "Hạ 5 Yêu tướng (tiểu yêu tinh hung dữ) ở vùng đông nam",
		"obj": {"type": "kills", "mob": "goblin_elite", "target": 5},
		"intro": [
			"Phía đông nam có yêu tướng cầm đầu lũ tiểu yêu. Chúng khó đối phó hơn hắc lang nhiều, đòn nặng và máu dày.",
			"Hạ năm tên, tông môn trọng thưởng. Đừng đánh một lúc nhiều tên, dụ từng tên một.",
		],
		"remind": "Yêu tướng ở vùng đông nam, gần đường tới Hang Linh Mạch. Hạ đủ năm tên rồi quay lại.",
		"ready": ["Giỏi lắm! Yêu tướng không phải đối thủ dễ. Đây là phần thưởng xứng đáng."],
		"reward": {"stones": 200, "merit": 90, "items": {"yeu_dan": 1}},
	},
	{
		"id": "q14", "title": "Đan dược cho tông môn", "giver": "sect_keeper", "turn_in": "sect_keeper", "free": true, "after": "q8", "since": true,
		"desc": "Luyện thành 5 viên đan (lò đan ở quảng trường làng)",
		"obj": {"type": "craft", "target": 5},
		"intro": [
			"Kho đan của Tàng Bảo Các sắp cạn. Ngươi biết luyện đan chứ?",
			"Luyện cho tông môn năm lò đan, loại nào cũng được. Lò đan ở quảng trường làng, nguyên liệu thì tự lo.",
		],
		"remind": "Cần luyện thành năm viên đan, loại nào cũng được. Lò đan ở quảng trường làng.",
		"ready": ["Đan này dùng được. Tông môn nhận, đây là phần của ngươi."],
		"reward": {"stones": 60, "merit": 50, "items": {"dan_tu_vi": 1}},
	},
	{
		"id": "q15", "title": "Dâng yêu đan", "giver": "sect_keeper", "turn_in": "sect_keeper", "free": true, "after": "q13",
		"desc": "Mang 3 Yêu đan về nộp cho Chấp sự Mộ Dung",
		"obj": {"type": "collect", "item": "yeu_dan", "target": 3},
		"intro": [
			"Yêu đan là nguyên liệu quý để luyện Trúc Cơ Linh Đan. Tông môn đang cần ba viên.",
			"Yêu tướng và Hắc Lang Vương thỉnh thoảng rơi ra thứ này. Gom đủ ba viên, mang về cho ta.",
		],
		"remind": "Cần ba Yêu đan, rơi từ yêu tướng và yêu lang. Đủ rồi quay lại gặp ta.",
		"ready": ["Ba viên Yêu đan đều thượng phẩm. Tông môn ghi nhớ công của ngươi."],
		"reward": {"stones": 150, "merit": 70},
	},
]
var states: Dictionary = {}   # id -> "active" | "done"
var meditate_time := 0.0
var sword_hits := 0
var kills: Dictionary = {}
var crafts := 0
var visited: Dictionary = {}
var base: Dictionary = {}   # nhiệm vụ có "since": tiến độ tính từ lúc nhận (id -> giá trị bộ đếm lúc nhận)
var inv: Inventory
var cult: Cultivation
var _last_sec := -1


func setup(p_inv: Inventory, p_cult: Cultivation) -> void:
	inv = p_inv
	cult = p_cult
	inv.changed.connect(func(): changed.emit())
	cult.changed.connect(func(): changed.emit())


func add_meditate(dt: float) -> void:
	meditate_time += dt
	var sec := int(meditate_time)
	if sec != _last_sec:
		_last_sec = sec
		changed.emit()


## Giá trị bộ đếm hiện tại của một loại mục tiêu tích luỹ.
func _counter(o: Dictionary) -> int:
	match o["type"]:
		"hits": return sword_hits
		"kills": return int(kills.get(o["mob"], 0))
		"craft": return crafts
	return 0


func progress(q: Dictionary) -> Vector2i:
	var o: Dictionary = q["obj"]
	var target: int = o["target"]
	var cur := 0
	match o["type"]:
		"meditate": cur = int(meditate_time)
		"collect": cur = inv.count(o["item"])
		"reach": cur = cult.step_index() + 1
		"hits", "kills", "craft": cur = _counter(o) - (int(base.get(q["id"], 0)) if q.get("since", false) else 0)
		"visit": cur = 1 if visited.get(o["area"], false) else 0
	return Vector2i(mini(cur, target), target)


func is_complete(q: Dictionary) -> bool:
	var p := progress(q)
	return p.x >= p.y


func add_kill(mob: String) -> void:
	kills[mob] = int(kills.get(mob, 0)) + 1
	changed.emit()


## Ghi nhận người chơi đã đặt chân tới một khu vực (kể cả khi chưa nhận nhiệm vụ).
func add_visit(area: String) -> void:
	if visited.get(area, false):
		return
	visited[area] = true
	changed.emit()


func add_craft() -> void:
	crafts += 1
	changed.emit()


func add_hit() -> void:
	sword_hits += 1
	changed.emit()


func _unlocked(i: int) -> bool:
	if QUESTS[i].has("after"):
		return states.get(QUESTS[i]["after"], "") == "done"
	if QUESTS[i].get("free", false):
		return true
	return i == 0 or states.get(QUESTS[i - 1]["id"], "") == "done"


## Trạng thái hiển thị của nhiệm vụ thứ i: ready / active / available / locked / done.
func status(i: int) -> String:
	var qd: Dictionary = QUESTS[i]
	var st: String = states.get(qd["id"], "")
	if st == "done":
		return "done"
	if st == "active":
		return "ready" if is_complete(qd) else "active"
	return "available" if _unlocked(i) else "locked"


func available_for(npc: String) -> Dictionary:
	for i in QUESTS.size():
		var q: Dictionary = QUESTS[i]
		if q["giver"] == npc and not states.has(q["id"]) and _unlocked(i):
			return q
	return {}


func ready_for(npc: String) -> Dictionary:
	for q in QUESTS:
		if states.get(q["id"], "") == "active" and q["turn_in"] == npc and is_complete(q):
			return q
	return {}


func active_for(npc: String) -> Dictionary:
	for q in QUESTS:
		if states.get(q["id"], "") == "active" and (q["turn_in"] == npc or q["giver"] == npc):
			return q
	return {}


func accept(id: String) -> void:
	states[id] = "active"
	var qd := _find(id)
	if qd.get("since", false):
		base[id] = _counter(qd["obj"])
	message.emit("Nhận nhiệm vụ: %s" % _find(id)["title"])
	changed.emit()


func complete(id: String) -> void:
	var q := _find(id)
	var o: Dictionary = q["obj"]
	if o["type"] == "collect":
		inv.remove(o["item"], int(o["target"]))
	var r: Dictionary = q["reward"]
	var parts: Array[String] = []
	if r.get("stones", 0) > 0:
		inv.add_stones(int(r["stones"]))
		parts.append("%d linh thạch" % int(r["stones"]))
	if r.get("merit", 0) > 0:
		inv.add_merit(int(r["merit"]))
		parts.append("%d cống hiến" % int(r["merit"]))
	var its: Dictionary = r.get("items", {})
	for k in its:
		inv.add(k, int(its[k]))
		parts.append("%s x%d" % [Items.item_name(k), int(its[k])])
	states[id] = "done"
	message.emit("Hoàn thành: %s  (+%s)" % [q["title"], ", ".join(parts)])
	changed.emit()


func _find(id: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == id:
			return q
	return {}


static func npc_name(id: String) -> String:
	return {"elder": "Trưởng lão Vân Hạc", "merchant": "Thương nhân Lý Tam", "swordmaster": "Kiếm sư Lăng Tiêu", "sect_head": "Chưởng môn Thanh Huyền", "hermit": "Ẩn sĩ Mặc Thạch", "sect_keeper": "Chấp sự Mộ Dung"}.get(id, id)


func tracker_text() -> String:
	for q in QUESTS:
		if states.get(q["id"], "") == "active":
			var p := progress(q)
			var line := "%s\n%s  (%d/%d)" % [q["title"], q["desc"], p.x, p.y]
			if p.x >= p.y:
				line += "\n→ Quay lại gặp %s" % (npc_name(q["turn_in"]))
			return line
	for i in QUESTS.size():
		var q: Dictionary = QUESTS[i]
		if not states.has(q["id"]) and _unlocked(i):
			return "Nhiệm vụ mới: hãy gặp %s (dấu !)" % (npc_name(q["giver"]))
	return "Đã hoàn thành các nhiệm vụ hiện có."


func to_dict() -> Dictionary:
	return {"states": states, "meditate": meditate_time, "hits": sword_hits, "kills": kills, "crafts": crafts, "visited": visited, "base": base}


func from_dict(d: Dictionary) -> void:
	states = {}
	var s: Dictionary = d.get("states", {})
	for k in s:
		states[str(k)] = str(s[k])
	meditate_time = float(d.get("meditate", 0.0))
	sword_hits = int(d.get("hits", 0))
	kills = {}
	var kd: Dictionary = d.get("kills", {})
	for k in kd:
		kills[str(k)] = int(kd[k])
	crafts = int(d.get("crafts", 0))
	base = {}
	var bd: Dictionary = d.get("base", {})
	for k in bd:
		base[str(k)] = int(bd[k])
	visited = {}
	var vd: Dictionary = d.get("visited", {})
	for k in vd:
		visited[str(k)] = bool(vd[k])
	changed.emit()
