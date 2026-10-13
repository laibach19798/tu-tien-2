extends Node
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
const Progression = preload("res://scripts/v1/progression.gd")
const Resolver = preload("res://scripts/v1/combat_resolver.gd")
var state = Progression.new()
var engine = Resolver.new()
var main: Node
var ui: CanvasLayer
var study_game: StudyGame   # mini game Ngộ đạo của chức năng Tham ngộ
var pending: Dictionary = {}
var summons: Array = []
var dash_left := 0.0
var dash_age := 0.0
var dash_direction := Vector2.ZERO
var dodge_registered := false
var interrupted := 0.0
var combat_left := 0.0
var _map := ""
var _target_nodes: Dictionary = {}
var _ghost_t := 0.0
var _marks: StatusMarks  # biểu tượng trạng thái nổi trên đầu mục tiêu
var _rng := RandomNumberGenerator.new()

func setup(host: Node) -> void:
	main = host
	engine.progression = state
	_rng.randomize()
	if state.origin.is_empty():
		state.seed_value = _rng.randi_range(1, 1000000000)
		state.bootstrap()
	ui = preload("res://scripts/v1/cultivation_ui.gd").new()
	ui.runtime = self
	add_child(ui)
	study_game = StudyGame.new()
	add_child(study_game)
	main.vitals.damage_filter = filter_damage
	main._spawn_npc("v1_librarian","Chấp sự truyền pháp",{"hair":"hair_topknot_silver","clothes":"outfit_thanh","shoes":"shoes_boot_black"},Vector2(1230,1030))
	state.changed.connect(_state_changed)
	main.inv.changed.connect(sync_membership)
	_state_changed()
	_map = main.current_map
	if not state.origin.confirmed and not OS.has_environment("TUTIEN_NO_SAVE"):
		ui.open_ui("origin")

## Sân tông môn của người chơi theo tông V1 đã chọn (id tông cũ làm khoá cho bản đồ và chiến sự).
func sync_player_sect() -> void:
	var sect_id := str(state.sect)
	if sect_id == "" or not Data.data().sects.has(sect_id):
		return
	if SectWar.set_player(str(Data.data().sects[sect_id].legacy)):
		Maps.refresh_sects()


func restore(save: Dictionary) -> void:
	if save.has("cultivation_v1"):
		state.from_dict(save.cultivation_v1)
	else:
		state = Progression.new()
		state.bootstrap(save)
		if main != null:
			state.changed.connect(_state_changed)
	engine.progression = state
	sync_player_sect()
	engine.clear_transient()
	pending.clear()
	summons.clear()
	dash_left = 0.0
	interrupted = 0.0
	_target_nodes.clear()
	if main != null:
		_state_changed()

func active() -> bool:
	return main != null

func is_open() -> bool:
	return (ui != null and ui.visible) or (study_game != null and study_game.visible)

func open_ui(page := "loadout") -> void:
	if ui != null:
		main.meditating = false
		ui.open_ui(page)

func _state_changed() -> void:
	if main == null:
		return
	main._apply_set_bonus(false)
	sync_membership()
	_sync_resources()
	_refresh_bar()
	if ui != null and ui.visible:
		ui.refresh()

func sync_membership() -> void:
	state.merit = main.inv.merit_total
	state.reputation = maxi(state.reputation, main.inv.merit_total)
	state.inner_exam_passed = main.inv.inner_exam_passed

func apply_attributes() -> void:
	if main == null or state.origin.is_empty():
		return
	var a: Dictionary = state.origin.attributes
	var scale := Data.balance("attribute_scale")
	# Thưởng bộ trang phục (Wardrobe) cộng thêm lên tiên thiên: tu vi, khí huyết, tốc độ, sát thương.
	var b := Wardrobe.total_bonus(main.wardrobe.equipped)
	main.cult.qi_mult = 1.0 + (float(a.meridians) - 50.0) * scale
	main.vitals.set_hp_bonus((1.0 + (float(a.constitution) - 50.0) * scale) * (1.0 + float(b["hp"])) - 1.0)
	main.cult.xp_mult = 1.0 + float(b["xp"])
	main.cult.med_mult = 1.0 + (float(a.meridians) - 50.0) * scale
	main.cult.breakthrough_bonus = 0.0
	main.vitals.taken_mult = 1.0
	main.set_speed_mult = (1.0 + (float(a.agility) - 50.0) * scale) * (1.0 + float(b["speed"])) * float(state.def_for("armor").get("movement_mult", 1))
	if main.school != null:
		main.school.dmg_mult = 1.0 + float(b["dmg"])

