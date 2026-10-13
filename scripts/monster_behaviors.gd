extends RefCounted
class_name MonsterBehaviors
## Hành vi của quái (xem docs/QUAI_VAT.md §3) và tinh anh (§6.1). Mô-đun hóa trên máy trạng thái của Monster:
## Monster gọi chase_hook() khi đang đuổi, tick_state() cho các trạng thái mới
## (charge_tele / charging / stunned / fuse / cast), incoming() khi bị đánh, on_strike_hit() khi đánh trúng người chơi.
## Hành vi nằm trong kind["behaviors"]: howler, charger, bomber, thrower, support, summoner, armored, drainer, enrage.

const HOWL_CD := 25.0
const HOWL_DELAY := 1.3
const CHARGE_CD := 7.0
const CHARGE_TELE := 0.8
const CHARGE_TIME := 0.5
const CHARGE_SPEED_K := 4.0
const SHOT_CD := 3.2
const SHOT_TELE := 0.75
const SHOT_SPEED := 250.0
const BOMB_FUSE := 0.7
const BOMB_RADIUS := 90.0
const SUPPORT_CD := 6.0
const SUPPORT_RANGE := 220.0
const SUMMON_CD := 11.0
const SUMMON_TELE := 1.2
const SUMMON_CAP := 4
const ARMOR_MULT := 0.35
const DRAIN_FRAC := 0.08
const SKILL_TELE := 0.6        # dấu báo tối thiểu trước khi NPC tung chiêu (cộng thêm cast_time của chiêu)
const SKILL_CD_K := 2.5        # NPC hồi chiêu chậm hơn người chơi
const SKILL_CD_MIN := 3.5
const SKILL_DMG_REF := 21.0    # sát thương chiêu cơ bản (Thanh Phong Kiếm) = 1x sát thương quái

## Chiêu của tông môn: đệ tử biết chiêu đầu, trưởng lão hai chiêu đầu, tông chủ biết hết.
const SECT_SKILLS := {
	"kiem_tong": ["kiem_cut", "kiem_wave"],
	"xich_viem": ["dao_cut", "dao_break", "ngu_fire"],
	"han_bang": ["ngu_water", "the_fist", "the_quake"],
	"doc_mon": ["hon_seal", "dao_cut", "ngu_water"],
	"huyen_minh": ["hon_seal", "soul_bell", "hon_clone"],
}
## Tán tu: kẻ yếu chỉ biết một chiêu cơ bản; cao nhân tán tu biết ba chiêu mạnh.
const ROGUE_BASIC := ["kiem_cut", "dao_cut", "the_fist"]
const ROGUE_MASTER := ["kiem_wave", "dao_break", "the_quake", "ngu_fire", "hon_seal", "ngu_water"]

const ELITE_AFFIXES := {
	"nhanh_nhen": {"prefix": "Nhanh nhẹn", "tint": Color(0.7, 1.0, 0.8)},
	"giap_da": {"prefix": "Giáp đá", "tint": Color(0.75, 0.8, 0.95)},
	"cuong_no": {"prefix": "Cuồng nộ", "tint": Color(1.0, 0.6, 0.5)},
	"doc_nanh": {"prefix": "Độc nanh", "tint": Color(0.7, 1.0, 0.5)},
	"ho_ve": {"prefix": "Hộ vệ", "tint": Color(1.0, 0.9, 0.6)},
	"hut_huyet": {"prefix": "Hút huyết", "tint": Color(1.0, 0.5, 0.7)},
	"phan_chan": {"prefix": "Phản chấn", "tint": Color(0.8, 0.7, 1.0)},
}


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---------------------------------------------------------------- khởi tạo
## Gọi ở cuối Monster.setup (đã có tier, max_hp, damage).
static func setup(m: Monster) -> void:
	m.behaviors = (m.kind.get("behaviors", []) as Array).duplicate()
	m._bt = {}
	if m.kind.has("outfits") and m.outfit.is_empty():
		var o: Array = m.kind["outfits"]
		m.outfit = (o[randi() % o.size()] as Dictionary).duplicate()
	_assign_skills(m)
	_roll_elite(m)


