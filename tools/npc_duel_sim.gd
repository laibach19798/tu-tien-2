extends SceneTree
## Cân bằng đối thủ NPC có tên (NpcCombat) so với người chơi cùng cảnh giới.
## Mô hình giải tích dùng ĐÚNG số liệu thật của đối thủ (máu, sát thương, chiêu, hồi chiêu, thủ pháp) và sức mạnh người chơi
## lấy từ kết quả build_sim (DPS đơn mục tiêu một Công Pháp ở bậc 12 = DPS12, co giãn theo realm_damage_per_step).
## R = (thời gian người chơi sống) / (thời gian người chơi cần để hạ NPC). R > 1: người chơi thắng.
## Chạy: godot --headless --path . --script res://tools/npc_duel_sim.gd
const TARGET_LO := 1.0       # mục tiêu: cùng cảnh giới R trung bình trong khoảng này, khó nhưng thắng được
const TARGET_HI := 2.2
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


func player_hp(step: int) -> float:
	return NpcCombat.player_hp(step)


func player_dps(step: int) -> float:
	return NpcCombat.player_dps(step)


## Chỉ số đối thủ thật + DPS ước lượng của nó lên người chơi.
func npc_numbers(id: String) -> Dictionary:
	var m := NpcCombat.spawn(main, id, Vector2.ZERO)
	var skill_dps := 0.0
	for d in m.get_meta("npc_skills", []):
		var amount := m.damage * m.dmg_mult() * clampf(float(d.get("damage", MonsterBehaviors.SKILL_DMG_REF)) / MonsterBehaviors.SKILL_DMG_REF, 0.8, 2.5)
		var cd := maxf(float(d.get("cooldown", 1.0)) * MonsterBehaviors.SKILL_CD_K, MonsterBehaviors.SKILL_CD_MIN)
		skill_dps += amount / cd
	var melee := m.damage / (float(m.kind["windup"]) + float(m.kind["recover"]))
	var df: Dictionary = m.get_meta("npc_defense", {})
	var out := {
		"hp": m.max_hp, "melee": melee, "skill": skill_dps, "guard": float(df.get("guard", 0.0)), "dodge": float(df.get("dodge", 0.0)),
		"heal": float(df.get("heal", 0.0)),
		"has_skills": not (m.get_meta("npc_skills", []) as Array).is_empty(),
	}
	m.free()
	return out


func ratio(n: Dictionary, player_step: int) -> float:
	var eff_hp: float = float(n["hp"]) / maxf(0.05, (1.0 - float(n["guard"])) * (1.0 - float(n["dodge"])))
	eff_hp *= 1.0 + float(n["heal"]) * 2.0
	var ttk_player := eff_hp / player_dps(player_step)
	var dps_npc: float = float(n["melee"]) * NpcCombat.MELEE_FRACTION * (1.0 - NpcCombat.MELEE_DODGE) + float(n["skill"]) * NpcCombat.SKILL_UPTIME * (1.0 - NpcCombat.PLAYER_DODGE)
	var survive := player_hp(player_step) / maxf(dps_npc, 0.01)
	return survive / ttk_player


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var W: NpcWorld = main.npc_world
	var ids: Array = W.agent_ids()
	var rows: Array = []
	print("%-18s %4s %7s %7s %7s %5s | R(cùng bậc) R(-6) R(+6)" % ["NPC", "bậc", "máu", "cận", "chiêu", "thủ"])
	var eq_all: Array = []
	var low_all: Array = []
	var hi_all: Array = []
	for id in ids:
		var step := W.step_of(str(id))
		var n := npc_numbers(str(id))
		var r_eq := ratio(n, step)
		var r_lo := ratio(n, maxi(0, step - 6))
		var r_hi := ratio(n, step + 6)
		eq_all.append(r_eq)
		low_all.append(r_lo)
		hi_all.append(r_hi)
		rows.append([str(id), step, r_eq])
		print("%-18s %4d %7.0f %7.1f %7.1f %4.0f%% | %6.2f %6.2f %6.2f" % [W.display_name(str(id)), step, float(n["hp"]), float(n["melee"]), float(n["skill"]), (float(n["guard"]) + float(n["dodge"])) * 100.0, r_eq, r_lo, r_hi])
	var avg := func(a: Array) -> float:
		var t := 0.0
		for x in a:
			t += float(x)
		return t / maxf(1.0, float(a.size()))
	var mn := 999.0
	var mx := 0.0
	for r in eq_all:
		mn = minf(mn, float(r))
		mx = maxf(mx, float(r))
	print("Trung bình R: cùng bậc %.2f · thấp hơn 6 bậc %.2f · cao hơn 6 bậc %.2f | min %.2f max %.2f" % [avg.call(eq_all), avg.call(low_all), avg.call(hi_all), mn, mx])
	check(avg.call(eq_all) >= TARGET_LO and avg.call(eq_all) <= TARGET_HI, "cùng cảnh giới: người chơi thắng được nhưng không dễ (R TB %.2f trong %.1f–%.1f)" % [avg.call(eq_all), TARGET_LO, TARGET_HI])
	check(mn >= 0.5 and mx <= 4.0, "không NPC nào quá khó hoặc quá dễ so với cùng bậc (min %.2f, max %.2f)" % [mn, mx])
	check(avg.call(low_all) < avg.call(eq_all) and avg.call(low_all) < 1.0, "thấp hơn 6 bậc: bất lợi rõ rệt (R TB %.2f)" % avg.call(low_all))
	check(avg.call(hi_all) > avg.call(eq_all), "cao hơn 6 bậc: dễ hơn (R TB %.2f)" % avg.call(hi_all))
	print("NPC DUEL SIM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
