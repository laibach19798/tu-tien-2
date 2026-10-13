extends RefCounted
class_name NpcMind
## Ra quyết định của NPC (thiết kế NPC Thông Minh V1.0, bước 3): chấm điểm "độ hợp" của từng hành động ở từng nơi theo
## tính cách, mục tiêu, nhu cầu thật (tiền, hàng đang giữ, vật liệu cần), rủi ro (nguy hiểm so với sức), vết thương gần đây
## và những gì họ BIẾT. Chọn bằng softmax nên không phải lúc nào cũng tối ưu: người ta có thể liều hoặc nhát.
## Lịch `routine` trong dữ liệu chỉ còn là "thiên hướng nghề nghiệp" (prior), không còn là xác suất cố định.
##
## Hành động: rest (nghỉ) · cultivate (tu luyện) · gather (tìm vật liệu) · hunt (săn) · trade (buôn bán) · event (chạy theo sự kiện).
## Mục tiêu (goal_kind trong dữ liệu): wealth · craft · seek · mastery · breakthrough · safety.

const ACTS := ["rest", "cultivate", "gather", "hunt", "trade", "event"]
const GOAL_NAMES := {
	"wealth": "kiếm linh thạch", "craft": "tìm vật liệu luyện chế", "seek": "tầm cơ duyên",
	"mastery": "tôi luyện võ đạo", "breakthrough": "đột phá cảnh giới", "safety": "giữ yên ổn",
}
const ACT_NAMES := {"rest": "nghỉ ngơi", "cultivate": "tu luyện", "gather": "tìm vật liệu", "hunt": "săn yêu thú", "trade": "buôn bán", "event": "chạy theo sự kiện"}
const TEMPERATURE := 0.22


