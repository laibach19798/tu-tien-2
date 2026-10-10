extends RefCounted
class_name Maps
## Các map phụ (khu săn quái). Thế giới gốc ("overworld": làng, Hắc Lâm, Kiếm Tông...) không còn quái;
## muốn săn phải đi qua cổng dịch chuyển vào một trong các map dưới đây, và cổng trong map đưa về làng.
## Thêm map mới: thêm một mục vào DEFS và một cổng vào OVERWORLD_GATES (xem skill add-map).

# Cổng ở thế giới gốc: pos = nơi đặt cổng, to = id map; người chơi quay về sẽ đứng ở pos + BACK_OFFSET.
const BACK_OFFSET := Vector2(0, 110)
const OVERWORLD_GATES := [
	{"pos": Vector2(220, 800), "to": "soi_linh", "label": "Sói Lĩnh", "tint": Color(0.9, 1.0, 0.7)},
	{"pos": Vector2(430, 2290), "to": "dam_lay", "label": "Đầm Lầy Độc", "tint": Color(0.7, 1.0, 0.6)},
	{"pos": Vector2(3580, 510), "to": "tuyet_coc", "label": "Hắc Lang Cốc", "tint": Color(0.7, 0.9, 1.0)},
	{"pos": Vector2(3340, 2310), "to": "linh_mach_dong", "label": "Linh Mạch Động", "tint": Color(0.6, 0.9, 1.0)},
]