## Gán chiêu thức V1 cho NPC hình người (đệ tử, trưởng lão, tông chủ, tán tu). Danh sách là định nghĩa chiêu đọc từ catalog.
static func _assign_skills(m: Monster) -> void:
	var ids: Array = []
	if m.sect_id != "" and SECT_SKILLS.has(m.sect_id):
		var all: Array = SECT_SKILLS[m.sect_id]
		var n := all.size()
		if m.kind_id == "sect_disciple":
			n = 1
		elif m.kind_id == "sect_elder":
			n = mini(2, all.size())
		ids = all.slice(0, n)
	elif m.kind_id == "rogue_weak":
		ids = [ROGUE_BASIC[randi() % ROGUE_BASIC.size()]]
	elif m.kind_id == "rogue_master":
		var pool: Array = ROGUE_MASTER.duplicate()
		pool.shuffle()
		ids = pool.slice(0, 3)
	elif m.kind.has("skills"):
		ids = (m.kind["skills"] as Array).duplicate()
	var defs: Array = []
	for id in ids:
		var d: Dictionary = preload("res://scripts/v1/catalog.gd").definition(str(id))
		if d.is_empty() or int(d.get("need", 0)) > maxi(m.tier, 6 if bool(m.kind.get("boss", false)) else 0):
			continue
		defs.append(d)
	if defs.is_empty():
		return
	m.set_meta("npc_skills", defs)
	if not ("skills" in m.behaviors):
		m.behaviors.append("skills")


static func _roll_elite(m: Monster) -> void:
	if bool(m.kind.get("boss", false)) or m.minion or m.sect_id != "":
		return
	if m.tier < Hell.ELITE_MIN_TIER or randf() >= Hell.elite_chance(m.tier):
		return
	var ids: Array = ELITE_AFFIXES.keys()
	ids.shuffle()
	var n := 2 if m.tier >= Hell.ELITE_DOUBLE_TIER else 1
	for i in n:
		m.elite_affixes.append(str(ids[i]))
	m.elite = true
	m.max_hp *= 1.5
	m.hp = m.max_hp
	m.damage *= 1.2
	if "giap_da" in m.elite_affixes and not ("armored" in m.behaviors):
		m.behaviors.append("armored")
	if "ho_ve" in m.elite_affixes and not ("summoner" in m.behaviors):
		m.behaviors.append("summoner")
		m._bt["summon_kind"] = str(m.kind.get("minion_kind", _minion_for(m)))
	if "cuong_no" in m.elite_affixes and not ("enrage" in m.behaviors):
		m.behaviors.append("enrage")


static func _minion_for(m: Monster) -> String:
	var fam := str(m.kind.get("family", ""))
	if fam == "wolf":
		return "wolf"
	if fam == "goblin":
		return "goblin"
	if bool(m.kind.get("humanoid", false)):
		return "rogue_weak"
	return "wolf"


## Tên hiển thị tiền tố cho tinh anh.
static func elite_name(m: Monster) -> String:
	var parts: Array = []
	for id in m.elite_affixes:
		parts.append(str(ELITE_AFFIXES[id]["prefix"]))
	return "%s %s" % [" ".join(parts), str(m.kind.get("name", ""))]


