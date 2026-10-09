extends Node
class_name Wardrobe
## Thời trang: danh mục trang phục, đồ đã sở hữu, đồ đang mặc, và áp bộ đồ lên nhân vật.
## Ảnh lớp trang phục là thang xám (tools/gen_fashion.ps1), màu được tô bằng modulate.

signal changed

const SLOTS := ["hair", "clothes", "shoes"]
const SLOT_NAMES := {"hair": "Tóc", "clothes": "Áo", "shoes": "Giày"}

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
	"tien_bao": {"slot": "clothes", "name": "Tiên bào", "style": "test", "full": true, "aura": {"color": Color(1.0, 0.55, 0.2), "color2": Color(1.0, 0.95, 0.6), "outline": 1.0}, "tint": Color(1, 1, 1), "price": 240, "desc": "Tiên bào có hào quang linh lực rực rỡ bao quanh."},
	"outfit_lam": {"slot": "clothes", "name": "Áo lam", "style": "lam", "full": true, "tint": Color(1, 1, 1), "price": 20, "desc": "Áo vải màu lam, giản dị."},
	"outfit_do": {"slot": "clothes", "name": "Áo đỏ thẫm", "style": "do", "full": true, "tint": Color(1, 1, 1), "price": 30, "desc": "Áo vải nhuộm đỏ thẫm."},
	"outfit_luc": {"slot": "clothes", "name": "Áo lục", "style": "luc", "full": true, "tint": Color(1, 1, 1), "price": 30, "desc": "Áo xanh lục như lá trúc."},
	"outfit_vang": {"slot": "clothes", "name": "Áo vàng nghệ", "style": "vang", "full": true, "tint": Color(1, 1, 1), "price": 40, "desc": "Áo vàng nghệ ấm áp."},
	"outfit_tim": {"slot": "clothes", "name": "Áo tím", "style": "tim", "full": true, "tint": Color(1, 1, 1), "price": 50, "desc": "Áo tím nhạt, nhã nhặn."},
	"outfit_trang": {"slot": "clothes", "name": "Áo trắng", "style": "trang", "full": true, "tint": Color(1, 1, 1), "price": 60, "desc": "Áo trắng thanh sạch."},
	"outfit_xam": {"slot": "clothes", "name": "Áo xám tro", "style": "xam", "full": true, "tint": Color(1, 1, 1), "price": 25, "desc": "Áo xám tro kín đáo."},
	"outfit_thanh": {"slot": "clothes", "name": "Áo thanh ngọc", "style": "thanh", "full": true, "tint": Color(1, 1, 1), "price": 50, "desc": "Áo màu xanh ngọc thanh nhã."},
	"tien_bao_bach_van": {"slot": "clothes", "name": "Tiên bào Bạch Vân", "style": "bachvan", "full": true, "aura": {"color": Color(0.6, 0.9, 1.0), "color2": Color(1.0, 1.0, 1.0), "outline": 1.0}, "tint": Color(1, 1, 1), "price": 300, "desc": "Tiên bào trắng như mây, hào quang xanh băng."},
	"tien_bao_tu_dien": {"slot": "clothes", "name": "Tiên bào Tử Điện", "style": "tudien", "full": true, "aura": {"color": Color(0.7, 0.4, 1.0), "color2": Color(1.0, 0.85, 0.4), "outline": 1.0}, "tint": Color(1, 1, 1), "price": 360, "desc": "Tiên bào tím sẫm, linh lực tím vàng như sấm."},
	# --- Giày ---
	"shoes_cloth_brown": {"slot": "shoes", "name": "Giày vải - nâu", "style": "cloth", "tint": Color(0.50, 0.34, 0.22), "price": 0, "desc": "Giày vải đơn giản."},
	"shoes_cloth_white": {"slot": "shoes", "name": "Giày vải - trắng", "style": "cloth", "tint": Color(0.93, 0.90, 0.84), "price": 20, "desc": "Giày vải trắng sạch sẽ."},
	"shoes_boot_black": {"slot": "shoes", "name": "Hài cao cổ - đen", "style": "boot", "tint": Color(0.20, 0.20, 0.25), "price": 60, "desc": "Hài cao cổ chắc chắn, hợp đường xa."},
	"shoes_boot_gold": {"slot": "shoes", "name": "Hài cao cổ - vàng", "style": "boot", "tint": Color(0.85, 0.66, 0.25), "price": 110, "desc": "Hài thêu chỉ vàng."},
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


func buy(id: String, inv: Inventory) -> bool:
	if is_owned(id) or not inv.spend_stones(int(ITEMS[id]["price"])):
		return false
	owned.append(id)
	changed.emit()
	return true


func equip(id: String) -> void:
	if not is_owned(id):
		return
	equipped[ITEMS[id]["slot"]] = id
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


## Áp bộ đồ (slot -> id) lên một nhân vật dùng prefab base_character.tscn.
static func apply(character: Node, outfit: Dictionary) -> void:
	var hair: Dictionary = ITEMS.get(outfit.get("hair", ""), {})
	var clothes: Dictionary = ITEMS.get(outfit.get("clothes", ""), {})
	var shoes: Dictionary = ITEMS.get(outfit.get("shoes", ""), {})
	_set_layer(character.get_node("HairFront"), "hairf", hair)
	_set_layer(character.get_node("HairBack"), "hairb", hair)
	_set_layer(character.get_node("Clothes"), "clothes", clothes)
	character.get_node("Body").visible = not bool(clothes.get("full", false))   # bộ vẽ cả người che luôn thân trần
	_set_layer(character.get_node("Shoes"), "shoes", shoes)
	_set_aura(character, clothes.get("aura", {}))
	if character.is_inside_tree():
		character._sync_layers()


## Bộ đồ có "aura" (color, color2, outline, rise, trail) thì gắn hào quang; không thì gỡ.
static func _set_aura(character: Node, cfg: Dictionary) -> void:
	var node := character.get_node_or_null("OutfitAura")
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
