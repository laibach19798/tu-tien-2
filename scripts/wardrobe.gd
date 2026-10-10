extends Node
class_name Wardrobe
## Thời trang: danh mục trang phục, đồ đã sở hữu, đồ đang mặc, và áp bộ đồ lên nhân vật.
## Ảnh lớp trang phục là thang xám (tools/gen_fashion.ps1), màu được tô bằng modulate.

signal changed
signal title_earned(title_name: String, how: String)   # vừa đạt một danh hiệu mới

const SLOTS := ["hair", "clothes", "dye", "shoes", "head", "waist", "sword"]
# slot không bắt buộc: có thể không mặc món nào
const OPTIONAL_SLOTS := ["dye", "head", "waist", "sword"]
const SLOT_NAMES := {"hair": "Tóc", "clothes": "Áo", "dye": "Nhuộm", "shoes": "Giày", "head": "Đầu", "waist": "Thắt lưng", "sword": "Kiếm đeo"}

# Bộ trang phục: mặc đủ số món trong bộ thì có thưởng (cộng dồn các mốc đã đạt, lấy mốc cao nhất của mỗi bộ).
# pieces: slot -> id món; bonus theo số món: dmg (sát thương), xp (tu vi nhận được), hp (khí huyết tối đa), speed (tốc độ chạy)
const SETS := {
	"giang_ho": {
		"name": "Giang Hồ", "title": "Giang Hồ Khách",
		"pieces": {"clothes": "outfit_lam", "head": "head_band_white", "waist": "waist_gourd", "sword": "sword_iron"},
		"bonus": {2: {"speed": 0.06}, 4: {"speed": 0.12, "hp": 0.10}},
	},
	"kiem_tu": {
		"name": "Kiếm Tu", "title": "Kiếm Tu Hắc Y",
		"pieces": {"clothes": "outfit_do", "head": "head_band_red", "shoes": "shoes_boot_black", "sword": "sword_black"},
		"bonus": {2: {"dmg": 0.08}, 4: {"dmg": 0.22, "speed": 0.05}},
	},
	"dao_si": {
		"name": "Đạo Sĩ", "title": "Đạo Sĩ Thanh Tịnh",
		"pieces": {"clothes": "outfit_trang", "hair": "hair_topknot_silver", "head": "head_crown_gold", "waist": "waist_jade", "shoes": "shoes_cloth_white"},
		"bonus": {2: {"xp": 0.10}, 3: {"xp": 0.18, "hp": 0.08}, 5: {"xp": 0.30, "hp": 0.15}},
	},
	"tien_nhan": {
		"name": "Tiên Nhân", "title": "Tiên Nhân Hạ Phàm",
		"pieces": {"clothes": "tien_bao_bach_van", "hair": "hair_long_silver", "head": "head_halo", "waist": "waist_jade_white", "sword": "sword_frost"},
		"bonus": {3: {"xp": 0.15, "dmg": 0.10}, 5: {"xp": 0.35, "dmg": 0.25, "hp": 0.20}},
	},
	"lang_vuong": {
		"name": "Lang Vương", "title": "Thợ Săn Lang Vương",
		"pieces": {"clothes": "outfit_wolf_king", "waist": "waist_wolf_fang", "head": "head_band_wolf", "shoes": "shoes_boot_wolf", "sword": "sword_wolf"},
		"bonus": {2: {"dmg": 0.06}, 3: {"dmg": 0.12, "speed": 0.04}, 5: {"dmg": 0.25, "hp": 0.10, "speed": 0.06}},
	},
	"linh_mach": {
		"name": "Linh Mạch", "title": "Hành Giả Linh Mạch",
		"pieces": {"clothes": "outfit_linh_mach", "head": "head_pin_crystal", "waist": "waist_crystal", "shoes": "shoes_boot_crystal", "sword": "sword_crystal"},
		"bonus": {2: {"xp": 0.08}, 3: {"xp": 0.15, "hp": 0.08}, 5: {"xp": 0.30, "hp": 0.12, "speed": 0.04}},
	},
}
const REGION_NAMES := {"cave": "Hang Linh Mạch"}
# mốc số trang phục đã sưu tầm -> danh hiệu (danh hiệu theo bộ: SETS[...]["title"])
const MILESTONES := [[15, "Người Mê Y Phục"], [30, "Chủ Nhân Y Quán"], [50, "Thiên Y Vô Phùng"]]
const BONUS_LABELS := {"dmg": "sát thương", "xp": "tu vi nhận được", "hp": "khí huyết", "speed": "tốc độ"}
# style trùng với tên file trong character/fashion/frames/
const ITEMS := {
	# --- Tóc ---
	"hair_topknot_black": {"slot": "hair", "name": "Búi tóc đạo sĩ - đen", "style": "topknot", "tint": Color(0.16, 0.15, 0.20), "price": 0, "desc": "Búi tóc gọn gàng của người mới nhập đạo."},
	"hair_ponytail_black": {"slot": "hair", "name": "Đuôi ngựa - đen", "style": "ponytail", "tint": Color(0.16, 0.15, 0.20), "price": 30, "desc": "Buộc cao, gọn gàng khi tu luyện."},
	"hair_ponytail_brown": {"slot": "hair", "name": "Đuôi ngựa - nâu", "style": "ponytail", "tint": Color(0.46, 0.30, 0.20), "price": 30, "desc": "Màu nâu hạt dẻ."},
	"hair_long_black": {"slot": "hair", "name": "Tóc dài - đen", "style": "long", "tint": Color(0.14, 0.13, 0.18), "price": 45, "desc": "Mái tóc đen xõa dài."},
	"hair_topknot_silver": {"slot": "hair", "name": "Búi tóc - bạc", "style": "topknot", "tint": Color(0.85, 0.88, 0.95), "price": 90, "desc": "Tóc bạc phơ như bậc cao nhân."},
	"hair_long_silver": {"slot": "hair", "name": "Tóc dài - bạc", "style": "long", "tint": Color(0.85, 0.88, 0.95), "price": 140, "desc": "Tóc bạc buông dài, phong thái tiên nhân."},
	# --- Áo ---
	"outfit_plain": {"slot": "clothes", "name": "Áo thường", "style": "test", "full": true, "tint": Color(1, 1, 1), "price": 0, "desc": "Bộ trang phục thường, không có hào quang."},
	"tien_bao": {"slot": "clothes", "unlock": {"quest": "q4"}, "name": "Tiên bào", "style": "test", "full": true, "aura": {"color": Color(1.0, 0.55, 0.2), "color2": Color(1.0, 0.95, 0.6), "outline": 1.0, "qi_cape": true}, "tint": Color(1, 1, 1), "price": 240, "desc": "Tiên bào có hào quang linh lực rực rỡ bao quanh."},
	"outfit_lam": {"slot": "clothes", "name": "Áo vải nhuộm được", "style": "lam", "full": true, "dyeable": true, "tint": Color(1, 1, 1), "price": 20, "desc": "Áo vải màu lam, giản dị."},
	"outfit_do": {"slot": "clothes", "name": "Áo đỏ thẫm", "style": "do", "full": true, "tint": Color(1, 1, 1), "price": 30, "desc": "Áo vải nhuộm đỏ thẫm."},
	"outfit_luc": {"slot": "clothes", "name": "Áo lục", "style": "luc", "full": true, "tint": Color(1, 1, 1), "price": 30, "desc": "Áo xanh lục như lá trúc."},
	"outfit_vang": {"slot": "clothes", "name": "Áo vàng nghệ", "style": "vang", "full": true, "tint": Color(1, 1, 1), "price": 40, "desc": "Áo vàng nghệ ấm áp."},
	"outfit_tim": {"slot": "clothes", "name": "Áo tím", "style": "tim", "full": true, "tint": Color(1, 1, 1), "price": 50, "desc": "Áo tím nhạt, nhã nhặn."},
	"outfit_trang": {"slot": "clothes", "name": "Áo trắng", "style": "trang", "full": true, "tint": Color(1, 1, 1), "price": 60, "desc": "Áo trắng thanh sạch."},
	"outfit_xam": {"slot": "clothes", "drop": {"mob": "goblin", "chance": 0.06}, "name": "Áo xám tro", "style": "xam", "full": true, "tint": Color(1, 1, 1), "price": 25, "desc": "Áo xám tro kín đáo."},
	"outfit_thanh": {"slot": "clothes", "name": "Áo thanh ngọc", "style": "thanh", "full": true, "tint": Color(1, 1, 1), "price": 50, "desc": "Áo màu xanh ngọc thanh nhã."},
	"tien_bao_bach_van": {"slot": "clothes", "unlock": {"quest": "q15"}, "name": "Tiên bào Bạch Vân", "style": "bachvan", "full": true, "aura": {"color": Color(0.6, 0.9, 1.0), "color2": Color(1.0, 1.0, 1.0), "outline": 1.0, "qi_cape": true}, "tint": Color(1, 1, 1), "price": 300, "desc": "Tiên bào trắng như mây, hào quang xanh băng."},
	"tien_bao_tu_dien": {"slot": "clothes", "unlock": {"quest": "q13"}, "name": "Tiên bào Tử Điện", "style": "tudien", "full": true, "aura": {"color": Color(0.7, 0.4, 1.0), "color2": Color(1.0, 0.85, 0.4), "outline": 1.0, "qi_cape": true}, "tint": Color(1, 1, 1), "price": 360, "desc": "Tiên bào tím sẫm, linh lực tím vàng như sấm."},
	# --- Giày ---
	"shoes_cloth_brown": {"slot": "shoes", "name": "Giày vải - nâu", "style": "cloth", "tint": Color(0.50, 0.34, 0.22), "price": 0, "desc": "Giày vải đơn giản."},
	"shoes_cloth_white": {"slot": "shoes", "name": "Giày vải - trắng", "style": "cloth", "tint": Color(0.93, 0.90, 0.84), "price": 20, "desc": "Giày vải trắng sạch sẽ."},
	"shoes_boot_black": {"slot": "shoes", "unlock": {"quest": "q12"}, "name": "Hài cao cổ - đen", "style": "boot", "tint": Color(0.20, 0.20, 0.25), "price": 60, "desc": "Hài cao cổ chắc chắn, hợp đường xa."},
	"shoes_boot_gold": {"slot": "shoes", "drop": {"mob": "wolf_dark", "chance": 0.05}, "name": "Hài cao cổ - vàng", "style": "boot", "tint": Color(0.85, 0.66, 0.25), "price": 110, "desc": "Hài thêu chỉ vàng."},
	# --- Kiếm đeo lưng ---
	"sword_iron": {"slot": "sword", "unlock": {"quest": "q5"}, "name": "Thiết kiếm vỏ nâu", "scabbard": Color(0.30, 0.20, 0.15), "edge": Color(0.52, 0.38, 0.28), "metal": Color(0.95, 0.78, 0.30), "hilt": Color(0.45, 0.28, 0.20), "tint": Color(0.30, 0.20, 0.15), "price": 60, "desc": "Thanh kiếm sắt vỏ gỗ nâu của người mới nhập môn."},
	"sword_black": {"slot": "sword", "unlock": {"quest": "q8"}, "name": "Huyền thiết kiếm", "scabbard": Color(0.13, 0.13, 0.18), "edge": Color(0.30, 0.30, 0.40), "metal": Color(0.92, 0.76, 0.30), "hilt": Color(0.20, 0.18, 0.22), "tint": Color(0.13, 0.13, 0.18), "price": 120, "desc": "Vỏ đen huyền, khoen vàng, trầm mặc."},
	"sword_jade": {"slot": "sword", "name": "Thanh ngọc kiếm", "scabbard": Color(0.18, 0.50, 0.42), "edge": Color(0.55, 0.85, 0.75), "metal": Color(0.90, 0.92, 0.85), "hilt": Color(0.12, 0.35, 0.30), "tint": Color(0.18, 0.50, 0.42), "price": 160, "desc": "Vỏ xanh ngọc khảm bạc, thanh nhã."},
	"sword_frost": {"slot": "sword", "unlock": {"quest": "q15"}, "name": "Hàn Băng kiếm", "scabbard": Color(0.72, 0.86, 0.95), "edge": Color(0.95, 0.98, 1.0), "metal": Color(0.60, 0.85, 1.0), "hilt": Color(0.40, 0.55, 0.75), "glow": Color(0.6, 0.9, 1.0), "tint": Color(0.72, 0.86, 0.95), "price": 280, "desc": "Vỏ trắng xanh toả hàn khí lạnh lẽo."},
	"sword_flame": {"slot": "sword", "unlock": {"quest": "q9"}, "name": "Liệt Hỏa kiếm", "scabbard": Color(0.55, 0.12, 0.10), "edge": Color(0.95, 0.45, 0.20), "metal": Color(1.0, 0.75, 0.25), "hilt": Color(0.30, 0.10, 0.08), "glow": Color(1.0, 0.55, 0.2), "tint": Color(0.55, 0.12, 0.10), "price": 280, "desc": "Vỏ đỏ thẫm, ánh lửa bập bùng quanh lưng."},
	# --- Phụ kiện đầu ---
	"head_band_white": {"slot": "head", "unlock": {"quest": "q1"}, "name": "Khăn buộc trán trắng", "gear": "band", "col": Color(0.95, 0.95, 0.98), "col2": Color(0.95, 0.8, 0.3), "tint": Color(0.95, 0.95, 0.98), "price": 25, "desc": "Khăn trắng buộc trán, đuôi khăn bay theo gió."},
	"head_band_red": {"slot": "head", "unlock": {"quest": "q6"}, "name": "Khăn buộc trán đỏ", "gear": "band", "col": Color(0.78, 0.15, 0.18), "col2": Color(0.95, 0.8, 0.3), "tint": Color(0.78, 0.15, 0.18), "price": 35, "desc": "Khăn đỏ thẫm của kẻ hành tẩu giang hồ."},
	"head_pin_jade": {"slot": "head", "drop": {"mob": "wolf", "chance": 0.04}, "name": "Trâm ngọc cài tóc", "gear": "pin", "col": Color(0.35, 0.8, 0.65), "col2": Color(0.92, 0.9, 0.8), "tint": Color(0.35, 0.8, 0.65), "price": 70, "desc": "Trâm bạc khảm ngọc xanh, tua rủ nhẹ."},
	"head_flower": {"slot": "head", "name": "Hoa đào cài tóc", "gear": "flower", "col": Color(0.98, 0.65, 0.75), "col2": Color(1.0, 0.9, 0.5), "tint": Color(0.98, 0.65, 0.75), "price": 40, "desc": "Đoá hoa đào cài bên tai."},
	"head_crown_gold": {"slot": "head", "unlock": {"quest": "q9"}, "name": "Kim quan", "gear": "crown", "col": Color(0.45, 0.85, 0.7), "col2": Color(0.95, 0.78, 0.3), "tint": Color(0.45, 0.85, 0.7), "price": 150, "desc": "Mão vàng ngọc đỉnh, dành cho bậc chân nhân."},
	"head_mask_fox": {"slot": "head", "drop": {"mob": "goblin_elite", "chance": 0.08}, "name": "Mặt nạ hồ ly nửa mặt", "gear": "mask", "col": Color(0.96, 0.95, 0.92), "col2": Color(0.85, 0.2, 0.2), "tint": Color(0.96, 0.95, 0.92), "price": 120, "desc": "Mặt nạ trắng vằn đỏ che nửa mặt, bí ẩn."},
	"head_halo": {"slot": "head", "unlock": {"quest": "q10"}, "name": "Đạo quang", "gear": "halo", "col": Color(1.0, 0.9, 0.55), "col2": Color(1.0, 1.0, 0.9), "tint": Color(1.0, 0.9, 0.55), "price": 320, "desc": "Vòng sáng lơ lửng trên đỉnh đầu của người đắc đạo."},
	# --- Vật treo thắt lưng ---
	"waist_jade": {"slot": "waist", "name": "Ngọc bội xanh", "kind": "jade", "col": Color(0.35, 0.8, 0.62), "col2": Color(0.95, 0.78, 0.3), "tint": Color(0.35, 0.8, 0.62), "price": 80, "desc": "Ngọc bội xanh buộc dây vàng, tua đỏ lắc lư."},
	"waist_jade_white": {"slot": "waist", "unlock": {"quest": "q10"}, "name": "Bạch ngọc bội", "kind": "jade", "col": Color(0.92, 0.95, 0.95), "col2": Color(0.55, 0.8, 0.95), "tint": Color(0.92, 0.95, 0.95), "price": 140, "desc": "Bạch ngọc trong như sương, tua xanh băng."},
	"waist_bell_copper": {"slot": "waist", "unlock": {"quest": "q2"}, "name": "Chuông đồng", "kind": "bell", "col": Color(0.8, 0.5, 0.2), "col2": Color(0.85, 0.55, 0.25), "tint": Color(0.8, 0.5, 0.2), "price": 60, "desc": "Chuông đồng nhỏ, bước đi leng keng."},
	"waist_bell_silver": {"slot": "waist", "name": "Chuông bạc", "kind": "bell", "col": Color(0.85, 0.88, 0.95), "col2": Color(0.82, 0.86, 0.95), "tint": Color(0.85, 0.88, 0.95), "price": 110, "desc": "Chuông bạc trong trẻo, tiếng ngân dài."},
	"waist_gourd": {"slot": "waist", "unlock": {"quest": "q7"}, "name": "Hồ lô rượu", "kind": "gourd", "col": Color(0.75, 0.5, 0.2), "col2": Color(0.85, 0.2, 0.2), "tint": Color(0.75, 0.5, 0.2), "price": 90, "desc": "Hồ lô đựng rượu, thắt dây đỏ, hợp khách giang hồ."},
	"waist_jade_bell": {"slot": "waist", "drop": {"mob": "goblin_elite", "chance": 0.05}, "name": "Ngọc bội và chuông", "kind": "both", "col": Color(0.35, 0.8, 0.62), "col2": Color(0.95, 0.78, 0.3), "tint": Color(0.35, 0.8, 0.62), "price": 190, "desc": "Một bên ngọc bội, một bên chuông vàng."},
	# --- Thuốc nhuộm (dùng cho áo vải nhuộm được) ---
	"dye_crimson": {"slot": "dye", "name": "Thuốc nhuộm đỏ thẫm", "hue": 355, "sat_mul": 1.15, "val_mul": 1.4, "val_add": 0, "tint": Color(0.62, 0.14, 0.16), "price": 30, "desc": "Nhuộm vải thành đỏ thẫm."},
	"dye_orange": {"slot": "dye", "name": "Thuốc nhuộm cam đất", "hue": 22, "sat_mul": 1.1, "val_mul": 1.5, "val_add": 0.03, "tint": Color(0.85, 0.5, 0.18), "price": 30, "desc": "Màu cam đất của lá thu."},
	"dye_yellow": {"slot": "dye", "name": "Thuốc nhuộm vàng nghệ", "hue": 42, "sat_mul": 1, "val_mul": 1.55, "val_add": 0.05, "tint": Color(0.85, 0.7, 0.2), "price": 35, "desc": "Vàng nghệ ấm áp."},
	"dye_green": {"slot": "dye", "name": "Thuốc nhuộm lục trúc", "hue": 130, "sat_mul": 1.05, "val_mul": 1.35, "val_add": 0, "tint": Color(0.25, 0.62, 0.32), "price": 35, "desc": "Xanh lục như lá trúc."},
	"dye_jade": {"slot": "dye", "name": "Thuốc nhuộm thanh ngọc", "hue": 178, "sat_mul": 1.05, "val_mul": 1.4, "val_add": 0, "tint": Color(0.2, 0.62, 0.55), "price": 40, "desc": "Xanh ngọc thanh nhã."},
	"dye_indigo": {"slot": "dye", "name": "Thuốc nhuộm chàm", "hue": 235, "sat_mul": 1, "val_mul": 0.75, "val_add": 0, "tint": Color(0.22, 0.25, 0.6), "price": 30, "desc": "Chàm đậm, màu áo thầy tu."},
	"dye_violet": {"slot": "dye", "name": "Thuốc nhuộm tím", "hue": 275, "sat_mul": 1, "val_mul": 1.35, "val_add": 0, "tint": Color(0.5, 0.3, 0.7), "price": 45, "desc": "Tím nhạt, nhã nhặn."},
	"dye_pink": {"slot": "dye", "name": "Thuốc nhuộm hồng đào", "hue": 330, "sat_mul": 0.75, "val_mul": 1.55, "val_add": 0.1, "tint": Color(0.9, 0.55, 0.65), "price": 45, "desc": "Hồng đào nhẹ."},
	"dye_white": {"slot": "dye", "name": "Thuốc nhuộm trắng ngà", "hue": 210, "sat_mul": 0.12, "val_mul": 1.25, "val_add": 0.35, "tint": Color(0.92, 0.93, 0.95), "price": 60, "desc": "Trắng ngà thanh sạch."},
	"dye_gray": {"slot": "dye", "name": "Thuốc nhuộm xám tro", "hue": 210, "sat_mul": 0.08, "val_mul": 1, "val_add": 0.1, "tint": Color(0.55, 0.57, 0.6), "price": 25, "desc": "Xám tro kín đáo."},
	"dye_black": {"slot": "dye", "drop": {"mob": "wolf_dark", "chance": 0.1}, "name": "Thuốc nhuộm mực đen", "hue": 250, "sat_mul": 0.15, "val_mul": 0.45, "val_add": 0, "tint": Color(0.12, 0.12, 0.16), "price": 55, "desc": "Đen như mực, trầm mặc."},
	# --- Chỉ rơi từ quái ---
	"waist_wolf_fang": {"slot": "waist", "name": "Nanh sói bội", "drop": {"mob": "wolf", "chance": 0.06}, "kind": "fang", "col": Color(0.95, 0.93, 0.85), "col2": Color(0.8, 0.2, 0.2), "tint": Color(0.95, 0.93, 0.85), "price": 0, "desc": "Chiếc nanh sói đục lỗ xâu dây đỏ, chiến lợi phẩm của kẻ săn sói."},
	"outfit_wolf_king": {"slot": "clothes", "name": "Áo Lang Vương", "drop": {"mob": "wolf_king", "chance": 0.35}, "style": "langvuong", "full": true, "tint": Color(1, 1, 1), "price": 0, "desc": "Áo may từ da Hắc Lang Vương, đỏ sẫm như máu, chỉ rơi từ thủ lĩnh bầy sói."},
	"shoes_boot_wolf": {"slot": "shoes", "name": "Hài Lang Vương", "drop": {"mob": "wolf_king", "chance": 0.3}, "style": "boot", "tint": Color(0.45, 0.10, 0.12), "price": 0, "desc": "Hài cao cổ đỏ sẫm bọc da sói, bước đi êm như thú săn mồi."},
	"head_band_wolf": {"slot": "head", "name": "Khăn trán Lang Vương", "drop": {"mob": "wolf_king", "chance": 0.3}, "gear": "band", "col": Color(0.5, 0.08, 0.1), "col2": Color(0.95, 0.93, 0.85), "tint": Color(0.5, 0.08, 0.1), "price": 0, "desc": "Khăn đỏ sẫm cài nanh sói, đuôi khăn phần phật như bờm sói."},
	"sword_wolf": {"slot": "sword", "name": "Huyết Lang kiếm", "drop": {"mob": "wolf_king", "chance": 0.2}, "scabbard": Color(0.35, 0.08, 0.10), "edge": Color(0.7, 0.2, 0.2), "metal": Color(0.95, 0.9, 0.8), "hilt": Color(0.2, 0.05, 0.07), "glow": Color(1.0, 0.25, 0.2), "tint": Color(0.35, 0.08, 0.10), "price": 0, "desc": "Vỏ kiếm đỏ máu, sát khí của Hắc Lang Vương còn vương lại."},
	# --- Bộ Linh Mạch: chỉ rơi từ yêu tướng canh Hang Linh Mạch ---
	"outfit_linh_mach": {"slot": "clothes", "name": "Áo Linh Mạch", "drop": {"mob": "goblin_elite", "chance": 0.07, "region": "cave"}, "style": "linhmach", "full": true, "tint": Color(1, 1, 1), "price": 0, "desc": "Áo xanh lam thấm linh khí của mạch ngầm, lấp lánh như tinh thạch."},
	"head_pin_crystal": {"slot": "head", "name": "Trâm tinh thạch", "drop": {"mob": "goblin_elite", "chance": 0.12, "region": "cave"}, "gear": "pin", "col": Color(0.45, 0.85, 1.0), "col2": Color(0.9, 0.97, 1.0), "tint": Color(0.45, 0.85, 1.0), "price": 0, "desc": "Trâm cài tóc mài từ tinh thạch trong hang, toả ánh xanh nhạt."},
	"waist_crystal": {"slot": "waist", "name": "Linh tinh bội", "drop": {"mob": "goblin_elite", "chance": 0.12, "region": "cave"}, "kind": "jade", "col": Color(0.4, 0.85, 1.0), "col2": Color(0.85, 0.95, 1.0), "tint": Color(0.4, 0.85, 1.0), "price": 0, "desc": "Bội tinh thạch xanh băng, tua bạc khẽ sáng trong bóng tối."},
	"shoes_boot_crystal": {"slot": "shoes", "name": "Hài tinh thạch", "drop": {"mob": "goblin_elite", "chance": 0.12, "region": "cave"}, "style": "boot", "tint": Color(0.35, 0.65, 0.85), "price": 0, "desc": "Hài cao cổ khảm mảnh tinh thạch, bước nhẹ như lướt trên linh mạch."},
	"sword_crystal": {"slot": "sword", "name": "Tinh Thạch kiếm", "drop": {"mob": "goblin_elite", "chance": 0.06, "region": "cave"}, "scabbard": Color(0.2, 0.45, 0.65), "edge": Color(0.7, 0.95, 1.0), "metal": Color(0.9, 0.98, 1.0), "hilt": Color(0.12, 0.3, 0.45), "glow": Color(0.4, 0.85, 1.0), "tint": Color(0.2, 0.45, 0.65), "price": 0, "desc": "Vỏ kiếm xanh thẫm toả linh quang, rèn từ lõi tinh thạch của hang."},
}