func _sync_resources() -> void:
	engine.qi = main.cult.qi
	engine.max_qi = main.cult.qi_max()
	engine.hp = main.vitals.hp
	engine.max_hp = main.vitals.max_hp

func open_source(method: String) -> void:
	ui.method = method
	open_ui("acquire")

func _commit_resources() -> void:
	main.cult.qi = clampf(engine.qi, 0.0, main.cult.qi_max())
	main.vitals.hp = clampf(engine.hp, 0.0, main.vitals.max_hp)
	main.vitals.changed.emit()

func safe_change() -> bool:
	return pending.is_empty() and summons.is_empty() and combat_left <= 0.0 and dash_left <= 0.0

## Công huân cần để đổi một bí tịch ở Tàng Kinh Các; mức bảo mật càng cao càng đắt.
func merit_price(definition: Dictionary) -> int:
	var mult: float = float(Data.data().balance.sect_merit_mult.get(str(definition.get("secrecy", "public")), 1.0))
	if _exchange_partner(definition):
		mult *= 1.5   # bí tịch tông bạn qua hiệp ước giao lưu: giá cao hơn
	return roundi(Data.balance("sect_merit") * mult)


## id V1 -> id tông trong SectWar (trường legacy).
func _legacy_of(v1_sect: String) -> String:
	return str(Data.data().sects.get(v1_sect, {}).get("legacy", ""))


## Bí tịch Phổ Truyền / Nội Truyền của tông khác, đang có hiệp ước giao lưu với tông của mình.
func _exchange_partner(definition: Dictionary) -> bool:
	var other := str(definition.get("sect", ""))
	if other == "" or other == state.sect or main.get("diplomacy") == null:
		return false
	if str(definition.get("secrecy", "public")) not in ["public", "inner"]:
		return false
	return main.diplomacy.has_treaty(_legacy_of(str(state.sect)), _legacy_of(other), "exchange")


## Phẩm chất bản nhận từ Tàng Kinh Các: bảo mật càng cao càng dễ ra bản tốt.
func sect_quality(definition: Dictionary) -> String:
	match str(definition.get("secrecy", "public")):
		"inner":
			return "linh"
		"true", "secret":
			return "huyen"
	return "thuong"


func equip(uid: String, into := "") -> void:
	if not safe_change():
		main.hud.toast("Chờ thoát giao tranh / kết thúc triệu hồi để đổi trang bị.")
		return
	var wanted: Dictionary = Data.definition(str(state.instances.get(uid, {}).get("definition", "")))
	var need := int(wanted.get("need", 0))
	if main.cult.step_index() < need:
		main.hud.toast("Cần đạt %s mới dùng được." % Data.step_name(need))
		return
	if state.equip(uid, into):
		main.hud.toast("Đã trang bị." if into == "cong2" else "Đã trang bị. Mỗi loại pháp và trang bị chỉ có một ô (Công Pháp có thêm ô phụ).")

## Ô thứ hai trên thanh chiêu (phím K): thứ còn lại trong {Công Pháp, Pháp Bảo} khi một trong hai đã là nguồn chính (J).
func other_slot() -> String:
	return "artifact" if state.primary == "cong" else "cong"

func choose_primary(slot: String) -> void:
	if safe_change() and slot in ["cong","artifact"] and not state.item_for(slot).is_empty():
		state.primary = slot
		state.changed.emit()

