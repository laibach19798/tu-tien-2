extends SceneTree
## Mô phỏng headless mọi tổ hợp Công–Tâm–Thân (+ pháp bảo) bằng đúng CombatResolver của V1.
## Mục tiêu: tìm tổ hợp thống trị / chết, và kiểm tra việc phối khác phái có chịu thiệt hay không.
## Chạy:  godot --headless --path . --script res://tools/build_sim.gd -- [rolled] [limit=N] [seed=N]
##   rolled : mỗi bí tịch có dòng phụ roll thật (mặc định: sạch, đo cơ chế thuần)
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
const State = preload("res://scripts/v1/progression.gd")
const Resolver = preload("res://scripts/v1/combat_resolver.gd")

const DT := 0.1
const STEP := 12            # Trúc Cơ tầng 4
const DURATION := 40.0
const SCENARIOS := ["single", "pack", "boss", "swarm"]
const ARTIFACTS := ["qi_pearl", "soul_bell", "nine_swords"]


class Sim extends RefCounted:
	var state
	var engine
	var rng := RandomNumberGenerator.new()
	var targets: Array = []
	var summons: Array = []
	var pending: Dictionary = {}
	var dash_left := 0.0
	var dash_age := 0.0
	var dodge_registered := false
	var interrupted := 0.0
	var dealt_total := 0.0
	var primary := "cong"
	var cast_slots: Array = []   # thứ tự ưu tiên tung chiêu; rỗng = chỉ nguồn chính (J) như trước khi có ô K/U
	var attributes: Dictionary
	var _next_id := 0
	var starved := 0     # số nhịp Công Pháp đã hồi chiêu xong nhưng thiếu linh lực
	var ready_ticks := 0

	func setup(p_state, scenario: String, seed_value: int) -> void:
		state = p_state
		primary = state.primary
		attributes = state.origin.attributes
		rng.seed = seed_value
		engine = Resolver.new()
		engine.progression = state
		var scale := Data.balance("attribute_scale")
		engine.max_qi = (100.0 + 40.0 * STEP) * (1.0 + (float(attributes.meridians) - 50.0) * scale)
		engine.qi = engine.max_qi
		engine.max_hp = (100.0 + 24.0 * STEP) * (1.0 + (float(attributes.constitution) - 50.0) * scale)
		engine.hp = engine.max_hp
		match scenario:
			"single":
				_spawn(Vector2(90, 0), 1.0e9, 0.0, 1.0)
			"pack":
				for i in 5:
					var a := TAU * i / 5.0
					_spawn(Vector2(90, 0) + Vector2(cos(a), sin(a)) * 55.0, 700.0, 0.0, 1.0)
			"boss":
				_spawn(Vector2(90, 0), 1.0e9, 22.0, 1.1)
			"swarm":
				for i in 3:
					var a := TAU * i / 3.0
					_spawn(Vector2(90, 0) + Vector2(cos(a), sin(a)) * 40.0, 350.0, 9.0, 1.0)
					targets[i].atk_t = 0.33 * i

	func _spawn(pos: Vector2, hp: float, atk: float, interval: float) -> void:
		_next_id += 1
		targets.append({"id": "t%d" % _next_id, "hp": hp, "max": hp, "pos": pos, "alive": true, "atk": atk, "int": interval, "atk_t": interval, "respawn": 0.0})

	func in_range(radius: float) -> Array:
		radius = minf(radius, Data.balance("sensing_range") * (1.0 + (float(attributes.awareness) - 50.0) * Data.balance("attribute_scale")))
		var out: Array = []
		for t in targets:
			if t.alive and (t.pos as Vector2).length() <= radius:
				out.append(t)
		out.sort_custom(func(a, b): return a.pos.length_squared() < b.pos.length_squared())
		return out

	func deal(target: Dictionary, base: float, ctx: Dictionary, summon := false, secondary := false) -> void:
		if not target.alive:
			return
		var critical := not secondary and rng.randf() < Data.balance("critical_chance")
		var amount := base
		if not secondary:
			amount *= 1.0 + Data.balance("realm_damage_per_step") * STEP
			amount *= engine.damage_multiplier(str(ctx.source_slot), str(target.id), summon) * (Data.balance("critical_multiplier") if critical else 1.0)
		var old: float = target.hp
		target.hp -= amount
		var done := minf(old, amount)
		dealt_total += done
		var killed: bool = target.hp <= 0.0
		if killed:
			target.alive = false
			target.respawn = 2.0
		engine.hit(str(target.id), done, ctx, killed, critical)

	func flush() -> void:
		var budget := int(Data.balance("chain_events"))
		while not engine.damage_requests.is_empty() and budget > 0:
			budget -= 1
			var req: Dictionary = engine.damage_requests.pop_front()
			for t in targets:
				if t.id == req.target:
					deal(t, float(req.amount), req.context, false, true)
		if budget <= 0:
			engine.damage_requests.clear()

	func execute(result: Dictionary) -> void:
		var d: Dictionary = result.definition
		var ctx: Dictionary = result.context
		if d.get("shape", "") == "summon":
			create_summon(ctx, d)
		else:
			var found := in_range(maxf(float(d.get("range", 125)), GrandFx.reach(d)))   # đại chiêu: vùng trúng = vùng hình ảnh (như runtime)
			var aim := Vector2.RIGHT
			if not found.is_empty():
				aim = (found[0].pos as Vector2).normalized()
			engine.emit_event("attack_started", ctx)
			var hits := 0
			for t in found:
				var toward: Vector2 = t.pos
				var shape := str(d.get("shape", "single"))
				var blast := GrandFx.impact_radius(d)
				var splash := false
				if shape in ["cone", "line"] and toward.normalized().dot(aim) < (0.5 if shape == "cone" else 0.92):
					if not (shape == "line" and blast > 0.0 and (t.pos as Vector2).distance_to(found[0].pos) <= blast):
						continue
					splash = true
				if shape == "single" and hits > 0:
					break
				if shape == "burst" and (t.pos as Vector2).distance_to(found[0].pos) > (blast if blast > 0.0 else 110.0):
					continue
				deal(t, float(d.get("damage", 20)) * (GrandFx.SPLASH_FALLOFF if splash else 1.0), ctx)
				hits += 1
		engine.completed(ctx)
		flush()

	func create_summon(ctx: Dictionary, definition: Dictionary) -> void:
		var child := ctx.duplicate(true)
		child.tags = ["summon", "artifact" if ctx.source_slot == "artifact" else "spell"]
		var fate: Dictionary = Data.data().fates[state.origin.fate]
		summons.append({"context": child, "definition": definition.duplicate(true), "remaining": float(definition.get("duration", 4)) + float(fate.get("summon_duration", 0)), "next": 0.0})
		engine.emit_event("summon_created", child)

	func try_cast(slot: String) -> bool:
		if float(engine.cooldowns[slot]) > 0.0 or state.def_for(slot).is_empty():
			return false
		if engine.qi < float(engine.cost(slot).actual):
			return false
		var result: Dictionary = engine.cast(slot)
		if not result.ok:
			return false
		if slot == "than":
			dash_left = Data.balance("dash_seconds")
			dash_age = 0.0
			dodge_registered = false
			engine.emit_event("dodge_attempted", result.context)
			engine.completed(result.context)
		else:
			var cast_time := float(result.definition.get("cast_time", 0))
			if cast_time > 0.0:
				pending = {"result": result, "remaining": cast_time}
			else:
				execute(result)
		return true

	## Một đòn của quái chạm người chơi.
	func incoming_hit(attacker: Dictionary) -> void:
		var id := str(attacker.id)
		if dash_left <= 0.0 and pending.is_empty() and interrupted <= 0.0 and rng.randf() < 0.7:
			# Phản xạ: bấm Thân Pháp; đòn rơi ngẫu nhiên trong 0,25s của cú lướt.
			var offset := rng.randf() * Data.balance("dash_seconds")
			if try_cast("than"):
				dash_age = offset
				dash_left = maxf(0.001, Data.balance("dash_seconds") - offset)
		if dash_left > 0.0:
			var window := Data.balance("dodge_window") * (1.0 + (float(attributes.agility) - 50.0) * Data.balance("attribute_scale"))
			if dash_age <= window and not dodge_registered:
				dodge_registered = true
				engine.emit_event("perfect_dodge", engine.context("than", ["movement"]), {"target": id})
			return
		var dealt: float = engine.incoming(float(attacker.atk), id)
		engine.hp -= dealt
		if not pending.is_empty() and not engine.has_status("player", "steadfast"):
			pending.clear()
			interrupted = Data.balance("interrupt_seconds") / (1.0 + (float(attributes.composure) - 25.0) * Data.balance("attribute_scale"))

	func run() -> Dictionary:
		var t := 0.0
		var alive_for := DURATION
		while t < DURATION:
			t += DT
			engine.qi = minf(engine.max_qi, engine.qi + Data.balance("qi_regen") * DT)
			engine.tick(DT)
			interrupted = maxf(0.0, interrupted - DT)
			if dash_left > 0.0:
				dash_left = maxf(0.0, dash_left - DT)
				dash_age += DT
				if dash_left <= 0.0:
					engine.emit_event("dodge_completed", engine.context("than", ["movement"]))
			if not pending.is_empty():
				pending.remaining = float(pending.remaining) - DT
				if pending.remaining <= 0.0:
					var res: Dictionary = pending.result
					pending = {}
					execute(res)
			for s in summons.duplicate():
				s.remaining = float(s.remaining) - DT
				s.next = float(s.next) - DT
				if s.remaining <= 0.0:
					summons.erase(s)
					continue
				if s.next <= 0.0:
					var fate: Dictionary = Data.data().fates[state.origin.fate]
					var upkeep := Data.balance("summon_upkeep") + float(fate.get("summon_upkeep", 0))
					if engine.qi < upkeep:
						summons.erase(s)
						continue
					engine.qi -= upkeep
					engine.emit_event("resource_spent", s.context, {"resource": "qi", "amount": upkeep, "skill_type": "summon"})
					s.next = Data.balance("summon_interval")
					var found := in_range(float(s.definition.get("range", 300)))
					if not found.is_empty():
						var dmg := float(s.definition.get("damage", 14))
						deal(found[0], dmg, s.context, true)
						if GrandFx.is_area_summon(s.definition):
							for extra in found.slice(1, GrandFx.SUMMON_MAX_TARGETS):
								deal(extra, dmg * GrandFx.SUMMON_FALLOFF, s.context, true)
			flush()
			# quái hồi sinh và tấn công
			for tg in targets:
				if not tg.alive:
					tg.respawn = float(tg.respawn) - DT
					if tg.respawn <= 0.0:
						tg.alive = true
						tg.hp = tg.max
						engine.statuses.erase(tg.id)
					continue
				if float(tg.atk) <= 0.0:
					continue
				var speed: float = float(Data.data().statuses.slow.slow) if engine.has_status(str(tg.id), "slow") else 1.0
				tg.atk_t = float(tg.atk_t) - DT * float(speed)
				if tg.atk_t <= 0.0:
					tg.atk_t = tg.int
					incoming_hit(tg)
			if engine.hp <= 0.0:
				alive_for = t
				break
			# người chơi: tung chiêu chính khi đủ điều kiện
			if pending.is_empty() and dash_left <= 0.0 and interrupted <= 0.0:
				if float(engine.cooldowns[primary]) <= 0.0 and not state.def_for(primary).is_empty():
					ready_ticks += 1
					if engine.qi < float(engine.cost(primary).actual):
						starved += 1
				if cast_slots.is_empty():
					try_cast(primary)
				else:
					for slot in cast_slots:
						if pending.is_empty() and dash_left <= 0.0:
							try_cast(str(slot))
		return {"dmg": dealt_total, "hp_frac": maxf(0.0, engine.hp) / engine.max_hp, "alive": alive_for, "starve": float(starved) / maxf(1.0, ready_ticks)}