# ---------------------------------------------------------------- khi đang đuổi
## Trả true nếu hành vi đã xử lý khung hình này (di chuyển/đổi trạng thái): Monster bỏ qua luồng đuổi thường.
static func chase_hook(m: Monster, to_p: Vector2, dist: float, delta: float) -> bool:
	if m.behaviors.is_empty():
		return false
	var bt: Dictionary = m._bt
	var t := now()
	var spd: float = float(m.kind["speed"]) * m._spd()
	# bầy hú gọi
	if "howler" in m.behaviors:
		if not bt.has("howl_at") and t >= float(bt.get("howl_cd", 0.0)):
			bt["howl_at"] = t + HOWL_DELAY
			bt["howl_cd"] = t + HOWL_CD
			_float_text(m, "Ngao!", Color(1.0, 0.75, 0.4))
		if bt.has("howl_at") and t >= float(bt["howl_at"]):
			bt.erase("howl_at")
			_call_pack(m)
	# bùng nổ
	if "bomber" in m.behaviors and dist < BOMB_RADIUS + 5.0:
		m.state = "fuse"
		m._timer = BOMB_FUSE
		_tele(m).show_circle(BOMB_RADIUS, BOMB_FUSE, Color(1.0, 0.45, 0.15))
		return true
	# lao thẳng
	if "charger" in m.behaviors and t >= float(bt.get("charge_cd", 0.0)) and dist > 130.0 and dist < 360.0 and _clear_line(m, to_p.normalized(), minf(dist, 320.0)):
		bt["charge_cd"] = t + CHARGE_CD * (0.7 if m._enraged else 1.0)
		bt["dir"] = to_p.normalized()
		m.state = "charge_tele"
		m._timer = CHARGE_TELE
		m._facing = Dir.from_vector(to_p, m._facing)
		_tele(m).show_arrow(to_p, 320.0, CHARGE_TELE)
		return true
	# triệu hồi
	if "summoner" in m.behaviors and t >= float(bt.get("summon_cd", 0.0)) and _minions(m) < SUMMON_CAP:
		bt["summon_cd"] = t + SUMMON_CD
		m.state = "cast"
		bt["cast"] = "summon"
		m._timer = SUMMON_TELE
		_tele(m).show_circle(70.0, SUMMON_TELE, Color(0.7, 0.45, 1.0))
		return true
	# hỗ trợ: gầm cổ vũ đồng bọn, giữ khoảng cách
	if "support" in m.behaviors:
		if t >= float(bt.get("support_cd", 0.0)):
			bt["support_cd"] = t + SUPPORT_CD
			_buff_allies(m)
		if dist < 150.0 and dist > 70.0:
			m._facing = Dir.from_vector(to_p, m._facing)
			m._step(-to_p.normalized() * spd * 0.8 * delta)
			m._play("walk")
			return true
	# chiêu thức V1 của NPC: chọn chiêu đã hồi và đủ tầm, gồng có dấu báo rồi tung
	if "skills" in m.behaviors and _skill_hook(m, to_p, dist):
		return true
	# xạ thủ: giữ khoảng cách, bắn đạn có dấu báo
	if "thrower" in m.behaviors:
		if dist < 130.0 and dist > 60.0:
			m._facing = Dir.from_vector(to_p, m._facing)
			m._step(-to_p.normalized() * spd * 0.7 * delta)
			m._play("walk")
			return true
		if dist <= 330.0 and dist >= 130.0:
			m._facing = Dir.from_vector(to_p, m._facing)
			if t >= float(bt.get("shot_cd", 0.0)) and _clear_line(m, to_p.normalized(), dist):
				bt["shot_cd"] = t + SHOT_CD * (0.7 if m._enraged else 1.0)
				bt["cast"] = "shot"
				bt["dir"] = to_p.normalized()
				m.state = "cast"
				m._timer = SHOT_TELE
				_tele(m).show_arrow(to_p, minf(dist, 330.0), SHOT_TELE, Color(1.0, 0.8, 0.3))
			else:
				m._play("idle")
			return true
	return false


static func _call_pack(m: Monster) -> void:
	var fam := str(m.kind.get("family", m.kind_id))
	var called := 0
	for o in m.host.monsters:
		if o == m or not o.alive or o.state in ["chase", "windup", "recover", "hurt"]:
			continue
		if str(o.kind.get("family", o.kind_id)) != fam:
			continue
		if o.position.distance_to(m.position) < 340.0:
			o.state = "chase"
			called += 1
	if called > 0:
		_float_text(m, "Bầy tụ!", Color(1.0, 0.6, 0.4))


static func _buff_allies(m: Monster) -> void:
	var fam := str(m.kind.get("family", m.kind_id))
	var n := 0
	for o in m.host.monsters:
		if o == m or not o.alive:
			continue
		if o.position.distance_to(m.position) > SUPPORT_RANGE or str(o.kind.get("family", o.kind_id)) != fam:
			continue
		o._buff_until = now() + 4.0
		o._buff_spd = 1.3
		o._buff_dmg = 1.25
		n += 1
	if n > 0:
		_float_text(m, "Gầm!", Color(1.0, 0.5, 0.4))
		if m.host.fx_layer != null:
			Fx.ring(m.host.fx_layer, m.global_position, 8.0, SUPPORT_RANGE * 0.6, Color(1.0, 0.5, 0.3), 0.5, 0.55, 4.0)


static func _clear_line(m: Monster, dir: Vector2, length: float) -> bool:
	var d := 40.0
	while d < length:
		var p := m.position + dir * d
		if m.host._is_blocked(Rect2(p.x - 12, p.y - 8, 24, 10)):
			return false
		d += 40.0
	return true