func confirm_origin(origin: Dictionary, sect: String) -> void:
	if state.origin.get("confirmed", false) or not Origin.valid(origin) or not Data.data().sects.has(sect):
		return
	state.origin = origin.duplicate(true)
	state.origin.confirmed = true
	state.join(sect)
	sync_player_sect()
	if sect != "kiem_tong":
		main.inv.pass_inner_exam()
	main.school.joined = true # Quyền điều khiển; membership thật nằm trong state.sect.
	_state_changed()
	main.vitals.hp = main.vitals.max_hp
	main.cult.qi = main.cult.qi_max()
	main._save_game()
	ui.hide()
	main.hud.toast("Nhấn J ra chiêu, Space thân pháp, Y mở bí tịch và trang bị.")

func _process(delta: float) -> void:
	if main == null:
		return
	if _map != main.current_map:
		_map = main.current_map
		pending.clear()
		summons.clear()
		engine.statuses.clear()
		engine.damage_requests.clear()
		_target_nodes.clear()
		dash_left = 0.0
	if main._dead:
		pending.clear()
		summons.clear()
		dash_left = 0.0
		return
	if main._ui_blocked():
		return
	_sync_resources()
	engine.tick(delta)
	interrupted = maxf(0.0, interrupted - delta)
	combat_left = maxf(0.0, combat_left - delta)
	if state.advance_study(delta):
		main.hud.toast("Tham ngộ hoàn tất. Nhấn Y xem dòng mới; bí tịch chưa bị tung lại toàn bộ.")
	if not pending.is_empty():
		pending.remaining = float(pending.remaining) - delta
		if pending.remaining <= 0.0:
			_execute(pending.result)
			pending = {}
	for summon in summons.duplicate():
		summon.remaining = float(summon.remaining) - delta
		summon.next = float(summon.next) - delta
		if summon.remaining <= 0.0:
			summons.erase(summon)
			continue
		if summon.next <= 0.0:
			var fate: Dictionary = Data.data().fates[state.origin.fate]
			var upkeep := Data.balance("summon_upkeep") + float(fate.get("summon_upkeep",0))
			if engine.qi < upkeep:
				summons.erase(summon)
				main.hud.toast("Triệu hồi tan biến: không đủ linh lực duy trì.")
				continue
			engine.qi -= upkeep
			engine.emit_event("resource_spent", summon.context, {"resource":"qi","amount":upkeep,"skill_type":"summon"})
			summon.next = Data.balance("summon_interval")
			var targets := targets_in_range(float(summon.definition.get("range",300)))
			if not targets.is_empty():
				var dmg := float(summon.definition.get("damage",14))
				_deal(targets[0], dmg, summon.context, true)
				if GrandFx.is_area_summon(summon.definition):   # mưa kiếm phủ cả vùng: mục tiêu thứ hai trở đi chịu một phần sát thương
					for extra in targets.slice(1, GrandFx.SUMMON_MAX_TARGETS):
						_deal(extra, dmg * GrandFx.SUMMON_FALLOFF, summon.context, true)
			Fx.ring(main.fx_layer, main.player.position, 12, 42, UIKit.QI_BLUE, 0.35)
	_flush_damage()
	if not is_instance_valid(_marks) or _marks.get_parent() != main.fx_layer:
		_marks = StatusMarks.new()
		_marks.engine = engine
		_marks.nodes = _target_nodes
		_marks.main = main
		main.fx_layer.add_child(_marks)
	for id in engine.statuses:
		var target = _target_nodes.get(id)
		if is_instance_valid(target) and target.alive and engine.has_status(id,"slow") and target.has_method("apply_slow"):
			# Boss vẫn bị khống chế nhẹ thay vì miễn nhiễm.
			target.apply_slow(0.9 if target.get("kind_id") in ["sect_master","wolf_king"] else float(Data.data().statuses.slow.slow), 0.2)
	_commit_resources()
	_update_bar()

