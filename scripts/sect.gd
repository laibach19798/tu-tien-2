extends RefCounted
class_name Sect
## Chức vị trong Kiếm Tông: tính theo tổng điểm cống hiến đã tích luỹ; mỗi lần thăng chức có thưởng.
## Điểm cống hiến nhận từ nhiệm vụ của Kiếm Tông, hạ yêu tướng / Hắc Lang Vương, và nộp nguyên liệu cho Chấp sự.

static var RANKS: Array = _v1_ranks()

static func _v1_ranks() -> Array:
	var data = preload("res://scripts/v1/catalog.gd").data()
	var result: Array = []
	for i in data.ranks.size():
		var reward: Dictionary = data.rank_rewards[i]
		result.append({"name":data.ranks[i],"need":data.balance.rank_thresholds[i],"stones":reward.stones,"items":reward.items})
	return result

## Điểm cống hiến nhận khi hạ quái (chỉ tính khi đã là người của Kiếm Tông).
const KILL_MERIT := {"wolf_dark": 1, "goblin_elite": 3, "wolf_king": 40, "sect_disciple": 2, "sect_elder": 8, "sect_master": 120}

## Hàng của Tàng Bảo Các: "item" = vật phẩm trong túi, "wear" = trang phục (id trong Wardrobe.ITEMS). cost = điểm cống hiến, rank = chức vị tối thiểu.
const SHOP := [
	{"kind": "wear", "id": "sword_thanh_huyen", "cost": 2500, "rank": 4},
	{"kind": "item", "id": "dan_tu_khi", "cost": 3, "rank": 0},
	{"kind": "item", "id": "dan_hoi_huyet", "cost": 4, "rank": 0},
	{"kind": "item", "id": "dan_tu_vi", "cost": 12, "rank": 0},
	{"kind": "item", "id": "dan_ho_the", "cost": 20, "rank": 1},
	{"kind": "item", "id": "dan_kiem_y", "cost": 30, "rank": 1},
	{"kind": "wear", "id": "shoes_boot_gold", "cost": 60, "rank": 1},
	{"kind": "item", "id": "dan_truc_co", "cost": 90, "rank": 3},
	{"kind": "wear", "id": "tien_bao_bach_van", "cost": 900, "rank": 4},
	{"kind": "wear", "id": "hair_long_silver", "cost": 100, "rank": 3},
	{"kind": "wear", "id": "tien_bao_tu_dien", "cost": 1800, "rank": 4},
]


static func rank_of(total: int) -> int:
	var r := 0
	for i in RANKS.size():
		if total >= int(RANKS[i]["need"]):
			r = i
	return r


static func rank_name(total: int) -> String:
	return str(RANKS[rank_of(total)]["name"])


## Điểm còn thiếu để lên chức tiếp theo (0 nếu đã tối đa).
static func to_next(total: int) -> int:
	var r := rank_of(total)
	return 0 if r >= RANKS.size() - 1 else int(RANKS[r + 1]["need"]) - total