static func _minions(m: Monster) -> int:
	var n := 0
	for o in m.host.monsters:
		if o.alive and o.master_ref == m:
			n += 1
	return n


static func _tele(m: Monster) -> MonsterTelegraph:
	if m._tele == null or not is_instance_valid(m._tele):
		m._tele = MonsterTelegraph.new()
		m.add_child(m._tele)
	return m._tele


static func _float_text(m: Monster, text: String, color: Color) -> void:
	if m.host != null and m.host.has_method("float_text"):
		m.host.float_text(m.position + Vector2(0, -70), text, color)


# ---------------------------------------------------------------- trạng thái mới
static func tick_state(m: Monster, delta: float, to_p: Vector2, dist: float) -> void:
	var bt: Dictionary = m._bt
	match m.state:
		"charge_tele":
			m._play("attack")
			m._timer -= delta
			m._facing = Dir.from_vector(bt.get("dir", to_p), m._facing)
			if m._timer <= 0.0:
				m.state = "charging"
				m._timer = CHARGE_TIME
				bt["hit"] = false
				_tele(m).hide_now()
		"charging":
			m._play("walk")
			m._timer -= delta
			var dir: Vector2 = bt.get("dir", Vector2.RIGHT)
			var step := dir * float(m.kind["speed"]) * CHARGE_SPEED_K * m._spd() * delta
			var before := m.position
			m._move_axis(Vector2(step.x, 0.0))
			m._move_axis(Vector2(0.0, step.y))
			if m.position.distance_to(before) < step.length() * 0.3:
				m.state = "stunned"
				m._timer = 1.4
				m._flash = 1.0
				_float_text(m, "Choáng!", Color(1.0, 0.9, 0.4))
				return
			if not bool(bt.get("hit", false)) and m.host.player != null and m.position.distance_to(m.host.player.position) < 36.0:
				bt["hit"] = true
				m.host.vitals.take(m.damage * m.dmg_mult() * 1.5, m.global_position)
			if m._timer <= 0.0:
				m.state = "recover"
				m._timer = 1.0
		"stunned":
			m._play("idle")
			m._timer -= delta
			if m._timer <= 0.0:
				m.state = "chase"
		"fuse":
			m._play("attack")
			m._timer -= delta
			if m._timer <= 0.0:
				_explode(m)
		"cast":
			m._play("attack")
			m._timer -= delta
			m._facing = Dir.from_vector(to_p, m._facing)
			if m._timer <= 0.0:
				_tele(m).hide_now()
				match str(bt.get("cast", "")):
					"shot":
						_fire(m)
					"summon":
						_summon(m)
					"skill":
						_cast_skill(m)
				m.state = "recover"
				m._timer = 0.7


# ---------------------------------------------------------------- chiêu thức của NPC
static func _skill_range_ok(d: Dictionary, dist: float) -> bool:
	var r := float(d.get("range", 125))
	match str(d.get("shape", "single")):
		"ring":
			return dist <= r * 0.8
		"summon":
			return dist <= r
		"cone":
			return dist <= r * 0.9
		_:
			return dist <= r * 0.95


static func _skill_hook(m: Monster, to_p: Vector2, dist: float) -> bool:
	var bt: Dictionary = m._bt
	var t := now()
	var ready: Array = []
	for sk in (m.get_meta("npc_skills", []) as Array):
		var id := str(sk.get("id", ""))
		if t < float(bt.get("scd_" + id, 0.0)) or not _skill_range_ok(sk, dist):
			continue
		if str(sk.get("shape", "")) == "summon" and _minions(m) >= 2:
			continue
		if str(sk.get("shape", "")) in ["line", "single"] and not _clear_line(m, to_p.normalized(), dist):
			continue
		ready.append(sk)
	if ready.is_empty():
		return false
	var d: Dictionary = ready[randi() % ready.size()]
	var id2 := str(d.get("id", ""))
	var cd := maxf(float(d.get("cooldown", 1.0)) * SKILL_CD_K, SKILL_CD_MIN) * (0.7 if m._enraged else 1.0)
	cd *= 1.5 if m.kind_id == "rogue_weak" else 1.0
	bt["scd_" + id2] = t + cd
	var tele := SKILL_TELE + float(d.get("cast_time", 0.0))
	var dir := to_p.normalized()
	bt["cast"] = "skill"
	bt["skill"] = d
	bt["dir"] = dir
	bt["at"] = m.host.player.position if m.host.player != null else m.position + dir * dist
	m.state = "cast"
	m._timer = tele
	m._facing = Dir.from_vector(to_p, m._facing)
	var col: Color = SkillFx.palette(d)[0]
	col = Color(1.0, 0.35, 0.25).lerp(col, 0.25)
	var r := float(d.get("range", 125))
	var tl := _tele(m)
	match str(d.get("shape", "single")):
		"cone", "line":
			tl.show_arrow(dir, minf(r, 350.0), tele, col)
		"burst":
			tl.show_circle(105.0, tele, col)
			tl.position = (bt["at"] as Vector2) - m.position
		"ring":
			tl.show_circle(r, tele, col)
		"summon":
			tl.show_circle(70.0, tele, Color(0.7, 0.45, 1.0))
		_:
			tl.show_arrow(dir, minf(dist, r), tele, col)
	_float_text(m, str(d.get("name", "")), SkillFx.palette(d)[0])
	return true