func move_dash(delta: float) -> bool:
	if dash_left <= 0.0 or main._ui_blocked():
		return false
	dash_left = maxf(0.0, dash_left - delta)
	dash_age += delta
	var distance := Data.balance("dash_speed") * float(state.def_for("than").get("dash_mult",1)) * delta
	# Chia bước để không xuyên vật cản ở FPS thấp.
	var steps := maxi(1, ceili(distance / 8.0))
	for i in steps:
		var step := dash_direction * distance / steps
		main._move_axis(Vector2(step.x,0))
		main._move_axis(Vector2(0,step.y))
	main.player.set_motion("run", main.direction)
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.04
		SkillFx.afterimage(main, SkillFx.palette(state.def_for("than"))[0])
	if dash_left <= 0.0:
		engine.emit_event("dodge_completed", engine.context("than", ["movement"]))
	return true

func cast(slot := "") -> void:
	if main == null or main._ui_blocked() or not pending.is_empty() or dash_left > 0.0 or interrupted > 0.0:
		return
	if not state.origin.confirmed:
		open_ui("origin")
		return
	if slot == "":
		slot = state.primary
	main.meditating = false
	_sync_resources()
	var result: Dictionary = engine.cast(slot)
	if not result.ok:
		main.hud.toast(result.reason)
		return
	_commit_resources()
	combat_left = 2.0
	if slot == "than":
		dash_left = Data.balance("dash_seconds")
		dash_age = 0.0
		dodge_registered = false
		dash_direction = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		if Input.is_key_pressed(KEY_A): dash_direction.x -= 1
		if Input.is_key_pressed(KEY_D): dash_direction.x += 1
		if Input.is_key_pressed(KEY_W): dash_direction.y -= 1
		if Input.is_key_pressed(KEY_S): dash_direction.y += 1
		if dash_direction == Vector2.ZERO:
			dash_direction = Dir.to_vector(main.direction)
		dash_direction = dash_direction.normalized()
		engine.emit_event("dodge_attempted", result.context)
		if result.definition.has("summon_duration"):
			_create_summon(result.context, {"duration":result.definition.summon_duration,"damage":10,"range":300})
		engine.completed(result.context)
	else:
		var cast_time := float(result.definition.get("cast_time",0))
		if cast_time > 0.0:
			pending = {"result":result,"remaining":cast_time}
			Fx.glow(main.fx_layer, main.player.position + Vector2(0,-28), 8, 42, UIKit.JADE, cast_time)
		else:
			_execute(result)
	_update_bar()

func filter_damage(amount: float, from: Vector2) -> float:
	if main == null:
		return amount
	if main._ui_blocked():
		return -1.0
	if main.get("flight") != null and main.flight.active and main.flight.try_evade(from):
		return -1.0   # đang ngự không: thân nhẹ, đòn có thể trượt ("Lướt gió")
	_sync_resources()
	var attacker_id := ""
	var nearest := 90.0
	for mob in main.monsters:
		if is_instance_valid(mob) and mob.alive and mob.position.distance_to(from) < nearest:
			nearest = mob.position.distance_to(from)
			attacker_id = _register(mob)
	# Perfect dodge được quyết định trước damage; chỉ khi một đòn thật chạm cửa sổ né.
	if dash_left > 0.0:
		var window := Data.balance("dodge_window") * (1.0 + (float(state.origin.attributes.agility)-50.0)*Data.balance("attribute_scale"))
		if dash_age <= window and not dodge_registered:
			dodge_registered = true
			engine.emit_event("perfect_dodge", engine.context("than",["movement"]), {"target":attacker_id})
			main.hud.toast("Né hoàn hảo!")
			SkillFx.perfect_dodge(main, state.def_for("than"))
			_commit_resources()
		return -1.0
	combat_left = 2.0
	var dealt: float = engine.incoming(amount, attacker_id)
	if not pending.is_empty() and not engine.has_status("player","steadfast"):
		pending.clear()
		interrupted = Data.balance("interrupt_seconds") / (1.0 + (float(state.origin.attributes.composure)-25.0)*Data.balance("attribute_scale"))
		main.hud.toast("Thi pháp bị gián đoạn; chi phí đã tiêu hao không hoàn lại.")
	_commit_resources()
	return dealt

func _register(target: Node) -> String:
	var id := str(target.get_instance_id())
	_target_nodes[id] = target
	return id

