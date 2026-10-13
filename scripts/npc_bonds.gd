extends RefCounted
class_name NpcBonds
## Quan hệ NPC–người chơi gồm 4 chỉ số độc lập (+ sợ hãi) và các loại sự kiện ghi ký ức (thiết kế NPC Thông Minh V1.0, bước 2).
##   Thiện cảm (-100..100)  Tín nhiệm (-100..100)  Ân nghĩa (0..100, đang mắc ơn)  Thù hận (0..100)  Sợ hãi (0..100)
## Thiện cảm chính là `rel` cũ trong trạng thái NPC (nhiều hệ thống khác đã ghi vào đó); bốn chỉ số còn lại nằm ở states[id]["bonds"].
## Tính cách làm lệch mức thay đổi: người trọng nghĩa nhớ ơn nặng hơn, người hiếu chiến ôm hận mạnh hơn, người thận trọng chậm tin...

const STATS := ["affinity", "trust", "debt", "hate", "fear"]
const NAMES := {"affinity": "Thiện cảm", "trust": "Tín nhiệm", "debt": "Ân nghĩa", "hate": "Thù hận", "fear": "Sợ hãi"}
const LIMITS := {"affinity": [-100, 100], "trust": [-100, 100], "debt": [0, 100], "hate": [0, 100], "fear": [0, 100]}

## Mỗi loại sự kiện: d = thay đổi cơ bản của từng chỉ số, imp = độ quan trọng của ký ức (0 thường, 1-3 quan trọng),
## mem = câu NPC nhớ (ngôi thứ nhất), wrong = có phải việc xấu (đặt mốc để thù hận không phai ngay).
const KINDS := {
	"chat": {"d": {"affinity": 1}, "imp": 0, "mem": "Ngươi từng ngồi lại hỏi chuyện ta."},
	"trade": {"d": {"affinity": 1, "trust": 1}, "imp": 0, "mem": "Ngươi mua của ta một món hàng, giá cả phân minh."},
	"gift": {"d": {"affinity": 3, "debt": 3}, "imp": 1, "mem": "Ngươi để lại lễ vật khi ta đang bế quan."},
	"disturb": {"d": {"affinity": -3, "trust": -1}, "imp": 1, "mem": "Ngươi gõ cửa quấy rầy lúc ta bế quan.", "wrong": true},
	"rescue": {"d": {"affinity": 10, "trust": 10, "debt": 25}, "imp": 3, "mem": "Ngươi cứu ta lúc ta bị thương nặng."},
	"help": {"d": {"affinity": 4, "trust": 4, "debt": 6}, "imp": 2, "mem": "Ngươi ra tay giúp ta giải quyết một việc."},
	"robbed": {"d": {"affinity": -25, "trust": -25, "hate": 30, "fear": 5}, "imp": 3, "mem": "Ngươi cướp đồ của ta.", "wrong": true},
	"threat": {"d": {"affinity": -10, "trust": -10, "fear": 15, "hate": 5}, "imp": 2, "mem": "Ngươi ra tay đe doạ ta.", "wrong": true},
	"betray": {"d": {"affinity": -15, "trust": -30, "hate": 15}, "imp": 2, "mem": "Ngươi thất hứa với ta.", "wrong": true},
	"repay": {"d": {"debt": -15, "affinity": 2}, "imp": 1, "mem": "Ta đã báo đáp ơn của ngươi."},
	"favor": {"d": {"affinity": 2}, "imp": 1, "mem": "Ngươi để ta có chuyện thuận lợi."},
	"slight": {"d": {"affinity": -2}, "imp": 1, "mem": "Ngươi làm ta mất mặt hoặc thiệt thòi.", "wrong": true},
	# tin gián tiếp (người thứ ba): nghe đồn thì nhẹ, có bằng chứng thì nặng
	"heard_wrong": {"d": {"affinity": -2, "trust": -6, "fear": 2}, "imp": 1, "mem": "Ta nghe đồn ngươi làm chuyện bất chính."},
	"known_wrong": {"d": {"affinity": -10, "trust": -18, "fear": 4, "hate": 3}, "imp": 2, "mem": "Ta tận mắt hoặc có bằng chứng ngươi làm chuyện bất chính."},
	"heard_good": {"d": {"affinity": 1, "trust": 1}, "imp": 0, "mem": "Ta nghe đồn ngươi từng giúp người."},
	"known_good": {"d": {"affinity": 4, "trust": 4}, "imp": 1, "mem": "Ta biết rõ ngươi từng giúp người."},
}

const TRAIT_FACTORS := {
	# chỉ số: [đặc điểm, nghịch đảo?, nền, biên độ] -> hệ số = nền + (giá trị/100 hoặc 1-giá trị/100) * biên độ, chỉ áp cho mức TĂNG
	"debt": ["righteous", false, 0.6, 0.9],
	"trust": ["caution", true, 0.6, 0.7],
	"hate": ["aggression", false, 0.7, 0.8],
	"fear": ["aggression", true, 0.6, 0.8],
}


static func empty() -> Dictionary:
	return {"trust": 0, "debt": 0, "hate": 0, "fear": 0}


static func clamp_stat(stat: String, v: int) -> int:
	var lim: Array = LIMITS[stat]
	return clampi(v, int(lim[0]), int(lim[1]))


## Thay đổi thực tế cho một loại sự kiện, đã tính tính cách của NPC.
static func scaled(kind: String, traits: Dictionary) -> Dictionary:
	var out := {}
	var base: Dictionary = (KINDS.get(kind, {}) as Dictionary).get("d", {})
	for stat in base:
		var v := float(base[stat])
		if v > 0.0 and TRAIT_FACTORS.has(stat):
			var f: Array = TRAIT_FACTORS[stat]
			var t := float(traits.get(str(f[0]), 50)) / 100.0
			if bool(f[1]):
				t = 1.0 - t
			v *= float(f[2]) + t * float(f[3])
		if stat == "affinity" and v > 0.0 and kind == "gift":
			v *= 0.7 + float(traits.get("greed", 50)) / 100.0 * 0.8   # người tham lam thích quà hơn
		out[stat] = int(roundf(v))
	return out


## Mô tả mức từng chỉ số bằng lời (rỗng nếu không đáng kể).
static func words(stat: String, v: int) -> String:
	match stat:
		"affinity":
			if v <= -40: return "căm ghét"
			if v <= -10: return "không ưa"
			if v >= 40: return "thân thiết"
			if v >= 15: return "có thiện cảm"
			return "xa lạ"
		"trust":
			if v <= -40: return "tuyệt đối không tin"
			if v <= -10: return "nghi ngờ"
			if v >= 40: return "hết lòng tin cậy"
			if v >= 15: return "tin tưởng"
			return "chưa rõ"
		"debt":
			if v >= 50: return "mang ơn rất nặng"
			if v >= 15: return "mang ơn"
			return ""
		"hate":
			if v >= 60: return "thù sâu như biển"
			if v >= 25: return "oán hận"
			if v >= 10: return "còn ấm ức"
			return ""
		"fear":
			if v >= 40: return "e sợ"
			if v >= 15: return "dè chừng"
			return ""
	return ""
