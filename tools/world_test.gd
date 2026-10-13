extends SceneTree
## Thế giới mở V1: dữ liệu địa điểm/tuyến, khám phá ba mức, tin đồn, động phủ, lưu/tải, bản đồ đại vực.
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


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var w: World = main.province
	var locs: Dictionary = w.locations()

	# --- dữ liệu
	check(locs.size() >= 15, "có %d địa điểm" % locs.size())
	var maps_ok := true
	for id in locs:
		var m := str(locs[id]["map"])
		maps_ok = maps_ok and (m == "overworld" or Maps.exists(m))
	check(maps_ok, "mọi địa điểm trỏ tới map có thật")
	var routes_ok := true
	for r in w.routes():
		routes_ok = routes_ok and locs.has(str(r["a"])) and locs.has(str(r["b"]))
	check(routes_ok, "mọi tuyến đường nối hai địa điểm có thật")
	var shortcut := false
	for r in w.routes():
		shortcut = shortcut or str(r.get("kind", "")) == "shortcut"
	check(shortcut, "có đường tắt bên cạnh đường chính")
	var sect_n := 0
	for id in locs:
		if str(locs[id]["kind"]) == "sect":
			sect_n += 1
	check(sect_n == 6, "6 sơn môn (ngoại viện Kiếm Tông + 5 căn cứ) (%d)" % sect_n)

	# --- trạng thái ban đầu: ba mức
	check(w.state_of("van_khe") == World.DISCOVERED and w.state_of("kiem_tong_ngoai") == World.DISCOVERED, "nơi khởi đầu (làng, thung lũng) đã phát hiện")
	check(w.state_of("tuyet_coc") == World.UNKNOWN and w.state_of("dp_thien_mach") == World.UNKNOWN, "nơi xa và động phủ chưa biết")

	# --- phát hiện khi tới nơi
	check(w.location_at("overworld", Vector2(1280, 900)) == "van_khe", "vị trí giữa làng ứng với Làng Vân Khê")
	check(w.location_at("overworld", Vector2(3300, 850)) == "hac_lam", "vị trí đông ứng với Hắc Lâm")
	check(w.location_at("overworld", Vector2(5, 5)) == "", "vị trí hoang không thuộc địa điểm nào")
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	w._check_here()
	check(w.state_of("soi_linh") == World.DISCOVERED, "vào Sói Lĩnh: tự phát hiện")
	check(not w.log.is_empty() and str(w.log[w.log.size() - 1]["text"]).contains("Sói Lĩnh"), "ghi tin tức khi phát hiện")

	# --- tin đồn: vị trí gần đúng, rồi được xác nhận
	var before := w.state_of("tuyet_coc")
	check(before == World.UNKNOWN, "Hắc Lang Cốc ban đầu chưa biết (không kề nơi đã tới)")
	check(w.add_rumor("tuyet_coc", "", "thương hội", "low"), "thêm tin đồn cho nơi chưa biết")
	check(w.state_of("tuyet_coc") == World.RUMOR and w.rumors.has("tuyet_coc"), "đã chuyển sang tin đồn")
	var exact := Vector2(float(locs["tuyet_coc"]["pos"][0]), float(locs["tuyet_coc"]["pos"][1]))
	var shown := w.map_pos("tuyet_coc")
	check(shown.distance_to(exact) <= w.rumor_radius("tuyet_coc") + 0.01, "vị trí tin đồn lệch trong bán kính bất định (%.0f ≤ %.0f)" % [shown.distance_to(exact), w.rumor_radius("tuyet_coc")])
	check(not w.add_rumor("van_khe"), "nơi đã biết không thêm tin đồn")
	w.discover("tuyet_coc", "thử")
	check(w.state_of("tuyet_coc") == World.DISCOVERED and not w.rumors.has("tuyet_coc"), "xác nhận: bỏ tin đồn, vị trí chính xác")
	check(w.map_pos("tuyet_coc").is_equal_approx(exact), "đã phát hiện: vị trí chính xác")

	# --- tin đồn theo ngày: chỉ kề nơi đã biết, không chọn động phủ ẩn
	var bad := false
	for i in 40:
		var snapshot := w.states.duplicate()
		w._daily_force()
		for id in w.states:
			if not snapshot.has(id):
				var nb_known := false
				for r in w.routes():
					var other := ""
					if str(r["a"]) == str(id):
						other = str(r["b"])
					elif str(r["b"]) == str(id):
						other = str(r["a"])
					if other != "" and snapshot.has(other):
						nb_known = true
				bad = bad or not nb_known or bool(locs[id].get("hidden", false))
	check(not bad, "tin đồn theo ngày chỉ về nơi kề địa điểm đã biết, không lộ động phủ ẩn")

	# --- động phủ: mảnh bản đồ → tin đồn → xác nhận
	main.destiny.fragments["dp_vo_danh"] = 1
	w._sync_dong_phu()
	check(w.state_of("dp_vo_danh") == World.RUMOR, "có mảnh bản đồ: thành tin đồn")
	main.destiny.fragments["dp_vo_danh"] = 3
	w._sync_dong_phu()
	check(w.state_of("dp_vo_danh") == World.DISCOVERED, "đủ ba mảnh: động phủ được xác nhận")

	# --- lưu / tải
	var saved: Dictionary = w.to_dict()
	var w2 := World.new()
	w2.main = main
	w2._load_data()
	w2.from_dict(saved)
	check(w2.states == w.states and w2.log.size() == w.log.size(), "lưu/tải giữ trạng thái và nhật ký")
	w2.states["kho_ton_tai"] = World.DISCOVERED
	var w3 := World.new()
	w3._load_data()
	w3.from_dict({})
	check(w3.state_of("van_khe") == World.DISCOVERED and w3.states.size() == 3, "bản lưu cũ không có khóa: tải được, giữ nơi khởi đầu")
	w3.from_dict({"states": {"kho_ton_tai": "discovered", "soi_linh": "discovered"}})
	check(not w3.states.has("kho_ton_tai") and w3.state_of("soi_linh") == World.DISCOVERED, "id không còn tồn tại bị bỏ khi tải")
	w2.free()
	w3.free()

	# --- bản đồ đại vực trong sổ tay
	main.dialogue.open = false
	main.journal.open_ui("world")
	await process_frame
	var found := false
	for c in main.journal._content.get_children():
		found = found or c is WorldMapView
	check(found, "tab Đại vực dựng được bản đồ")
	main.journal.close_ui()

	print("WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
