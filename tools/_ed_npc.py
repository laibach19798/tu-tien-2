def edit(p, pairs):
    s = open(p, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (p, a[:80])
        s = s.replace(a, b, 1)
    if crlf:
        s = s.replace('\n', '\r\n')
    open(p, 'w', encoding='utf-8', newline='').write(s)

edit('scripts/npc_world.gd', [
('''	var cand: Array = []
	var specs: Array = main.resources.map_specs(map_id)
	if map_id == "overworld":
		specs = specs.filter(func(s): return _in_region(s, li))
	for s in specs:
		for i in int(s.get("count", 1)):
			cand.append("%s:%s:%d" % [map_id, str(s["kind"]), i])
	cand.shuffle_with(r) if cand.has_method("shuffle_with") else cand.shuffle()
''', '''	var cand: Array = []
	for s in main.resources.map_specs(map_id):
		if map_id == "overworld" and not _spec_near(s, li):
			continue
		for i in int(s.get("count", 1)):
			cand.append("%s:%s:%d" % [map_id, str(s["kind"]), i])
	# linh thảo thường (không nằm trong danh sách rải mà do dựng map sinh ra): lấy theo số điểm đã dựng
	for i in mini(int(main.resources.known_count(map_id, "linh_thao")), 12):
		cand.append("%s:linh_thao:%d" % [map_id, i * 3 % maxi(1, int(main.resources.known_count(map_id, "linh_thao")))])
	_shuffle(cand, r)
'''),
('''## Trong map gốc: chỉ lấy điểm thuộc vùng của địa điểm (theo rect của danh sách) — đơn giản hoá: mọi spec overworld dùng chung.
func _in_region(_spec: Dictionary, _li: Dictionary) -> bool:
	return true
''', '''## Trong map gốc: chỉ lấy điểm có vùng rải giao với vùng của địa điểm (±300 điểm thế giới).
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
'''),
])
edit('scripts/resource_world.gd', [
('''## Người chơi hái: cộng vào túi và báo.''', '''## NPC có thể lấy điểm này không (bỏ qua điều kiện ban đêm vì NPC chủ động đi đêm; vẫn tôn trọng ngày kết tinh/lộ ra).
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


## Người chơi hái: cộng vào túi và báo.'''),
('''	states[node.node_id] = {"regrow_day": today() + int(kd.get("regrow_days", 0)), "gone": gone, "by": who, "day": today()}
	return {"item": str(kd["item"]), "amount": amount}


## Người chơi hái''', '''	states[node.node_id] = {"regrow_day": today() + int(kd.get("regrow_days", 0)), "gone": gone, "by": who, "day": today()}
	if str(kd.get("class", "")) == "unique" and main != null and main.get("npc_world") != null:
		main.npc_world.claim_relic(node.node_id, str(kd.get("name", "")), who if who != "player" else "player")
	return {"item": str(kd["item"]), "amount": amount}


## Người chơi hái'''),
])
edit('scripts/world.gd', [
('''func _roll_reliability() -> String:''', '''## Tin tức chung (từ NPC, sự kiện...) hiện ở nhật ký đại vực.
func add_news(text: String) -> void:
	_log("", text)
	changed.emit()


func _roll_reliability() -> String:'''),
])
edit('scripts/destiny.gd', [
('''	var who: String = SectWar.sect_name(rivals[rng.randi_range(0, rivals.size() - 1)])
''', '''	var who: String = SectWar.sect_name(rivals[rng.randi_range(0, rivals.size() - 1)])
	var hunter: String = main.npc_world.on_rival_takes(id, day)   # kẻ tầm bảo cụ thể giành truyền thừa
	if hunter != "":
		who = hunter
'''),
('''						dp_state[id] = {"state": "sealed", "regen_day": 0}
						fragments[id] = 0''', '''						dp_state[id] = {"state": "sealed", "regen_day": 0}
						fragments[id] = 0
						main.npc_world.new_generation(str(id))   # bản truyền thừa mới, không phải bản gốc cũ'''),
('''func _legacy(id: String, how: String) -> void:
	var info: Dictionary = dong_phu()[id]''', '''func _legacy(id: String, how: String) -> void:
	var info: Dictionary = dong_phu()[id]
	var inherited_ok := how == "inherit" and (duyen >= float((info["legacy"] as Dictionary).get("min_duyen", 0)) or bool(_run.get("heart", false)))'''),
('''	var how_text := {"inherit": "Ngươi kế thừa truyền thừa của tiên nhân."''', '''	# sổ sở hữu: một bản truyền thừa chỉ có một chủ
	main.npc_world.on_player_legacy(id, how if (how != "inherit" or inherited_ok) else "loot")
	var how_text := {"inherit": "Ngươi kế thừa truyền thừa của tiên nhân."'''),
('''func open(node: EncounterNode) -> void:
	var id := node.enc_id
''', '''func open(node: EncounterNode) -> void:
	var id := node.enc_id
	if id.begins_with("wnpc_"):
		main.npc_world.talk(node)
		return
'''),
])
edit('scripts/main.gd', [
('''var province: World = World.new()''', '''var npc_world: NpcWorld = NpcWorld.new()  # NPC trong/ngoài scene + sổ sở hữu vật phẩm độc nhất (data/npcs.json)
var province: World = World.new()'''),
('''	add_child(province)
	add_child(resources)
''', '''	add_child(province)
	add_child(resources)
	add_child(npc_world)
'''),
('''	resources.setup(self)
''', '''	resources.setup(self)
	npc_world.setup(self)
'''),
('''"resources": resources.to_dict(),''', '''"resources": resources.to_dict(), "npc_world": npc_world.to_dict(),'''),
('''	resources.from_dict(data.get("resources", {}))
''', '''	resources.from_dict(data.get("resources", {}))
	npc_world.from_dict(data.get("npc_world", {}))
'''),
])
print('ok')
