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
	{"pos": Vector2(1190, 2360), "to": "tieu_gioi", "label": "Tiểu Thế Giới", "tint": Color(1.0, 0.85, 0.5)},
]

# Mỗi map:
#  name, size, music (theme của Sfx), surface (tiếng bước chân), entry (chỗ đến), ground/ground2/path_col (màu dự phòng khi thiếu ảnh),
#  tiles: tên bộ ảnh nền trong assets/ground/<tên>_<base|alt|path|rock>_<0..3>.png (alt/rock rải theo nhiễu, path dọc đường mòn), alt_blocks: ô alt chặn đường đi,
#  path: các đường mòn [[điểm...]], path_w; props: [{n, count, block, sc, tint, margin}], border: {names, step, rows, block},
#  groups: [[loại quái, tâm, số con]], qi: linh mạch, herbs: số linh thảo, safe: [[tâm, bán kính]],
#  gates: cổng ra, areas: tên vùng cho bản đồ nhỏ, mm: màu nền bản đồ nhỏ.
const BASE_DEFS := {
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
	"tieu_gioi": {
		"name": "Tiểu Thế Giới", "war": true, "size": Vector2(4480, 3200), "music": "sect", "surface": "grass",
		"entry": Vector2(330, 2740),
		"ground": Color(0.42, 0.62, 0.36), "ground2": Color(0.55, 0.62, 0.34), "path_col": Color(0.78, 0.66, 0.46), "rock_col": Color(0.52, 0.55, 0.52),
		"tiles": "meadow",
		"path": [
			[Vector2(190, 2740), Vector2(560, 2700), Vector2(1050, 2500), Vector2(1500, 2450), Vector2(2200, 2600), Vector2(3100, 2400), Vector2(3900, 2560)],
			[Vector2(560, 2600), Vector2(800, 2100), Vector2(1050, 1650), Vector2(1250, 1400), Vector2(1350, 900), Vector2(900, 700), Vector2(560, 700)],
			[Vector2(1350, 900), Vector2(1700, 520), Vector2(2240, 380), Vector2(2800, 600), Vector2(3900, 760)],
			[Vector2(2240, 380), Vector2(2240, 1100), Vector2(2240, 1600), Vector2(2200, 2600)],
			[Vector2(2800, 600), Vector2(3300, 1300), Vector2(3600, 1850), Vector2(3900, 2560)],
			[Vector2(2240, 1600), Vector2(3300, 1300)],
			[Vector2(2240, 1600), Vector2(3100, 2400)],
			[Vector2(1250, 1400), Vector2(2240, 1600)],
		],
		"path_w": 96.0,
		"props": [], "groups": [], "herbs": 30,
		"qi": [{"pos": Vector2(560, 2420), "r": 220.0, "density": 3.0}, {"pos": Vector2(2240, 1600), "r": 260.0, "density": 5.0}],
		"safe": [[Vector2(560, 2560), 340.0]],
		"gates": [{"pos": Vector2(190, 2740), "to": "overworld", "label": "Về làng", "tint": Color(1.0, 0.85, 0.5)}],
		"areas": [
			[Vector2(560, 2560), 380.0, "Kiếm Tông"], [Vector2(560, 700), 380.0, "Xích Viêm Tông"], [Vector2(2240, 380), 380.0, "Hàn Băng Cung"],
			[Vector2(3900, 760), 380.0, "Độc Môn"], [Vector2(3900, 2560), 380.0, "Huyền Minh Giáo"],
			[Vector2(1500, 2450), 260.0, "Linh Tuyền Nam Sơn"], [Vector2(1050, 1650), 260.0, "Trúc Lâm Biên Giới"], [Vector2(1350, 900), 260.0, "Mỏ Hỏa Tinh"],
			[Vector2(1250, 1400), 260.0, "Lò Địa Hỏa"], [Vector2(1700, 520), 260.0, "Băng Tuyền"], [Vector2(2800, 600), 260.0, "Tuyết Đỉnh"],
			[Vector2(3300, 1300), 260.0, "Đầm Độc"], [Vector2(3600, 1850), 260.0, "Vườn Độc Thảo"], [Vector2(3100, 2400), 260.0, "Huyết Trì"],
			[Vector2(3500, 2950), 260.0, "Âm Phủ Động"], [Vector2(2240, 1600), 320.0, "Thiên Mạch"], [Vector2(2200, 2600), 300.0, "Cổ Chiến Trường"],
		],
		"mm": Color(0.40, 0.58, 0.34),
	},
}