var rolled := false
var fit := false
var multi := false
var limit := 0
var seed_base := 7


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "rolled":
			rolled = true
		elif a == "fit":
			fit = true
		elif a == "multi":
			multi = true
		elif a.begins_with("limit="):
			limit = int(a.substr(6))
		elif a.begins_with("seed="):
			seed_base = int(a.substr(5))
	call_deferred("run")


func make_state(cong: String, tam: String, than: String, artifact: String, primary: String, serial: int, cong2 := ""):
	var s = State.new()
	s.origin = Origin.sample()
	s.origin.confirmed = true
	s.seed_value = seed_base * 100003 + serial
	var quality := "linh" if rolled else "thuong"
	for id in [cong, tam, than, "iron_sword", "cloth_robe", artifact]:
		if id == "":
			continue
		var uid: String = s.acquire(id, "sim", quality)
		if not rolled:
			s.instances[uid].affixes = []
		s.learn(uid)
		s.equip(uid)
	if cong2 != "":
		var uid2: String = s.acquire(cong2, "sim", quality)
		if not rolled:
			s.instances[uid2].affixes = []
		s.learn(uid2)
		s.equip(uid2, "cong2")
	s.primary = primary
	return s


func score(r: Dictionary) -> float:
	return float(r.dmg) * (0.4 + 0.6 * float(r.hp_frac)) if float(r.alive) < DURATION or float(r.hp_frac) < 1.0 else float(r.dmg)