## Tung chiêu: hiệu ứng dùng chung với người chơi (SkillFx) + sát thương theo hình dạng.
static func _cast_skill(m: Monster) -> void:
	var host: Node = m.host
	var d: Dictionary = m._bt.get("skill", {})
	if d.is_empty() or host.player == null:
		return
	var dir: Vector2 = m._bt.get("dir", Vector2.RIGHT)
	var r := float(d.get("range", 125))
	var shape := str(d.get("shape", "single"))
	var amount := m.damage * m.dmg_mult() * clampf(float(d.get("damage", SKILL_DMG_REF)) / SKILL_DMG_REF, 0.8, 2.5)
	var pp: Vector2 = host.player.position
	var rel := pp - m.position
	var hit := false
	var fx_targets: Array = []
	match shape:
		"cone":
			hit = rel.length() <= r + 22.0 and absf(dir.angle_to(rel)) <= 1.05
		"line":
			var along := rel.dot(dir)
			hit = along >= 0.0 and along <= r and absf(rel.cross(dir)) < 30.0
		"burst":
			var at: Vector2 = m._bt.get("at", pp)
			hit = pp.distance_to(at) < 105.0
			fx_targets = [_Point.new(at)]
		"ring":
			hit = rel.length() <= r
		"summon":
			_summon(m)
		_:
			_fire_skill(m, d, dir, amount)
	SkillFx.cast(host, d, dir, fx_targets, m)
	if hit:
		host.vitals.take(amount, m.global_position)
		var heal := float((m.get_meta("npc_defense", {}) as Dictionary).get("heal", 0.0))
		if heal > 0.0:
			m.hp = minf(m.max_hp, m.hp + amount * heal * 3.0)


## Mục tiêu giả có `position` để SkillFx đặt hiệu ứng nổ đúng điểm đã khóa.
class _Point extends RefCounted:
	var position := Vector2.ZERO

	func _init(p: Vector2) -> void:
		position = p


static func _fire_skill(m: Monster, d: Dictionary, dir: Vector2, amount: float) -> void:
	var host: Node = m.host
	var shot := MonsterShot.new()
	shot.host = host
	shot.position = m.position + Vector2(0, -24)
	shot.vel = dir * SHOT_SPEED * 1.1
	shot.damage = amount
	shot.color = SkillFx.palette(d)[0]
	host.fx_layer.add_child(shot)


static func _explode(m: Monster) -> void:
	_tele(m).hide_now()
	var host: Node = m.host
	if host.fx_layer != null:
		Fx.ring(host.fx_layer, m.global_position, 10.0, BOMB_RADIUS, Color(1.0, 0.5, 0.2), 0.4, 0.55, 6.0)
		Fx.burst(host.fx_layer, m.global_position + Vector2(0, -20), Color(1.0, 0.6, 0.25), 16, 150.0, 0.45)
	Sfx.play("hit_big", 0.7)
	if host.player != null and m.position.distance_to(host.player.position) < BOMB_RADIUS:
		host.vitals.take(m.damage * m.dmg_mult() * 2.2, m.global_position)
	m.hp = 0.0
	m._die()