const STARTER := {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"}

var owned: Array = []
var equipped: Dictionary = {}
var earned_titles: Array = []   # "set:<id bộ>" hoặc "mile:<mốc>"
var title := ""                 # danh hiệu đang đeo ("" = không đeo)


func _init() -> void:
	reset()


func reset() -> void:
	owned = STARTER.values()
	equipped = STARTER.duplicate()
	earned_titles = []
	title = ""


static func items_of(slot: String) -> Array:
	var out: Array = []
	for id in ITEMS:
		if ITEMS[id]["slot"] == slot:
			out.append(id)
	return out


func is_owned(id: String) -> bool:
	return owned.has(id)


func is_equipped(id: String) -> bool:
	return equipped.get(ITEMS[id]["slot"], "") == id


## Các món được mở khóa khi hoàn thành nhiệm vụ qid.
static func items_unlocked_by(qid: String) -> Array:
	var out: Array = []
	for id in ITEMS:
		var u: Dictionary = ITEMS[id].get("unlock", {})
		if str(u.get("quest", "")) == qid:
			out.append(id)
	return out


## Các món có thể rơi từ quái loại mob: [{id, chance}].
static func items_dropped_by(mob: String) -> Array:
	var out: Array = []
	for id in ITEMS:
		var d: Dictionary = ITEMS[id].get("drop", {})
		if str(d.get("mob", "")) == mob:
			out.append({"id": id, "chance": float(d.get("chance", 0.0)), "region": str(d.get("region", ""))})
	return out

## Thêm món vào kho (không tốn linh thạch). Trả true nếu vừa mới có.
func grant(id: String) -> bool:
	if not ITEMS.has(id) or owned.has(id):
		return false
	owned.append(id)
	_check_titles(false)
	changed.emit()
	return true


func buy(id: String, inv: Inventory) -> bool:
	if is_owned(id) or ITEMS[id].has("unlock") or ITEMS[id].has("drop") or not inv.spend_stones(int(ITEMS[id]["price"])):   # món mở khóa bằng nhiệm vụ không mua được
		return false
	owned.append(id)
	_check_titles(false)
	changed.emit()
	return true


func equip(id: String) -> void:
	if not is_owned(id):
		return
	equipped[ITEMS[id]["slot"]] = id
	changed.emit()


## Bỏ món đang mặc ở slot không bắt buộc (OPTIONAL_SLOTS, ví dụ kiếm đeo).
func unequip(slot: String) -> void:
	if OPTIONAL_SLOTS.has(slot) and equipped.has(slot):
		equipped.erase(slot)
		changed.emit()


func to_dict() -> Dictionary:
	return {"owned": owned, "equipped": equipped, "titles": earned_titles, "title": title}


func from_dict(d: Dictionary) -> void:
	reset()
	var o: Array = d.get("owned", [])
	for id in o:
		if ITEMS.has(str(id)) and not owned.has(str(id)):
			owned.append(str(id))
	var e: Dictionary = d.get("equipped", {})
	for slot in e:
		var id := str(e[slot])
		if ITEMS.has(id) and owned.has(id) and ITEMS[id]["slot"] == str(slot):
			equipped[str(slot)] = id
	for tid in d.get("titles", []):
		if title_name(str(tid)) != "" and not earned_titles.has(str(tid)):
			earned_titles.append(str(tid))
	_check_titles(true)   # save cũ: tính lại danh hiệu đã đạt, không báo
	if d.has("title"):
		var want := str(d["title"])
		title = want if earned_titles.has(want) else ""
	changed.emit()


## Mô tả cách có được món (rỗng nếu mua được ở tiệm may).
static func acquire_text(id: String, short := false) -> String:
	var d: Dictionary = ITEMS[id]
	if d.has("unlock"):
		var qid := str((d["unlock"] as Dictionary).get("quest", ""))
		var qtitle := qid
		for qd in QuestLog.QUESTS:
			if qd["id"] == qid:
				qtitle = str(qd["title"])
		return ("Nhiệm vụ: %s" if short else "Mở khóa: hoàn thành nhiệm vụ \"%s\"") % qtitle
	if d.has("drop"):
		var dd: Dictionary = d["drop"]
		var mob_name := str((Monster.KINDS.get(str(dd.get("mob", "")), {}) as Dictionary).get("name", "quái"))
		var where := ""
		if dd.has("region"):
			where = " ở %s" % REGION_NAMES.get(str(dd["region"]), "")
		return ("Rơi từ %s%s (%d%%)" if short else "Chỉ rơi từ: %s%s (%d%%)") % [mob_name, where, int(round(float(dd.get("chance", 0.0)) * 100.0))]
	return ""


## Số món của bộ đã có: {have, total, missing: [id món còn thiếu]}.
func set_progress(sid: String) -> Dictionary:
	var pieces: Dictionary = SETS[sid]["pieces"]
	var missing: Array = []
	for slot in pieces:
		if not owned.has(str(pieces[slot])):
			missing.append(str(pieces[slot]))
	return {"have": pieces.size() - missing.size(), "total": pieces.size(), "missing": missing}


## Tên danh hiệu theo id ("" nếu id không hợp lệ).
static func title_name(tid: String) -> String:
	if tid.begins_with("set:"):
		return str((SETS.get(tid.substr(4), {}) as Dictionary).get("title", ""))
	if tid.begins_with("mile:"):
		for m in MILESTONES:
			if "mile:%d" % int(m[0]) == tid:
				return str(m[1])
	return ""


static func title_how(tid: String) -> String:
	if tid.begins_with("set:"):
		return "Thu thập đủ bộ %s" % str((SETS.get(tid.substr(4), {}) as Dictionary).get("name", ""))
	if tid.begins_with("mile:"):
		return "Sưu tầm %d món trang phục" % int(tid.substr(5))
	return ""


## Mọi danh hiệu có thể đạt, theo thứ tự hiển thị.
static func all_title_ids() -> Array:
	var out: Array = []
	for sid in SETS:
		out.append("set:" + str(sid))
	for m in MILESTONES:
		out.append("mile:%d" % int(m[0]))
	return out


func set_title(tid: String) -> void:
	if tid == "" or earned_titles.has(tid):
		title = tid
		changed.emit()


func _check_titles(silent: bool) -> void:
	for tid in all_title_ids():
		if earned_titles.has(tid) or not _title_met(str(tid)):
			continue
		earned_titles.append(tid)
		if title == "":
			title = tid
		if not silent:
			title_earned.emit(title_name(tid), title_how(tid))


func _title_met(tid: String) -> bool:
	if tid.begins_with("set:"):
		return int(set_progress(tid.substr(4))["have"]) == int(set_progress(tid.substr(4))["total"])
	return owned.size() >= int(tid.substr(5))


## Trạng thái các bộ trang phục khi mặc outfit (slot -> id): [{id, name, count, total, bonus(đã đạt), next_need, next_bonus}].
static func set_status(outfit: Dictionary) -> Array:
	var out: Array = []
	for sid in SETS:
		var s: Dictionary = SETS[sid]
		var count := 0
		for slot in s["pieces"]:
			if str(outfit.get(slot, "")) == str(s["pieces"][slot]):
				count += 1
		var tiers: Array = (s["bonus"] as Dictionary).keys()
		tiers.sort()
		var active: Dictionary = {}
		var next_need := 0
		for need in tiers:
			if count >= int(need):
				active = s["bonus"][need]
			elif next_need == 0:
				next_need = int(need)
		out.append({"id": sid, "name": s["name"], "count": count, "total": (s["pieces"] as Dictionary).size(),
			"bonus": active, "next_need": next_need})
	return out


## Tổng thưởng bộ trang phục: {dmg, xp, hp, speed} (0.1 = +10%).
static func total_bonus(outfit: Dictionary) -> Dictionary:
	var sum := {"dmg": 0.0, "xp": 0.0, "hp": 0.0, "speed": 0.0}
	for st in set_status(outfit):
		for k in (st["bonus"] as Dictionary):
			sum[k] = float(sum[k]) + float(st["bonus"][k])
	return sum


## Mô tả ngắn các thưởng đang có: "+8% sát thương, +5% tốc độ".
static func bonus_text(b: Dictionary) -> String:
	var parts: Array = []
	for k in ["dmg", "xp", "hp", "speed"]:
		if float(b.get(k, 0.0)) > 0.0:
			parts.append("+%d%% %s" % [int(round(float(b[k]) * 100.0)), BONUS_LABELS[k]])
	return ", ".join(parts)

## Áp bộ đồ (slot -> id) lên một nhân vật dùng prefab base_character.tscn.
static func apply(character: Node, outfit: Dictionary) -> void:
	var hair: Dictionary = ITEMS.get(outfit.get("hair", ""), {})
	var clothes: Dictionary = ITEMS.get(outfit.get("clothes", ""), {})
	var shoes: Dictionary = ITEMS.get(outfit.get("shoes", ""), {})
	_set_layer(character.get_node("HairFront"), "hairf", hair)
	_set_layer(character.get_node("HairBack"), "hairb", hair)
	_set_layer(character.get_node("Clothes"), "clothes", clothes)
	_set_dye(character.get_node("Clothes"), clothes, ITEMS.get(outfit.get("dye", ""), {}))
	character.get_node("Body").visible = not bool(clothes.get("full", false))   # bộ vẽ cả người che luôn thân trần
	_set_layer(character.get_node("Shoes"), "shoes", shoes)
	_set_aura(character, clothes.get("aura", {}))
	_set_sword(character, ITEMS.get(outfit.get("sword", ""), {}))
	_set_head(character, ITEMS.get(outfit.get("head", ""), {}))
	_set_waist(character, ITEMS.get(outfit.get("waist", ""), {}))
	if character.is_inside_tree():
		character._sync_layers()


const DYE_SHADER := preload("res://scripts/outfit_dye.gdshader")


## Nhuộm áo vải nhuộm được ("dyeable") bằng shader; áo khác hoặc không chọn thuốc thì bỏ nhuộm (không đụng vào shader hào quang).
static func _set_dye(layer: AnimatedSprite2D, clothes: Dictionary, dye: Dictionary) -> void:
	var current := layer.material as ShaderMaterial
	if bool(clothes.get("dyeable", false)) and not dye.is_empty():
		var mat := current if current != null and current.shader == DYE_SHADER else ShaderMaterial.new()
		mat.shader = DYE_SHADER
		mat.set_shader_parameter("hue", float(dye["hue"]))
		mat.set_shader_parameter("sat_mul", float(dye["sat_mul"]))
		mat.set_shader_parameter("val_mul", float(dye["val_mul"]))
		mat.set_shader_parameter("val_add", float(dye["val_add"]))
		layer.material = mat
	elif current != null and current.shader == DYE_SHADER:
		layer.material = null

## Vật treo thắt lưng: node WaistGear (waist_gear.gd); không có món thì gỡ.
static func _set_waist(character: Node, item: Dictionary) -> void:
	var node := character.get_node_or_null("WaistGear")
	if item.is_empty():
		if node != null:
			character.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = preload("res://scripts/waist_gear.gd").new()
		node.name = "WaistGear"
		character.add_child(node)
	node.configure(item)

## Phụ kiện đầu: node HeadGear (head_gear.gd); không có món thì gỡ.
static func _set_head(character: Node, item: Dictionary) -> void:
	var node := character.get_node_or_null("HeadGear")
	if item.is_empty():
		if node != null:
			character.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = preload("res://scripts/head_gear.gd").new()
		node.name = "HeadGear"
		character.add_child(node)
	node.configure(item)

## Kiếm đeo lưng: node BackSword (back_sword.gd) với màu vỏ theo món; không có món thì gỡ.
static func _set_sword(character: Node, item: Dictionary) -> void:
	var node := character.get_node_or_null("BackSword")
	if item.is_empty():
		if node != null:
			character.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = preload("res://scripts/back_sword.gd").new()
		node.name = "BackSword"
		character.add_child(node)
	node.configure_style(item["scabbard"], item["edge"], item["metal"], item["hilt"])
	if item.has("glow"):
		node.glow_color = item["glow"]
		node.glow = 0.5
	else:
		node.glow = 0.0


## Bộ đồ có "aura" (color, color2, outline, rise, trail) thì gắn hào quang; không thì gỡ.
static func _set_aura(character: Node, cfg: Dictionary) -> void:
	var node := character.get_node_or_null("OutfitAura")
	var qi := character.get_node_or_null("QiCape")
	if cfg.is_empty() or not bool(cfg.get("qi_cape", false)):
		if qi != null:   # áo choàng linh khí chỉ có khi aura bật "qi_cape"
			character.remove_child(qi)
			qi.queue_free()
	elif qi == null:
		qi = preload("res://scripts/qi_cape.gd").new()
		qi.name = "QiCape"
		character.add_child(qi)
	if qi != null and not cfg.is_empty():
		qi.configure(cfg)
	if cfg.is_empty():
		if node != null:
			character.remove_child(node)
			node.queue_free()
		return
	if node == null:
		node = preload("res://scripts/outfit_aura.gd").new()
		node.name = "OutfitAura"
		character.add_child(node)
		character.move_child(node, 0)   # vẽ phía sau mọi lớp sprite
	node.configure(cfg, character.get_node("Clothes"))


static func _set_layer(layer: AnimatedSprite2D, prefix: String, item: Dictionary) -> void:
	if item.is_empty():
		layer.sprite_frames = null
		return
	var path := "res://character/hd/frames/%s_%s.tres" % [prefix, item["style"]]
	# có .tres thì dùng; không thì dựng từ PNG theo tên file (SkinLibrary); không có gì thì ẩn lớp
	layer.sprite_frames = load(path) if ResourceLoader.exists(path) else SkinLibrary.build(prefix, item["style"])
	layer.modulate = item["tint"]
