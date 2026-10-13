extends RefCounted
class_name Hell
## Độ khó "địa ngục": mọi hằng số cân bằng toàn cục nằm ở đây (đường cong tu vi, quái, đột phá, tử vong, kinh tế).
## Nguyên tắc: không có gì nhanh. Muốn đổi nhịp cả game chỉ sửa file này, rồi chạy tools/hell_test.gd.

# ---------------------------------------------------------------- tu vi
## Tu vi cần cho tầng 1 của từng cảnh giới (chỉ số = cảnh giới: 1 Luyện Khí .. 5 Hóa Thần).
## Mỗi cảnh giới gấp 3 lần cảnh giới trước; trong cảnh giới mỗi tầng gấp 1,13 lần tầng trước (hết tầng 9 vẫn nhỏ hơn tầng 1 cảnh giới sau).
## Mục tiêu giờ thiền thuần ở linh mạch (mật độ 3 → 12 tu vi/giây): 3, 9, 27, 81, 243 giờ.
const REALM_BASE := [0.0, 8400.0, 25300.0, 76000.0, 228000.0, 683000.0]
const LAYER_GROWTH := 1.13


static func xp_needed(realm: int, layer: int) -> float:
	return float(REALM_BASE[clampi(realm, 1, REALM_BASE.size() - 1)]) * pow(LAYER_GROWTH, float(layer - 1))


# ---------------------------------------------------------------- thiền
## Hệ số theo giờ: ban ngày thuận lợi, đêm khuya khí âm nặng làm chậm hấp thụ. darkness: 0 (ban ngày) .. 1 (đêm).
static func time_factor(darkness: float) -> float:
	return 1.15 - 0.35 * clampf(darkness, 0.0, 1.0)


## Thiền liên tục quá lâu thì linh khí đọng: sau FATIGUE_START giây giảm dần tới FATIGUE_FLOOR vào FATIGUE_END giây.
const FATIGUE_START := 1200.0
const FATIGUE_END := 2400.0
const FATIGUE_FLOOR := 0.6
## Thiền bị gián đoạn dưới giây này thì không tính là nghỉ (tránh bấm F liên tục để lách).
const FATIGUE_REST := 90.0


static func fatigue_factor(run_seconds: float) -> float:
	if run_seconds <= FATIGUE_START:
		return 1.0
	var k := clampf((run_seconds - FATIGUE_START) / (FATIGUE_END - FATIGUE_START), 0.0, 1.0)
	return lerpf(1.0, FATIGUE_FLOOR, k)


# ---------------------------------------------------------------- đột phá
## Tỉ lệ nền khi đột phá từ cảnh giới r lên r+1 (r = 1..4).
const BREAKTHROUGH := {1: 0.60, 2: 0.45, 3: 0.30, 4: 0.20}
## Thất bại: giữ lại tỉ lệ tu vi tầng cuối; và bị trọng thương (giảm hấp thụ) trong INJURY_SECONDS giây.
const FAIL_KEEP := 0.30
const INJURY_SECONDS := 600.0
const INJURY_FACTOR := 0.5


static func breakthrough_chance(realm: int) -> float:
	return float(BREAKTHROUGH.get(realm, 0.1))


# ---------------------------------------------------------------- quái
const MON_HP_MULT := 1.6
const MON_DMG_MULT := 1.35
## Mỗi bậc "tầng nguy hiểm" của khu cộng thêm vào máu / sát thương quái.
const TIER_HP := 0.10
const TIER_DMG := 0.06
## Tu vi nhận từ quái nhân với hệ số này (đường cong tu vi lớn hơn bản gốc rất nhiều).
const XP_K := 30.0
const STONE_MULT := 0.6
const DROP_MULT := 0.7


## Tu vi/phần thưởng theo chênh lệch bậc giữa người chơi và khu: vượt cấp thì giảm nhanh, thấp hơn thì nhỉnh lên.
static func reward_factor(player_step: int, tier: int) -> float:
	var diff := player_step - tier
	if diff > 0:
		return maxf(0.05, 1.0 - 0.20 * float(diff))
	return minf(1.5, 1.0 + 0.08 * float(-diff))


static func monster_hp(base: float, tier: int) -> float:
	return base * MON_HP_MULT * (1.0 + TIER_HP * float(tier))


static func monster_dmg(base: float, tier: int) -> float:
	return base * MON_DMG_MULT * (1.0 + TIER_DMG * float(tier))


# ---------------------------------------------------------------- tinh anh, cao nhân, đồ hiếm
const ELITE_MIN_TIER := 7
const ELITE_DOUBLE_TIER := 17
const MASTER_CHANCE := 0.03          # xác suất có một cao nhân tán tu mỗi lần ghé một bản đồ tầng ≥ 7
## Tỉ lệ rơi tàn quyển (đồ ngon) cho MỖI lần hạ: siêu hiếm. Quái thường 0,2%, tinh anh 2%, cao nhân 30%.
const RARE_NORMAL := 0.002
const RARE_ELITE := 0.02
const RARE_MASTER := 0.30
const RARE_HUYEN := 0.12             # trong số lần rơi, tỉ lệ ra phẩm Huyền (còn lại phẩm Linh)


static func elite_chance(tier: int) -> float:
	return 0.12 if tier >= ELITE_DOUBLE_TIER else 0.08


# ---------------------------------------------------------------- tử vong
const DEATH_STONES := 0.20
const DEATH_XP := 0.15            # tỉ lệ tu vi của tầng đang tu bị mất (không bao giờ tụt tầng)
const DEATH_MATERIALS := ["linh_thao", "soi_nanh", "da_yeu", "yeu_dan", "lang_vuong_nanh"]


# ---------------------------------------------------------------- lịch game
## 1 ngày game = 360 giây thật (Atmosphere.DAY_SECONDS); 1 năm game = 120 ngày = 12 giờ chơi.
## Động phủ đã dùng tái tạo sau 10–20 năm game (120–240 giờ chơi): trong một ván chỉ thấy lại một lần, ở nửa sau.
const DAYS_PER_YEAR := 120


static func date_text(day: int) -> String:
	return "Năm %d, ngày %d" % [(day - 1) / DAYS_PER_YEAR + 1, (day - 1) % DAYS_PER_YEAR + 1]


# ---------------------------------------------------------------- thiên kiếp
## Thời gian (giây) và số tia sét mỗi nhịp theo cảnh giới đang đột phá lên.
static func tribulation_seconds(realm: int) -> float:
	return 30.0 + 10.0 * float(realm)


static func tribulation_damage(realm: int) -> float:
	return 24.0 + 16.0 * float(realm)