static func _fire(m: Monster) -> void:
	var host: Node = m.host
	if host.player == null:
		return
	var shot := MonsterShot.new()
	shot.host = host
	shot.position = m.position + Vector2(0, -24)
	var target: Vector2 = host.player.position + Vector2(0, -24)
	shot.vel = (target - shot.position).normalized() * SHOT_SPEED
	shot.damage = m.damage * m.dmg_mult() * float(m.kind.get("shot_mult", 0.9))
	shot.drain = float(m.kind.get("shot_drain", 0.0))
	var c: Array = m.kind.get("shot_color", [0.95, 0.8, 0.4])
	shot.color = Color(float(c[0]), float(c[1]), float(c[2]))
	host.fx_layer.add_child(shot)
	Sfx.play("qi", 1.2)


static func _summon(m: Monster) -> void:
	var host: Node = m.host
	var kid := str(m._bt.get("summon_kind", m.kind.get("summon_kind", "goblin")))
	if not Monster.KINDS.has(kid):
		return
	for i in 2:
		var off := Vector2(randf_range(-60.0, 60.0), randf_range(30.0, 70.0))
		var mon := Monster.new()
		mon.minion = true
		mon.master_ref = m
		mon.setup(host, kid, m.position + off)
		host.world.add_child(mon)
		host.monsters.append(mon)
		mon.state = "chase"
	_float_text(m, "Triệu hồi!", Color(0.8, 0.6, 1.0))


# ---------------------------------------------------------------- bị đánh / đánh trúng
## Điều chỉnh sát thương nhận vào (trọng giáp, phản chấn).
static func incoming(m: Monster, dmg: float) -> float:
	# thủ pháp từ Tâm / Thân Pháp V1 của NPC có tên (NpcCombat): né đòn và đỡ đòn
	var df: Dictionary = m.get_meta("npc_defense", {})
	if not df.is_empty():
		if randf() < float(df.get("dodge", 0.0)):
			_float_text(m, "Né!", Color(0.8, 0.95, 1.0))
			return 0.0
		dmg *= 1.0 - float(df.get("guard", 0.0))
	if "armored" in m.behaviors:
		var broken := false
		var rt = m.host.get("cultivation_v1")
		if rt != null and rt.get("engine") != null:
			broken = rt.engine.has_status(str(m.get_instance_id()), "armor_break")
		if not broken:
			dmg *= ARMOR_MULT
			if now() >= float(m._bt.get("armor_note", 0.0)):
				m._bt["armor_note"] = now() + 3.0
				_float_text(m, "Giáp cứng!", Color(0.7, 0.8, 1.0))
	if "phan_chan" in m.elite_affixes and now() >= float(m._bt.get("thorn_cd", 0.0)) and m.host.player != null:
		if m.position.distance_to(m.host.player.position) < 80.0:
			m._bt["thorn_cd"] = now() + 1.5
			m.host.vitals.take(m.damage * 0.25, m.global_position)
	return dmg


## Đòn cận chiến của quái trúng người chơi.
static func on_strike_hit(m: Monster) -> void:
	var host: Node = m.host
	if "drainer" in m.behaviors:
		host.cult.qi = maxf(0.0, host.cult.qi - host.cult.qi_max() * DRAIN_FRAC)
		host.cult.changed.emit()
		m.hp = minf(m.max_hp, m.hp + m.max_hp * 0.1)
		_float_text(m, "Hút linh!", Color(0.7, 0.5, 1.0))
	if "hut_huyet" in m.elite_affixes:
		m.hp = minf(m.max_hp, m.hp + m.damage * 0.3)
	if "doc_nanh" in m.elite_affixes:
		for i in range(1, 4):
			host.get_tree().create_timer(0.8 * float(i)).timeout.connect(func():
				if is_instance_valid(m) and host.vitals.alive():
					host.vitals.take(m.damage * 0.12, m.global_position))


## Gọi mỗi khung hình: nổi giận khi máu thấp, hết hiệu lực buff.
static func passive(m: Monster) -> void:
	var low: float = 0.4 if m.kind_id == "rogue_master" else 0.3
	if ("enrage" in m.behaviors) and not m._enraged and m.hp < m.max_hp * low:
		m._enraged = true
		_float_text(m, "Nổi giận!", Color(1.0, 0.4, 0.3))
	if m._buff_until > 0.0 and now() > m._buff_until:
		m._buff_until = 0.0