## Chế độ fit: chạy từng Công Pháp / pháp bảo chủ lực với các ô còn lại để trống, in điểm từng kịch bản để cân lại sát thương.
func run_fit() -> void:
	# Đường chuẩn: Thân Pháp "trần" (không hiệu ứng) để đo riêng Công Pháp, nhưng vẫn né được như người chơi thật.
	Data.definition("kiem_step").effects = []
	var entries: Array = []
	for b in Data.data().books:
		if b.slot == "cong":
			entries.append({"id": b.id, "cong": b.id, "art": "", "primary": "cong"})
	for e in Data.data().equipment:
		if e.slot == "artifact":
			entries.append({"id": e.id, "cong": "", "art": e.id, "primary": "artifact"})
	var res := {}
	var sums := {}
	for sc in SCENARIOS:
		sums[sc] = 0.0
	for i in entries.size():
		var en: Dictionary = entries[i]
		res[en.id] = {}
		for sc in SCENARIOS:
			var sim := Sim.new()
			sim.setup(make_state(en.cong, "", "kiem_step", en.art, en.primary, i), sc, i * 31 + 5)
			var r := sim.run()
			res[en.id][sc] = score(r)
			res[en.id][sc + "_starve"] = r.starve
			sums[sc] += res[en.id][sc]
	var out := {}
	for en in entries:
		var lg := 0.0
		for sc in SCENARIOS:
			lg += log(maxf(0.02, float(res[en.id][sc]) / (float(sums[sc]) / entries.size())))
		out[en.id] = exp(lg / SCENARIOS.size())
	print("FITJSON " + JSON.stringify({"overall": out, "raw": res}))
	quit(0)