func targets_in_range(radius: float) -> Array:
	radius = minf(radius,Data.balance("sensing_range") * (1.0 + (float(state.origin.attributes.awareness)-50.0)*Data.balance("attribute_scale")))
	var targets: Array = []
	for target in get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(target) and target.alive and target.is_visible_in_tree() and target.global_position.distance_to(main.player.global_position) <= radius:
			targets.append(target)
	targets.sort_custom(func(a,b): return a.position.distance_squared_to(main.player.position) < b.position.distance_squared_to(main.player.position))
	return targets

func _execute(result: Dictionary) -> void:
	var d: Dictionary = result.definition
	var ctx: Dictionary = result.context
	if d.get("shape", "") == "summon":
		_create_summon(ctx, d)
	else:
		var targets := targets_in_range(maxf(float(d.get("range",125)), GrandFx.reach(d)))   # đại chiêu: vùng trúng = vùng hình ảnh (GrandFx)
		var aim := Dir.to_vector(main.direction)
		if not targets.is_empty():
			aim = (targets[0].position - main.player.position).normalized()
			main.direction = Dir.from_vector(aim, main.direction)
		engine.emit_event("attack_started", ctx)
		var hits := 0
		for target in targets:
			var toward: Vector2 = target.position - main.player.position
			var shape := str(d.get("shape","single"))
			var blast := GrandFx.impact_radius(d)   # cự kiếm / cột sáng: nổ quanh điểm rơi
			var splash := false   # chỉ dính vùng nổ chứ không nằm trên đường tia
			if shape in ["cone","line"] and toward.normalized().dot(aim) < (0.5 if shape == "cone" else 0.92):
				if not (shape == "line" and blast > 0.0 and target.position.distance_to(targets[0].position) <= blast):
					continue
				splash = true
			if shape == "single" and hits > 0:
				break
			if shape == "burst" and target.position.distance_to(targets[0].position) > (blast if blast > 0.0 else 110.0):
				continue
			_deal(target, float(d.get("damage",20)) * (GrandFx.SPLASH_FALLOFF if splash else 1.0), ctx)
			hits += 1
		SkillFx.cast(main, d, aim, targets)
		SkillFx.body_motion(main, d, aim)
		Sfx.play("slash" if "melee" in ctx.tags else "qi")
	engine.completed(ctx)
	_flush_damage()
	_commit_resources()

func _create_summon(ctx: Dictionary, definition: Dictionary) -> void:
	SkillFx.summon(main, definition)
	var child := ctx.duplicate(true)
	child.tags = ["summon", "artifact" if ctx.source_slot == "artifact" else "spell"]
	var fate: Dictionary = Data.data().fates[state.origin.fate]
	summons.append({"context":child,"definition":definition.duplicate(true),"remaining":float(definition.get("duration",4)) + float(fate.get("summon_duration",0)),"next":0.0})
	engine.emit_event("summon_created", child)

func _deal(target: Node, base: float, ctx: Dictionary, summon := false, secondary := false) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var id := _register(target)
	var critical := not secondary and _rng.randf() < Data.balance("critical_chance")
	var amount := base
	if not secondary:
		amount *= 1.0 + Data.balance("realm_damage_per_step") * main.cult.step_index()
		amount *= main.school.dmg_mult if main.school != null else 1.0
		amount *= engine.damage_multiplier(str(ctx.source_slot),id,summon) * (Data.balance("critical_multiplier") if critical else 1.0)
	# Bản thân trong gương Thiên Mạch thuộc lòng chiêu đang dùng: chiêu đó gần như vô dụng, buộc đổi phối hợp.
	if target.has_meta("mirror_ids") and not secondary:
		var used := str(state.def_for(str(ctx.source_slot)).get("id", ""))
		if used in (target.get_meta("mirror_ids") as Array):
			amount *= float(target.get_meta("mirror_resist", 0.25))
			if MonsterBehaviors.now() >= float(target.get_meta("mirror_note", 0.0)):
				target.set_meta("mirror_note", MonsterBehaviors.now() + 2.5)
				main.float_text(target.position + Vector2(0, -70), "Thuộc lòng chiêu này!", Color(0.7, 0.85, 1.0))
	var old_hp: float = target.hp
	if target.take_hit(amount, main.player.position):
		engine.hit(id, minf(old_hp, amount), ctx, not target.alive, critical)
		SkillFx.hit(main, target.hit_center(), state.def_for(str(ctx.source_slot)), critical)

