extends SceneTree
## Tài nguyên có ID và tái sinh (data/resources.json, ResourceWorld/ResourceNode): ID ổn định, lấy → chờ tái sinh theo ngày game,
## khan hiếm cần điều kiện, độc nhất không tái sinh, NPC lấy chung trạng thái, lưu/tải, dựng lại map giữ trạng thái.
var main: Node
var failures := 0
var checks := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)


func find_kind(kind: String) -> Node2D:
	for h in main.herbs:
		if is_instance_valid(h) and h.kind_id == kind:
			return h
	return null


func ids_of(kind: String) -> Array:
	var out: Array = []
	for h in main.herbs:
		if is_instance_valid(h) and h.kind_id == kind:
			out.append(h.node_id)
	out.sort()
	return out


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var r: ResourceWorld = main.resources

	# --- dữ liệu
	var items_ok := true
	for k in r.kinds():
		items_ok = items_ok and Items.DATA.has(str(r.kinds()[k]["item"]))
	check(items_ok and r.kinds().size() >= 9, "mọi loại tài nguyên có vật phẩm tương ứng (%d loại)" % r.kinds().size())
	var spec_ok := true
	for m in r._data.get("maps", {}):
		spec_ok = spec_ok and (m == "overworld" or Maps.exists(str(m)))
		for s in r.map_specs(str(m)):
			spec_ok = spec_ok and r.kinds().has(str(s["kind"]))
	check(spec_ok, "danh sách rải tài nguyên chỉ dùng map và loại có thật")
	var classes := {}
	for k in r.kinds():
		classes[str(r.kinds()[k]["class"])] = true
	check(classes.has("renewable") and classes.has("scarce") and classes.has("unique"), "đủ ba loại: tái sinh, khan hiếm, độc nhất")

	# --- ID duy nhất, ổn định
	var seen := {}
	var dup := false
	for h in main.herbs:
		if is_instance_valid(h):
			dup = dup or seen.has(h.node_id)
			seen[h.node_id] = true
	check(seen.size() >= 50 and not dup, "thế giới gốc có %d điểm khai thác, ID không trùng" % seen.size())
	check(find_kind("linh_thao").node_id.begins_with("overworld:linh_thao:"), "ID dạng <map>:<loại>:<số>")
	check(ids_of("thiet_tinh").size() >= 5 and ids_of("co_tu_di_vat").size() == 1, "khoáng và di vật độc nhất được rải theo danh sách")

	# --- lấy và tái sinh theo ngày game
	var herb: Node2D = find_kind("linh_thao")
	var before: int = main.inv.count("linh_thao")
	check(herb.available, "linh thảo ban đầu có thể hái")
	herb.pick()
	check(main.inv.count("linh_thao") == before + 1 and not herb.available, "hái xong: vào túi và biến mất")
	check(r.state_of(herb.node_id, "linh_thao") == "taken" and r.days_left(herb.node_id) == 2, "đang chờ tái sinh, còn 2 ngày game")
	main.sect_life.day += 1
	check(not herb.available, "chưa đủ ngày thì chưa mọc lại")
	main.sect_life.day += 1
	check(herb.available, "đủ 2 ngày game thì mọc lại")

	# --- độc nhất: không tái sinh
	var relic: Node2D = find_kind("co_tu_di_vat")
	var rid: String = relic.node_id
	var held: int = main.inv.count("co_tu_di_vat")
	relic.pick()
	check(main.inv.count("co_tu_di_vat") == held + 1 and r.state_of(rid, "co_tu_di_vat") == "gone", "di vật cổ tu lấy một lần và mất hẳn")
	main.sect_life.day += 500
	check(r.state_of(rid, "co_tu_di_vat") == "gone" and not relic.available, "500 ngày sau vẫn không tái sinh")
	check(r.take(relic, "player").is_empty(), "không lấy lại được lần hai")

	# --- khan hiếm: điều kiện xuất hiện
	var night_node: Node2D = find_kind("ngan_nien_thao")
	main.atmo.darkness = 0.0
	check(r.state_of(night_node.node_id, "ngan_nien_thao") == "hidden", "ngàn năm linh thảo ẩn ban ngày")
	main.atmo.darkness = 0.9
	check(r.state_of(night_node.node_id, "ngan_nien_thao") == "ready", "hiện ra vào ban đêm")
	var tinh: Node2D = find_kind("linh_mach_tinh")
	main.sect_life.day = 1
	check(r.state_of(tinh.node_id, "linh_mach_tinh") == "hidden", "tinh thể linh mạch chưa đủ ngày thì chưa kết")
	main.sect_life.day = 10
	check(r.state_of(tinh.node_id, "linh_mach_tinh") == "ready", "đủ ngày thì kết tinh")
	var got := r.take(night_node, "player")
	check(not got.is_empty() and r.days_left(night_node.node_id) == 15, "khan hiếm tái sinh rất chậm (15 ngày)")

	# --- NPC dùng chung trạng thái
	var ore: Node2D = find_kind("thiet_tinh")
	var oid: String = ore.node_id
	var taken := r.npc_take(oid, "luc_van")
	check(not taken.is_empty() and taken["item"] == "thiet_tinh", "NPC lấy được vật liệu")
	check(not ore.available and str(r.states[oid]["by"]) == "npc:luc_van", "người chơi thấy điểm đó đã bị NPC lấy")
	check(r.npc_take(oid, "khac").is_empty() and r.take(ore, "player").is_empty(), "lấy lần hai (NPC khác/người chơi) bị từ chối")

	# --- lưu / tải
	var saved: Dictionary = r.to_dict()
	var r2 := ResourceWorld.new()
	r2.main = main
	r2.from_dict(saved)
	check(r2.states.has(oid) and r2.states.has(rid) and r2.states[rid]["gone"] == true, "lưu/tải giữ điểm đã lấy và di vật đã mất")
	main.sect_life.day += 400
	var pruned: Dictionary = r.to_dict()
	check(pruned["states"].has(rid) and not pruned["states"].has(oid), "điểm đã tái sinh được dọn khỏi bản lưu, di vật vẫn nhớ")
	r2.free()

	# --- dựng lại map phụ vẫn giữ ID, vị trí, trạng thái
	main.switch_map_now("linh_mach_dong", Maps.DEFS["linh_mach_dong"]["entry"])
	await process_frame
	var first_ids := ids_of("thiet_tinh")
	check(first_ids.size() >= 6 and str(first_ids[0]).begins_with("linh_mach_dong:thiet_tinh:"), "map phụ rải khoáng theo ID riêng (%d)" % first_ids.size())
	var pos_a: Vector2 = find_kind("thiet_tinh").position
	var id_a: String = find_kind("thiet_tinh").node_id
	var node_a: Node2D = find_kind("thiet_tinh")
	r.take(node_a, "player")
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame
	main.switch_map_now("linh_mach_dong", Maps.DEFS["linh_mach_dong"]["entry"])
	await process_frame
	check(ids_of("thiet_tinh") == first_ids, "vào lại map: cùng bộ ID")
	var again: Node2D = null
	for h in main.herbs:
		if is_instance_valid(h) and h.node_id == id_a:
			again = h
	check(again != null and again.position.is_equal_approx(pos_a), "vào lại map: cùng vị trí")
	check(again != null and not again.available, "điểm đã lấy vẫn còn trống sau khi dựng lại map")

	print("RESOURCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
