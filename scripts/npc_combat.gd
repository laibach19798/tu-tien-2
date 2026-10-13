extends RefCounted
class_name NpcCombat
## Nối bộ pháp V1 của NPC (NpcProfile) vào chiến đấu thật: dựng một Monster hình người mang đúng chiêu, hiệu ứng thủ,
## lối đánh và chỉ số theo cảnh giới của NPC đó (đệ tử Đao Môn đánh bằng đao, tán tu Hồn Đạo bằng thuật hồn...).
##  - Công / Công phụ / Pháp bảo → các chiêu NPC tung (MonsterBehaviors._skill_hook / _cast_skill, dùng chung SkillFx với người chơi).
##  - Tâm / Thân → hiệu ứng thủ: đỡ đòn (guard), né (dodge), hồi máu khi đánh trúng (heal).
##  - Lối đánh (NpcMind) → hành vi di chuyển sẵn có (ném / lao tới / giáp / hút).
##  - Máu và sát thương co giãn theo cảnh giới (Hell.monster_*), không thưởng xp / đồ (là trận giao đấu, không cày được).

const GUARD_EFFECTS := ["dodge_guard", "guard_counter", "kim_than_guard"]
const HEAL_EFFECTS := ["dodge_heal", "break_heal", "blood_heal", "kim_than_heal"]
const STYLE_BEHAVIORS := {
	"approach": [], "range": ["thrower"], "counter": ["armored"], "stack": [], "burst": ["charger"], "survive": ["drainer"],
}
const MAX_GUARD := 0.3
const MAX_DODGE := 0.25
const MAX_HEAL := 0.12


## Chiêu NPC sẽ tung: Công, Công phụ, Pháp bảo đang dùng (có hình dạng), không vượt cảnh giới của họ.
static func skills_of(prog: RefCounted, step: int) -> Array:
	var out: Array = []
	for slot in ["cong", "cong2", "artifact"]:
		var d: Dictionary = prog.def_for(slot)
		if d.is_empty() or not d.has("shape") or int(d.get("need", 0)) > step:
			continue
		if d.get("shape", "") == "summon" and slot == "artifact":
			continue   # pháp bảo triệu hồi chưa hỗ trợ cho NPC
		out.append(d)
	return out


## Thủ pháp từ Tâm Pháp và Thân Pháp: {guard, dodge, heal} (đều 0..max).
static func defenses_of(prog: RefCounted) -> Dictionary:
	var guard := 0.0
	var dodge := 0.0
	var heal := 0.0
	for slot in ["tam", "than"]:
		for e in prog.def_for(slot).get("effects", []):
			var eid := str(e)
			if eid in GUARD_EFFECTS:
				guard += 0.1
			if eid in HEAL_EFFECTS:
				heal += 0.05
			if eid.begins_with("dodge"):
				dodge += 0.07
	return {"guard": minf(guard, MAX_GUARD), "dodge": minf(dodge, MAX_DODGE), "heal": minf(heal, MAX_HEAL)}


## Dựng kẻ giao đấu cho NPC `id` tại `pos`. Trả null nếu thiếu dữ liệu.
static func spawn(main: Node, id: String, pos: Vector2) -> Monster:
	var nw = main.npc_world
	if nw == null:
		return null
	var d: Dictionary = nw.def_of(id)
	var prog = nw.profile_of(id)
	if d.is_empty() or prog == null:
		return null
	var step: int = nw.step_of(id)
	var m := Monster.new()
	m.outfit = (d.get("outfit", {}) as Dictionary).duplicate()
	m.display_name = str(d.get("name", id))
	m.minion = true   # giao đấu: không thưởng, không hồi sinh, không tính nhiệm vụ, không roll tinh anh
	m.setup(main, "npc_duelist", pos)
	# chỉ số theo cảnh giới của NPC (xem balance_to_step)
	m.tier = clampi(int(ceil(float(step) / 3.0)), 1, 12)
	# chiêu thức
	var defs := skills_of(prog, step)
	m.set_meta("npc_skills", defs)
	m.set_meta("npc_id", id)
	m.set_meta("npc_defense", defenses_of(prog))
	m.behaviors = []
	if not defs.is_empty():
		m.behaviors.append("skills")
	var style: String = nw.style_of(id)
	for b in STYLE_BEHAVIORS.get(style, []):
		if b not in m.behaviors:
			m.behaviors.append(b)
	m.set_meta("npc_style", style)
	balance_to_step(m, step, int(d.get("strength", 2)), defs)
	return m


# ---------------------------------------------------------------- cân bằng theo người chơi cùng cảnh giới
## Mô hình dùng chung với tools/npc_duel_sim.gd. Sức người chơi lấy từ build_sim (DPS đơn mục tiêu một Công Pháp ở bậc 12).
const PLAYER_DPS12 := 60.0
const PLAYER_DODGE := 0.4        # người chơi né được 40% sát thương chiêu có dấu báo
const MELEE_DODGE := 0.2
const SKILL_UPTIME := 0.7
const MELEE_FRACTION := 0.5
const FIGHT_SECS := 16.0         # độ dài trận mong muốn giữa người chơi cùng bậc và NPC sức 2 (không né không hồi)
const MELEE_CYCLE := 1.7         # windup + recover của kind npc_duelist


static func player_hp(step: int) -> float:
	return 100.0 + 24.0 * float(step)


static func player_dps(step: int) -> float:
	var rd := float(preload("res://scripts/v1/catalog.gd").balance("realm_damage_per_step"))
	return PLAYER_DPS12 * (1.0 + rd * float(step)) / (1.0 + rd * 12.0)


## R mục tiêu theo sức NPC (người chơi cùng bậc): NPC càng mạnh càng khó. R = thời gian người chơi sống / thời gian cần để hạ NPC.
static func target_ratio(strength: int) -> float:
	return clampf(2.0 - 0.2 * float(strength - 1), 1.2, 2.2)


## Đặt máu và sát thương để một trận với người chơi cùng cảnh giới đạt R mục tiêu, bất kể bộ chiêu cụ thể:
## bộ chiêu quyết định nhịp và kiểu đánh, còn tổng sức uy hiếp được chuẩn hoá theo cảnh giới và sức NPC.
static func balance_to_step(m: Monster, step: int, strength: int, defs: Array) -> void:
	var df: Dictionary = m.get_meta("npc_defense", {})
	var guard := float(df.get("guard", 0.0))
	var dodge := float(df.get("dodge", 0.0))
	var heal := float(df.get("heal", 0.0))
	var eff_hp := player_dps(step) * FIGHT_SECS * (0.8 + 0.1 * float(strength))
	m.max_hp = maxf(40.0, eff_hp * (1.0 - guard) * (1.0 - dodge) / (1.0 + 2.0 * heal))
	m.hp = m.max_hp
	var dps_target := player_hp(step) / (FIGHT_SECS * target_ratio(strength))
	# hệ số: DPS lên người chơi = damage × k
	var k := MELEE_FRACTION * (1.0 - MELEE_DODGE) / MELEE_CYCLE
	for d in defs:
		var cd := maxf(float(d.get("cooldown", 1.0)) * MonsterBehaviors.SKILL_CD_K, MonsterBehaviors.SKILL_CD_MIN)
		k += SKILL_UPTIME * (1.0 - PLAYER_DODGE) * clampf(float(d.get("damage", MonsterBehaviors.SKILL_DMG_REF)) / MonsterBehaviors.SKILL_DMG_REF, 0.8, 2.5) / cd
	m.damage = dps_target / maxf(k, 0.01)
