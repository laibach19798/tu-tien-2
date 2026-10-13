extends SceneTree
## NPC thông minh V1 bước 6: NPC chủ động tìm người chơi (báo ân, đòi nợ, nhờ giúp, rủ đi, chỉ manh mối), mất thời gian đi đường.
var main: Node
var W: NpcWorld
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


func reset_all() -> void:
	for id in W.agent_ids():
		W.states[str(id)] = W._fresh_state(str(id))
	W.deeds.clear()
	main.events.events.clear()


func opts_text() -> Array:
	var out: Array = []
	for o in main.dialogue._opts:
		out.append(str(o["text"]))
	return out


func click(prefix: String) -> void:
	for o in main.dialogue._opts:
		if str(o["text"]).begins_with(prefix):
			(o["call"] as Callable).call()
			return
	push_error("không có lựa chọn: " + prefix)


func talk_to(id: String) -> void:
	var node := EncounterNode.new()
	node.setup("wnpc_" + id, {"name": id, "kind": "figure"})
	W.talk(node)
	node.free()


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	main.sect_life.day = 100
	main.player.position = Vector2(1280, 900)
	var here := str(main.journey.here())
	check(here != "", "người chơi đang ở một địa điểm xác định (%s)" % here)

	# --- không có lý do thì không tìm
	reset_all()
	W._initiatives(100)
	var none := true
	for id in W.roster():
		none = none and W.seek_of(str(id)).is_empty()
	check(none, "chưa có quan hệ đặc biệt: không NPC nào tự tìm người chơi")

	# --- báo ân
	reset_all()
	W.record("luc_van", "rescue")
	W.record("luc_van", "help")
	W.states["luc_van"]["loc"] = "soi_linh"
	var intent: Dictionary = W._intent("luc_van", 100)
	check(str(intent.get("kind", "")) == "repay_gift", "mắc ơn nặng + trọng nghĩa: ý định báo ân")
	var started := false
	for dday in range(100, 140):
		main.sect_life.day = dday
		W._initiatives(dday)
		if not W.seek_of("luc_van").is_empty():
			started = true
			break
	var sk: Dictionary = W.seek_of("luc_van")
	check(started and int(sk["arrive"]) >= int(sk["since"]), "NPC lên đường tìm người chơi")
	check(not bool(sk["arrived"]), "chưa tới nơi thì chưa hiện ra")
	var arrive_day: int = int(sk["arrive"])
	var days_needed: int = arrive_day - int(sk["since"])
	var travelled_ok := true
	if str(W.states["luc_van"]["loc"]) != here:
		travelled_ok = days_needed >= 1
	check(travelled_ok, "đi từ nơi khác tới mất ít nhất 1 ngày (%d ngày)" % days_needed)
	W._seek_tick(arrive_day - 1 if days_needed > 0 else arrive_day)
	if days_needed > 0:
		check(str(W.states["luc_van"]["loc"]) != here or bool(W.seek_of("luc_van")["arrived"]) == false, "chưa đủ ngày: chưa tới")
	W._seek_tick(arrive_day)
	check(bool(W.seek_of("luc_van")["arrived"]) and str(W.states["luc_van"]["loc"]) == here, "đủ ngày: tới nơi người chơi đứng")
	var debt_before := int(W.bond("luc_van").debt)
	var stones_before: int = main.inv.stones
	talk_to("luc_van")
	check(main.dialogue.open, "gặp NPC đã tới: mở hội thoại chủ động")
	main.dialogue.open = false
	check(int(W.bond("luc_van").debt) < debt_before or main.inv.stones > stones_before or W.states["luc_van"]["assets"].size() != 0, "báo ân: NPC đưa quà và ân nghĩa giảm")
	check(W.seek_of("luc_van").is_empty(), "xong việc: NPC không còn tìm nữa")

	# --- đòi nợ
	reset_all()
	W.record("quan_dao", "robbed")
	W.record("quan_dao", "robbed")
	W.states["quan_dao"]["last_wrong"] = 80
	var it: Dictionary = W._intent("quan_dao", 100)
	check(str(it.get("kind", "")) == "revenge_demand" and int(it["stones"]) >= 30, "thù sâu + hiếu chiến: đòi bồi thường")
	W.states["quan_dao"]["seek"] = {"kind": "revenge_demand", "stones": 50, "target": here, "arrive": 100, "since": 100, "arrived": true}
	W.states["quan_dao"]["loc"] = here
	main.inv.stones = 200
	var hate0 := int(W.bond("quan_dao").hate)
	talk_to("quan_dao")
	check(opts_text().size() == 2 and str(opts_text()[0]).begins_with("Nộp"), "đòi nợ: có lựa chọn nộp hoặc giao đấu")
	click("Nộp")
	main.dialogue.open = false
	check(main.inv.stones == 150 and int(W.bond("quan_dao").hate) < hate0, "nộp tiền: mất linh thạch, thù hận giảm")
	check(W.seek_of("quan_dao").is_empty(), "xong nợ: NPC đi")

	# --- nhờ mang vật liệu
	reset_all()
	W.states["luc_van"]["rel"] = 20
	W.bond("luc_van")["trust"] = 10
	W.states["luc_van"]["assets"] = {}
	var bi: Dictionary = W._intent("luc_van", 100)
	check(str(bi.get("kind", "")) == "bring_material" and str(bi["item"]) in ["thiet_tinh", "truc_linh"], "thiếu vật liệu mình cần + có thiện cảm: nhờ giúp (%s)" % str(bi.get("item", "")))
	W.states["luc_van"]["seek"] = {"kind": "bring_material", "item": str(bi["item"]), "qty": 2, "reward": int(bi["reward"]), "target": here, "arrive": 100, "since": 100, "arrived": true}
	W.states["luc_van"]["loc"] = here
	talk_to("luc_van")
	click("Nhận lời")
	main.dialogue.open = false
	check(not W.request_of("luc_van").is_empty() and W.seek_of("luc_van").is_empty(), "nhận lời: ghi thành lời nhờ")
	W.states["luc_van"]["money"] = 500
	var item := str(bi["item"])
	var have0: int = main.inv.count(item)
	main.inv.add(item, 2)
	var money0: int = main.inv.stones
	var got_before := int(W.states["luc_van"]["assets"].get(item, 0))
	talk_to("luc_van")
	check(opts_text().filter(func(t): return str(t).begins_with("Giao")).size() > 0, "có lựa chọn giao vật liệu theo lời nhờ")
	main.dialogue.open = false
	W.turn_in_request("luc_van")
	main.dialogue.open = false
	check(main.inv.stones > money0 and main.inv.count(item) == have0 and int(W.states["luc_van"]["assets"][item]) == got_before + 2, "giao vật liệu: nhận thưởng, NPC thực sự nhận hàng")
	check(W.request_of("luc_van").is_empty(), "xong lời nhờ")

	# --- lời nhờ được giải quyết nơi khác
	W.states["luc_van"]["request"] = {"kind": "bring_material", "item": item, "qty": 2, "reward": 100, "day": 100, "until": 112}
	W.states["luc_van"]["assets"] = {item: 3}
	var have1: int = main.inv.count(item)
	main.inv.add(item, 2)
	var stones_now: int = main.inv.stones
	W.turn_in_request("luc_van")
	main.dialogue.open = false
	check(main.inv.stones == stones_now and main.inv.count(item) == have1 + 2 and W.request_of("luc_van").is_empty(), "NPC đã tự kiếm đủ: lời nhờ huỷ, không bắt giao hàng")
	main.inv.remove(item, 2)

	# --- quá hạn
	W.states["luc_van"]["request"] = {"kind": "bring_material", "item": item, "qty": 2, "reward": 100, "day": 100, "until": 110}
	W._expire_requests(111)
	check(W.request_of("luc_van").is_empty(), "lời nhờ quá hạn thì bỏ")

	# --- rủ đi sự kiện / chỉ manh mối
	reset_all()
	W.states["tue_linh"]["assets"] = {"linh_mach_tinh": 1, "xich_hoa_thach": 1}
	W.states["tue_linh"]["rel"] = 30
	W.bond("tue_linh")["trust"] = 20
	W.states["tue_linh"]["loc"] = "soi_linh"
	var e: Dictionary = main.events.spawn("yeu_thu_tinh_anh", 90, "soi_linh")
	e["state"] = "active"
	e["start"] = 90
	var inv_intent: Dictionary = W._intent("tue_linh", 100)
	var kind := str(inv_intent.get("kind", ""))
	check(kind == "invite_event" or kind == "share_tip", "thân thiết + hiếu kỳ: rủ đi hoặc chỉ manh mối (%s)" % kind)
	main.events.events.clear()
	var tip_loc := ""
	for lid in main.province.locations():
		if main.province.state_of(str(lid)) == World.UNKNOWN and not bool(main.province.info(str(lid)).get("hidden", false)):
			tip_loc = str(lid)
			break
	if tip_loc != "":
		W.states["tue_linh"]["seek"] = {"kind": "share_tip", "loc": tip_loc, "target": here, "arrive": 100, "since": 100, "arrived": true}
		W.states["tue_linh"]["loc"] = here
		W._seek_tip("tue_linh")
		main.dialogue.open = false
		check(main.province.state_of(tip_loc) != World.UNKNOWN, "chỉ manh mối: nơi đó thành tin đồn trong sổ")
	else:
		check(true, "(không còn nơi chưa biết để chỉ)")

	# --- chờ không gặp
	reset_all()
	W.states["luc_van"]["seek"] = {"kind": "share_tip", "loc": "x", "target": here, "arrive": 100, "since": 98, "arrived": true}
	W.states["luc_van"]["loc"] = here
	var trust0 := int(W.bond("luc_van").trust)
	W._seek_tick(106)
	check(W.seek_of("luc_van").is_empty() and int(W.bond("luc_van").trust) == trust0 - 2, "chờ quá lâu không gặp: bỏ về, hơi buồn")

	# --- giới hạn đồng thời & hồi
	reset_all()
	for id in ["luc_van", "ha_kiem", "tue_linh", "bach_tam"]:
		W.states[id]["rel"] = 40
		W.bond(id)["trust"] = 30
		W.bond(id)["debt"] = 40
		W.states[id]["loc"] = "van_khe"
	for dday in range(100, 106):
		W._initiatives(dday)
	var n_active := 0
	for id in W.roster():
		if not W.seek_of(str(id)).is_empty():
			n_active += 1
	check(n_active <= 2, "tối đa 2 NPC cùng đi tìm (%d)" % n_active)

	# --- lưu / tải
	W.states["luc_van"]["request"] = {"kind": "bring_material", "item": "truc_linh", "qty": 2, "reward": 90, "day": 100, "until": 112}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	check(not W2.request_of("luc_van").is_empty() and str(W2.request_of("luc_van")["item"]) == "truc_linh", "lưu/tải giữ lời nhờ đang dở")
	W2.free()

	print("NPC SEEK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
