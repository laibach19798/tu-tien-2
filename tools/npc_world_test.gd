extends SceneTree
## NPC trong thế giới mở: mô phỏng ngoài scene theo ngày, dùng chung trạng thái tài nguyên, sổ sở hữu vật phẩm độc nhất,
## NPC giành truyền thừa khi người chơi chậm, hiện/ẩn trong scene, trò chuyện + giao dịch, lưu/tải.
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


func tick_days(n: int) -> void:
	var nw: NpcWorld = main.npc_world
	main.sect_life.day += n
	nw._timer = 0.0
	nw._process(0.0)


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	var nw: NpcWorld = main.npc_world
	var P: World = main.province

	# --- dữ liệu
	check(nw.roster().size() >= 10 and nw.residents().size() >= 4, "có %d NPC lang thang + %d cư dân (tổng ≥ 15)" % [nw.roster().size(), nw.residents().size()])
	var data_ok := true
	for id in nw.roster():
		var d: Dictionary = nw.roster()[id]
		data_ok = data_ok and P.locations().has(str(d["home"]))
		for k in ["gather_at", "hunt_at"]:
			for l in d.get(k, []):
				data_ok = data_ok and P.locations().has(str(l))
		data_ok = data_ok and P.locations().has(str(d.get("trade_at", "van_khe")))
	check(data_ok, "nhà và nơi hoạt động của mọi NPC là địa điểm có thật")
	check(nw.states.size() == nw.agent_ids().size() and nw.agent_ids().size() >= 15 and str(nw.state_of("luc_van")["loc"]) == "van_khe", "mọi NPC (lang thang + cư dân) có trạng thái khởi đầu (%d)" % nw.agent_ids().size())

	# --- mô phỏng ngoài scene theo ngày
	var money0 := 0
	for id in nw.states:
		money0 += int(nw.states[id]["money"])
	tick_days(60)
	var events := 0
	var with_cause := true
	for id in nw.states:
		events += (nw.states[id]["history"] as Array).size()
		for h in nw.states[id]["history"]:
			with_cause = with_cause and str(h["text"]).length() > 10
	check(events >= 15, "60 ngày game: NPC làm việc ngoài scene, có %d sự kiện ghi lại" % events)
	check(with_cause, "mọi thay đổi trạng thái đều có lý do được ghi")
	var took := 0
	for id in main.resources.states:
		if str(main.resources.states[id].get("by", "")).begins_with("npc:"):
			took += 1
	check(took >= 1, "NPC lấy tài nguyên qua cùng ResourceWorld (%d điểm)" % took)
	var money1 := 0
	var injured_or_trade := false
	for id in nw.states:
		money1 += int(nw.states[id]["money"])
		for h in nw.states[id]["history"]:
			injured_or_trade = injured_or_trade or str(h["text"]).contains("Bán ") or str(h["text"]).contains("thương")
	check(money1 > money0 or injured_or_trade, "có buôn bán hoặc gặp nạn: tài sản/trạng thái thay đổi")
	check(main.province.log.size() >= 1, "tin đáng chú ý lên nhật ký tin tức đại vực")

	# --- điểm NPC đã lấy thì người chơi không lấy lại được
	var npc_taken := ""
	for id in main.resources.states:
		if str(main.resources.states[id].get("by", "")).begins_with("npc:") and not bool(main.resources.states[id].get("gone", false)):
			npc_taken = str(id)
			break
	if npc_taken != "":
		var kind: String = main.resources.node_kind(npc_taken)
		check(main.resources.state_of(npc_taken, kind) in ["taken", "gone"], "điểm NPC vừa lấy hiện là 'đang chờ tái sinh'")

	# --- sổ sở hữu độc nhất
	check(nw.register_unique("test:thanh_kiem", "Thanh kiếm thử", "world:x"), "đăng ký vật độc nhất")
	check(not nw.register_unique("test:thanh_kiem", "Bản sao", "player"), "không đăng ký lại cùng ID (không nhân bản)")
	check(not nw.transfer("test:thanh_kiem", "player", "npc:luc_van", "sai chủ"), "chuyển chủ khai sai chủ cũ bị từ chối")
	check(nw.transfer("test:thanh_kiem", "world:x", "player", "nhặt được") and nw.owner_of("test:thanh_kiem") == "player", "chuyển chủ đúng: chỉ một chủ")
	check(nw.uniques["test:thanh_kiem"]["history"].size() == 1, "lịch sử chuyển chủ được ghi")

	# --- động phủ: NPC giành truyền thừa khi người chơi chậm chân
	var dp := "dp_vo_danh"
	var uid := nw.ensure_legacy(dp)
	check(nw.owner_of(uid) == "world:" + dp, "truyền thừa động phủ ban đầu thuộc về động phủ")
	var log_before: int = main.province.log.size()
	var who: String = nw.on_rival_takes(dp, int(main.sect_life.day))
	check(who != "" and nw.owner_of(uid).begins_with("npc:"), "kẻ tầm bảo giành truyền thừa (%s)" % who)
	var hunter := nw.owner_of(uid).trim_prefix("npc:")
	check(str(nw.states[hunter]["status"]) == "seclusion", "NPC giành được bế quan")
	check(main.province.log.size() > log_before, "việc giành truyền thừa có tin tức")
	var hist_ok := false
	for h in nw.states[hunter]["history"]:
		hist_ok = hist_ok or str(h["text"]).contains("Giành")
	check(hist_ok, "dữ liệu NPC ghi lại việc giành truyền thừa")
	nw.on_player_legacy(dp, "inherit")
	check(nw.owner_of(uid).begins_with("npc:"), "người chơi không thể lấy lại bản đã bị NPC giành (không nhân bản)")
	nw.new_generation(dp)
	var uid2 := nw.ensure_legacy(dp)
	check(uid2 != uid and nw.owner_of(uid2) == "world:" + dp and nw.owner_of(uid).begins_with("npc:"), "động phủ tái tạo: bản truyền thừa mới, bản cũ vẫn ở NPC")
	nw.on_player_legacy(dp, "inherit")
	check(nw.owner_of(uid2) == "player", "bản mới người chơi kế thừa được")
	check(nw.owned_by("player").has(uid2) and not nw.owned_by("player").has(uid), "mỗi truyền thừa chỉ một chủ")

	# --- vật độc nhất trong thế giới (di vật): NPC lấy thì có chủ là NPC
	var relic_id := "overworld:co_tu_di_vat:0"
	main.resources.states.erase(relic_id)
	nw.uniques.erase("relic:" + relic_id)
	var rg: Dictionary = main.resources.npc_take(relic_id, "quan_dao")
	check(not rg.is_empty() and nw.owner_of("relic:" + relic_id) == "npc:quan_dao", "NPC lấy di vật độc nhất: ghi chủ là NPC")
	check(main.resources.npc_take(relic_id, "luc_van").is_empty(), "người khác không lấy lại được di vật")

	# --- hiện trong scene
	for id in nw.states:
		nw.states[id]["loc"] = "van_khe"
		nw.states[id]["status"] = "ok"
	nw.states["luc_van"]["loc"] = "soi_linh"
	nw.states["ngo_thanh"]["loc"] = "soi_linh"
	nw.states["ha_kiem"]["loc"] = "soi_linh"
	nw.states["tran_hoai"]["loc"] = "soi_linh"
	nw.states["bach_tam"]["loc"] = "soi_linh"
	nw.states["bach_tam"]["status"] = "seclusion"
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	nw._timer = 0.0
	nw._process(0.0)
	var in_scene: Array = []
	for n in main.npcs:
		if n is EncounterNode and str(n.enc_id).begins_with("wnpc_"):
			in_scene.append(str(n.enc_id))
	check(in_scene.size() == 3, "NPC ở Sói Lĩnh hiện trong scene, tối đa 3 (%d)" % in_scene.size())
	check(not in_scene.has("wnpc_bach_tam"), "NPC đang bế quan không hiện")
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame
	nw._timer = 0.0
	nw._process(0.0)
	var left := 0
	for n in main.npcs:
		if n is EncounterNode and str(n.enc_id).begins_with("wnpc_") and (str(n.enc_id) == "wnpc_luc_van" and str(nw.states["luc_van"]["loc"]) == "soi_linh"):
			left += 1
	check(left == 0, "rời map: NPC ở Sói Lĩnh biến khỏi scene")

	# --- NPC trong scene đi lại
	main.switch_map_now("soi_linh", Vector2(900, 700))
	await process_frame
	nw.states["luc_van"]["loc"] = "soi_linh"
	nw.states["luc_van"]["status"] = "ok"
	nw._dirty = true
	nw._timer = 0.0
	nw._process(0.0)
	var walker: EncounterNode = null
	for n in main.npcs:
		if n is EncounterNode and n.enc_id == "wnpc_luc_van":
			walker = n
	check(walker != null, "Lục Vân hiện ở Sói Lĩnh")
	if walker != null:
		main.player.position = walker.position + Vector2(700, 0)   # đứng xa để NPC được tự đi
		var p0: Vector2 = walker.position
		var moved := 0.0
		for i in 600:
			nw._wander(0.05)
			moved = maxf(moved, walker.position.distance_to(p0))
		check(moved > 10.0, "NPC trong scene tự đi lại quanh chỗ đứng (xa nhất %.0f)" % moved)
		var anchor: Vector2 = walker.get_meta("wander")["anchor"]
		check(walker.position.distance_to(anchor) <= 140.0, "không đi quá xa chỗ đứng gốc")
		var before := walker.position
		main.player.position = walker.position + Vector2(30, 0)
		for i in 40:
			nw._wander(0.05)
		check(walker.position.is_equal_approx(before), "người chơi lại gần thì NPC đứng lại")

	# --- bế quan: có cửa động để gõ / để lại lễ vật
	nw.states["bach_tam"]["loc"] = "soi_linh"
	nw.states["bach_tam"]["status"] = "seclusion"
	nw.states["bach_tam"]["status_until"] = main.sect_life.day + 5
	nw._dirty = true
	nw._timer = 0.0
	nw._process(0.0)
	var door: EncounterNode = null
	for n in main.npcs:
		if n is EncounterNode and n.enc_id == "wseclude_bach_tam":
			door = n
	check(door != null, "NPC bế quan có cửa động để người chơi tới tìm")
	var rel_b: int = int(nw.states["bach_tam"]["rel"])
	var until_b: int = int(nw.states["bach_tam"]["status_until"])
	nw._knock("bach_tam")
	check(int(nw.states["bach_tam"]["rel"]) == rel_b - 3 and int(nw.states["bach_tam"]["status_until"]) == until_b + 1, "gõ cửa: quan hệ giảm và bế quan kéo dài thêm")
	main.dialogue.open = false
	main.inv.add_stones(100)
	var st0: int = main.inv.stones
	nw._gift("bach_tam")
	check(main.inv.stones == st0 - 20 and int(nw.states["bach_tam"]["rel"]) > rel_b - 3 and int(nw.states["bach_tam"]["rel"]) <= rel_b + 2, "để lại lễ vật: tốn 20 linh thạch, thiện cảm tăng (mức tăng theo tính cách)")
	main.dialogue.open = false

	# --- cư dân đi việc ngoài scene, về ngay khi người chơi vào map nhà
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame
	nw.states["thanh_dao"]["loc"] = "soi_linh"
	nw.states["thanh_dao"]["act"] = "gather"
	nw.states["thanh_dao"]["until"] = main.sect_life.day + 5
	nw._dirty = true
	main.switch_map_now("sect_kiem_tong", Maps.DEFS["sect_kiem_tong"]["entry"])
	await process_frame
	nw._timer = 0.0
	nw._process(0.0)
	check(str(nw.states["thanh_dao"]["loc"]) == "sect_kiem_tong" and str(nw.states["thanh_dao"]["act"]) == "rest", "cư dân đang đi việc được gọi về khi người chơi vào sơn môn")
	main.switch_map_now("overworld", Vector2(1280, 1000))
	await process_frame

	# --- cân bằng: mô phỏng dài không bị thương quá nhiều, không tích trữ vô hạn
	var tot_trips := 0
	var tot_inj := 0
	var hoard := 0
	for step in 6:
		main.sect_life.day += 30
		nw._timer = 0.0
		nw._process(0.0)
		main.resources.states.clear()
	for id in nw.states:
		var sts: Dictionary = nw.states[id].get("stats", {})
		tot_trips += int(sts.get("trips", 0))
		tot_inj += int(sts.get("injured", 0))
		var held := 0
		for k in nw.states[id]["assets"]:
			held += int(nw.states[id]["assets"][k])
		hoard = maxi(hoard, held)
	var rate := float(tot_inj) / maxf(1.0, float(tot_trips))
	check(tot_trips > 300 and rate > 0.01 and rate < 0.2, "180 ngày: %d chuyến, tỉ lệ bị thương %.1f%% (trong khoảng 1–20%%)" % [tot_trips, rate * 100.0])
	check(hoard <= 12, "không NPC nào tích trữ quá 12 món (cao nhất %d)" % hoard)

	# --- trò chuyện: tin tức và mua đồ
	var st: Dictionary = nw.states["phu_quy"]
	st["assets"] = {"soi_nanh": 2}
	st["money"] = 0
	var known := P.count(World.UNKNOWN)
	nw._ask_news("phu_quy")
	check(P.count(World.RUMOR) >= 1 or P.count(World.UNKNOWN) < known, "hỏi thăm NPC: nhận được tin đồn")
	main.dialogue.open = false
	var rel0: int = int(st["rel"])
	nw._ask_news("phu_quy")
	check(int(st["rel"]) == rel0, "hỏi thăm lần hai trong ngày không tăng quan hệ")
	main.dialogue.open = false
	main.inv.add_stones(500)
	var stones0: int = main.inv.stones
	var fang0: int = main.inv.count("soi_nanh")
	nw._buy("phu_quy", "soi_nanh")
	check(main.inv.count("soi_nanh") == fang0 + 1 and int(st["assets"]["soi_nanh"]) == 1 and main.inv.stones < stones0, "mua lại: vật chuyển từ NPC sang người chơi, tiền chuyển ngược lại")
	check(int(st["money"]) > 0, "NPC nhận linh thạch")
	nw._buy("phu_quy", "soi_nanh")
	nw._buy("phu_quy", "soi_nanh")
	check(main.inv.count("soi_nanh") == fang0 + 2, "hết hàng thì không mua được thêm (không sinh vật phẩm)")

	# --- lưu / tải
	var saved: Dictionary = nw.to_dict()
	var n2 := NpcWorld.new()
	n2.main = main
	n2._data = nw._data
	n2.from_dict(saved)
	check(n2.states.size() == nw.states.size() and n2.uniques.size() == nw.uniques.size(), "lưu/tải giữ trạng thái NPC và sổ sở hữu")
	check(n2.owner_of(uid) == nw.owner_of(uid) and n2.owner_of(uid2) == "player", "chủ sở hữu giữ nguyên sau lưu/tải")
	var n3 := NpcWorld.new()
	n3.main = main
	n3._data = nw._data
	n3.from_dict({})
	check(n3.states.size() == nw.agent_ids().size(), "bản lưu cũ không có khóa: tải được, NPC có trạng thái khởi đầu")
	n2.free()
	n3.free()

	print("NPC WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