func _flush_damage() -> void:
	var budget := int(Data.balance("chain_events"))
	while not engine.damage_requests.is_empty() and budget > 0:
		budget -= 1
		var request: Dictionary = engine.damage_requests.pop_front()
		var target = _target_nodes.get(request.target)
		if is_instance_valid(target):
			_deal(target,float(request.amount),request.context,false,true)
	if budget <= 0:
		engine.damage_requests.clear()

func on_killed(mob: Node) -> void:
	if main.current_map == "linh_mach_dong":
		state.ruin_kills += 1
		if state.ruin_kills % int(Data.balance("ruin_kills")) == 0:
			var books: Array = Data.data().books
			var d: Dictionary = books[(state.ruin_kills / int(Data.balance("ruin_kills")) - 1) % books.size()]
			var every := int(Data.balance("ruin_huyen_every"))
			var rare: bool = (state.ruin_kills / int(Data.balance("ruin_kills"))) % every == 0
			state.acquire(d.id,"unowned_ruin","huyen" if rare else "linh",true)
			main.hud.toast("Di tích: tìm được tàn quyển %s. Y → tham ngộ để bổ khuyết." % d.name)
	if mob.kind_id == "sect_master":
		for id in Data.data().sects:
			if Data.data().sects[id].legacy == mob.sect_id:
				for book in Data.data().books:
					if book.sect == id and book.secrecy == "inner":
						state.acquire(book.id,"seized","huyen")
						main.hud.toast("Chiến lợi phẩm có nguồn gốc: %s ghi thù. Xem Y → Thu thập." % Data.data().sects[id].name)
						return

func access_reason(definition: Dictionary, method: String) -> String:
	var nearby := false
	var allowed: Array = {"market":["merchant"],"sect":["scripture_elder","sect_keeper","v1_librarian"],"npc":["thanh_dao"]}.get(method,[])
	for npc in main.npcs:
		if npc.visible and npc.get("npc_id") in allowed and npc.position.distance_to(main.player.position) < 120.0:
			nearby = true
	if not nearby:
		return "Đến gần thương nhân / Tàng Kinh Các / Thanh Dao tương ứng để nhận sách."
	state.merit = main.inv.merit_total
	if method == "market":
		return "" if definition.get("secrecy","public") == "public" else "Thương hội chỉ bán bản Phổ Truyền."
	if method == "sect":
		if definition.get("sect", "") != state.sect and not _exchange_partner(definition):
			return "Tàng Kinh Các chỉ truyền sách của tông môn đang gia nhập. Ngoại phái có thể mua / tìm di tích / nhờ NPC."
		var need := int(Data.data().secrecy_ranks.get(str(definition.secrecy),4))
		return "" if state.rank() >= need else "Cấp bậc chưa đủ để tiếp cận mức bảo mật này."
	if method == "npc":
		if definition.get("secrecy", "public") != "public":
			return "Quan hệ thông thường chỉ cho phép truyền sách Phổ Truyền."
		var bond := int(main.sect_life.bonds.get("thanh_dao",0))
		state.npc_relations["thanh_dao"] = bond
		return "" if bond >= int(Data.balance("npc_bond")) and not state.claimed.has(definition.id) else "Thanh Dao cần thiện cảm 15; mỗi bí tịch được truyền một lần."
	return "Nguồn không hợp lệ."

