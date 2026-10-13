extends SceneTree
## Hạng mục hoàn thiện Thế Giới Mở: công thức dùng vật liệu mới, bản đồ mua của thương hội, khu khai thác do tông môn kiểm soát.
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
	main.dialogue.open = false
	var inv = main.inv
	var P: World = main.province
	var R: ResourceWorld = main.resources

	# --- công thức dùng vật liệu mới
	var ok := true
	var used := {}
	for r in Items.RECIPES:
		ok = ok and Items.DATA.has(str(r["out"]))
		for m in r["mats"]:
			ok = ok and Items.DATA.has(str(m))
			used[str(m)] = true
	check(ok and Items.RECIPES.size() >= 10, "mọi công thức dùng vật phẩm có thật (%d công thức)" % Items.RECIPES.size())
	var new_mats := ["thiet_tinh", "truc_linh", "han_thuy_thach", "xich_hoa_thach", "hoang_tho_tinh", "ngan_nien_thao", "linh_mach_tinh", "huyen_thiet"]
	var all_used := true
	for m in new_mats:
		all_used = all_used and used.has(m)
	check(all_used, "8 vật liệu mới đều có công thức dùng")
	var chances_ok := true
	for r in Items.RECIPES:
		chances_ok = chances_ok and float(r["chance"]) > 0.0 and float(r["chance"]) <= 0.9 and float(r["time"]) > 0.0
	check(chances_ok, "tỉ lệ luyện thành trong khoảng hợp lý")
	var rare: Dictionary = {}
	for r in Items.RECIPES:
		if str(r["id"]) == "r_linh_mach":
			rare = r
	check(not rare.is_empty() and float(rare["chance"]) < 0.5 and int(Items.DATA["dan_linh_mach"]["sell"]) >= 200, "đan từ vật liệu khan hiếm: khó luyện, giá trị cao")
	# luyện thử (không qua giao diện): đủ nguyên liệu thì có thể luyện
	for k in rare["mats"]:
		inv.add(str(k), int(rare["mats"][k]))
	check(main.alchemy.can_make(rare), "đủ nguyên liệu thì luyện được")
	# dùng đan mới
	main.vitals.hp = 1.0
	inv.add("dan_hau_tho", 1)
	check(inv.use("dan_hau_tho", main.cult) and main.vitals.hp >= minf(main.vitals.max_hp, 200.0) - 0.01, "Hậu Thổ Đan hồi khí huyết")
	main.cult.qi = 0.0
	inv.add("dan_han_tam", 1)
	check(inv.use("dan_han_tam", main.cult) and main.cult.qi >= minf(main.cult.qi_max(), 149.0) - 0.01, "Hàn Tâm Đan hồi linh khí")

	# --- bản đồ mua được
	check("ban_do_cu" in Items.SHOP_BUY and "ban_do_chi_tiet" in Items.SHOP_BUY, "thương hội bán bản đồ")
	P.states.clear()
	P.rumors.clear()
	P._apply_defaults()
	check(P.has_unknown_reachable(), "còn nơi chưa biết kề nơi đã biết")
	var rum0: int = P.count(World.RUMOR)
	inv.add("ban_do_cu", 1)
	check(inv.use("ban_do_cu", main.cult) and P.count(World.RUMOR) == rum0 + 1 and inv.count("ban_do_cu") == 0, "Bản đồ cũ: thêm một tin đồn đáng tin, tiêu hao")
	var disc0: int = P.count(World.DISCOVERED)
	var found0 := P.routes_found.size()
	inv.add("ban_do_chi_tiet", 1)
	P.discover("soi_linh", "thử")
	P.discover("dam_lay", "thử")
	disc0 = P.count(World.DISCOVERED)
	check(inv.use("ban_do_chi_tiet", main.cult) and P.count(World.DISCOVERED) == disc0 + 1, "Bản đồ chi tiết: xác nhận hẳn một nơi")
	check(P.routes_found.size() >= found0, "bản đồ chi tiết có thể lộ thêm đường tắt")
	# hết nơi chưa biết thì không dùng (không bị tiêu hao)
	for id in P.locations():
		if not bool(P.info(str(id)).get("hidden", false)):
			P.discover(str(id), "thử")
	inv.add("ban_do_cu", 1)
	check(not inv.use("ban_do_cu", main.cult) and inv.count("ban_do_cu") == 1, "không còn nơi chưa biết: bản đồ không bị tiêu hao")

	# --- khu khai thác do tông môn kiểm soát
	SectWar.PLAYER = "kiem_tong"
	var owned: Node2D = null
	var free_node: Node2D = null
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame
	for h in main.herbs:
		if is_instance_valid(h) and R.owner_of_node(h.node_id) == "kiem_tong":
			owned = h
		if is_instance_valid(h) and R.owner_of_node(h.node_id) == "" and free_node == null:
			free_node = h
	check(owned != null, "thung lũng Kiếm Tông có mạch thiết tinh do Kiếm Tông kiểm soát")
	check(R.restricted_owner(owned.node_id) == "", "tông của mình thì khai thác tự do")
	SectWar.PLAYER = "xich_viem"
	check(R.restricted_owner(owned.node_id) == "kiem_tong", "đổi sang tông khác: khu của Kiếm Tông bị hạn chế")
	check(free_node != null and R.restricted_owner(free_node.node_id) == "", "điểm vô chủ vẫn tự do")
	check(owned.prompt_text().contains("thuộc"), "gợi ý tương tác nói rõ điểm thuộc về tông nào")
	# xin phép
	inv.add_stones(300)
	var s0: int = inv.stones
	var got0: int = inv.count("thiet_tinh")
	R._permit_pay(owned, "kiem_tong")
	check(inv.stones == s0 - 25 and inv.count("thiet_tinh") > got0, "xin phép: nộp phí rồi được khai thác")
	check(R.restricted_owner(owned.node_id) == "", "giấy phép còn hạn: không bị hạn chế")
	main.sect_life.day += 4
	check(R.restricted_owner(owned.node_id) == "kiem_tong", "hết hạn giấy phép: lại bị hạn chế")
	# lén lấy: bị bắt gặp
	var node2: Node2D = null
	for h in main.herbs:
		if is_instance_valid(h) and h != owned and R.owner_of_node(h.node_id) == "kiem_tong" and R.is_available(h):
			node2 = h
	check(node2 != null, "còn điểm khác của Kiếm Tông để thử")
	var dy0: float = main.destiny.duyen
	var stones1: int = inv.stones
	R.steal(node2, "kiem_tong", 1)
	check(main.inv.stones < stones1 and main.destiny.duyen < dy0, "lén lấy bị bắt gặp: mất tiền phạt, duyên giảm")
	check(int(main.cultivation_v1.state.wanted.get("kiem_tong", 0)) >= 1 and str(main.cultivation_v1.state.relations.get("kiem_tong", "")) == "hostile", "tông bị trộm coi người chơi là thù địch (cùng cơ chế cướp bí tịch)")
	# lưu/tải giấy phép
	R.permits["kiem_tong"] = int(main.sect_life.day) + 2
	var r2 := ResourceWorld.new()
	r2.main = main
	r2.from_dict(R.to_dict())
	check(int(r2.permits.get("kiem_tong", 0)) == int(R.permits["kiem_tong"]), "lưu/tải giữ giấy phép khai thác")
	r2.free()
	# địa bàn đổi chủ theo chiến sự
	SectWar.PLAYER = "kiem_tong"
	main.switch_map_now("tieu_gioi", Maps.DEFS["tieu_gioi"]["entry"])
	await process_frame
	var terr: Node2D = null
	for h in main.herbs:
		if is_instance_valid(h) and R._node_owner.get(h.node_id, {}).has("territory"):
			terr = h
	check(terr != null, "Tiểu Thế Giới có điểm khai thác gắn với địa bàn")
	if terr != null:
		var tid := str(R._node_owner[terr.node_id]["territory"])
		var before := R.owner_of_node(terr.node_id)
		main.war.owners[tid] = SectWar.PLAYER
		check(R.owner_of_node(terr.node_id) == SectWar.PLAYER and R.restricted_owner(terr.node_id) == "", "chiếm được địa bàn thì khai thác tự do (trước đó thuộc %s)" % before)

	print("WORLD EXTRAS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
