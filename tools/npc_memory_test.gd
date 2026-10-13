extends SceneTree
## NPC thông minh V1 bước 2: quan hệ 4 chỉ số (+ sợ hãi), ký ức, phai nhạt, tính cách lệch phản ứng, hội thoại phản ứng theo quan hệ.
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


func fresh(id: String) -> void:
	W.states[id] = W._fresh_state(id)


func opts_text() -> Array:
	var out: Array = []
	for o in main.dialogue._opts:
		out.append(str(o["text"]))
	return out


func has_opt(prefix: String) -> bool:
	for t in opts_text():
		if str(t).begins_with(prefix):
			return true
	return false


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
	main.sect_life.day = 40

	# --- trạng thái và 4 chỉ số
	fresh("luc_van")
	var b: Dictionary = W.bond("luc_van")
	check(b.size() == 5 and int(b.affinity) == 0 and int(b.trust) == 0 and int(b.debt) == 0 and int(b.hate) == 0 and int(b.fear) == 0, "quan hệ khởi đầu: 5 chỉ số đều 0")
	W.states["luc_van"]["rel"] = 12
	check(int(W.bond("luc_van").affinity) == 12, "thiện cảm chính là `rel` cũ (các hệ thống cũ vẫn ghi vào đó)")

	# --- cứu giúp: tính cách lệch ân nghĩa
	fresh("luc_van")
	fresh("quan_dao")
	var d1: Dictionary = W.record("luc_van", "rescue")
	var d2: Dictionary = W.record("quan_dao", "rescue")
	check(int(d1.debt) > int(d2.debt), "người trọng nghĩa (Lục Vân) mang ơn nặng hơn kẻ thực dụng (Quan Đạo): %d > %d" % [int(d1.debt), int(d2.debt)])
	check(int(W.bond("luc_van").debt) == int(d1.debt) and int(W.states["luc_van"]["rel"]) == int(d1.affinity), "thay đổi đã ghi vào chỉ số (kể cả `rel`)")
	var mem: Array = W.memories_of("luc_van")
	check(mem.size() == 1 and int(mem[0].imp) == 3 and str(mem[0].kind) == "rescue" and int(mem[0].day) == 40, "cứu mạng: ký ức quan trọng, ghi ngày")
	check(NpcBonds.words("debt", int(W.bond("luc_van").debt)) != "", "mô tả bằng lời: " + W.bond_text("luc_van"))

	# --- đe doạ / cướp: thù hận, sợ hãi, tín nhiệm
	fresh("quan_dao")
	fresh("tailor")
	var r1: Dictionary = W.record("quan_dao", "robbed")
	var r2: Dictionary = W.record("tailor", "robbed")
	check(int(r1.hate) > int(r2.hate), "kẻ hiếu chiến (Quan Đạo) ôm hận mạnh hơn người hiền (Tô Nương): %d > %d" % [int(r1.hate), int(r2.hate)])
	check(int(W.bond("quan_dao").trust) < 0 and int(W.bond("quan_dao").affinity) < 0, "bị cướp: mất tín nhiệm và thiện cảm")
	var t1: Dictionary = W.record("quan_dao", "threat")
	var t2: Dictionary = W.record("tailor", "threat")
	check(int(t2.fear) > int(t1.fear), "người nhút nhát sợ hơn kẻ hiếu chiến khi bị đe doạ: %d > %d" % [int(t2.fear), int(t1.fear)])

	# --- giá và việc có chịu bán
	fresh("quan_dao")
	var base_price: float = W.price_mult("quan_dao")
	W.record("quan_dao", "robbed")
	check(W.price_mult("quan_dao") > base_price, "thù hận làm giá đắt hơn")
	check(W.will_trade("quan_dao") or int(W.bond("quan_dao").hate) < 60, "chưa thù sâu thì vẫn bán")
	W.record("quan_dao", "robbed")
	check(int(W.bond("quan_dao").hate) >= 60 and not W.will_trade("quan_dao"), "thù sâu và hiếu chiến: không bán cho người chơi")
	W.states["quan_dao"]["assets"] = {"linh_thao": 2}
	main.inv.stones = 999
	var stones_before: int = main.inv.stones
	W._buy("quan_dao", "linh_thao")
	check(main.inv.stones == stones_before and int(W.states["quan_dao"]["assets"]["linh_thao"]) == 2, "bị từ chối: không mất tiền, NPC không mất hàng")
	main.dialogue.open = false
	fresh("luc_van")
	var neutral: float = W.price_mult("luc_van")
	W.record("luc_van", "rescue")
	W.record("luc_van", "help")
	check(W.price_mult("luc_van") < neutral, "ân nhân được giá tốt hơn")

	# --- phai nhạt
	fresh("quan_dao")
	W.record("quan_dao", "threat")
	W.record("quan_dao", "rescue")
	var hate0: int = int(W.bond("quan_dao").hate)
	var fear0: int = int(W.bond("quan_dao").fear)
	var debt0: int = int(W.bond("quan_dao").debt)
	var trust0: int = int(W.bond("quan_dao").trust)
	W.states["quan_dao"]["last_wrong"] = 40
	for dday in range(41, 91):
		W._decay_bonds("quan_dao", dday)
	check(int(W.bond("quan_dao").hate) < hate0 and int(W.bond("quan_dao").fear) < fear0, "thù hận và sợ hãi phai dần theo ngày")
	check(int(W.bond("quan_dao").debt) == debt0 and int(W.bond("quan_dao").trust) == trust0, "ân nghĩa và tín nhiệm không tự phai")
	var h1: int = int(W.bond("quan_dao").hate)
	W.states["quan_dao"]["last_wrong"] = 90
	for dday in range(91, 99):
		W._decay_bonds("quan_dao", dday)
	check(int(W.bond("quan_dao").hate) == h1, "vừa có việc xấu mới thì thù hận chưa phai")

	# --- ký ức: giới hạn, phai ký ức thường, giữ ký ức quan trọng
	fresh("luc_van")
	W.record("luc_van", "rescue")
	for i in 30:
		W.record("luc_van", "chat")
	var mems: Array = W.memories_of("luc_van")
	var kept_rescue := false
	for m in mems:
		kept_rescue = kept_rescue or str(m.kind) == "rescue"
	check(mems.size() <= 16 and kept_rescue, "ký ức có giới hạn (%d) và giữ ký ức cứu mạng" % mems.size())
	fresh("luc_van")
	W.record("luc_van", "chat")
	W.record("luc_van", "gift")
	main.sect_life.day = 90
	W.record("luc_van", "chat")
	var kinds: Array = []
	for m in W.memories_of("luc_van"):
		kinds.append(str(m.kind))
	check(kinds.count("chat") == 1 and kinds.has("gift"), "ký ức thường quá 30 ngày bị quên, ký ức quan trọng còn")
	main.sect_life.day = 40

	# --- hệ thống cũ ghi qua ký ức
	fresh("luc_van")
	W.states["luc_van"]["talk_day"] = 0
	W._ask_news("luc_van")
	main.dialogue.open = false
	check(int(W.states["luc_van"]["rel"]) == 1 and str(W.memories_of("luc_van").back().kind) == "chat", "hỏi thăm tin: +1 thiện cảm và ghi ký ức")
	fresh("phu_quy")
	W.states["phu_quy"]["assets"] = {"linh_thao": 3}
	main.inv.stones = 500
	W._buy("phu_quy", "linh_thao")
	check(str(W.memories_of("phu_quy").back().kind) == "trade" and int(W.bond("phu_quy").trust) >= 1, "mua hàng: thiện cảm và tín nhiệm tăng, ghi ký ức")
	fresh("luc_van")
	var ev = main.events
	ev._adjust_rel("luc_van", 6)
	check(int(W.states["luc_van"]["rel"]) == 6 and W.memories_of("luc_van").size() == 1, "sự kiện thế giới chỉnh thiện cảm cũng để lại ký ức")

	# --- hội thoại phản ứng theo quan hệ
	fresh("luc_van")
	W.states["luc_van"]["status"] = "injured"
	talk_to("luc_van")
	check(has_opt("Nhắc chuyện cũ") and not has_opt("Đưa "), "bị thương nhưng không có đan: chưa có lựa chọn cứu giúp")
	main.dialogue.open = false
	main.inv.add("dan_hoi_huyet", 1)
	talk_to("luc_van")
	check(has_opt("Đưa "), "bị thương và có đan: có lựa chọn cứu giúp")
	main.dialogue.open = false
	var pills: int = main.inv.count("dan_hoi_huyet")
	W._rescue("luc_van")
	main.dialogue.open = false
	check(str(W.states["luc_van"]["status"]) == "ok" and main.inv.count("dan_hoi_huyet") == pills - 1, "cứu giúp: NPC khỏi thương, mất một viên đan")
	check(int(W.bond("luc_van").debt) >= 15 and W.memories_of("luc_van").back().kind == "rescue", "cứu giúp: NPC mắc ơn và ghi nhớ")
	talk_to("luc_van")
	check(has_opt("Nhận lời báo đáp"), "mắc ơn + trọng nghĩa: có lời báo đáp")
	main.dialogue.open = false
	var debt_before: int = int(W.bond("luc_van").debt)
	var worth_before: int = int(W.states["luc_van"]["money"])
	for k in W.states["luc_van"]["assets"]:
		worth_before += int(W.states["luc_van"]["assets"][k])
	var inv_before: int = main.inv.stones
	W._repay("luc_van")
	main.dialogue.open = false
	var worth_after: int = int(W.states["luc_van"]["money"])
	for k in W.states["luc_van"]["assets"]:
		worth_after += int(W.states["luc_van"]["assets"][k])
	check(int(W.bond("luc_van").debt) < debt_before and worth_after < worth_before, "báo đáp: ân nghĩa giảm, NPC thực sự mất đi một thứ (không sinh vật phẩm hư không)")
	talk_to("luc_van")
	check(not has_opt("Nhận lời báo đáp"), "vừa báo đáp xong: 10 ngày sau mới báo đáp lần nữa")
	main.dialogue.open = false
	fresh("quan_dao")
	W.states["quan_dao"]["assets"] = {"linh_thao": 2}
	W.record("quan_dao", "robbed")
	W.record("quan_dao", "robbed")
	talk_to("quan_dao")
	var buy_ok := false
	for t in opts_text():
		buy_ok = buy_ok or str(t).begins_with("Mua ")
	check(not buy_ok, "kẻ thù sâu: không còn lựa chọn mua hàng")
	main.dialogue.open = false
	W._recall("quan_dao")
	check(main.dialogue.open, "nhắc chuyện cũ: NPC kể lại ký ức")
	main.dialogue.open = false

	# --- lưu / tải
	fresh("luc_van")
	W.record("luc_van", "rescue")
	W.record("luc_van", "chat")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	var m1: Array = W.memories_of("luc_van")
	var m2: Array = W2.memories_of("luc_van")
	check(m2.size() == m1.size() and int(W2.bond("luc_van").debt) == int(W.bond("luc_van").debt) and int(W2.states["luc_van"]["rel"]) == int(W.states["luc_van"]["rel"]), "lưu/tải giữ nguyên quan hệ và ký ức")
	var old: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	for id in old["states"]:
		(old["states"][id] as Dictionary).erase("bonds")
		(old["states"][id] as Dictionary).erase("memory")
	var W3 := NpcWorld.new()
	W3.main = main
	W3._data = W._data
	W3.from_dict(old)
	check(W3.bond("luc_van").size() == 5 and W3.memories_of("luc_van").is_empty(), "bản lưu cũ chưa có ký ức: tự bổ sung")
	W2.free()
	W3.free()

	print("NPC MEMORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
