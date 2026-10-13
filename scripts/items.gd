extends RefCounted
class_name Items
## Dữ liệu vật phẩm. "xp"/"qi"/"hp": hiệu quả khi dùng; "sell"/"buy": giá bằng linh thạch (0 = không bán/mua).
## "icon": tên biểu tượng điểm ảnh trong UIKit.ICONS; "tint": màu nhuộm biểu tượng (đan dược).

const DATA := {
	"linh_thao": {
		"name": "Linh thảo",
		"desc": "Thảo dược mọc nơi linh khí dồi dào, nguyên liệu luyện đan.",
		"sell": 6, "buy": 0, "merit": 1, "usable": false, "icon": "herb",
	},
	"dan_tu_khi": {
		"name": "Tụ Khí Đan",
		"desc": "Hồi 60 linh khí.",
		"sell": 10, "buy": 40, "usable": true, "qi": 60, "icon": "pill", "tint": Color(0.35, 0.68, 0.98),
	},
	"dan_tu_vi": {
		"name": "Dưỡng Nguyên Đan",
		"desc": "Tăng 3% tu vi của tầng đang tu. Dùng liên tiếp sẽ kháng dược, hiệu lực giảm dần.",
		"sell": 20, "buy": 120, "usable": true, "xp_frac": 0.03, "icon": "pill", "tint": Color(0.98, 0.76, 0.25),
	},
	"dan_hoi_huyet": {
		"name": "Hồi Huyết Đan",
		"desc": "Hồi 70 khí huyết.",
		"sell": 16, "buy": 0, "usable": true, "hp": 70, "icon": "pill", "tint": Color(0.92, 0.35, 0.33),
	},
	"soi_nanh": {
		"name": "Nanh sói",
		"desc": "Chiếc nanh sắc của sói hoang. Thương nhân thu mua, cũng dùng để luyện đan.",
		"sell": 8, "buy": 0, "merit": 1, "usable": false, "icon": "fang", "tint": Color(0.96, 0.94, 0.86),
	},
	"da_yeu": {
		"name": "Da yêu quái",
		"desc": "Mảnh da dày lấy từ yêu quái núi. Bán được ít linh thạch.",
		"sell": 7, "buy": 0, "merit": 1, "usable": false, "icon": "hide", "tint": Color(0.66, 0.46, 0.28),
	},
	"yeu_dan": {
		"name": "Yêu đan",
		"desc": "Hạt nhân linh khí của yêu thú. Nguyên liệu quý để luyện đan, bán được giá.",
		"sell": 30, "buy": 0, "merit": 5, "usable": false, "icon": "pill", "tint": Color(0.78, 0.42, 0.96),
	},
	"lang_vuong_nanh": {
		"name": "Nanh Lang Vương",
		"desc": "Chiếc nanh khổng lồ của Hắc Lang Vương. Báu vật hiếm, bán được giá rất cao.",
		"sell": 150, "buy": 0, "merit": 40, "usable": false, "icon": "fang", "tint": Color(1.0, 0.55, 0.5),
	},
	"dan_ho_the": {
		"name": "Hộ Thể Đan",
		"desc": "Hồi 220 khí huyết. Đan dược của Kiếm Tông.",
		"sell": 40, "buy": 0, "usable": true, "hp": 220, "icon": "pill", "tint": Color(0.95, 0.5, 0.3),
	},
	"dan_kiem_y": {
		"name": "Kiếm Ý Đan",
		"desc": "Tăng 8% tu vi của tầng đang tu. Đan dược của Kiếm Tông; dùng liên tiếp sẽ kháng dược.",
		"sell": 60, "buy": 0, "usable": true, "xp_frac": 0.08, "icon": "pill", "tint": Color(0.5, 0.92, 0.85),
	},
	"dan_truc_co": {
		"name": "Trúc Cơ Linh Đan",
		"desc": "Tăng 20% tu vi của tầng đang tu; cũng là trợ lực đột phá (+15% tỉ lệ). Chỉ có ở Tàng Bảo Các, dành cho người có chức vị cao.",
		"sell": 200, "buy": 0, "usable": true, "xp_frac": 0.20, "icon": "pill", "tint": Color(1.0, 0.85, 0.4),
	},
	"linh_tuyen_binh": {
		"name": "Bình linh tuyền",
		"desc": "Nước linh tuyền đóng bình. Dùng làm trợ lực khi đột phá (+4% tỉ lệ), không uống được.",
		"sell": 40, "buy": 0, "usable": false, "icon": "pill", "tint": Color(0.5, 0.92, 1.0),
	},
	"thiet_tinh": {
		"name": "Thiết tinh",
		"desc": "Quặng sắt đã nhiễm Kim khí, nguyên liệu rèn đúc cơ bản.",
		"sell": 9, "buy": 0, "merit": 1, "usable": false, "icon": "stone", "tint": Color(0.78, 0.84, 0.95),
	},
	"truc_linh": {
		"name": "Trúc linh",
		"desc": "Đốt trúc ngậm Mộc khí, dùng làm dược dẫn hoặc luyện khí.",
		"sell": 8, "buy": 0, "merit": 1, "usable": false, "icon": "herb", "tint": Color(0.55, 1.0, 0.7),
	},
	"han_thuy_thach": {
		"name": "Hàn thủy thạch",
		"desc": "Đá lạnh ngưng từ nước ngầm, mang Thủy khí.",
		"sell": 10, "buy": 0, "merit": 1, "usable": false, "icon": "stone", "tint": Color(0.55, 0.78, 1.0),
	},
	"xich_hoa_thach": {
		"name": "Xích hỏa thạch",
		"desc": "Đá đỏ còn hơi nóng của địa hỏa, mang Hỏa khí.",
		"sell": 10, "buy": 0, "merit": 1, "usable": false, "icon": "stone", "tint": Color(1.0, 0.55, 0.35),
	},
	"hoang_tho_tinh": {
		"name": "Hoàng thổ tinh",
		"desc": "Tinh thể vàng đất, nặng tay, mang Thổ khí.",
		"sell": 10, "buy": 0, "merit": 1, "usable": false, "icon": "stone", "tint": Color(0.9, 0.78, 0.45),
	},
	"ngan_nien_thao": {
		"name": "Ngàn năm linh thảo",
		"desc": "Linh thảo sống qua ngàn năm, chỉ hé lộ khi trời tối. Khan hiếm.",
		"sell": 90, "buy": 0, "merit": 4, "usable": false, "icon": "herb", "tint": Color(0.7, 0.95, 1.0),
	},
	"linh_mach_tinh": {
		"name": "Tinh thể linh mạch",
		"desc": "Linh khí tụ lại nhiều ngày mới kết thành. Khan hiếm.",
		"sell": 120, "buy": 0, "merit": 5, "usable": false, "icon": "stone", "tint": Color(0.6, 0.95, 1.0),
	},
	"huyen_thiet": {
		"name": "Huyền thiết",
		"desc": "Khoáng đen tím chỉ lộ ra khi vách đá đủ cũ. Rất khan hiếm.",
		"sell": 180, "buy": 0, "merit": 6, "usable": false, "icon": "stone", "tint": Color(0.55, 0.5, 0.75),
	},
	"co_tu_di_vat": {
		"name": "Di vật cổ tu",
		"desc": "Vật còn sót lại của một tu sĩ cổ. Chỉ có một, không tự sinh lại.",
		"sell": 400, "buy": 0, "merit": 10, "usable": false, "icon": "scroll", "tint": Color(1.0, 0.85, 0.5),
	},
	"dan_truc_linh": {
		"name": "Trúc Linh Đan",
		"desc": "Hồi 90 linh khí. Luyện từ trúc linh và linh thảo.",
		"sell": 16, "buy": 0, "usable": true, "qi": 90, "icon": "pill", "tint": Color(0.5, 0.95, 0.65),
	},
	"dan_thiet_cot": {
		"name": "Thiết Cốt Đan",
		"desc": "Hồi 140 khí huyết. Luyện từ thiết tinh và yêu đan.",
		"sell": 26, "buy": 0, "usable": true, "hp": 140, "icon": "pill", "tint": Color(0.75, 0.82, 0.95),
	},
	"dan_han_tam": {
		"name": "Hàn Tâm Đan",
		"desc": "Hồi 150 linh khí, mát lạnh khai mở tâm thần.",
		"sell": 26, "buy": 0, "usable": true, "qi": 150, "icon": "pill", "tint": Color(0.5, 0.78, 1.0),
	},
	"dan_xich_duong": {
		"name": "Xích Dương Đan",
		"desc": "Tăng 4% tu vi của tầng đang tu. Dùng liên tiếp sẽ kháng dược.",
		"sell": 60, "buy": 0, "usable": true, "xp_frac": 0.04, "icon": "pill", "tint": Color(1.0, 0.5, 0.3),
	},
	"dan_hau_tho": {
		"name": "Hậu Thổ Đan",
		"desc": "Hồi 220 khí huyết, dày dặn như đất.",
		"sell": 40, "buy": 0, "usable": true, "hp": 220, "icon": "pill", "tint": Color(0.9, 0.78, 0.45),
	},
	"dan_linh_mach": {
		"name": "Linh Mạch Đan",
		"desc": "Tăng 12% tu vi của tầng đang tu. Luyện từ vật liệu khan hiếm; dùng liên tiếp sẽ kháng dược.",
		"sell": 300, "buy": 0, "usable": true, "xp_frac": 0.12, "icon": "pill", "tint": Color(0.6, 0.95, 1.0),
	},
	"dan_huyen_thiet": {
		"name": "Huyền Thiết Đan",
		"desc": "Hồi 400 khí huyết và 200 linh khí. Rất khó luyện.",
		"sell": 260, "buy": 0, "usable": true, "hp": 400, "qi": 200, "icon": "pill", "tint": Color(0.7, 0.55, 0.95),
	},
	"ban_do_cu": {
		"name": "Bản đồ cũ",
		"desc": "Tấm da vẽ đường đi do thương hội truyền tay. Dùng để biết thêm một nơi chưa rõ (tin đồn đáng tin).",
		"sell": 20, "buy": 70, "usable": true, "special": "map_rumor", "icon": "scroll", "tint": Color(0.85, 0.75, 0.5),
	},
	"ban_do_chi_tiet": {
		"name": "Bản đồ chi tiết",
		"desc": "Bản đồ do thương hội chép tay, ghi cả đường tắt. Dùng để xác nhận hẳn một nơi và lộ thêm một đường tắt.",
		"sell": 70, "buy": 220, "usable": true, "special": "map_discover", "icon": "scroll", "tint": Color(1.0, 0.9, 0.55),
	},
	"tro_dan": {
		"name": "Tro đan",
		"desc": "Đan hỏng, chỉ còn là nắm tro. Bán chẳng được bao nhiêu.",
		"sell": 1, "buy": 0, "usable": false, "icon": "ash", "tint": Color(0.55, 0.55, 0.6),
	},
}