# Mỗi map:
#  name, size, music (theme của Sfx), surface (tiếng bước chân), entry (chỗ đến), ground/ground2/path_col (màu dự phòng khi thiếu ảnh),
#  tiles: tên bộ ảnh nền trong assets/ground/<tên>_<base|alt|path|rock>_<0..3>.png (alt/rock rải theo nhiễu, path dọc đường mòn), alt_blocks: ô alt chặn đường đi,
#  path: các đường mòn [[điểm...]], path_w; props: [{n, count, block, sc, tint, margin}], border: {names, step, rows, block},
#  groups: [[loại quái, tâm, số con]], qi: linh mạch, herbs: số linh thảo, safe: [[tâm, bán kính]],
#  gates: cổng ra, areas: tên vùng cho bản đồ nhỏ, mm: màu nền bản đồ nhỏ.
const DEFS := {
	"soi_linh": {
		"name": "Sói Lĩnh", "size": Vector2(2560, 1792), "music": "forest", "surface": "grass",
		"entry": Vector2(250, 900),
		"ground": Color(0.42, 0.62, 0.36), "ground2": Color(0.55, 0.62, 0.34), "path_col": Color(0.78, 0.66, 0.46), "rock_col": Color(0.52, 0.55, 0.52),
		"tiles": "meadow",
		"path": [[Vector2(150, 900), Vector2(700, 880), Vector2(1250, 960), Vector2(1800, 820), Vector2(2350, 880)]], "path_w": 100.0,
		"props": [
			{"n": "tree_a", "count": 40, "block": Vector2(44, 30)},
			{"n": "tree_b", "count": 30, "block": Vector2(44, 30)},
			{"n": "tree_big", "count": 18, "block": Vector2(54, 34)},
			{"n": "rock_a", "count": 24, "block": Vector2(50, 26)},
			{"n": "rock_b", "count": 16, "block": Vector2(50, 26)},
			{"n": "bush_a", "count": 36, "block": Vector2(30, 14)},
			{"n": "bush_b", "count": 24, "block": Vector2(30, 14)},
			{"n": "flower_white", "count": 50},
			{"n": "flower_pink", "count": 40},
			{"n": "cliff_a", "count": 8, "block": Vector2(70, 40)},
		],
		"border": {"names": ["tree_big", "tree_a", "tree_b", "tree_c"], "step": 150, "rows": 2, "block": Vector2(44, 30)},
		"groups": [
			["wolf", Vector2(800, 520), 3], ["wolf", Vector2(1500, 1350), 3], ["wolf", Vector2(2150, 500), 3],
			["goblin", Vector2(1250, 560), 2], ["goblin", Vector2(1900, 1250), 2],
		],
		"qi": [{"pos": Vector2(1280, 1300), "r": 150.0, "density": 2.5}],
		"herbs": 14,
		"safe": [[Vector2(250, 900), 170.0]],
		"gates": [{"pos": Vector2(140, 900), "to": "overworld", "label": "Về làng", "tint": Color(0.9, 1.0, 0.7)}],
		"areas": [[Vector2(250, 900), 200.0, "Cổng về làng"], [Vector2(800, 520), 320.0, "Gò sói tây bắc"], [Vector2(1500, 1350), 320.0, "Gò sói nam"],
			[Vector2(2150, 500), 320.0, "Gò sói đông bắc"], [Vector2(1900, 1250), 300.0, "Triền yêu quái"]],
		"mm": Color(0.40, 0.58, 0.34),
	},
	"dam_lay": {
		"name": "Đầm Lầy Độc", "size": Vector2(2304, 1792), "music": "forest", "surface": "grass",
		"entry": Vector2(250, 1500),
		"ground": Color(0.24, 0.34, 0.22), "ground2": Color(0.20, 0.38, 0.30), "path_col": Color(0.40, 0.32, 0.22), "rock_col": Color(0.30, 0.36, 0.28),
		"tiles": "swamp", "alt_blocks": true,
		"path": [[Vector2(140, 1500), Vector2(600, 1420), Vector2(1000, 1000), Vector2(1500, 900), Vector2(2000, 600)]], "path_w": 90.0,
		"props": [
			{"n": "tree_swamp", "count": 36, "block": Vector2(40, 26)},
			{"n": "reeds", "count": 60},
			{"n": "mushroom_giant", "count": 18, "block": Vector2(36, 20)},
			{"n": "skull_stake", "count": 10, "block": Vector2(18, 10)},
			{"n": "dead_tree", "count": 14, "block": Vector2(36, 22)},
			{"n": "rock_a", "count": 12, "block": Vector2(50, 26), "tint": Color(0.7, 0.8, 0.7)},
			{"n": "bush_c", "count": 30, "block": Vector2(30, 14), "tint": Color(0.7, 0.85, 0.6)},
		],
		"border": {"names": ["tree_swamp", "dead_tree"], "step": 140, "rows": 2, "block": Vector2(40, 26)},
		"groups": [
			["goblin", Vector2(900, 400), 3], ["goblin", Vector2(1100, 1350), 3], ["goblin", Vector2(1700, 1300), 2],
			["goblin_elite", Vector2(1750, 450), 2], ["goblin_elite", Vector2(1300, 800), 1],
		],
		"qi": [{"pos": Vector2(1500, 1450), "r": 140.0, "density": 2.0}],
		"herbs": 14,
		"safe": [[Vector2(250, 1500), 170.0]],
		"gates": [{"pos": Vector2(140, 1500), "to": "overworld", "label": "Về làng", "tint": Color(0.7, 1.0, 0.6)}],
		"areas": [[Vector2(250, 1500), 200.0, "Cổng về làng"], [Vector2(900, 400), 300.0, "Bãi bùn tây bắc"], [Vector2(1100, 1350), 300.0, "Bãi bùn nam"],
			[Vector2(1750, 450), 320.0, "Ổ yêu tướng đầm"], [Vector2(1700, 1300), 280.0, "Bãi lau"]],
		"mm": Color(0.26, 0.40, 0.28),
	},
	"tuyet_coc": {
		"name": "Hắc Lang Cốc", "size": Vector2(2560, 1792), "music": "forest", "surface": "grass",
		"entry": Vector2(250, 1400),
		"ground": Color(0.86, 0.9, 0.95), "ground2": Color(0.70, 0.82, 0.92), "path_col": Color(0.70, 0.64, 0.58), "rock_col": Color(0.55, 0.6, 0.68),
		"tiles": "snow",
		"path": [[Vector2(140, 1400), Vector2(700, 1300), Vector2(1200, 1100), Vector2(1700, 800), Vector2(2250, 480)]], "path_w": 100.0,
		"props": [
			{"n": "tree_pine_snow", "count": 46, "block": Vector2(36, 24)},
			{"n": "ice_crystal", "count": 18, "block": Vector2(40, 22)},
			{"n": "rock_a", "count": 16, "block": Vector2(50, 26), "tint": Color(0.82, 0.9, 1.0)},
			{"n": "rock_b", "count": 12, "block": Vector2(50, 26), "tint": Color(0.82, 0.9, 1.0)},
			{"n": "snow_mound", "count": 30},
			{"n": "dead_tree", "count": 10, "block": Vector2(36, 22), "tint": Color(0.85, 0.9, 1.0)},
		],
		"border": {"names": ["tree_pine_snow", "tree_pine_snow", "rock_a", "rock_b"], "step": 140, "rows": 2, "block": Vector2(40, 24), "tint": Color(0.82, 0.9, 1.0)},
		"groups": [
			["wolf_dark", Vector2(900, 700), 3], ["wolf_dark", Vector2(1500, 1350), 3],
			["wolf_king", Vector2(2150, 520), 1],
		],
		"qi": [{"pos": Vector2(1300, 1450), "r": 140.0, "density": 3.0}],
		"herbs": 10,
		"safe": [[Vector2(250, 1400), 170.0]],
		"gates": [{"pos": Vector2(140, 1400), "to": "overworld", "label": "Về làng", "tint": Color(0.7, 0.9, 1.0)}],
		"areas": [[Vector2(250, 1400), 200.0, "Cổng về làng"], [Vector2(900, 700), 320.0, "Sườn tuyết tây"], [Vector2(1500, 1350), 320.0, "Thung lũng băng"],
			[Vector2(2150, 520), 360.0, "Hang ổ Hắc Lang Vương"]],
		"mm": Color(0.78, 0.86, 0.92),
	},
	"linh_mach_dong": {
		"name": "Linh Mạch Động", "size": Vector2(2304, 1664), "music": "cave", "surface": "rock",
		"entry": Vector2(260, 830),
		"ground": Color(0.20, 0.19, 0.27), "ground2": Color(0.18, 0.28, 0.36), "path_col": Color(0.34, 0.30, 0.32), "rock_col": Color(0.26, 0.26, 0.30),
		"tiles": "cave",
		"path": [[Vector2(140, 830), Vector2(700, 780), Vector2(1150, 860), Vector2(1700, 760), Vector2(2150, 800)]], "path_w": 90.0,
		"props": [
			{"n": "stalagmite", "count": 40, "block": Vector2(36, 22)},
			{"n": "crystal", "count": 14, "block": Vector2(50, 26)},
			{"n": "cave_mushroom", "count": 30},
			{"n": "rock_a", "count": 18, "block": Vector2(50, 26), "tint": Color(0.6, 0.6, 0.75)},
			{"n": "rock_b", "count": 12, "block": Vector2(50, 26), "tint": Color(0.6, 0.6, 0.75)},
		],
		"border": {"names": ["stalagmite", "stalagmite", "rock_a", "rock_b"], "step": 120, "rows": 2, "block": Vector2(44, 26), "tint": Color(0.6, 0.6, 0.75)},
		"groups": [
			["goblin_elite", Vector2(900, 400), 2], ["goblin_elite", Vector2(1100, 1250), 2], ["goblin_elite", Vector2(1800, 1200), 2],
		],
		"qi": [{"pos": Vector2(1150, 820), "r": 200.0, "density": 6.0}],
		"herbs": 12,
		"safe": [[Vector2(260, 830), 170.0]],
		"gates": [{"pos": Vector2(140, 830), "to": "overworld", "label": "Ra khỏi động", "tint": Color(0.6, 0.9, 1.0)}],
		"areas": [[Vector2(260, 830), 200.0, "Cửa động"], [Vector2(1150, 820), 300.0, "Tâm linh mạch"], [Vector2(900, 400), 300.0, "Hốc đá bắc"],
			[Vector2(1100, 1250), 300.0, "Hốc đá nam"], [Vector2(1800, 1200), 300.0, "Động sâu"]],
		"mm": Color(0.22, 0.24, 0.32),
	},
}


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func map_name(id: String) -> String:
	return str((DEFS.get(id, {}) as Dictionary).get("name", "Làng"))


## Nơi người chơi đứng khi quay về thế giới gốc từ map id (trước cổng dẫn vào map đó).
static func overworld_landing(id: String) -> Vector2:
	for g in OVERWORLD_GATES:
		if g["to"] == id:
			return (g["pos"] as Vector2) + BACK_OFFSET
	return Vector2(1280, 1100)