## ctx: traits{6}, prior 0..1, strength, danger, money_need 0..1, holding, goal, place_has_need, injured_days (999 = chưa từng),
##      streak (số lần liên tiếp ở đúng nơi này), event_tpl, righteous_help (sự kiện cần người giúp)
## Trả {"u": điểm, "parts": {lý do: đóng góp}}.
static func utility(act: String, c: Dictionary) -> Dictionary:
	var t: Dictionary = c.get("traits", {})
	var amb := float(t.get("ambition", 50)) / 100.0
	var gre := float(t.get("greed", 50)) / 100.0
	var rig := float(t.get("righteous", 50)) / 100.0
	var cau := float(t.get("caution", 50)) / 100.0
	var agg := float(t.get("aggression", 50)) / 100.0
	var cur := float(t.get("curiosity", 50)) / 100.0
	var goal := str(c.get("goal", ""))
	var need := float(c.get("money_need", 0.0))
	var holding := int(c.get("holding", 0))
	var danger := int(c.get("danger", 1))
	var strength := int(c.get("strength", 2))
	var gap := maxi(0, danger - strength)
	var injured := int(c.get("injured_days", 999)) <= 3
	var parts := {}
	var u := 0.0
	var add := func(label: String, v: float) -> void:
		if absf(v) > 0.001:
			parts[label] = float(parts.get(label, 0.0)) + v
	var prior := float(c.get("prior", 0.0))
	match act:
		"rest":
			u += 0.15
			add.call("nghề nghiệp", prior * 0.6)
			if injured:
				add.call("vừa bị thương", 0.45)
			add.call("thận trọng", cau * 0.2)
			add.call("chưa thiếu thốn", (1.0 - need) * 0.1)
		"cultivate":
			u += 0.1
			add.call("tham vọng", amb * 0.4)
			add.call("mục tiêu đột phá", 0.4 if goal == "breakthrough" else 0.0)
			add.call("hiếu kỳ", cur * 0.1)
			add.call("còn thiếu thốn", -need * 0.35)
			add.call("vừa bị thương", 0.2 if injured else 0.0)
		"gather":
			u += 0.1
			add.call("nghề nghiệp", prior * 0.9)
			add.call("hiếu kỳ", cur * 0.2)
			add.call("thiếu linh thạch", need * (0.15 + gre * 0.3))
			add.call("mục tiêu của họ", 0.3 if goal in ["craft", "wealth"] else 0.0)
			add.call("nơi có thứ họ cần", 0.5 if bool(c.get("place_has_need", false)) else 0.0)
			add.call("ngại nguy hiểm", -float(gap) * (0.2 + cau * 0.5))
			add.call("tham vọng", amb * 0.1 * float(maxi(0, danger - 2)))
			add.call("vừa bị thương", -0.35 if injured else 0.0)
		"hunt":
			u += 0.05
			add.call("nghề nghiệp", prior * 0.9)
			add.call("hiếu chiến", agg * 0.4)
			add.call("tham vọng", amb * 0.15 + amb * 0.1 * float(maxi(0, danger - 2)))
			add.call("mục tiêu tôi luyện", 0.35 if goal == "mastery" else 0.0)
			add.call("thiếu linh thạch", need * gre * 0.25)
			add.call("ngại nguy hiểm", -float(gap) * (0.25 + cau * 0.6))
			add.call("vừa bị thương", -0.45 if injured else 0.0)
		"trade":
			if holding <= 0:
				return {"u": -1.0, "parts": {}}
			u += 0.2
			add.call("đang giữ hàng", 0.16 * float(mini(holding, 6)))
			add.call("thiếu linh thạch", need * 0.35)
			add.call("tham lam", gre * minf(1.0, float(holding) / 4.0) * 0.25)
			add.call("nghề nghiệp", prior * 0.5)
		"event":
			u += 0.12
			add.call("hiếu kỳ", cur * 0.4)
			add.call("tham lam", gre * 0.3)
			add.call("tham vọng", amb * 0.25)
			add.call("mục tiêu tầm cơ duyên", 0.4 if goal == "seek" else 0.0)
			if bool(c.get("righteous_help", false)):
				add.call("trọng nghĩa", rig * 0.35)
			if str(c.get("event_tpl", "")) in ["yeu_thu_tinh_anh", "xung_dot_de_tu"]:
				add.call("hiếu chiến", agg * 0.2)
			add.call("ngại nguy hiểm", -float(gap) * (0.2 + cau * 0.55))
			add.call("vừa bị thương", -0.5 if injured else 0.0)
	var streak := int(c.get("streak", 0))
	if streak > 0 and act in ["gather", "hunt", "event"]:
		add.call("đã đi đi lại lại một nơi", -0.12 * float(streak))
	for k in parts:
		u += float(parts[k])
	return {"u": u, "parts": parts}


## Lý do nổi bật nhất (đóng góp dương lớn nhất, tối đa n), dạng câu ngắn.
static func reasons(parts: Dictionary, n := 2) -> String:
	var items: Array = []
	for k in parts:
		if float(parts[k]) > 0.05:
			items.append([str(k), float(parts[k])])
	items.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var out: Array = []
	for i in mini(n, items.size()):
		out.append(str(items[i][0]))
	return ", ".join(out)


## Chọn một ứng viên theo softmax. rng đã được gieo hạt (tất định).
## cands: [{"act", "loc", "ctx"}]; trả về {"index", "act", "loc", "u", "why"} (index -1 nếu rỗng).
static func choose(cands: Array, rng: RandomNumberGenerator, temperature := TEMPERATURE) -> Dictionary:
	if cands.is_empty():
		return {"index": -1}
	var us: Array = []
	var best := -INF
	for c in cands:
		var r: Dictionary = utility(str(c["act"]), c["ctx"])
		c["score"] = r
		us.append(float(r["u"]))
		best = maxf(best, float(r["u"]))
	var weights: Array = []
	var total := 0.0
	for u in us:
		var w := exp((float(u) - best) / maxf(temperature, 0.01)) if float(u) > -0.5 else 0.0
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var pick := 0
	for i in cands.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			pick = i
			break
	var c: Dictionary = cands[pick]
	return {"index": pick, "act": str(c["act"]), "loc": str(c.get("loc", "")), "u": float(us[pick]), "why": reasons(c["score"]["parts"])}
