extends Node2D
class_name Monster
## Yêu thú: lang thang quanh chỗ ở, thấy người chơi thì đuổi, vung đòn có báo hiệu, bị đánh thì choáng,
## chết thì rơi đồ rồi hồi sinh sau một lúc. Nằm trong group "targets" như mộc nhân (take_hit / hit_center / alive).

signal killed(kind_id: String)

const KINDS := {
	"wolf": {
		"name": "Sói hoang", "hp": 70.0, "dmg": 9.0, "speed": 112.0, "aggro": 250.0, "leash": 560.0,
		"reach": 40.0, "windup": 0.40, "recover": 0.9, "xp": 14.0, "stones": [2, 5],
		"drops": {"soi_nanh": 0.65, "yeu_dan": 0.12}, "frames": "res://character/monsters/wolf/frames.tres",
		"family": "wolf", "behaviors": ["howler"],
		"center": Vector2(0, -22), "shadow": Vector2(22.0, 7.0), "tint": Color(0.62, 0.64, 0.7), "size": 1.0, "bar": -54.0,
	},
	"goblin": {
		"name": "Yêu quái núi", "hp": 110.0, "dmg": 14.0, "speed": 84.0, "aggro": 230.0, "leash": 520.0,
		"reach": 42.0, "windup": 0.55, "recover": 1.1, "xp": 24.0, "stones": [4, 9],
		"drops": {"da_yeu": 0.7, "yeu_dan": 0.22, "linh_thao": 0.3}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin",
		"center": Vector2(0, -36), "shadow": Vector2(24.0, 8.0), "tint": Color(0.45, 0.7, 0.4), "size": 1.3, "bar": -76.0,
	},
	"wolf_dark": {
		"name": "Hắc lang", "hp": 140.0, "dmg": 15.0, "speed": 128.0, "aggro": 280.0, "leash": 620.0,
		"reach": 44.0, "windup": 0.38, "recover": 0.8, "xp": 32.0, "stones": [6, 12],
		"drops": {"soi_nanh": 0.85, "yeu_dan": 0.3}, "frames": "res://character/monsters/wolf/frames.tres",
		"family": "wolf", "behaviors": ["howler"],
		"center": Vector2(0, -24), "shadow": Vector2(24.0, 8.0), "tint": Color(0.4, 0.38, 0.55), "sprite_tint": Color(0.5, 0.46, 0.7), "size": 1.12, "bar": -58.0,
	},
	"goblin_elite": {
		"name": "Yêu tướng", "hp": 260.0, "dmg": 24.0, "speed": 92.0, "aggro": 250.0, "leash": 560.0,
		"reach": 52.0, "windup": 0.6, "recover": 1.0, "xp": 58.0, "stones": [10, 20],
		"drops": {"da_yeu": 0.8, "yeu_dan": 0.55, "linh_thao": 0.4}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin", "behaviors": ["summoner"], "summon_kind": "goblin",
		"center": Vector2(0, -46), "shadow": Vector2(30.0, 10.0), "tint": Color(0.7, 0.4, 0.3), "sprite_tint": Color(1.0, 0.68, 0.58), "size": 1.65, "bar": -94.0,
	},
	"sect_disciple": {
		"name": "Đệ tử", "hp": 170.0, "dmg": 16.0, "speed": 112.0, "aggro": 270.0, "leash": 620.0,
		"reach": 46.0, "windup": 0.5, "recover": 0.9, "xp": 40.0, "stones": [8, 16], "humanoid": true, "respawn": 600.0,
		"drops": {"linh_thao": 0.3, "yeu_dan": 0.12}, "frames": "",
		"center": Vector2(0, -30), "shadow": Vector2(16.0, 6.4), "tint": Color(0.6, 0.6, 0.7), "size": 1.0, "bar": -84.0,
	},
	"sect_elder": {
		"name": "Trưởng lão", "hp": 560.0, "dmg": 30.0, "speed": 122.0, "aggro": 300.0, "leash": 700.0,
		"reach": 56.0, "windup": 0.55, "recover": 0.8, "xp": 160.0, "stones": [40, 70], "humanoid": true, "respawn": 600.0,
		"drops": {"yeu_dan": 0.6, "linh_thao": 0.5}, "frames": "",
		"center": Vector2(0, -30), "shadow": Vector2(18.0, 7.0), "tint": Color(0.8, 0.7, 0.4), "size": 1.0, "bar": -90.0,
	},
	"sect_master": {
		"name": "Tông chủ", "hp": 2200.0, "dmg": 46.0, "speed": 128.0, "aggro": 340.0, "leash": 900.0,
		"reach": 64.0, "windup": 0.6, "recover": 0.75, "xp": 800.0, "stones": [250, 400], "humanoid": true, "boss": true, "respawn": 900.0,
		"drops": {"yeu_dan": 1.0, "linh_thao": 1.0, "dan_hoi_huyet": 0.6}, "frames": "",
		"center": Vector2(0, -34), "shadow": Vector2(20.0, 8.0), "tint": Color(0.9, 0.75, 0.3), "size": 1.0, "bar": -96.0,
	},
	"wolf_king": {
		"name": "Hắc Lang Vương", "hp": 950.0, "dmg": 30.0, "speed": 132.0, "aggro": 340.0, "leash": 820.0,
		"reach": 66.0, "windup": 0.55, "recover": 0.8, "xp": 240.0, "stones": [70, 110], "boss": true, "respawn": 240.0,
		"drops": {"lang_vuong_nanh": 1.0, "yeu_dan": 1.0, "soi_nanh": 1.0}, "frames": "res://character/monsters/wolf/frames.tres",
		"family": "wolf", "behaviors": ["howler", "charger", "enrage"],
		"center": Vector2(0, -42), "shadow": Vector2(40.0, 13.0), "tint": Color(0.85, 0.3, 0.3), "sprite_tint": Color(1.0, 0.55, 0.55), "size": 2.0, "bar": -108.0,
	},
	# ---- loài mới (docs/QUAI_VAT.md): dùng hình sói/goblin có sẵn, khác nhau ở hành vi
	"wolf_charger": {
		"name": "Cuồng lang", "hp": 160.0, "dmg": 16.0, "speed": 120.0, "aggro": 300.0, "leash": 640.0,
		"reach": 44.0, "windup": 0.4, "recover": 0.9, "xp": 40.0, "stones": [6, 12],
		"drops": {"soi_nanh": 0.8, "yeu_dan": 0.3}, "frames": "res://character/monsters/wolf/frames.tres",
		"family": "wolf", "behaviors": ["charger"],
		"center": Vector2(0, -24), "shadow": Vector2(24.0, 8.0), "tint": Color(0.8, 0.4, 0.3), "sprite_tint": Color(1.0, 0.55, 0.45), "size": 1.15, "bar": -58.0,
	},
	"wolf_alpha": {
		"name": "Lang tăng", "hp": 320.0, "dmg": 20.0, "speed": 110.0, "aggro": 320.0, "leash": 640.0,
		"reach": 54.0, "windup": 0.5, "recover": 0.9, "xp": 90.0, "stones": [14, 26],
		"drops": {"soi_nanh": 1.0, "yeu_dan": 0.6}, "frames": "res://character/monsters/wolf/frames.tres",
		"family": "wolf", "behaviors": ["support", "howler"],
		"center": Vector2(0, -34), "shadow": Vector2(34.0, 11.0), "tint": Color(0.5, 0.35, 0.65), "sprite_tint": Color(0.7, 0.5, 1.0), "size": 1.55, "bar": -88.0,
	},
	"goblin_thrower": {
		"name": "Yêu quái ném đá", "hp": 90.0, "dmg": 12.0, "speed": 82.0, "aggro": 320.0, "leash": 560.0,
		"reach": 40.0, "windup": 0.5, "recover": 1.0, "xp": 30.0, "stones": [4, 9],
		"drops": {"da_yeu": 0.6, "yeu_dan": 0.2, "linh_thao": 0.3}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin", "behaviors": ["thrower"], "shot_mult": 1.0, "shot_color": [0.85, 0.75, 0.45],
		"center": Vector2(0, -36), "shadow": Vector2(24.0, 8.0), "tint": Color(0.7, 0.65, 0.3), "sprite_tint": Color(0.95, 0.9, 0.6), "size": 1.2, "bar": -72.0,
	},
	"goblin_bomber": {
		"name": "Yêu quái nổ", "hp": 60.0, "dmg": 26.0, "speed": 112.0, "aggro": 300.0, "leash": 520.0,
		"reach": 30.0, "windup": 0.4, "recover": 0.8, "xp": 26.0, "stones": [3, 7],
		"drops": {"da_yeu": 0.4, "yeu_dan": 0.15}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin", "behaviors": ["bomber"],
		"center": Vector2(0, -34), "shadow": Vector2(22.0, 8.0), "tint": Color(0.9, 0.5, 0.2), "sprite_tint": Color(1.0, 0.6, 0.3), "size": 1.1, "bar": -70.0,
	},
	"goblin_shield": {
		"name": "Yêu quái giáp đá", "hp": 220.0, "dmg": 20.0, "speed": 70.0, "aggro": 240.0, "leash": 520.0,
		"reach": 46.0, "windup": 0.6, "recover": 1.1, "xp": 55.0, "stones": [8, 16],
		"drops": {"da_yeu": 0.9, "yeu_dan": 0.4, "linh_thao": 0.3}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin", "behaviors": ["armored"],
		"center": Vector2(0, -42), "shadow": Vector2(28.0, 10.0), "tint": Color(0.6, 0.65, 0.8), "sprite_tint": Color(0.7, 0.75, 0.95), "size": 1.5, "bar": -88.0,
	},
	"goblin_shaman": {
		"name": "Yêu quái pháp sư", "hp": 120.0, "dmg": 10.0, "speed": 76.0, "aggro": 300.0, "leash": 560.0,
		"reach": 40.0, "windup": 0.6, "recover": 1.2, "xp": 60.0, "stones": [8, 16],
		"drops": {"da_yeu": 0.5, "yeu_dan": 0.5, "linh_thao": 0.5}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "goblin", "behaviors": ["summoner"], "summon_kind": "goblin",
		"center": Vector2(0, -38), "shadow": Vector2(24.0, 8.0), "tint": Color(0.6, 0.4, 0.8), "sprite_tint": Color(0.75, 0.55, 1.0), "size": 1.25, "bar": -76.0,
	},
	"soul_wisp": {
		"name": "Du hồn", "hp": 80.0, "dmg": 10.0, "speed": 72.0, "aggro": 320.0, "leash": 600.0,
		"reach": 40.0, "windup": 0.6, "recover": 1.2, "xp": 45.0, "stones": [5, 12], "humanoid": true, "ghost": true,
		"drops": {"linh_thao": 0.4, "yeu_dan": 0.3}, "frames": "",
		"family": "soul", "behaviors": ["thrower", "drainer"], "shot_mult": 0.7, "shot_drain": 0.06, "shot_color": [0.7, 0.5, 1.0],
		"outfits": [{"hair": "hair_long_silver", "clothes": "outfit_tim", "shoes": "shoes_cloth_white"}],
		"center": Vector2(0, -30), "shadow": Vector2(14.0, 5.0), "tint": Color(0.7, 0.5, 1.0), "size": 1.0, "bar": -84.0,
	},
	"soul_lord": {
		"name": "Quỷ tu", "hp": 300.0, "dmg": 18.0, "speed": 80.0, "aggro": 340.0, "leash": 640.0,
		"reach": 44.0, "windup": 0.6, "recover": 1.0, "xp": 140.0, "stones": [20, 40], "humanoid": true, "ghost": true,
		"drops": {"yeu_dan": 0.6, "linh_thao": 0.5}, "frames": "",
		"family": "soul", "behaviors": ["summoner", "drainer"], "summon_kind": "soul_wisp",
		"outfits": [{"hair": "hair_topknot_black", "clothes": "tien_bao_tu_dien", "shoes": "shoes_boot_black", "head": "head_band_red"}],
		"center": Vector2(0, -30), "shadow": Vector2(16.0, 6.0), "tint": Color(0.5, 0.3, 0.8), "size": 1.0, "bar": -90.0,
	},
	"stone_golem": {
		"name": "Khôi lỗi đá", "hp": 380.0, "dmg": 26.0, "speed": 66.0, "aggro": 300.0, "leash": 700.0,
		"reach": 50.0, "windup": 0.75, "recover": 1.3, "xp": 90.0, "stones": [10, 20], "respawn": 99999.0,
		"drops": {"da_yeu": 0.9, "yeu_dan": 0.4}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "golem", "behaviors": ["armored"],
		"center": Vector2(0, -50), "shadow": Vector2(34.0, 12.0), "tint": Color(0.65, 0.68, 0.75), "sprite_tint": Color(0.7, 0.72, 0.82), "size": 1.8, "bar": -100.0,
	},
	"stone_colossus": {
		"name": "Cự khôi lỗi", "hp": 2400.0, "dmg": 40.0, "speed": 58.0, "aggro": 360.0, "leash": 900.0,
		"reach": 72.0, "windup": 0.9, "recover": 1.4, "xp": 520.0, "stones": [120, 200], "boss": true, "respawn": 99999.0,
		"drops": {"yeu_dan": 1.0, "da_yeu": 1.0}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "golem", "behaviors": ["armored", "charger", "enrage"],
		"center": Vector2(0, -70), "shadow": Vector2(50.0, 17.0), "tint": Color(0.6, 0.6, 0.7), "sprite_tint": Color(0.62, 0.64, 0.78), "size": 2.8, "bar": -140.0,
	},
	"blood_golem": {
		"name": "Huyết khôi lỗi", "hp": 520.0, "dmg": 30.0, "speed": 82.0, "aggro": 320.0, "leash": 700.0,
		"reach": 48.0, "windup": 0.6, "recover": 1.1, "xp": 130.0, "stones": [15, 30], "respawn": 99999.0,
		"drops": {"yeu_dan": 0.6, "da_yeu": 0.7}, "frames": "res://character/monsters/goblin/frames.tres",
		"family": "golem", "behaviors": ["drainer"],
		"center": Vector2(0, -44), "shadow": Vector2(30.0, 11.0), "tint": Color(0.9, 0.3, 0.3), "sprite_tint": Color(1.0, 0.5, 0.5), "size": 1.65, "bar": -92.0,
	},
	"mirror_self": {
		"name": "Bản thân", "hp": 900.0, "dmg": 34.0, "speed": 120.0, "aggro": 500.0, "leash": 1000.0,
		"reach": 50.0, "windup": 0.5, "recover": 0.8, "xp": 600.0, "stones": [150, 250], "humanoid": true, "ghost": true, "boss": true, "respawn": 99999.0,
		"drops": {"yeu_dan": 1.0}, "frames": "",
		"family": "mirror", "behaviors": ["enrage"],
		"outfits": [{"hair": "hair_topknot_black", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"}],
		"center": Vector2(0, -32), "shadow": Vector2(18.0, 7.0), "tint": Color(0.7, 0.85, 1.0), "size": 1.0, "bar": -92.0,
	},
	"rogue_weak": {
		"name": "Tán tu", "hp": 90.0, "dmg": 11.0, "speed": 100.0, "aggro": 260.0, "leash": 560.0,
		"reach": 44.0, "windup": 0.7, "recover": 1.3, "xp": 22.0, "stones": [4, 10], "humanoid": true,
		"drops": {"linh_thao": 0.3, "da_yeu": 0.2}, "frames": "",
		"family": "rogue", "behaviors": ["thrower"], "shot_mult": 0.6, "shot_color": [0.8, 0.9, 1.0],
		"outfits": [
			{"hair": "hair_topknot_black", "clothes": "outfit_xam", "shoes": "shoes_cloth_brown"},
			{"hair": "hair_ponytail_brown", "clothes": "outfit_plain", "shoes": "shoes_cloth_brown"},
			{"hair": "hair_ponytail_black", "clothes": "outfit_luc", "shoes": "shoes_boot_black"},
		],
		"center": Vector2(0, -30), "shadow": Vector2(16.0, 6.4), "tint": Color(0.6, 0.6, 0.6), "size": 1.0, "bar": -84.0,
	},
	# Kẻ giao đấu dựng từ hồ sơ V1 của một NPC có tên (xem NpcCombat): chỉ số, chiêu và lối đánh gán lúc dựng.
	"npc_duelist": {
		"name": "Tu sĩ", "hp": 120.0, "dmg": 14.0, "speed": 112.0, "aggro": 400.0, "leash": 900.0,
		"reach": 48.0, "windup": 0.6, "recover": 1.1, "xp": 0.0, "stones": [0, 0], "humanoid": true,
		"drops": {}, "frames": "",
		"family": "rogue", "behaviors": [], "shot_mult": 0.7, "shot_color": [0.85, 0.95, 1.0],
		"outfits": [{"hair": "hair_topknot_black", "clothes": "outfit_xam", "shoes": "shoes_boot_black"}],
		"center": Vector2(0, -32), "shadow": Vector2(17.0, 6.8), "tint": Color(0.8, 0.85, 0.95), "size": 1.0, "bar": -88.0,
	},
	"rogue_master": {
		"name": "Cao nhân tán tu", "hp": 1500.0, "dmg": 36.0, "speed": 130.0, "aggro": 360.0, "leash": 900.0,
		"reach": 60.0, "windup": 0.5, "recover": 0.7, "xp": 600.0, "stones": [180, 300], "humanoid": true, "boss": true, "respawn": 99999.0,
		"drops": {"yeu_dan": 1.0, "linh_thao": 1.0, "dan_hoi_huyet": 0.8}, "frames": "",
		"family": "rogue_master", "behaviors": ["charger", "thrower", "enrage"], "shot_mult": 0.9, "shot_color": [1.0, 0.95, 0.7], "master": true,
		"outfits": [{"hair": "hair_long_silver", "clothes": "tien_bao_bach_van", "shoes": "shoes_boot_black", "head": "head_crown_gold"}],
		"center": Vector2(0, -34), "shadow": Vector2(20.0, 8.0), "tint": Color(1.0, 0.9, 0.6), "size": 1.0, "bar": -96.0,
	},
}

const RESPAWN := 45.0
var kind_id := "wolf"
var kind: Dictionary = {}
var host: Node
var home := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var alive := true
var state := "idle"
var _sprite: AnimatedSprite2D
var _bar: HealthBar
var _facing := "south"
var _t := 0.0
var _timer := 0.0
var _wander_to := Vector2.ZERO
var _knock := Vector2.ZERO
var _flash := 0.0
var _lunge := Vector2.ZERO
var _struck := false
var _body: Node2D          # kẻ địch hình người: nhân vật nền + trang phục của tông môn
var outfit: Dictionary = {}
var sect_id := ""          # tông môn của kẻ địch hình người
var territory_id := ""     # địa bàn mà con này canh giữ
var _last_motion := ""
var invader := false       # quân xâm lược (tông địch tập kích địa bàn của Kiếm Tông)
var display_name := ""
var behaviors: Array = []      # kind["behaviors"] + hành vi do tinh anh thêm (xem MonsterBehaviors)
var elite := false
var elite_affixes: Array = []
var minion := false            # quái do kẻ khác triệu hồi: không có phần thưởng, không hồi sinh
var master_ref: Monster = null
var _bt: Dictionary = {}       # bộ đếm/ngữ cảnh của hành vi
var _tele: MonsterTelegraph
var _enraged := false
var _buff_until := 0.0
var _buff_spd := 1.0
var _buff_dmg := 1.0
var tier := 0              # tầng nguy hiểm của khu (Maps.DEFS[map].tier): quyết định co giãn máu/sát thương/thưởng
var damage := 0.0          # sát thương đã co giãn (độ khó địa ngục)


func setup(p_host: Node, id: String, p_home: Vector2) -> void:
	host = p_host
	kind_id = id
	kind = KINDS[id]
	home = p_home
	position = p_home
	var map_id: String = str(host.get("current_map")) if host != null and host.get("current_map") != null else ""
	tier = int((Maps.DEFS.get(map_id, {}) as Dictionary).get("tier", 0))
	max_hp = Hell.monster_hp(float(kind["hp"]), tier)
	damage = Hell.monster_dmg(float(kind["dmg"]), tier)
	hp = max_hp
	MonsterBehaviors.setup(self)


func _ready() -> void:
	add_to_group("targets")
	var sh := Shadow.make(float(kind["shadow"].x), float(kind["shadow"].y), 0.34)
	add_child(sh)
	if bool(kind.get("humanoid", false)):
		_body = load("res://character/hd/base_character.tscn").instantiate()
		Wardrobe.apply(_body, outfit)
		add_child(_body)
		if display_name == "" and sect_id == "":
			display_name = str(kind.get("name", ""))
		if elite:
			display_name = MonsterBehaviors.elite_name(self)
		if display_name != "":
			var nl := Label.new()
			nl.text = display_name
			nl.add_theme_font_size_override("font_size", 16)
			nl.add_theme_color_override("font_color", SectWar.sect_color(sect_id).lerp(Color.WHITE, 0.4) if sect_id != "" else (Color(1.0, 0.85, 0.4) if elite or bool(kind.get("master", false)) else Color(0.9, 0.9, 0.95)))
			nl.add_theme_color_override("font_outline_color", Color.BLACK)
			nl.add_theme_constant_override("outline_size", 5)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.custom_minimum_size = Vector2(200, 0)
			nl.position = Vector2(-100, float(kind["bar"]) - 24.0)
			nl.z_index = 5
			add_child(nl)
	elif ResourceLoader.exists(kind["frames"]):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = load(kind["frames"])
		_sprite.position = Vector2(0, -28)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.scale = Vector2.ONE * float(kind["size"])
		_sprite.self_modulate = kind.get("sprite_tint", Color.WHITE)
		add_child(_sprite)
		_play("idle")
		if elite:
			var first: String = str(elite_affixes[0])
			_sprite.self_modulate = (_sprite.self_modulate as Color) * (MonsterBehaviors.ELITE_AFFIXES[first]["tint"] as Color)
			var nl2 := Label.new()
			nl2.text = MonsterBehaviors.elite_name(self)
			nl2.add_theme_font_size_override("font_size", 16)
			nl2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			nl2.add_theme_color_override("font_outline_color", Color.BLACK)
			nl2.add_theme_constant_override("outline_size", 5)
			nl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl2.custom_minimum_size = Vector2(220, 0)
			nl2.position = Vector2(-110, float(kind["bar"]) - 22.0)
			nl2.z_index = 5
			add_child(nl2)
	if elite:
		var ring := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			pts.append(Vector2(cos(a), sin(a) * 0.42) * (float(kind["shadow"].x) + 8.0))
		ring.polygon = pts
		ring.color = Color(1.0, 0.8, 0.3, 0.35)
		ring.material = Fx.additive()
		ring.z_index = -1
		add_child(ring)
	_bar = HealthBar.new()
	_bar.m = self
	_bar.z_index = 4
	add_child(_bar)
	_timer = randf_range(0.5, 2.5)


func hit_center() -> Vector2:
	return global_position + kind["center"]


func take_hit(dmg: float, from: Vector2) -> bool:
	if not alive:
		return false
	dmg = MonsterBehaviors.incoming(self, dmg)
	hp -= dmg
	_flash = 1.0
	var away := (global_position - from).normalized()
	_knock = away * 170.0
	if state != "windup" or randf() < 0.5:   # đang gồng đòn thì không phải lúc nào cũng bị ngắt
		state = "hurt"
		_timer = 0.32
		_struck = false
	_show_number(dmg)
	Sfx.play("mhurt", randf_range(0.9, 1.1))
	if hp <= 0.0:
		_die()
	elif host != null and host.player != null:
		_facing = Dir.from_vector(host.player.position - position, _facing)
	return true


# ---- trạng thái do công pháp gây ra
var _slow_until := 0.0
var _slow_mult := 1.0


## Làm chậm: nhân tốc độ di chuyển với mult trong dur giây.
func apply_slow(mult: float, dur: float) -> void:
	_slow_mult = mult
	_slow_until = Time.get_ticks_msec() / 1000.0 + dur


func _spd() -> float:
	var k := _slow_mult if Time.get_ticks_msec() / 1000.0 < _slow_until else 1.0
	k *= dyn_speed()
	return k


## Hệ số tốc độ động: buff của Lang tăng, nổi giận, tinh anh nhanh nhẹn.
func dyn_speed() -> float:
	var k := 1.0
	if _buff_until > 0.0 and MonsterBehaviors.now() < _buff_until:
		k *= _buff_spd
	if _enraged:
		k *= 1.25
	if "nhanh_nhen" in elite_affixes:
		k *= 1.25
	return k


## Hệ số sát thương động.
func dmg_mult() -> float:
	var k := 1.0
	if _buff_until > 0.0 and MonsterBehaviors.now() < _buff_until:
		k *= _buff_dmg
	if _enraged:
		k *= 1.4
	return k


## Sát thương theo thời gian (thiêu đốt): không gây giật lùi hay ngắt đòn.
func take_dot(dmg: float) -> void:
	if not alive:
		return
	hp -= dmg
	_flash = 0.6
	_show_number(dmg)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	Sfx.play("mdie", randf_range(0.9, 1.1))
	state = "dead"
	_bar.queue_redraw()
	if host != null and host.has_method("on_monster_killed"):
		host.on_monster_killed(self)
	killed.emit(kind_id)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.25)
	if minion:
		tw.tween_callback(func():
			host.monsters.erase(self)
			queue_free())
		return
	tw.tween_interval(float(kind.get("respawn", RESPAWN)))
	tw.tween_callback(_respawn)


func reset_to_home() -> void:
	_respawn()


func _respawn() -> void:
	_enraged = false
	_bt.clear()
	position = home
	hp = max_hp
	alive = true
	state = "idle"
	_timer = 1.0
	_knock = Vector2.ZERO
	modulate.a = 1.0


func _show_number(dmg: float) -> void:
	var l := Label.new()
	l.text = str(int(dmg))
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 200
	get_parent().add_child(l)
	l.global_position = hit_center() + Vector2(randf_range(-14.0, 14.0) - 8.0, -30.0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- hoạt ảnh
func _play(action: String) -> void:
	if _body != null:
		_play_body(action)
		return
	if _sprite == null:
		return
	var frames := _sprite.sprite_frames
	var key := action + "_" + _facing
	if not frames.has_animation(key):
		if action == "idle" and frames.has_animation("walk_" + _facing):
			_sprite.animation = "walk_" + _facing   # đứng yên = khung đầu của hoạt ảnh đi
			_sprite.stop()
			_sprite.frame = 0
			return
		key = "walk_" + _facing
		if not frames.has_animation(key):
			return
	if action == "attack":
		var n := frames.get_frame_count(key)
		var fps := frames.get_animation_speed(key)
		_sprite.speed_scale = (float(n) / maxf(fps, 1.0)) / maxf(float(kind["windup"]), 0.1)   # đòn gồng xong đúng lúc vung
	else:
		_sprite.speed_scale = 1.0
	if _sprite.animation != key or not _sprite.is_playing():
		_sprite.play(key)

func _play_body(action: String) -> void:
	var motion := action + _facing + str(state in ["chase", "return"])
	if action != "attack" and motion == _last_motion and not _body.is_busy():
		return   # đang phát đúng hoạt ảnh rồi: không gọi lại (tránh đồng bộ 5 lớp sprite mỗi khung)
	_last_motion = motion
	if action == "attack":
		if not _body.is_busy():
			var spd := 0.6 / maxf(float(kind["windup"]), 0.1)   # đòn chém xong đúng lúc ra đòn
			if not _body.play_oneshot("slash", _facing, spd):
				_body.set_motion("idle", _facing)
		return
	_body.set_motion("run" if action == "walk" and state in ["chase", "return"] else action, _facing)


# ---------------------------------------------------------------- AI
func _physics_process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _knock.length() > 4.0:
		_step(_knock * delta)
		_knock = _knock.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	if _body != null:
		var bb := 1.0 + _flash * 1.4
		var ghost: bool = bool(kind.get("ghost", false))
		var gt := Color(0.8, 0.65, 1.0) if ghost else Color.WHITE
		_body.modulate = Color(bb * gt.r, bb * (1.0 - 0.4 * _flash) * gt.g, bb * (1.0 - 0.4 * _flash) * gt.b, 0.62 if ghost else 1.0)
		_body.position = _lunge + (Vector2(0, sin(_t * 2.2) * 4.0 - 6.0) if ghost else Vector2.ZERO)
	if _sprite != null:
		var b := 1.0 + _flash * 1.4
		_sprite.modulate = Color(b, b * (1.0 - 0.4 * _flash), b * (1.0 - 0.4 * _flash), 1.0)
		_sprite.position = Vector2(0, -28) + _lunge
	if not alive or host == null or host.player == null:
		return
	MonsterBehaviors.passive(self)
	var player: Node2D = host.player
	var to_p := player.position - position
	var dist := to_p.length()
	# kẻ giao đấu có tên (NpcCombat) không bị khu an toàn của làng/tông môn cản: trận đã được định đoạt ở nơi người chơi đứng
	var duel: bool = has_meta("npc_id")
	var seeing: bool = dist < float(kind["aggro"]) and host.vitals.alive() and (duel or not host.is_safe(player.position)) and not host.debug_peaceful
	match state:
		"idle":
			_play("idle")
			_timer -= delta
			if seeing:
				state = "chase"
			elif _timer <= 0.0:
				_wander_to = home + Vector2(randf_range(-70, 70), randf_range(-45, 45))
				state = "wander"
				_timer = 3.0
		"wander":
			_play("walk")
			_timer -= delta
			var d := _wander_to - position
			if seeing:
				state = "chase"
			elif d.length() < 6.0 or _timer <= 0.0:
				state = "idle"
				_timer = randf_range(1.0, 3.0)
			else:
				_facing = Dir.from_vector(d, _facing)
				_step(d.normalized() * (float(kind["speed"]) * _spd()) * 0.45 * delta)
		"chase":
			_play("walk")
			if not seeing and dist > float(kind["aggro"]) * 1.5:
				state = "return"
			elif (position - home).length() > float(kind["leash"]) or (not duel and host.is_safe(position + to_p.normalized() * 24.0)):
				state = "return"
			elif MonsterBehaviors.chase_hook(self, to_p, dist, delta):
				pass   # hành vi riêng (lao thẳng, bắn, hú gọi...) đã xử lý khung hình này
			elif dist <= float(kind["reach"]):
				state = "windup"
				_timer = float(kind["windup"])
				_facing = Dir.from_vector(to_p, _facing)
				_struck = false
			else:
				_facing = Dir.from_vector(to_p, _facing)
				_step(to_p.normalized() * (float(kind["speed"]) * _spd()) * delta)
		"windup":
			_play("attack")
			_timer -= delta
			_facing = Dir.from_vector(to_p, _facing)
			_lunge = _lunge.lerp(-to_p.normalized() * 5.0, minf(1.0, delta * 12.0))   # lùi nhẹ lấy đà
			if _timer <= 0.0:
				state = "recover"
				_timer = float(kind["recover"])
				_strike(to_p)
		"charge_tele", "charging", "stunned", "fuse", "cast":
			MonsterBehaviors.tick_state(self, delta, to_p, dist)
		"recover":
			_play("idle")
			_timer -= delta
			_lunge = _lunge.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
			if _timer <= 0.0:
				state = "chase" if seeing else "return"
		"hurt":
			_timer -= delta
			_lunge = Vector2.ZERO
			if _timer <= 0.0:
				state = "chase"
		"return":
			_play("walk")
			var d2 := home - position
			if d2.length() < 8.0:
				state = "idle"
				hp = max_hp
				_timer = 1.5
			else:
				_facing = Dir.from_vector(d2, _facing)
				_step(d2.normalized() * (float(kind["speed"]) * _spd()) * 0.9 * delta)
				hp = minf(max_hp, hp + max_hp * 0.1 * delta)
			if seeing and (position - home).length() < float(kind["leash"]) * 0.6:
				state = "chase"


func _strike(to_p: Vector2) -> void:
	var tw := create_tween()
	_lunge = to_p.normalized() * 11.0
	tw.tween_property(self, "_lunge", Vector2.ZERO, 0.22)
	var player: Node2D = host.player
	var d := (player.position - position).length()
	if d <= float(kind["reach"]) + 16.0 and host.vitals.take(damage * dmg_mult(), global_position):
		MonsterBehaviors.on_strike_hit(self)


## Đẩy nhẹ khỏi các con khác để không chồng lên nhau.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for m in host.monsters:
		if m == self or not m.alive:
			continue
		var d: Vector2 = position - m.position
		var l := d.length()
		if l < 40.0:
			push += (d / maxf(l, 0.1)) * (40.0 - l) / 40.0
	return push


func _step(step: Vector2) -> void:
	step += _separation() * 150.0 * get_physics_process_delta_time()
	_move_axis(Vector2(step.x, 0.0))
	_move_axis(Vector2(0.0, step.y))


func _move_axis(step: Vector2) -> void:
	var np := position + step
	np = np.clamp(Vector2(30, 40), host.map_size - Vector2(30, 20))
	if host._is_blocked(Rect2(np.x - 12, np.y - 8, 24, 10)):
		return
	if host.is_safe(np) and not host.is_safe(position) and not has_meta("npc_id"):
		return   # yêu thú không vào được quảng trường làng (trừ kẻ giao đấu có tên)
	position = np


func _draw() -> void:
	if _sprite != null or _body != null or not alive:
		return
	# chưa có ảnh: vẽ tạm một khối có mắt
	var c: Color = kind["tint"]
	draw_rect(Rect2(-14, -26, 28, 24), UIKit.BLACK)
	draw_rect(Rect2(-12, -24, 24, 20), c)
	draw_rect(Rect2(-8, -18, 5, 5), Color(1, 0.2, 0.2))
	draw_rect(Rect2(3, -18, 5, 5), Color(1, 0.2, 0.2))


func _process(_delta: float) -> void:
	if _sprite == null and _body == null:
		queue_redraw()


## Thanh máu pixel nổi phía trên đầu; hiện khi bị thương hoặc đang gồng đòn.
class HealthBar extends Node2D:
	var m: Monster
	var _shown_hp := -1.0
	var _shown_state := ""

	func _process(_delta: float) -> void:
		if m == null:
			return
		var blink := m.state in ["windup", "charge_tele", "fuse", "cast"]   # dấu ! nhấp nháy khi gồng đòn
		if blink or m.hp != _shown_hp or m.state != _shown_state:
			_shown_hp = m.hp
			_shown_state = m.state
			queue_redraw()

	func _draw() -> void:
		if m == null or not m.alive:
			return
		var y: float = m.kind["bar"]
		if m.hp < m.max_hp:
			draw_rect(Rect2(-22, y, 44, 7), UIKit.BLACK)
			draw_rect(Rect2(-20, y + 2, 40, 3), Color(0.25, 0.08, 0.1))
			var w := floorf(40.0 * clampf(m.hp / m.max_hp, 0.0, 1.0) / 2.0) * 2.0
			draw_rect(Rect2(-20, y + 2, w, 3), UIKit.RED)
		if m.state == "windup":
			var blink := int(m._t * 14.0) % 2 == 0
			draw_rect(Rect2(-3, y - 16, 6, 10), UIKit.BLACK)
			draw_rect(Rect2(-2, y - 15, 4, 6), UIKit.RED if blink else Color.WHITE)
			draw_rect(Rect2(-2, y - 7, 4, 3), UIKit.RED if blink else Color.WHITE)
