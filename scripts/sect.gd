extends RefCounted
class_name Sect
## Chức vị trong Kiếm Tông: tính theo tổng điểm cống hiến đã tích luỹ; mỗi lần thăng chức có thưởng.
## Điểm cống hiến nhận từ nhiệm vụ của Kiếm Tông, hạ yêu tướng / Hắc Lang Vương, và nộp nguyên liệu cho Chấp sự.

const RANKS := [
	{"name": "Ngoại môn đệ tử", "need": 0, "stones": 0, "items": {}},
	{"name": "Nội môn đệ tử", "need": 100, "stones": 100, "items": {"dan_tu_vi": 2}},
	{"name": "Chân truyền đệ tử", "need": 400, "stones": 300, "items": {"dan_ho_the": 3}},
	{"name": "Hộ pháp Kiếm Tông", "need": 1000, "stones": 800, "items": {"dan_truc_co": 1}},
]

## Điểm cống hiến nhận khi hạ quái (chỉ tính khi đã là người của Kiếm Tông).
const KILL_MERIT := {"wolf_dark": 1, "goblin_elite": 3, "wolf_king": 40}

## Hàng của Tàng Bảo Các: "item" = vật phẩm trong túi, "wear" = trang phục (id trong Wardrobe.ITEMS). cost = điểm cống hiến, rank = chức vị tối thiểu.
const SHOP := [
	{"kind": "item", "id": "dan_tu_khi", "cost": 3, "rank": 0},
	{"kind": "item", "id": "dan_hoi_huyet", "cost": 4, "rank": 0},
	{"kind": "item", "id": "dan_tu_vi", "cost": 12, "rank": 0},
	{"kind": "item", "id": "dan_ho_the", "cost": 20, "rank": 1},
	{"kind": "item", "id": "dan_kiem_y", "cost": 30, "rank": 1},
	{"kind": "wear", "id": "shoes_boot_gold", "cost": 60, "rank": 1},
	{"kind": "item", "id": "dan_truc_co", "cost": 90, "rank": 2},
	{"kind": "wear", "id": "tien_bao_bach_van", "cost": 200, "rank": 2},
	{"kind": "wear", "id": "hair_long_silver", "cost": 100, "rank": 2},
	{"kind": "wear", "id": "tien_bao_tu_dien", "cost": 320, "rank": 3},
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
