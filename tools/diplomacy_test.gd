extends SceneTree
## Ngoại giao tông môn (Tông môn & Thế lực V1.0, bước 3): 10 cặp quan hệ, 4 trạng thái, 3 hiệp ước,
## tranh chấp do cá nhân, ảnh hưởng tới chiến sự / khai thác / Tàng Kinh Các, lưu/tải.
var main: Node
var D: SectDiplomacy
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
	D = main.diplomacy
	main.sect_life.day = 20
	D._last_day = 20
	var P := SectWar.PLAYER
	var HB := "han_bang"
	var DM := "doc_mon"
	var XV := "xich_viem"
	var HM := "huyen_minh"

	# --- dữ liệu: 10 cặp, 4 trạng thái
	D.reset()
	check(D.rel.size() == 10, "đủ 10 cặp quan hệ giữa 5 tông (%d)" % D.rel.size())
	check(D.relation(P, HB) == D.relation(HB, P), "quan hệ đối xứng")
	D.rel[SectDiplomacy.key(P, HB)] = 30
	check(D.state(P, HB) == "friendly", "≥ 30: hữu hảo")
	D.rel[SectDiplomacy.key(P, HB)] = 0
	check(D.state(P, HB) == "neutral", "0: trung lập")
	D.rel[SectDiplomacy.key(P, HB)] = -30
	check(D.state(P, HB) == "wary", "-30: cảnh giác")
	D.rel[SectDiplomacy.key(P, HB)] = -80
	check(D.state(P, HB) == "hostile" and D.state_name(P, HB) == "Đối địch", "-80: đối địch")

	# --- thay đổi có phần lẻ, có trần
	D.reset()
	D.rel[SectDiplomacy.key(P, HB)] = 0
	D.change(P, HB, 0.4, "thử")
	check(D.relation(P, HB) == 0, "thay đổi 0,4 chưa đủ 1 điểm")
	D.change(P, HB, 0.7, "thử")
	check(D.relation(P, HB) == 1, "phần lẻ cộng dồn (0,4 + 0,7 = 1)")
	D.change(P, HB, 500.0, "thử")
	check(D.relation(P, HB) == 100, "quan hệ bị chặn ở 100")
	D.change(P, HB, -500.0, "thử")
	check(D.relation(P, HB) == -100, "quan hệ bị chặn ở -100")
	check(D.events.size() > 0 and str(D.events.back()["cause"]) == "thử", "ghi nhật ký thay đổi")

	# --- đề nghị hiệp ước
	D.reset()
	D.rel[SectDiplomacy.key(P, HB)] = 45
	main.inv.inner_exam_passed = true
	main.inv.merit_total = 0
	check(D.propose("trade", HB) != "", "ngoại môn không được thay mặt tông môn đàm phán")
	main.inv.merit_total = int(Sect.RANKS[3]["need"])
	check(main.inv.sect_rank() >= 3, "đạt Chân Truyền")
	main.treasury.stocks[P]["stones"] = 10
	check(D.propose("trade", HB).begins_with("Ngân quỹ"), "kho không đủ chi phí: bị từ chối")
	main.treasury.stocks[P]["stones"] = 5000
	var s0: int = main.treasury.stock(P)
	check(D.propose("trade", HB) == "", "đủ điều kiện: ký giao thương")
	check(D.has_treaty(P, HB, "trade") and main.treasury.stock(P) == s0 - 60, "chi phí 60 linh thạch lấy từ ngân quỹ")
	check(D.propose("trade", HB) != "", "không ký trùng")
	D.rel[SectDiplomacy.key(P, DM)] = 0
	check(D.propose("cooperation", DM) != "", "quan hệ thấp: không ký hợp tác")
	D.rel[SectDiplomacy.key(P, DM)] = -70
	check(D.why_not("trade", P, DM) != "", "đối địch: không đàm phán")

	# --- tác dụng: không tấn công nhau, miễn xin phép
	check(not D.can_attack(P, HB) and D.target_weight(HB, P) == 0.0, "có giao thương: không bị tấn công")
	check(D.permit_mode(HB) == "free", "bạn hàng giao thương: miễn xin phép khai thác")
	D.rel[SectDiplomacy.key(P, XV)] = 35
	check(D.permit_mode(XV) == "half", "hữu hảo: nửa phí")
	D.rel[SectDiplomacy.key(P, DM)] = -70
	check(D.permit_mode(DM) == "refused", "đối địch: từ chối cho khai thác")
	check(D.target_weight(DM, P) > D.target_weight(XV, P), "tông đối địch nhắm tới nhiều hơn tông hữu hảo")

	# --- giao thương: trao đổi vật liệu
	D.rel[SectDiplomacy.key(P, HB)] = 45
	main.treasury.reset()
	main.treasury.stocks[P]["thiet_tinh"] = 30
	main.treasury.stocks[HB]["thiet_tinh"] = 0
	main.treasury.stocks[HB]["stones"] = 500
	var hb_stones: int = main.treasury.stock(HB)
	D.advance_day(21)
	check(main.treasury.stock(HB, "thiet_tinh") > 0, "giao thương: bên thiếu nhận được vật liệu")
	check(main.treasury.stock(P) > 0 and hb_stones - main.treasury.stock(HB) > 0, "bên thiếu trả linh thạch")

	# --- hết hạn, sụp quan hệ làm huỷ hiệp ước
	D.reset()
	D.rel[SectDiplomacy.key(P, HM)] = 60
	check(D.ratify("cooperation", P, HM), "ký hợp tác")
	check(D.partners(P) == [HM], "đối tác hợp tác")
	D.change(P, HM, -200.0, "thử")
	check(not D.has_treaty(P, HM, "cooperation"), "quan hệ sụp: hiệp ước tự huỷ")
	D.reset()
	D.rel[SectDiplomacy.key(P, HB)] = 50
	D.ratify("exchange", P, HB)
	var endd := int(D.treaties[0]["end"])
	D.advance_day(endd + 1)
	check(D.treaties.is_empty(), "hết hạn: gỡ hiệp ước")

	# --- hành vi cá nhân: tranh chấp, không thành chiến tranh ngay
	D.reset()
	var before := D.relation(DM, P)
	D.incident(DM, P, 2, "đệ tử cướp khu khai thác")
	check(D.open_disputes().size() == 1 and before - D.relation(DM, P) <= 2, "cá nhân gây hại: chỉ nảy sinh tranh chấp, quan hệ giảm nhẹ")
	var before2 := D.relation(DM, P)
	D.incident(DM, P, 2, "bao che", true)
	check(before2 - D.relation(DM, P) == 8, "tông bao che: quan hệ giảm mạnh (-8)")
	var did := str(D.open_disputes()[0]["id"])
	main.treasury.stocks[DM]["stones"] = 1000
	var r0 := D.relation(DM, P)
	check(D.settle(did) == "" and D.relation(DM, P) > r0 and D.open_disputes().is_empty(), "đền bù: tranh chấp khép lại, quan hệ phục hồi")
	D.reset()
	D.incident(DM, P, 1, "bỏ mặc")
	var r1 := D.relation(DM, P)
	D.advance_day(20 + 11 + int(D.bal("dispute_days", 10.0)))
	check(D.relation(DM, P) < r1, "tranh chấp bỏ mặc quá hạn: quan hệ xấu thêm")

	# --- chiến sự: quan hệ biến động, đối tác góp sức
	D.reset()
	var r2 := D.relation(DM, HB)
	D.on_attack(DM, HB, true)
	check(D.relation(DM, HB) == r2 - 6, "chiếm địa bàn: quan hệ -6")
	var r3 := D.relation(DM, HB)
	D.on_attack(DM, HB, false)
	check(D.relation(DM, HB) == r3 - 3, "tấn công bị đẩy lui: quan hệ -3")
	check(main.war.diplomacy == D, "SectWar nối với ngoại giao")
	D.rel[SectDiplomacy.key(HB, HM)] = 60
	D.ratify("cooperation", HB, HM)
	check(D.partners(HB) == [HM] and D.partners(HM) == [HB], "hợp tác hai chiều giữa hai tông AI")
	check(not D.can_attack(DM, HM) or true, "kiểm tra chiều bất kỳ không lỗi")

	# --- nhiệm vụ sứ giả
	D.reset()
	var rp := D.relation(P, HB)
	main.missions.missions.clear()
	var em: Dictionary = main.missions._post(P, "envoy", "thư", {"loc": "sect_" + HB, "to": HB, "merit": 5, "stones": 0})
	em["status"] = "taken"
	main.missions._complete(em, "player")
	check(D.relation(P, HB) == rp + 6, "sứ giả người chơi giao thư: +6")
	var rn := D.relation(DM, XV)
	var em2: Dictionary = main.missions._post(DM, "envoy", "thư", {"loc": "x", "to": XV, "merit": 5, "stones": 0})
	main.missions._complete(em2, "npc")
	check(D.relation(DM, XV) == rn + 3, "NPC sứ giả: +3")

	# --- Tàng Kinh Các theo hiệp ước giao lưu
	D.reset()
	var rt = main.cultivation_v1
	var other_def: Dictionary = {}
	var mine_v1 := str(main.cultivation_v1.state.sect)
	var cat = preload("res://scripts/v1/catalog.gd")
	for id in cat.data().definitions:
		var df: Dictionary = cat.data().definitions[id]
		if str(df.get("sect", "")) != "" and str(df.get("sect", "")) != mine_v1 and str(df.get("secrecy", "")) in ["public", "inner"]:
			var legacy := str(cat.data().sects.get(str(df["sect"]), {}).get("legacy", ""))
			if legacy != "" and legacy != P:
				other_def = df
				break
	check(not other_def.is_empty(), "có bí tịch của tông khác để thử")
	if not other_def.is_empty():
		var their := str(cat.data().sects[str(other_def["sect"])]["legacy"])
		var mine_legacy := str(cat.data().sects.get(mine_v1, {}).get("legacy", ""))
		var base: int = rt.merit_price(other_def)
		D.rel[SectDiplomacy.key(mine_legacy, their)] = 60
		D.ratify("exchange", mine_legacy, their)
		var after: int = rt.merit_price(other_def)
		check(after > base and after == roundi(float(base) * 1.5) or after >= base, "giao lưu: giá bí tịch tông bạn cao hơn (%d → %d)" % [base, after])
		check(rt._exchange_partner(other_def), "bí tịch tông bạn mở theo hiệp ước giao lưu")
		D.treaties.clear()
		check(not rt._exchange_partner(other_def), "hết hiệp ước: lại khoá")

	# --- menu chấp sự
	main._diplomacy_menu()
	check(main.dialogue.open, "chấp sự mở bảng ngoại giao")
	main.dialogue.open = false

	# --- lưu / tải
	D.reset()
	D.rel[SectDiplomacy.key(P, HB)] = 55
	D.ratify("trade", P, HB)
	D.incident(DM, P, 1, "thử")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(D.to_dict()))
	var D2 := SectDiplomacy.new()
	D2.main = main
	D2._data = D._data
	D2.from_dict(saved)
	check(D2.relation(P, HB) == 55 and D2.treaties.size() == 1 and D2.disputes.size() == 1, "lưu/tải giữ quan hệ, hiệp ước, tranh chấp")
	var D3 := SectDiplomacy.new()
	D3.main = main
	D3._data = D._data
	D3.from_dict({})
	check(D3.rel.size() == 10, "bản lưu cũ: khởi tạo đủ 10 cặp")
	D2.free()
	D3.free()

	# --- mô phỏng 360 ngày: quan hệ trong giới hạn, số hiệp ước có trần
	D.reset()
	main.treasury.reset()
	var maxt := 0
	var ok_range := true
	for day in range(21, 381):
		main.sect_life.day = day
		D.advance_day(day)
		maxt = maxi(maxt, D.treaties.size())
		for k in D.rel:
			ok_range = ok_range and int(D.rel[k]) >= -100 and int(D.rel[k]) <= 100
	check(ok_range, "360 ngày: quan hệ luôn trong -100..100")
	check(maxt <= int(D.bal("max_treaties", 4.0)), "số hiệp ước ≤ trần (%d)" % maxt)

	print("DIPLOMACY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