# Tông môn: mỗi tông là một map riêng ("sect_<id>", dựng từ khuôn dưới đây), vào bằng cổng duy nhất ở căn cứ tông trong Tiểu Thế Giới.
const COMPOUND_SIZE := Vector2(3600, 2800)
const COMPOUND_ENTRY := Vector2(1800, 2420)
const COMPOUND_GATE := Vector2(1800, 2700)
const COMPOUND_PLATEAU := Rect2(240, 330, 3120, 2430)   # cao nguyên đi được; ngoài là biển mây
# Các điện: foot = chân tòa nhà (giữa-đáy), cửa ở foot + (0, 55). Chức năng của từng điện xem MapBuilder._compound_npcs.
const COMPOUND_HALLS := [
	{"id": "main", "name": "Chưởng Môn Điện", "prop": "hall_main", "foot": Vector2(1800, 980), "sc": 1.9, "block": Vector2(320, 70)},
	{"id": "library", "name": "Tàng Kinh Các", "prop": "hall_library", "foot": Vector2(1000, 1380), "sc": 1.3, "block": Vector2(170, 60)},
	{"id": "war", "name": "Chiến Sự Đường", "prop": "hall_war", "foot": Vector2(2600, 1380), "sc": 1.3, "block": Vector2(240, 60)},
	{"id": "treasure", "name": "Tàng Bảo Các", "prop": "hall_treasure", "foot": Vector2(1000, 1960), "sc": 1.4, "block": Vector2(200, 60)},
	{"id": "alchemy", "name": "Luyện Đan Phòng", "prop": "hall_alchemy", "foot": Vector2(2600, 1960), "sc": 1.45, "block": Vector2(250, 60)},
	{"id": "training", "name": "Diễn Võ Đường", "prop": "hall_training", "foot": Vector2(880, 2480), "sc": 1.3, "block": Vector2(290, 50)},
	{"id": "array", "name": "Trận Pháp Đường", "prop": "hall_array", "foot": Vector2(2720, 2480), "sc": 1.4, "block": Vector2(230, 60)},
	{"id": "meditation", "name": "Linh Tuyền Thiền Viện", "prop": "hall_meditation", "foot": Vector2(520, 720), "sc": 1.45, "block": Vector2(250, 60)},
	{"id": "tailor", "name": "Tàng Y Các", "prop": "hall_tailor", "foot": Vector2(3080, 720), "sc": 1.45, "block": Vector2(200, 60)},
]

# màu dự phòng khi thiếu ảnh nền theo chủ đề
const THEME_COLORS := {
	"meadow": [Color(0.42, 0.62, 0.36), Color(0.55, 0.62, 0.34), Color(0.78, 0.66, 0.46), Color(0.52, 0.55, 0.52)],
	"lava": [Color(0.18, 0.14, 0.14), Color(0.45, 0.2, 0.1), Color(0.45, 0.28, 0.2), Color(0.25, 0.22, 0.22)],
	"snow": [Color(0.86, 0.9, 0.95), Color(0.70, 0.82, 0.92), Color(0.70, 0.64, 0.58), Color(0.55, 0.6, 0.68)],
	"swamp": [Color(0.24, 0.34, 0.22), Color(0.20, 0.38, 0.30), Color(0.40, 0.32, 0.22), Color(0.30, 0.36, 0.28)],
	"cave": [Color(0.20, 0.19, 0.27), Color(0.18, 0.28, 0.36), Color(0.34, 0.30, 0.32), Color(0.26, 0.26, 0.30)],
}

static var DEFS: Dictionary = _make_defs()


static func _make_defs() -> Dictionary:
	var out: Dictionary = BASE_DEFS.duplicate()
	for sid in SectWar.SECTS:
		out["sect_" + str(sid)] = _sect_def(str(sid))
	return out


static func _sect_def(sid: String) -> Dictionary:
	var h: Dictionary = SectWar.SECTS[sid]
	var tc: Array = THEME_COLORS[h["theme"]]
	var areas: Array = [[COMPOUND_GATE, 260.0, "Sơn môn"]]
	var paths: Array = [[COMPOUND_GATE, Vector2(1800, 2300), Vector2(1800, 1020)]]
	for hall in COMPOUND_HALLS:
		areas.append([hall["foot"], 240.0, hall["name"]])
		if hall["id"] == "main":
			continue
		var door: Vector2 = (hall["foot"] as Vector2) + Vector2(0, 60)
		var spine_y: float = door.y - 150.0
		paths.append([Vector2(1800, spine_y), Vector2(door.x, spine_y), door])
	var player := sid == SectWar.PLAYER
	return {
		"name": h["name"], "sect": sid, "size": COMPOUND_SIZE, "music": "cave" if h["theme"] == "cave" else "sect", "surface": "stone",
		"entry": COMPOUND_ENTRY,
		"ground": tc[0], "ground2": tc[1], "path_col": tc[2], "rock_col": tc[3],
		"tiles": h["theme"], "path_theme": "cobble", "path_row": h["pave"],
		"path": paths, "path_w": 120.0,
		"props": [], "groups": [], "herbs": 12 if player else 0,
		"qi": [{"pos": Vector2(520, 800), "r": 300.0, "density": 6.0, "heal": true}] if player else [{"pos": Vector2(520, 800), "r": 260.0, "density": 3.0}],
		"safe": [[Vector2(1800, 1400), 2300.0]] if player else [],
		"border": {"names": ["tree_big", "tree_a", "tree_b", "tree_c"], "step": 150, "rows": 2, "block": Vector2(44, 30)},
		"gates": [{"pos": COMPOUND_GATE, "to": "tieu_gioi", "to_pos": (h["hq"] as Vector2) + Vector2(0, 140), "label": "Rời %s" % h["name"], "tint": h["color"]}],
		"areas": areas,
		"mm": (tc[0] as Color).lerp(Color(0.3, 0.3, 0.35), 0.2),
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
