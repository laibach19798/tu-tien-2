extends SceneTree
## Bộ pháp V1 của NPC → chiến đấu thật: chiêu, thủ pháp, lối đánh, chỉ số, giao đấu (đòi nợ / cướp), không thưởng cày.
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


func names_of(m: Monster) -> Array:
	var out: Array = []
	for d in m.get_meta("npc_skills", []):
		out.append(str(d.get("id", "")))
	return out


func clear_monsters() -> void:
	for m in main.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	main.monsters.clear()
	W._duels.clear()


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	main.sect_life.day = 100
	main.player.position = Vector2(1280, 900)
	main.cult.realm = 3
	main.cult.layer = 5

	# --- dựng đối thủ từ hồ sơ V1
	var m1 := NpcCombat.spawn(main, "vu_nguyet", main.player.position + Vector2(200, 0))
	var prog1 = W.profile_of("vu_nguyet")
	var want1: Array = []
	for slot in ["cong", "cong2", "artifact"]:
		var d: Dictionary = prog1.def_for(slot)
		if not d.is_empty() and d.has("shape") and int(d.get("need", 0)) <= W.step_of("vu_nguyet") and d.get("shape", "") != "summon":
			want1.append(str(d["id"]))
	check(m1 != null and names_of(m1) == want1 and not want1.is_empty(), "chiêu NPC tung đúng Công/Công phụ/Pháp bảo của hồ sơ V1 (%s)" % str(want1))
	check("skills" in m1.behaviors and m1.display_name == "Vũ Nguyệt", "mang tên và hành vi tung chiêu")
	check(str(m1.outfit) == str(W.def_of("vu_nguyet")["outfit"]), "mặc đúng trang phục")
	check(m1.minion and not m1.elite, "trận giao đấu: không thưởng, không tinh anh")

	# --- chiêu theo bộ pháp, không phải khuôn chung
	var m2 := NpcCombat.spawn(main, "luc_van", main.player.position)
	var m3 := NpcCombat.spawn(main, "tue_linh", main.player.position)
	check(names_of(m1) != names_of(m2) or names_of(m2) != names_of(m3), "các NPC khác nhau dùng chiêu khác nhau (%s | %s | %s)" % [str(names_of(m1)), str(names_of(m2)), str(names_of(m3))])

	# --- chỉ số theo cảnh giới
	var strong := NpcCombat.spawn(main, "mac_tran", main.player.position)   # cảnh giới 25
	var weak := NpcCombat.spawn(main, "phu_quy", main.player.position)       # cảnh giới 6
	check(strong != null and weak != null and strong.max_hp > weak.max_hp * 1.5 and strong.damage > weak.damage, "cảnh giới cao: nhiều máu và sát thương hơn (%.0f vs %.0f)" % [strong.max_hp, weak.max_hp])

	# --- thủ pháp: né / đỡ
	var mm := NpcCombat.spawn(main, "luc_van", main.player.position)
	mm.set_meta("npc_defense", {"guard": 0.2, "dodge": 0.0, "heal": 0.0})
	check(is_equal_approx(MonsterBehaviors.incoming(mm, 100.0), 80.0), "đỡ đòn: giảm 20% sát thương")
	mm.set_meta("npc_defense", {"guard": 0.0, "dodge": 1.0, "heal": 0.0})
	check(MonsterBehaviors.incoming(mm, 100.0) == 0.0, "né đòn: không nhận sát thương")
	for id in ["luc_van", "ha_kiem", "vu_nguyet", "tue_linh", "thach_lao"]:
		var df: Dictionary = NpcCombat.defenses_of(W.profile_of(id))
		check(float(df.guard) <= NpcCombat.MAX_GUARD and float(df.dodge) <= NpcCombat.MAX_DODGE and float(df.heal) <= NpcCombat.MAX_HEAL, "thủ pháp %s trong giới hạn" % id)

	# --- lối đánh → hành vi
	var styles := {}
	for id in ["luc_van", "ha_kiem", "vu_nguyet", "tue_linh", "quan_dao", "thuy_dao", "doc_cuong"]:
		var mx := NpcCombat.spawn(main, id, main.player.position)
		styles[str(mx.get_meta("npc_style"))] = true
		var want: Array = NpcCombat.STYLE_BEHAVIORS[str(mx.get_meta("npc_style"))]
		var ok := true
		for b in want:
			ok = ok and b in mx.behaviors
		check(ok, "lối đánh %s → hành vi %s" % [str(mx.get_meta("npc_style")), str(want)])
	check(styles.size() >= 2, "nhiều lối đánh khác nhau")

	# --- tung chiêu thật gây sát thương lên người chơi
	var fighter := NpcCombat.spawn(main, "vu_nguyet", main.player.position + Vector2(60, 0))
	main.world.add_child(fighter)
	main.monsters.append(fighter)
	fighter.state = "chase"
	var skills: Array = fighter.get_meta("npc_skills", [])
	check(not skills.is_empty(), "đối thủ có chiêu")
	var cast_ok := false
	main.vitals.hp = main.vitals.max_hp
	for i in 30:
		fighter.position = main.player.position + Vector2(50, 0)
		fighter._bt.clear()
		var to_p: Vector2 = main.player.position - fighter.position
		if MonsterBehaviors._skill_hook(fighter, to_p, to_p.length()):
			cast_ok = true
			break
	check(cast_ok and str(fighter._bt.get("cast", "")) == "skill", "AI chọn và dựng dấu báo cho chiêu của NPC")
	var hp0: float = main.vitals.hp
	main.vitals.invuln = 0
	fighter.position = main.player.position + Vector2(40, 0)
	fighter._bt["dir"] = (main.player.position - fighter.position).normalized()
	for i in 6:
		MonsterBehaviors._cast_skill(fighter)
		if main.vitals.hp < hp0:
			break
		main.vitals.invuln = 0
	check(main.vitals.hp < hp0, "chiêu của NPC trúng người chơi: mất khí huyết (%.0f → %.0f)" % [hp0, main.vitals.hp])
	clear_monsters()

	# --- đứng trong khu an toàn của làng: đối thủ vẫn lao vào đánh (lỗi "NPC không đánh lại")
	main.player.position = Vector2(1280, 900)
	check(main.is_safe(main.player.position), "người chơi đang đứng trong khu an toàn của làng")
	main.vitals.hp = main.vitals.max_hp
	main.vitals.invuln = 0
	W.states["vu_nguyet"] = W._fresh_state("vu_nguyet")
	check(W.start_duel("vu_nguyet", "debug"), "dựng trận ngay giữa làng")
	var villager: Monster = W._duels["vu_nguyet"]
	var hp_start: float = main.vitals.hp
	var started_cast := false
	for i in 400:
		await physics_frame
		if villager.state in ["cast", "windup"]:
			started_cast = true
		if main.vitals.hp < hp_start:
			break
	check(started_cast and main.vitals.hp < hp_start, "đối thủ trong làng chủ động đánh người chơi (%.0f → %.0f)" % [hp_start, main.vitals.hp])
	clear_monsters()
	main.vitals.hp = main.vitals.max_hp

	# --- giao đấu: đòi nợ
	main.vitals.hp = main.vitals.max_hp
	W.states["quan_dao"] = W._fresh_state("quan_dao")
	W.record("quan_dao", "robbed")
	W.record("quan_dao", "robbed")
	var hate0 := int(W.bond("quan_dao").hate)
	var stones0: int = main.inv.stones
	W.states["quan_dao"]["seek"] = {"kind": "revenge_demand", "stones": 50, "target": "van_khe", "arrive": 100, "since": 100, "arrived": true}
	W._seek_fight("quan_dao")
	main.dialogue.open = false
	check(W.duel_active("quan_dao"), "đòi nợ → trận giao đấu thật")
	var duelist: Monster = W._duels["quan_dao"]
	check(duelist in main.monsters and duelist.get_meta("npc_id") == "quan_dao", "đối thủ có mặt trong cảnh với đúng danh tính")
	check(not W.start_duel("luc_van", "rob"), "chỉ một trận một lúc")
	duelist.set_meta("npc_defense", {})
	duelist.take_hit(duelist.max_hp * 5.0, main.player.position)
	check(not duelist.alive, "hạ được đối thủ")
	check(not W.duel_active("quan_dao") and str(W.states["quan_dao"]["status"]) == "injured", "thắng: NPC bị thương, về nhà dưỡng")
	check(int(W.bond("quan_dao").hate) < hate0 and int(W.bond("quan_dao").fear) >= 20, "thù hận giảm, NPC sợ hơn")
	check(main.inv.stones == stones0, "giao đấu không thưởng linh thạch (không cày được)")
	clear_monsters()

	# --- cướp thất bại → giao đấu; thắng thì lấy được đồ
	W.states["ngo_thanh"] = W._fresh_state("ngo_thanh")
	W.states["ngo_thanh"]["assets"] = {"linh_thao": 3, "yeu_dan": 1}
	W.states["ngo_thanh"]["step"] = 40
	W.states["ngo_thanh"]["loc"] = "van_khe"
	var items0: int = main.inv.count("linh_thao") + main.inv.count("yeu_dan")
	var res := {}
	for dday in range(100, 160):
		main.sect_life.day = dday
		res = W.rob("ngo_thanh")
		main.dialogue.open = false
		if bool(res.get("duel", false)):
			break
		clear_monsters()
		W.states["ngo_thanh"]["assets"] = {"linh_thao": 3, "yeu_dan": 1}
	check(bool(res.get("duel", false)) and W.duel_active("ngo_thanh"), "cướp NPC mạnh hơn: thất bại thì NPC rút binh khí giao đấu thật")
	var d2: Monster = W._duels["ngo_thanh"]
	check(main.inv.count("linh_thao") + main.inv.count("yeu_dan") == items0, "đồ chưa bị lấy khi còn đang đánh")
	d2.set_meta("npc_defense", {})
	d2.take_hit(d2.max_hp * 5.0, main.player.position)
	check(main.inv.count("linh_thao") + main.inv.count("yeu_dan") > items0, "thắng trận: lấy được hành trang")
	clear_monsters()

	# --- dọn trận bị bỏ
	W.states["luc_van"] = W._fresh_state("luc_van")
	check(W.start_duel("luc_van", "revenge"), "dựng trận mới")
	var orphan: Monster = W._duels["luc_van"]
	main.monsters.erase(orphan)
	orphan.free()
	W._duel_tick(101)
	check(not W.duel_active("luc_van") and not W.states["luc_van"].has("duel"), "đối thủ biến mất (rời map): trận được dọn")

	# --- ở Tiểu Thế Giới (chiến sự) không dựng trận
	main.current_map = "tieu_gioi"
	main.map_def = Maps.DEFS["tieu_gioi"]
	check(not W.start_duel("luc_van", "revenge"), "bản đồ chiến sự: không giao đấu cá nhân")
	main.current_map = "overworld"

	print("NPC COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
