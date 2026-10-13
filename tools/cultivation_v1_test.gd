extends SceneTree
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
const State = preload("res://scripts/v1/progression.gd")
const Resolver = preload("res://scripts/v1/combat_resolver.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)

func clean_item(state, id: String) -> String:
	var uid: String = state.acquire(id,"test")
	state.instances[uid].affixes = []
	state.learn(uid)
	state.equip(uid)
	return uid

func fixture() -> Array:
	var state = State.new()
	state.origin = Origin.sample()
	for e in state.origin.roots:
		state.origin.roots[e] = 20
	state.join("kiem_tong")
	for uid in state.instances:
		state.instances[uid].affixes = []
	var resolver = Resolver.new()
	resolver.progression = state
	return [state,resolver]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var valid_rolls := true
	for i in 3000:
		valid_rolls = valid_rolls and Origin.valid(Origin.roll(i))
	check(valid_rolls,"T1/T2: 3000 seeds, exact totals and bounds")
	check(Origin.valid(Origin.sample()),"specified sample valid")
	check(Origin.roll(99) == Origin.roll(99),"seed reproduces origin")
	var fx := fixture()
	var state = fx[0]
	var engine = fx[1]
	var foreign: String = state.acquire("hon_heart","market")
	check(state.learn(foreign) and state.equip(foreign) and state.sect == "kiem_tong","T3: Sword member learns/equips Soul heart")
	var variants := {}
	for i in 20:
		var uid: String = state.acquire("kiem_cut","market","linh")
		variants[str(state.instances[uid].affixes)] = true
	check(variants.size() > 1,"T4: same definition has distinct instance affixes")
	state.instances[foreign].affixes = []
	engine.qi = 50
	clean_item(state,"kiem_flow")
	for id in ["kiem_cut","hon_seal"]:
		clean_item(state,id)
		engine.tick(2)
		var ctx: Dictionary = engine.context("cong",["direct"])
		var before: float = engine.qi
		engine.hit("enemy",10,ctx)
		check(engine.qi == before + 8,"T5 status_applied cross-sect (same status family): " + id)
	# Ví dụ bắt buộc của tài liệu: ép dữ liệu mẫu về 45 linh lực để kiểm tra 45 → 36 → Tụ Linh Châu (≥40 thực trả) không kích hoạt.
	Data.definition("kiem_wave").cost = 45
	clean_item(state,"kiem_wave")
	clean_item(state,"qi_pearl")
	state.equipped.tam = ""
	engine.clear_transient()
	engine.qi = 100
	engine.cooldowns.than = 5
	engine.emit_event("perfect_dodge",engine.context("than",["movement"]))
	check(is_equal_approx(float(engine.cost("cong").actual),36),"T6 pending discount quotes 36")
	var cast: Dictionary = engine.cast("cong")
	check(cast.ok and is_equal_approx(cast.qi_spent,36),"T7 actual payment = 36")
	check(engine.cooldowns.than == 5,"T7 pearl does not proc below 40 actual")
	check(not engine.has_status("player","discount") and is_equal_approx(engine.cost("cong").actual,45),"T6 discount consumed exactly once")
	engine.cooldowns.cong = 0
	cast = engine.cast("cong")
	check(cast.ok and engine.cooldowns.than == 4.0,"pearl positive control: 45 triggers once")
	engine.clear_transient()
	engine.qi = 1
	engine.emit_event("perfect_dodge",engine.context("than",["movement"]))
	check(not engine.cast("cong").ok and engine.has_status("player","discount"),"failed cast does not consume one-shot")
	engine.tick(7)
	check(not engine.has_status("player","discount"),"discount expires")
	engine.clear_transient()
	state.origin.fate = "huyet_nghich"
	engine.qi = 35
	engine.hp = 100
	cast = engine.cast("cong")
	check(cast.ok and cast.qi_spent == 35 and cast.hp_spent == 20,"blood converts only missing qi; actual mana remains 35")
	engine.cooldowns.cong = 0
	engine.qi = 0
	check(not engine.cast("cong").ok,"blood payment capped per cast")
	engine.clear_transient()
	clean_item(state,"hon_echo")
	var summon_context: Dictionary = engine.context("artifact",["summon","artifact"])
	for i in 20:
		engine.hit("summon_target",10,summon_context)
	check(engine.statuses.summon_target.hon_an.stacks <= 5,"T8 summon inherited status capped")
	check(engine.logs.size() <= int(Data.balance("log_limit")),"T8 logs and chain bounded")
	# Force a cycle A->status->B->status->A; trace suppresses both ancestors.
	Data.data().effects["cycle_a"] = {"trigger":"status_applied","actions":[{"type":"status","status":"burn","stacks":1}],"conditions":{},"limits":{}}
	Data.data().effects["cycle_b"] = {"trigger":"status_applied","actions":[{"type":"status","status":"bleed","stacks":1}],"conditions":{},"limits":{}}
	var heart: Dictionary = Data.definition("hon_heart")
	var old_effects: Array = heart.effects.duplicate()
	heart.effects = ["cycle_a","cycle_b"]
	clean_item(state,"hon_heart")
	engine.apply_status("cycle_target","burn",1,engine.context("cong",["direct"]))
	check(engine.stack_count("cycle_target") <= 10,"T8 adversarial effect cycle terminates")
	heart.effects = old_effects
	Data.data().effects.erase("cycle_a")
	Data.data().effects.erase("cycle_b")
	clean_item(state,"nine_swords")
	clean_item(state,"heavy_blade")
	engine.clear_transient()
	engine.qi = 100
	state.primary = "artifact"
	cast = engine.cast(state.primary)
	check(cast.ok and cast.definition.shape == "summon" and Data.data().sects.size() == 5,"T9 artifact main attack without sixth sect")
	check(is_equal_approx(engine.damage_multiplier("artifact","enemy",true),1),"T9 weapon does not multiply artifact summon damage")
	var secret: String = state.acquire("hon_echo","npc","thuong")
	check(state.instances[secret].quality == "thuong" and state.instances[secret].secrecy == "secret","T10 quality separate from secrecy")
	state.relations.hon_dao = "hostile"
	state.npc_relations.soul_friend = 70
	check(state.npc_relations.soul_friend == 70 and state.relations.hon_dao == "hostile","T11 two independent relation layers")
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var restored = State.new()
	restored.from_dict(serialized)
	check(JSON.stringify(JSON.parse_string(JSON.stringify(restored.to_dict()))) == JSON.stringify(serialized),"T12 JSON roundtrip retains rolls/IDs/loadout/seed")
	var fragment: String = restored.acquire("dao_cut","unowned_ruin","linh",true)
	check(not restored.learn(fragment),"fragment cannot be learned")
	restored.begin_study(fragment)
	var mid: Dictionary = JSON.parse_string(JSON.stringify(restored.to_dict()))
	restored.from_dict(mid)
	restored.advance_study(10000)
	check(restored.learn(fragment),"fragment study resumes across save and repairs")
	var before_affixes: Array = restored.instances[fragment].affixes.duplicate()
	restored.begin_study(fragment)
	restored.advance_study(10000)
	check(restored.instances[fragment].affixes != before_affixes,"study replaces a random affix, not whole instance")
	# 30 bí tịch nền + 2 bí tịch truyền thừa động phủ (Bất Hoại Kim Thân Kinh, Thiên Mạch Chân Quyết)
	var dong_phu_books := ["bat_hoai_kim_than", "thien_mach_quyet"]
	check(Data.data().books.size() == 30 + dong_phu_books.size(),"30 books + dong phu legacies")
	for sect in Data.data().sects:
		for slot in ["cong","tam","than"]:
			var count := 0
			for book in Data.data().books:
				if book.sect == sect and book.slot == slot and not (book.id in dong_phu_books):
					count += 1
			check(count == 2,"two " + slot + " for " + sect)
	var old := {"innate":{"comp":92,"spirit":15}, "inv":{"merit_total":420,"manuals":["huyen_minh"]},"noicong":{"id":"nc_hoi_xuan"}}
	var migrated = State.new()
	migrated.bootstrap(old)
	check(Origin.valid(migrated.origin) and migrated.origin.attributes.insight == 75 and migrated.origin.attributes.awareness == 25,"legacy innate normalized within exact bounds")
	check(migrated.rank() == 3 and migrated.item_for("tam").definition == "ngu_wood","legacy rank and active internal technique migrated")
	var souls := 0
	for item in migrated.instances.values():
		if Data.definition(item.definition).get("sect", "") == "hon_dao" and item.learned:
			souls += 1
	check(souls == 6 and migrated.legacy.innate == old.innate,"legacy learned manuals and original values retained")
	var migrated_again = State.new()
	migrated_again.bootstrap(old)
	check(migrated.to_dict() == migrated_again.to_dict(),"legacy migration deterministic")
	# --- V1.2: điều kiện cảnh giới, pool dòng phụ riêng, dòng phụ có điều kiện, tầng phẩm chất
	var gate = State.new()
	gate.origin = Origin.sample()
	var inner_uid: String = gate.acquire("kiem_wave","test")
	check(not gate.learn(inner_uid, 0) and gate.learn(inner_uid, int(Data.definition("kiem_wave").need)),"inner book needs realm step before learning")
	var pool_ok := true
	for book in Data.data().books:
		check(book.has("affix_pool") and (book.affix_pool as Array).size() >= 5,"pool size " + str(book.id))
		var u: String = gate.acquire(book.id,"test","huyen")
		for a in gate.instances[u].affixes + [gate.instances[u].hidden_affix]:
			pool_ok = pool_ok and a in book.affix_pool
	check(pool_ok,"rolled and hidden affixes come from the book pool")
	var cond = fixture()
	var cst = cond[0]
	var ceng = cond[1]
	var cuid: String = clean_item(cst,"kiem_cut")
	cst.instances[cuid].affixes = ["opportunist"]
	var plain: float = ceng.damage_multiplier("cong","t1")
	ceng.statuses["t1"] = {"bleed":{"stacks":2,"remaining":5.0,"tick":1.0,"source":{}}}
	check(ceng.damage_multiplier("cong","t1") > plain * 1.15 and is_equal_approx(ceng.damage_multiplier("cong","none"), plain),"conditional affix only applies to its status family")
	print("V1 CORE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