## So sánh sức mạnh khi có ô K (pháp bảo) + U (Công phụ) so với chỉ J: cùng Tâm/Thân/pháp bảo, thêm một Công phụ.
func run_multi() -> void:
	var books := {"cong": [], "tam": [], "than": []}
	for b in Data.data().books:
		books[b.slot].append(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := limit if limit > 0 else 200
	var rows: Array = []
	var started := Time.get_ticks_msec()
	for i in n:
		var c: Dictionary = books.cong[rng.randi_range(0, books.cong.size() - 1)]
		var t: Dictionary = books.tam[rng.randi_range(0, books.tam.size() - 1)]
		var th: Dictionary = books.than[rng.randi_range(0, books.than.size() - 1)]
		var art: String = ARTIFACTS[rng.randi_range(0, ARTIFACTS.size() - 1)]
		var row := {"c": c.id, "t": t.id, "th": th.id, "art": art, "old": {}, "k_only": {}, "new_avg": {}, "new_best": {}}
		for sc in SCENARIOS:
			var sim := Sim.new()
			sim.setup(make_state(c.id, t.id, th.id, art, "cong", i), sc, i * 31 + 5)
			row.old[sc] = score(sim.run())
			# thêm K (pháp bảo) vào vòng tung chiêu
			var sk := Sim.new()
			sk.setup(make_state(c.id, t.id, th.id, art, "cong", i), sc, i * 31 + 5)
			sk.cast_slots = ["artifact", "cong"]
			row.k_only[sc] = score(sk.run())
			var sum := 0.0
			var best := 0.0
			var cnt := 0
			for c2 in books.cong:
				if c2.id == c.id:
					continue
				var sm := Sim.new()
				sm.setup(make_state(c.id, t.id, th.id, art, "cong", i, c2.id), sc, i * 31 + 5)
				sm.cast_slots = ["cong2", "artifact", "cong"]
				var v := score(sm.run())
				sum += v
				best = maxf(best, v)
				cnt += 1
			row.new_avg[sc] = sum / maxf(1, cnt)
			row.new_best[sc] = best
		rows.append(row)
	print("Đã mô phỏng %d tổ hợp trong %.1fs" % [n, (Time.get_ticks_msec() - started) / 1000.0])
	print("
== SỨC MẠNH TĂNG KHI THÊM Ô (tỉ lệ so với chỉ J, trung vị / p90 / max) ==")
	for key in ["k_only", "new_avg", "new_best"]:
		var label: String = {"k_only": "J + K (pháp bảo)", "new_avg": "J + K + U (Công phụ ngẫu nhiên)", "new_best": "J + K + U (chọn Công phụ tốt nhất)"}[key]
		for sc in SCENARIOS:
			var rs: Array = []
			for r in rows:
				rs.append(float(r[key][sc]) / maxf(1.0, float(r.old[sc])))
			rs.sort()
			print("%-38s %-6s x%.2f | p90 x%.2f | max x%.2f" % [label, sc, rs[rs.size() / 2], rs[int(0.9 * (rs.size() - 1))], rs[rs.size() - 1]])
	# phân bố điểm toàn cục: build mạnh nhất cũ so với build trung vị mới
	var olds: Array = []
	var news: Array = []
	for r in rows:
		var lo := 0.0
		var ln := 0.0
		for sc in SCENARIOS:
			lo += log(maxf(1.0, float(r.old[sc])))
			ln += log(maxf(1.0, float(r.new_best[sc])))
		olds.append(exp(lo / SCENARIOS.size()))
		news.append(exp(ln / SCENARIOS.size()))
	olds.sort()
	news.sort()
	print("
== ĐIỂM HÌNH HỌC (damage-score) ==")
	print("chỉ J    : p10 %.0f | p50 %.0f | p90 %.0f | max %.0f" % [pct(olds, 0.1), pct(olds, 0.5), pct(olds, 0.9), olds[olds.size() - 1]])
	print("J+K+U tốt: p10 %.0f | p50 %.0f | p90 %.0f | max %.0f" % [pct(news, 0.1), pct(news, 0.5), pct(news, 0.9), news[news.size() - 1]])
	print("trung vị mới / trung vị cũ = x%.2f ; trung vị mới / max cũ = x%.2f" % [pct(news, 0.5) / pct(olds, 0.5), pct(news, 0.5) / olds[olds.size() - 1]])
	# cặp Công phụ tốt nhất hay gặp
	var f := FileAccess.open("res://tools/build_sim_multi.csv", FileAccess.WRITE)
	f.store_line("cong,tam,than,art," + ",".join(SCENARIOS.map(func(x): return "old_" + x)) + "," + ",".join(SCENARIOS.map(func(x): return "k_" + x)) + "," + ",".join(SCENARIOS.map(func(x): return "best_" + x)))
	for r in rows:
		var parts: Array = [r.c, r.t, r.th, r.art]
		for key in ["old", "k_only", "new_best"]:
			for sc in SCENARIOS:
				parts.append("%.0f" % float(r[key][sc]))
		f.store_line(",".join(parts))
	quit(0)


func run() -> void:
	if multi:
		run_multi()
		return
	if fit:
		run_fit()
		return
	var books := {"cong": [], "tam": [], "than": []}
	for b in Data.data().books:
		books[b.slot].append(b)
	var builds: Array = []
	var serial := 0
	for art in ARTIFACTS:
		for c in books.cong:
			for t in books.tam:
				for th in books.than:
					builds.append({"cong": c.id, "tam": t.id, "than": th.id, "art": art, "primary": "cong", "serial": serial})
					serial += 1
		for t in books.tam:
			for th in books.than:   # Bảo Tu: pháp bảo là nguồn chính, không trang bị Công Pháp
				builds.append({"cong": "", "tam": t.id, "than": th.id, "art": art, "primary": "artifact", "serial": serial})
				serial += 1
	if limit > 0 and limit < builds.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var sample: Array = []
		for i in limit:
			sample.append(builds[rng.randi_range(0, builds.size() - 1)])
		builds = sample
	var started := Time.get_ticks_msec()
	var rows: Array = []
	for b in builds:
		var row := {"b": b, "s": {}}
		for sc in SCENARIOS:
			var sim := Sim.new()
			sim.setup(make_state(b.cong, b.tam, b.than, b.art, b.primary, int(b.serial)), sc, int(b.serial) * 31 + 5)
			row.s[sc] = score(sim.run())
			row["hp_" + sc] = sim.engine.hp / sim.engine.max_hp
		rows.append(row)
	print("Đã mô phỏng %d tổ hợp x %d kịch bản trong %.1fs (%s)" % [rows.size(), SCENARIOS.size(), (Time.get_ticks_msec() - started) / 1000.0, "dòng phụ roll thật" if rolled else "dòng phụ sạch"])
	report(rows)
	quit(0)


func median(a: Array) -> float:
	var c := a.duplicate()
	c.sort()
	return float(c[c.size() / 2])


func pct(sorted: Array, p: float) -> float:
	return float(sorted[clampi(int(p * (sorted.size() - 1)), 0, sorted.size() - 1)])


func report(rows: Array) -> void:
	var med := {}
	for sc in SCENARIOS:
		var vals: Array = []
		for r in rows:
			vals.append(r.s[sc])
		med[sc] = maxf(1.0, median(vals))
	for r in rows:
		var lg := 0.0
		for sc in SCENARIOS:
			lg += log(maxf(0.02, float(r.s[sc]) / float(med[sc])))
		r["overall"] = exp(lg / SCENARIOS.size())
	rows.sort_custom(func(a, b): return a.overall > b.overall)
	var overall: Array = []
	for r in rows:
		overall.append(r.overall)
	var asc := overall.duplicate()
	asc.sort()
	print("\n== PHÂN BỐ (điểm tổng hợp, 1.00 = trung vị) ==")
	print("min %.2f | p10 %.2f | p50 %.2f | p90 %.2f | p99 %.2f | max %.2f" % [asc[0], pct(asc, 0.1), pct(asc, 0.5), pct(asc, 0.9), pct(asc, 0.99), asc[asc.size() - 1]])
	var dead := 0
	var weak := 0
	for v in asc:
		if v < 0.5:
			dead += 1
		if v < 0.75:
			weak += 1
	print("tổ hợp < 0.50: %d (%.1f%%) | < 0.75: %d (%.1f%%)" % [dead, 100.0 * dead / asc.size(), weak, 100.0 * weak / asc.size()])
	print("trung vị từng kịch bản:", med)
	print("\n== TOP 12 ==")
	for i in mini(12, rows.size()):
		print(fmt(rows[i], med))
	print("\n== BOTTOM 8 ==")
	for i in 8:
		print(fmt(rows[rows.size() - 1 - i], med))
	# thống kê theo từng bí tịch
	print("\n== THEO BÍ TỊCH: điểm TB | chiếm trong top 5%% | chiếm trong bottom 20%% ==")
	var top_n := maxi(1, rows.size() / 20)
	var low_n := maxi(1, rows.size() / 5)
	var stats := {}
	for i in rows.size():
		var b: Dictionary = rows[i].b
		for key in ["cong", "tam", "than", "art"]:
			var id := str(b[key])
			if id == "":
				id = "(bảo tu)"
			if not stats.has(id):
				stats[id] = {"sum": 0.0, "n": 0, "top": 0, "low": 0}
			stats[id].sum += rows[i].overall
			stats[id].n += 1
			if i < top_n:
				stats[id].top += 1
			if i >= rows.size() - low_n:
				stats[id].low += 1
	var ids := stats.keys()
	ids.sort_custom(func(a, b): return stats[a].sum / stats[a].n > stats[b].sum / stats[b].n)
	for id in ids:
		var st: Dictionary = stats[id]
		var d := Data.definition(str(id))
		print("%-14s %-20s TB %.2f | top %5.1f%% | bottom %5.1f%%" % [id, str(d.get("name", "")), st.sum / st.n, 100.0 * st.top / maxi(1, st.n), 100.0 * st.low / maxi(1, st.n)])
	# phối cùng phái hay khác phái
	var same := []
	var cross := []
	for r in rows:
		if r.b.cong == "":
			continue
		var s1: String = Data.definition(r.b.cong).sect
		var s2: String = Data.definition(r.b.tam).sect
		var s3: String = Data.definition(r.b.than).sect
		(same if s1 == s2 and s2 == s3 else cross).append(r.overall)
	print("\n== CÙNG PHÁI vs KHÁC PHÁI ==")
	print("cùng phái: %d tổ hợp, TB %.3f | khác phái: %d tổ hợp, TB %.3f" % [same.size(), avg(same), cross.size(), avg(cross)])
	# tâm pháp: biên độ giữa phối tốt nhất và tệ nhất (phụ thuộc cao = ghép cứng)
	print("\n== TÂM PHÁP: điểm khi ghép với từng Công Pháp (min / max, hệ số) ==")
	var by_tam := {}
	for r in rows:
		if r.b.cong == "":
			continue
		var key := str(r.b.tam)
		if not by_tam.has(key):
			by_tam[key] = {}
		var ck := str(r.b.cong)
		by_tam[key][ck] = by_tam[key].get(ck, []) + [r.overall]
	for tam in by_tam:
		var means: Array = []
		for ck in by_tam[tam]:
			means.append(avg(by_tam[tam][ck]))
		means.sort()
		print("%-14s %-22s min %.2f | max %.2f | max/min %.2f" % [tam, Data.definition(tam).name, means[0], means[means.size() - 1], means[means.size() - 1] / maxf(0.01, means[0])])
	# CSV
	var f := FileAccess.open("res://tools/build_sim_%s.csv" % ("rolled" if rolled else "base"), FileAccess.WRITE)
	f.store_line("cong,tam,than,artifact,primary,overall," + ",".join(SCENARIOS))
	for r in rows:
		var parts: Array = [r.b.cong, r.b.tam, r.b.than, r.b.art, r.b.primary, "%.3f" % r.overall]
		for sc in SCENARIOS:
			parts.append("%.0f" % r.s[sc])
		f.store_line(",".join(parts))


func avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, a.size())


func fmt(r: Dictionary, med: Dictionary) -> String:
	var b: Dictionary = r.b
	var parts: Array = []
	for sc in SCENARIOS:
		parts.append("%s %.2f" % [sc, float(r.s[sc]) / float(med[sc])])
	return "%.2f | %s + %s + %s | %s | %s" % [r.overall, b.cong if b.cong != "" else "(bảo tu)", b.tam, b.than, b.art, "  ".join(parts)]