func acquire_from(id: String, method: String) -> void:
	var definition := Data.definition(id)
	if definition.is_empty():
		return
	var reason := access_reason(definition,method)
	if reason != "":
		main.hud.toast(reason)
		return
	if method == "sect":
		if not main.inv.spend_merit(merit_price(definition)):
			main.hud.toast("Không đủ công huân (cần %d)." % merit_price(definition))
			return
	elif method == "market":
		var price := int(Data.balance("book_price") if definition.slot in ["cong","tam","than"] else Data.balance("gear_price"))
		if not main.inv.spend_stones(price):
			main.hud.toast("Không đủ linh thạch.")
			return
	else:
		state.claimed[id] = true
	state.acquire(id,method,sect_quality(definition) if method == "sect" else "thuong")
	main.hud.toast("Đã nhận %s; xem Y → Bí tịch / Trang bị." % definition.name)

func study(uid: String) -> void:
	if not state.research.is_empty() or not state.instances.has(uid) or study_game.is_active():
		return
	if not main.inv.spend_stones(state.study_cost()):
		main.hud.toast("Không đủ linh thạch để tham ngộ.")
		return
	var item: Dictionary = state.instances[uid]
	var names: Array = []
	for id in item.affixes:
		var a: Dictionary = Data.data().affixes[id]
		names.append({"name": str(a.name), "desc": str(a.description)})
	var hidden: Dictionary = Data.data().affixes.get(str(item.hidden_affix), {"name": "?", "description": ""})
	study_game.begin({
		"name": str(Data.definition(item.definition).get("name", "")),
		"seed": state.study_seed(uid),
		"insight": float(state.origin.attributes.insight),
		"fragment": bool(item.fragment),
		"affixes": names,
		"hidden": {"name": str(hidden.get("name", "?")), "desc": str(hidden.get("description", ""))},
	})
	study_game.finished.connect(_study_done.bind(uid), CONNECT_ONE_SHOT)

func _study_done(result: Dictionary, uid: String) -> void:
	var r: Dictionary = state.resolve_study(uid, str(result.tier), int(result.replace))
	if not bool(r.ok):
		main.hud.toast("Tâm loạn, ngộ không thành.")
	elif r.get("repaired", false):
		main.hud.toast("Bổ khuyết thành công: có thể học bí tịch này.")
	elif r.get("kept", false):
		main.hud.toast("Đốn ngộ: giữ nguyên các dòng phụ.")
	else:
		main.hud.toast("Ngộ được: dòng %s thay bằng %s." % [str(Data.data().affixes[r.old].name), str(Data.data().affixes[r.new].name)])

func _refresh_bar() -> void:
	if main.school == null:
		return
	var active_def: Dictionary = state.def_for(state.primary)
	var movement: Dictionary = state.def_for("than")
	main.hud.refresh_skillbar([
		{"id":"slash","key":"J","icon":str(active_def.get("id","")),"name":active_def.get("name","Chưa trang bị"),"cost":engine.cost(state.primary).actual,"cd":maxf(0.1,engine.cooldown_for(state.primary)),"need":0},
		{"id":"storm","key":"K","icon":str(state.def_for(other_slot()).get("id","")),"name":state.def_for(other_slot()).get("name","Pháp Bảo" if other_slot() == "artifact" else "Công Pháp"),"cost":engine.cost(other_slot()).actual,"cd":maxf(0.1,engine.cooldown_for(other_slot())),"need":0},
		{"id":"slash","key":"U","icon":str(state.def_for("cong2").get("id","")),"name":state.def_for("cong2").get("name","Công phụ"),"cost":engine.cost("cong2").actual,"cd":maxf(0.1,engine.cooldown_for("cong2")),"need":0},
		{"id":"qi","key":"Space","icon":str(movement.get("id","")),"icon_fallback":"than_default","name":movement.get("name","Thân Pháp"),"cost":engine.cost("than").actual,"cd":maxf(0.1,engine.cooldown_for("than")),"need":0}])

func _update_bar() -> void:
	var infos: Array = []
	for slot in [state.primary, other_slot(), "cong2", "than"]:
		infos.append({"cd":float(engine.cooldowns[slot])/maxf(0.1,engine.cooldown_for(slot)),"unlocked":not state.item_for(slot).is_empty(),"afford":main.cult.qi >= float(engine.cost(slot).actual)})
	main.hud.update_skills(infos)
