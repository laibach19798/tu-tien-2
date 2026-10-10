extends Node
class_name Wardrobe
## Thời trang: danh mục trang phục, đồ đã sở hữu, đồ đang mặc, và áp bộ đồ lên nhân vật.
## Ảnh lớp trang phục là thang xám (tools/gen_fashion.ps1), màu được tô bằng modulate.

signal changed

const SLOTS := ["hair", "clothes", "dye", "shoes", "head", "waist", "sword"]
# slot không bắt buộc: có thể không mặc món nào
const OPTIONAL_SLOTS := ["dye", "head", "waist", "sword"]
const SLOT_NAMES := {"hair": "Tóc", "clothes": "Áo", "dye": "Nhuộm", "shoes": "Giày", "head": "Đầu", "waist": "Thắt lưng", "sword": "Kiếm đeo"}

# Bộ trang phục: mặc đủ số món trong bộ thì có thưởng (cộng dồn các mốc đã đạt, lấy mốc cao nhất của mỗi bộ).
# pieces: slot -> id món; bonus theo số món: dmg (sát thương), xp (tu vi nhận được), hp (khí huyết tối đa), speed (tốc độ chạy)
const SETS := {
	"giang_ho": {
		"name": "Giang Hồ",
		"pieces": {"clothes": "outfit_lam", "head": "head_band_white", "waist": "waist_gourd", "sword": "sword_iron"},
		"bonus": {2: {"speed": 0.06}, 4: {"speed": 0.12, "hp": 0.10}},
	},
	"kiem_tu": {
		"name": "Kiếm Tu",
		"pieces": {"clothes": "outfit_do", "head": "head_band_red", "shoes": "shoes_boot_black", "sword": "sword_black"},
		"bonus": {2: {"dmg": 0.08}, 4: {"dmg": 0.22, "speed": 0.05}},
	},
	"dao_si": {
		"name": "Đạo Sĩ",
		"pieces": {"clothes": "outfit_trang", "hair": "hair_topknot_silver", "head": "head_crown_gold", "waist": "waist_jade", "shoes": "shoes_cloth_white"},
		"bonus": {2: {"xp": 0.10}, 3: {"xp": 0.18, "hp": 0.08}, 5: {"xp": 0.30, "hp": 0.15}},
	},
	"tien_nhan": {
		"name": "Tiên Nhân",
		"pieces": {"clothes": "tien_bao_bach_van", "hair": "hair_long_silver", "head": "head_halo", "waist": "waist_jade_white", "sword": "sword_frost"},
		"bonus": {3: {"xp": 0.15, "dmg": 0.10}, 5: {"xp": 0.35, "dmg": 0.25, "hp": 0.20}},
	},
}
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
}

const STARTER := {"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"}

var owned: Array = []
var equipped: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	owned = STARTER.values()
	equipped = STARTER.duplicate()


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
			out.append({"id": id, "chance": float(d.get("chance", 0.0))})
	return out

## Thêm món vào kho (không tốn linh thạch). Trả true nếu vừa mới có.
func grant(id: String) -> bool:
	if not ITEMS.has(id) or owned.has(id):
		return false
	owned.append(id)
	changed.emit()
	return true

func buy(id: String, inv: Inventory) -> bool:
	if is_owned(id) or ITEMS[id].has("unlock") or ITEMS[id].has("drop") or not inv.spend_stones(int(ITEMS[id]["price"])):   # món mở khóa bằng nhiệm vụ không mua được
		return false
	owned.append(id)
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
	return {"owned": owned, "equipped": equipped}


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
	changed.emit()


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
