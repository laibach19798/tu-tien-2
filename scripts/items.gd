extends RefCounted
class_name Items
## Dữ liệu vật phẩm. "xp"/"qi"/"hp": hiệu quả khi dùng; "sell"/"buy": giá bằng linh thạch (0 = không bán/mua).
## "icon": tên biểu tượng điểm ảnh trong UIKit.ICONS; "tint": màu nhuộm biểu tượng (đan dược).

const DATA := {
	"linh_thao": {
		"name": "Linh thảo",
		"desc": "Thảo dược mọc nơi linh khí dồi dào, nguyên liệu luyện đan.",
		"sell": 6, "buy": 0, "usable": false, "icon": "herb",
	},
	"dan_tu_khi": {
		"name": "Tụ Khí Đan",
		"desc": "Hồi 60 linh khí.",
		"sell": 10, "buy": 22, "usable": true, "qi": 60, "icon": "pill", "tint": Color(0.35, 0.68, 0.98),
	},
	"dan_tu_vi": {
		"name": "Dưỡng Nguyên Đan",
		"desc": "Tăng 90 tu vi.",
		"sell": 20, "buy": 45, "usable": true, "xp": 90, "icon": "pill", "tint": Color(0.98, 0.76, 0.25),
	},
	"dan_hoi_huyet": {
		"name": "Hồi Huyết Đan",
		"desc": "Hồi 70 khí huyết.",
		"sell": 16, "buy": 0, "usable": true, "hp": 70, "icon": "pill", "tint": Color(0.92, 0.35, 0.33),
	},
	"soi_nanh": {
		"name": "Nanh sói",
		"desc": "Chiếc nanh sắc của sói hoang. Thương nhân thu mua, cũng dùng để luyện đan.",
		"sell": 8, "buy": 0, "usable": false, "icon": "fang", "tint": Color(0.96, 0.94, 0.86),
	},
	"da_yeu": {
		"name": "Da yêu quái",
		"desc": "Mảnh da dày lấy từ yêu quái núi. Bán được ít linh thạch.",
		"sell": 7, "buy": 0, "usable": false, "icon": "hide", "tint": Color(0.66, 0.46, 0.28),
	},
	"yeu_dan": {
		"name": "Yêu đan",
		"desc": "Hạt nhân linh khí của yêu thú. Nguyên liệu quý để luyện đan, bán được giá.",
		"sell": 30, "buy": 0, "usable": false, "icon": "pill", "tint": Color(0.78, 0.42, 0.96),
	},
	"lang_vuong_nanh": {
		"name": "Nanh Lang Vương",
		"desc": "Chiếc nanh khổng lồ của Hắc Lang Vương. Báu vật hiếm, bán được giá rất cao.",
		"sell": 150, "buy": 0, "usable": false, "icon": "fang", "tint": Color(1.0, 0.55, 0.5),
	},
	"tro_dan": {
		"name": "Tro đan",
		"desc": "Đan hỏng, chỉ còn là nắm tro. Bán chẳng được bao nhiêu.",
		"sell": 1, "buy": 0, "usable": false, "icon": "ash", "tint": Color(0.55, 0.55, 0.6),
	},
}

const SHOP_BUY := ["dan_tu_khi", "dan_tu_vi"]

## Công thức luyện đan: nguyên liệu, thành phẩm, tỉ lệ thành công gốc (cộng thêm theo cảnh giới).
const RECIPES := [
	{"id": "r_tu_khi", "out": "dan_tu_khi", "mats": {"linh_thao": 3}, "chance": 0.90, "time": 1.4},
	{"id": "r_hoi_huyet", "out": "dan_hoi_huyet", "mats": {"linh_thao": 2, "soi_nanh": 1}, "chance": 0.85, "time": 1.6},
	{"id": "r_tu_vi", "out": "dan_tu_vi", "mats": {"linh_thao": 4, "yeu_dan": 1}, "chance": 0.75, "time": 2.2},
]


static func item_name(id: String) -> String:
	return str(DATA.get(id, {}).get("name", id))
