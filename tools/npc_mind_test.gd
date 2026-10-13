extends SceneTree
## NPC thông minh V1 bước 3: quyết định theo tính cách / mục tiêu / nhu cầu / rủi ro / hiểu biết (NpcMind + NpcWorld._plan).
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


func ctx(over := {}) -> Dictionary:
	var c := {
		"traits": {"ambition": 50, "greed": 50, "righteous": 50, "caution": 50, "aggression": 50, "curiosity": 50},
		"prior": 0.3, "strength": 3, "danger": 3, "money_need": 0.5, "holding": 0, "goal": "wealth",
		"place_has_need": false, "injured_days": 999, "streak": 0,
	}
	for k in over:
		c[k] = over[k]
	return c


func trt(over: Dictionary) -> Dictionary:
	var t := {"ambition": 50, "greed": 50, "righteous": 50, "caution": 50, "aggression": 50, "curiosity": 50}
	for k in over:
		t[k] = over[k]
	return t


func u(act: String, over := {}) -> float:
	return float(NpcMind.utility(act, ctx(over))["u"])


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	main.sect_life.day = 30

	# --- hàm chấm điểm: đơn điệu theo từng yếu tố
	check(u("hunt", {"traits": trt({"aggression": 90})}) > u("hunt", {"traits": trt({"aggression": 10})}), "hiếu chiến cao: muốn săn hơn")
	check(u("gather", {"traits": trt({"caution": 90}), "danger": 5}) < u("gather", {"traits": trt({"caution": 10}), "danger": 5}), "thận trọng cao: ngại nơi nguy hiểm hơn")
	check(u("hunt", {"danger": 5, "strength": 2}) < u("hunt", {"danger": 2, "strength": 2}), "nơi nguy hiểm hơn sức: giảm hứng thú")
	check(u("trade", {"holding": 4, "money_need": 0.9}) > u("trade", {"holding": 4, "money_need": 0.0}), "thiếu tiền: muốn bán hàng hơn")
	check(float(NpcMind.utility("trade", ctx({"holding": 0}))["u"]) < 0.0, "không có hàng thì không bán được")
	check(u("rest", {"injured_days": 1}) > u("rest", {"injured_days": 999}), "vừa bị thương: muốn nghỉ hơn")
	check(u("hunt", {"injured_days": 1}) < u("hunt", {"injured_days": 999}), "vừa bị thương: ngại đi săn")
	check(u("cultivate", {"traits": trt({"ambition": 90}), "goal": "breakthrough"}) > u("cultivate", {"traits": trt({"ambition": 10}), "goal": "wealth"}), "tham vọng và mục tiêu đột phá: muốn tu luyện hơn")
	check(u("cultivate", {"money_need": 1.0}) < u("cultivate", {"money_need": 0.0}), "đang thiếu thốn: bớt tu luyện")
	check(u("gather", {"place_has_need": true}) > u("gather", {"place_has_need": false}), "nơi có thứ mình cần: hấp dẫn hơn")
	check(u("gather", {"streak": 3}) < u("gather", {"streak": 0}), "đi đi lại lại một nơi: bớt hứng")
	check(u("event", {"traits": trt({"curiosity": 90, "greed": 80})}) > u("event", {"traits": trt({"curiosity": 10, "greed": 10})}), "hiếu kỳ + tham lam: chạy theo sự kiện")
	check(u("event", {"traits": trt({"righteous": 90}), "righteous_help": true}) > u("event", {"traits": trt({"righteous": 90}), "righteous_help": false}), "trọng nghĩa: đi giúp người gặp nạn")
	var why: String = NpcMind.reasons(NpcMind.utility("hunt", ctx({"traits": trt({"aggression": 95}), "money_need": 1.0, "goal": "mastery"}))["parts"])
	check(why != "" and why.contains("hiếu chiến"), "giải thích lý do chọn (%s)" % why)

	# --- chọn: tất định, nhưng không luôn tối ưu
	var cands := [
		{"act": "hunt", "loc": "a", "ctx": ctx({"traits": trt({"aggression": 80})})},
		{"act": "rest", "loc": "b", "ctx": ctx()},
		{"act": "gather", "loc": "c", "ctx": ctx()},
	]
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var p1: Dictionary = NpcMind.choose(cands, r1)
	var p2: Dictionary = NpcMind.choose(cands, r2)
	check(str(p1["act"]) == str(p2["act"]) and str(p1["loc"]) == str(p2["loc"]), "cùng hạt giống: cùng lựa chọn")
	var counts := {}
	for i in 300:
		var rr := RandomNumberGenerator.new()
		rr.seed = i + 1
		var pk: Dictionary = NpcMind.choose(cands, rr)
		counts[str(pk["act"])] = int(counts.get(str(pk["act"]), 0)) + 1
	var best_act := ""
	var best_u := -INF
	for c in cands:
		var uu := float(NpcMind.utility(str(c["act"]), c["ctx"])["u"])
		if uu > best_u:
			best_u = uu
			best_act = str(c["act"])
	check(int(counts.get(best_act, 0)) > 150 and counts.size() >= 2, "nghiêng về lựa chọn tốt nhất (%s) nhưng đôi khi chọn khác (%s)" % [best_act, str(counts)])

	# --- hai NPC khác tính cách, cùng tình huống → xu hướng khác nhau
	var bold_c := [
		{"act": "hunt", "loc": "x", "ctx": ctx({"traits": trt({"aggression": 90, "caution": 10, "ambition": 80}), "danger": 4, "strength": 3, "prior": 0.2})},
		{"act": "rest", "loc": "h", "ctx": ctx({"traits": trt({"aggression": 90, "caution": 10, "ambition": 80}), "prior": 0.2})},
		{"act": "gather", "loc": "g", "ctx": ctx({"traits": trt({"aggression": 90, "caution": 10, "ambition": 80}), "danger": 4, "strength": 3, "prior": 0.2})},
	]
	var shy_c := [
		{"act": "hunt", "loc": "x", "ctx": ctx({"traits": trt({"aggression": 10, "caution": 90, "ambition": 20}), "danger": 4, "strength": 3, "prior": 0.2})},
		{"act": "rest", "loc": "h", "ctx": ctx({"traits": trt({"aggression": 10, "caution": 90, "ambition": 20}), "prior": 0.2})},
		{"act": "gather", "loc": "g", "ctx": ctx({"traits": trt({"aggression": 10, "caution": 90, "ambition": 20}), "danger": 4, "strength": 3, "prior": 0.2})},
	]
	var bold_hunt := 0
	var shy_hunt := 0
	for i in 400:
		var rb := RandomNumberGenerator.new()
		rb.seed = i + 7
		if str(NpcMind.choose(bold_c, rb)["act"]) == "hunt":
			bold_hunt += 1
		var rs := RandomNumberGenerator.new()
		rs.seed = i + 7
		if str(NpcMind.choose(shy_c, rs)["act"]) == "hunt":
			shy_hunt += 1
	check(bold_hunt > shy_hunt * 2 and bold_hunt > 120, "kẻ liều đi săn nơi nguy hiểm nhiều hơn người nhát (%d vs %d / 400)" % [bold_hunt, shy_hunt])

	# --- trong thế giới: lập kế hoạch từ dữ liệu thật
	var ids: Array = W.agent_ids()
	var known_ok := true
	var why_ok := true
	var acts := {}
	for id in ids:
		var st: Dictionary = W.states[str(id)]
		st["status"] = "ok"
		st["until"] = 0
		for day in range(30, 60):
			W._plan(str(id), day)
			acts[str(st["act"])] = true
			var loc := str(st["loc"])
			known_ok = known_ok and (loc in W.known_places(str(id)) or str(st["act"]) == "event")
			why_ok = why_ok and str(st.get("why", "")) != ""
	check(known_ok, "NPC chỉ đi tới nơi họ biết (hoặc sự kiện họ nghe tin)")
	check(why_ok, "mỗi quyết định đều có lý do ghi lại")
	check(acts.size() >= 4, "đa dạng hoạt động (%s)" % str(acts.keys()))
	var lv := "luc_van"
	var found_need := false
	var tally := {}
	for day in range(30, 130):
		W.states[lv]["status"] = "ok"
		W._plan(lv, day)
		if str(W.states[lv]["act"]) == "gather":
			tally[str(W.states[lv]["loc"])] = int(tally.get(str(W.states[lv]["loc"]), 0)) + 1
	var best_loc := ""
	var best_n := -1
	for l in tally:
		if int(tally[l]) > best_n:
			best_n = int(tally[l])
			best_loc = str(l)
	for n in W.def_of(lv).get("needs", []):
		found_need = found_need or str(n) in W.materials_at(best_loc)
	check(found_need, "Lục Vân cần thiết tinh/trúc linh: hay đi nơi có (%s: %s)" % [best_loc, str(tally)])
	check(NpcMind.GOAL_NAMES.has(W.goal_kind("quan_dao")) and W.goal_kind("luc_van") == "craft", "mỗi NPC có mục tiêu thuộc loại đã định")

	# --- sự kiện: chỉ biết sau khi tin lan ra và trong vùng quen
	var ev = main.events
	ev.events.clear()
	var e: Dictionary = ev.spawn("yeu_thu_tinh_anh", 30, "soi_linh")
	e["state"] = "active"
	check(W.known_events("ha_kiem", 30).is_empty(), "sự kiện vừa xảy ra: chưa ai kịp nghe")
	check(not W.known_events("ha_kiem", 31).is_empty() or main.province.info("soi_linh").get("map", "") not in [main.province.info("hac_lam").get("map", "")], "sau 1 ngày: NPC quen vùng đó nghe tin")
	var far := W.known_events("tailor", 31)
	var tailor_maps := {}
	for l in W.known_places("tailor"):
		tailor_maps[str(main.province.info(str(l)).get("map", ""))] = true
	check(far.is_empty() == (not tailor_maps.has(str(main.province.info("soi_linh").get("map", "")))), "NPC chưa từng tới vùng đó thì không biết sự kiện")
	ev.events.clear()

	# --- mô phỏng 360 ngày: không sụp đổ
	var total_trips := 0
	var total_inj := 0
	var rest_days := 0
	var days_n := 0
	main.sect_life.day = 100
	for id in ids:
		W.states[str(id)] = W._fresh_state(str(id))
	for day in range(101, 461):
		main.sect_life.day = day
		W._advance_day(day)
	var act_totals := {"gather": 0, "hunt": 0, "trade": 0, "cultivate": 0}
	for id in ids:
		var s: Dictionary = W.states[str(id)]["stats"]
		total_trips += int(s.get("trips", 0))
		total_inj += int(s.get("injured", 0))
		act_totals["cultivate"] += int(s.get("cultivate", 0))
	var rate := float(total_inj) / maxf(1.0, float(total_trips))
	print("360 ngày: chuyến %d, bị thương %d (%.0f%%), tu luyện %d" % [total_trips, total_inj, rate * 100.0, int(act_totals["cultivate"])])
	check(total_trips >= 60, "NPC vẫn hoạt động đều (%d chuyến)" % total_trips)
	check(rate <= 0.18, "tỉ lệ bị thương hợp lý (%.0f%%)" % (rate * 100.0))
	var earned := 0
	var someone_rich := false
	for id in ids:
		earned += int(W.states[str(id)]["stats"].get("earned", 0))
	check(earned > 0, "vẫn có giao dịch kiếm tiền (%d linh thạch)" % earned)

	# --- lưu/tải giữ lý do và nơi cuối
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	var same := true
	for id in ids:
		same = same and str(W2.states[str(id)].get("why", "")) == str(W.states[str(id)].get("why", ""))
	check(same, "lưu/tải giữ lý do quyết định")
	W2.free()

	print("NPC MIND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
