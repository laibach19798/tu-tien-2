extends SceneTree
## NPC thông minh V1 bước 4: tu vi, đột phá, đổi bí tịch / trang bị, truyền thừa, lưu/tải, mô phỏng 360 ngày.
const Data = preload("res://scripts/v1/catalog.gd")
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
	W._profiles.erase(id)


func legal_all(id: String) -> bool:
	var p = W.profile_of(id)
	var d: Dictionary = W.def_of(id)
	var sect := NpcProfile.sect_of(d)
	var step := W.step_of(id)
	var elder: bool = bool(d.get("elder", false)) or step >= 25
	for slot in p.equipped:
		var uid: String = str(p.equipped[slot])
		if uid == "":
			continue
		var def: Dictionary = Data.definition(str(p.instances[uid].definition))
		var src := str(p.instances[uid].source)
		if src != "legacy" and not NpcProfile.legal(def, sect, step, elder):
			return false
	return true


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	main.sect_life.day = 50

	# --- công thức
	check(NpcGrowth.xp_need(10) > NpcGrowth.xp_need(5) and NpcGrowth.break_cost(10) > NpcGrowth.break_cost(5), "bậc cao: cần nhiều tu vi và linh thạch hơn")
	check(NpcGrowth.break_chance(70.0, 5) > NpcGrowth.break_chance(30.0, 5), "Ngộ Tính cao đột phá dễ hơn")
	check(NpcGrowth.break_chance(50.0, 8) < NpcGrowth.break_chance(50.0, 3), "bậc lên cảnh giới lớn khó hơn")
	check(NpcGrowth.xp_gain("cultivate", 50.0) > NpcGrowth.xp_gain("rest", 50.0) * 4.0, "tu luyện tích tu vi nhanh hơn nghỉ rất nhiều")

	# --- đột phá thành công / thiếu tiền
	fresh("luc_van")
	var s0 := W.step_of("luc_van")
	W.states["luc_van"]["xp"] = NpcGrowth.xp_need(s0) + 1.0
	W.states["luc_van"]["money"] = 0
	W._try_breakthrough("luc_van", 50)
	check(W.step_of("luc_van") == s0, "đủ tu vi nhưng thiếu linh thạch: chờ, chưa đột phá")
	var found_ok := false
	var found_fail := false
	for dday in range(51, 200):
		fresh("luc_van")
		W.states["luc_van"]["xp"] = NpcGrowth.xp_need(s0) + 10.0
		W.states["luc_van"]["money"] = 500
		W._try_breakthrough("luc_van", dday)
		var st: Dictionary = W.states["luc_van"]
		if W.step_of("luc_van") == s0 + 1 and not found_ok:
			found_ok = true
			check(int(st["money"]) == 500 - NpcGrowth.break_cost(s0) and float(st["xp"]) < NpcGrowth.xp_need(s0), "đột phá thành công: trừ linh thạch và tu vi")
			var dev_log: Array = W.develop_log("luc_van")
			check(not dev_log.is_empty() and str(dev_log.back()["kind"]) == "breakthrough", "đột phá được ghi vào nhật ký phát triển")
		if W.step_of("luc_van") == s0 and not found_fail and str(st["status"]) == "injured":
			found_fail = true
			check(int(st["money"]) == 500 - NpcGrowth.break_cost(s0) and float(st["xp"]) < NpcGrowth.xp_need(s0) + 10.0, "đột phá thất bại: vẫn mất linh thạch, mất tu vi, bị thương")
		if found_ok and found_fail:
			break
	check(found_ok and found_fail, "cả hai kết cục (thành công / thất bại) đều xảy ra")

	# --- trần cảnh giới
	fresh("luc_van")
	W.states["luc_van"]["step"] = W.step_cap("luc_van")
	W.states["luc_van"]["xp"] = 99999.0
	W.states["luc_van"]["money"] = 99999
	W._try_breakthrough("luc_van", 60)
	check(W.step_of("luc_van") == W.step_cap("luc_van"), "không vượt quá trần cảnh giới")

	# --- mua bí tịch hợp luật, có lý do, trừ tiền
	fresh("vu_nguyet")
	var p = W.profile_of("vu_nguyet")
	var money0 := 5000
	W.states["vu_nguyet"]["money"] = money0
	W.states["vu_nguyet"]["traits"]["curiosity"] = 100
	var books_before: int = p.instances.size()
	var changed := false
	for dday in range(60, 120, 7):
		W.states["vu_nguyet"]["last_change"] = -99
		W._consider_growth("vu_nguyet", dday)
		if p.instances.size() > books_before:
			changed = true
			break
	check(changed and int(W.states["vu_nguyet"]["money"]) < money0, "NPC đủ tiền cân nhắc rồi mua bí tịch mới (trừ linh thạch)")
	check(legal_all("vu_nguyet"), "bộ pháp sau khi đổi vẫn hợp luật V1")
	var dlog: Array = W.develop_log("vu_nguyet")
	check(not dlog.is_empty() and str(dlog.back()["text"]).contains("vì"), "đổi bí tịch có lý do: " + (str(dlog.back()["text"]) if not dlog.is_empty() else ""))
	check(str(W.states["vu_nguyet"]["v1"]["instances"].size()) != "0" and W.states["vu_nguyet"]["v1"]["instances"].size() == p.instances.size(), "hồ sơ lưu đã cập nhật")

	# --- không đủ tiền thì không mua
	fresh("tran_hoai")
	W.states["tran_hoai"]["money"] = 5
	var p2 = W.profile_of("tran_hoai")
	var n2: int = p2.instances.size()
	for dday in range(60, 120, 7):
		W.states["tran_hoai"]["last_change"] = -99
		W._consider_growth("tran_hoai", dday)
	check(p2.instances.size() == n2 and int(W.states["tran_hoai"]["money"]) == 5, "không đủ linh thạch: không đổi gì")

	# --- truyền thừa: đủ cảnh giới thì lĩnh ngộ, chưa đủ thì giữ chờ
	fresh("quan_dao")
	var dp_id := ""
	for k in main.destiny.dong_phu():
		dp_id = str(k)
		break
	var uid := W.ensure_legacy(dp_id)
	W.transfer(uid, W.owner_of(uid), "npc:quan_dao", "thử nghiệm")
	var book := str(main.destiny.dong_phu()[dp_id].get("legacy", {}).get("book", ""))
	var need: int = int(Data.definition(book).get("need", 0))
	W.states["quan_dao"]["step"] = maxi(0, need - 1)
	W.states["quan_dao"]["last_change"] = -99
	var pq = W.profile_of("quan_dao")
	var nq: int = pq.instances.size()
	W._consider_growth("quan_dao", 70)
	check(pq.instances.size() == nq or need <= 0, "chưa đủ cảnh giới: giữ truyền thừa, chưa lĩnh ngộ")
	W.states["quan_dao"]["step"] = need + 2
	W.states["quan_dao"]["last_change"] = -99
	W._consider_growth("quan_dao", 71)
	check(uid in W.states["quan_dao"]["learned_unique"] and pq.instances.size() == nq + 1, "đủ cảnh giới: lĩnh ngộ truyền thừa (bí tịch vào hồ sơ)")
	check(W.owner_of(uid) == "npc:quan_dao", "quyền sở hữu truyền thừa vẫn là NPC (không nhân bản)")

	# --- lưu / tải
	fresh("han_phong")
	W.states["han_phong"]["step"] = 14
	W.states["han_phong"]["xp"] = 77.0
	W._log_dev("han_phong", 50, "book", "thử nghiệm", false)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(saved)
	check(W2.step_of("han_phong") == 14 and is_equal_approx(W2.xp_of("han_phong"), 77.0) and W2.develop_log("han_phong").size() == 1, "lưu/tải giữ cảnh giới, tu vi, nhật ký phát triển")
	var old: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	for id in old["states"]:
		for k in ["step", "xp", "develop", "last_change", "learned_unique"]:
			(old["states"][id] as Dictionary).erase(k)
	var W3 := NpcWorld.new()
	W3.main = main
	W3._data = W._data
	W3.from_dict(old)
	check(W3.step_of("luc_van") == int(W.def_of("luc_van").get("step", 0)) and W3.xp_of("luc_van") == 0.0, "bản lưu cũ: lấy cảnh giới theo dữ liệu")
	W2.free()
	W3.free()

	# --- mô phỏng 360 ngày
	var ids: Array = W.agent_ids()
	for id in ids:
		W.states[str(id)] = W._fresh_state(str(id))
		W._profiles.erase(str(id))
	var start := {}
	for id in ids:
		start[str(id)] = W.step_of(str(id))
	for day in range(100, 461):
		main.sect_life.day = day
		W._advance_day(day)
	var gains: Array = []
	var changes := 0
	var breakthroughs := 0
	var fails := 0
	var legal_ok := true
	var over_cap := false
	for id in ids:
		var g := W.step_of(str(id)) - int(start[str(id)])
		gains.append(g)
		var stats: Dictionary = W.states[str(id)]["stats"]
		breakthroughs += int(stats.get("breakthrough", 0))
		fails += int(stats.get("break_failed", 0))
		changes += int(stats.get("learned", 0)) + int(stats.get("gear", 0))
		legal_ok = legal_ok and legal_all(str(id))
		over_cap = over_cap or W.step_of(str(id)) > W.step_cap(str(id))
	var avg := 0.0
	for g in gains:
		avg += float(g)
	avg /= float(gains.size())
	print("360 ngày: lên bậc TB %.1f (đột phá %d, thất bại %d), đổi bí tịch/trang bị %d" % [avg, breakthroughs, fails, changes])
	check(avg >= 0.5 and avg <= 8.0, "tốc độ lên bậc hợp lý sau 1 năm game (TB %.1f)" % avg)
	check(not over_cap and legal_ok, "không ai vượt trần, bộ pháp luôn hợp luật")
	check(breakthroughs >= 3, "có người đột phá thật (%d)" % breakthroughs)

	print("NPC GROWTH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