const SHOP_BUY := ["dan_tu_khi", "dan_tu_vi", "ban_do_cu", "ban_do_chi_tiet"]

## Công thức luyện đan: nguyên liệu, thành phẩm, tỉ lệ thành công gốc (cộng thêm theo cảnh giới).
const RECIPES := [
	{"id": "r_tu_khi", "out": "dan_tu_khi", "mats": {"linh_thao": 3}, "chance": 0.80, "time": 2.2},
	{"id": "r_hoi_huyet", "out": "dan_hoi_huyet", "mats": {"linh_thao": 2, "soi_nanh": 1}, "chance": 0.70, "time": 2.6},
	{"id": "r_tu_vi", "out": "dan_tu_vi", "mats": {"linh_thao": 4, "yeu_dan": 1}, "chance": 0.60, "time": 3.4},
	{"id": "r_truc_linh", "out": "dan_truc_linh", "mats": {"truc_linh": 2, "linh_thao": 1}, "chance": 0.85, "time": 2.4},
	{"id": "r_thiet_cot", "out": "dan_thiet_cot", "mats": {"thiet_tinh": 2, "yeu_dan": 1}, "chance": 0.65, "time": 3.0},
	{"id": "r_han_tam", "out": "dan_han_tam", "mats": {"han_thuy_thach": 2, "linh_thao": 1}, "chance": 0.70, "time": 2.8},
	{"id": "r_xich_duong", "out": "dan_xich_duong", "mats": {"xich_hoa_thach": 2, "soi_nanh": 1, "linh_thao": 2}, "chance": 0.55, "time": 3.6},
	{"id": "r_hau_tho", "out": "dan_hau_tho", "mats": {"hoang_tho_tinh": 2, "linh_thao": 2}, "chance": 0.65, "time": 3.0},
	{"id": "r_linh_mach", "out": "dan_linh_mach", "mats": {"ngan_nien_thao": 1, "linh_mach_tinh": 1, "yeu_dan": 1}, "chance": 0.45, "time": 5.0},
	{"id": "r_huyen_thiet", "out": "dan_huyen_thiet", "mats": {"huyen_thiet": 1, "hoang_tho_tinh": 2, "yeu_dan": 2}, "chance": 0.50, "time": 5.0},
]


static func item_name(id: String) -> String:
	return str(DATA.get(id, {}).get("name", id))
