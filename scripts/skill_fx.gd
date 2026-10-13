extends RefCounted
class_name SkillFx
## Hiệu ứng chiêu thức của hệ V1, sinh từ dữ liệu: hình dạng (`shape`), phái (`sect`) và nguyên tố (`element`).
## Không cần hoạt ảnh nhân vật riêng cho từng chiêu: nhân vật chỉ làm một động tác đơn giản (chém / lao tới / nhấc người),
## còn "cảm giác chiêu" nằm hết ở vệt chém, tia, sóng, nổ, va chạm.
##   cone → vệt chém cung    line → tia xuyên    burst → nổ vùng    ring → sóng vòng    single → viên đạn    summon → pháp trận
## Màu: Ngũ Hành theo hành; các tông khác theo màu tông. Hiệu ứng người chơi dùng màu mát/sáng, dấu báo của địch luôn đỏ/cam.

const SECT_COLORS := {
	"kiem_tong": [Color(0.70, 0.90, 1.0), Color(0.45, 0.75, 1.0)],
	"dao_mon": [Color(1.0, 0.55, 0.30), Color(1.0, 0.82, 0.45)],
	"huyen_the": [Color(0.95, 0.80, 0.45), Color(0.75, 0.55, 0.30)],
	"hon_dao": [Color(0.78, 0.55, 1.0), Color(0.50, 0.85, 1.0)],
}
const ELEMENT_COLORS := {
	"kim": [Color(1.0, 0.95, 0.70), Color(0.85, 0.88, 0.95)],
	"moc": [Color(0.50, 1.0, 0.55), Color(0.80, 1.0, 0.60)],
	"thuy": [Color(0.45, 0.75, 1.0), Color(0.70, 0.95, 1.0)],
	"hoa": [Color(1.0, 0.50, 0.20), Color(1.0, 0.85, 0.40)],
	"tho": [Color(0.85, 0.70, 0.40), Color(0.60, 0.45, 0.30)],
}
## Màu riêng cho chiêu không thuộc tông nào (ưu tiên hơn màu tông / hành).
const SKILL_COLORS := {
	"soul_bell": [Color(0.80, 0.62, 1.0), Color(1.0, 0.88, 0.50)],
	"qi_pearl": [Color(0.55, 1.0, 0.80), Color(0.95, 1.0, 0.85)],
	"nine_swords": [Color(0.65, 0.88, 1.0), Color(1.0, 0.90, 0.55)],
	"dao_break": [Color(1.0, 0.45, 0.25), Color(0.95, 0.80, 0.50)],
}
const DEFAULT_COLORS :=[Color(0.70, 0.95, 1.0), Color(0.50, 0.80, 1.0)]
const ANCHOR := Vector2(0, -30)   # tâm người chơi (so với chân)


## [chính, phụ] theo định nghĩa chiêu.
static func palette(def: Dictionary) -> Array:
	if SKILL_COLORS.has(str(def.get("id", ""))):
		return SKILL_COLORS[str(def.get("id"))]
	var sect := str(def.get("sect", ""))
	if sect == "ngu_hanh" and ELEMENT_COLORS.has(str(def.get("element", ""))):
		return ELEMENT_COLORS[str(def.get("element"))]
	if SECT_COLORS.has(sect):
		return SECT_COLORS[sect]
	if ELEMENT_COLORS.has(str(def.get("element", ""))):
		return ELEMENT_COLORS[str(def.get("element"))]
	return DEFAULT_COLORS


## Đại chiêu: hồi lâu (>= 2.5 giây), bí truyền (cần >= 30 điểm) hoặc pháp bảo đặc biệt. Chiêu thường không có khung gồng lực.
static func is_grand(def: Dictionary) -> bool:
	return float(def.get("cooldown", 0.0)) >= 2.5 or int(def.get("need", 0)) >= 30 or str(def.get("id", "")) in ["nine_swords", "soul_bell"]


## Tung hiệu ứng xuất chiêu. aim: hướng ngắm đơn vị; targets: danh sách mục tiêu trong tầm (đã sắp theo khoảng cách).
## origin: kẻ tung chiêu (mặc định là người chơi; NPC truyền chính nó).
static func cast(main: Node, def: Dictionary, aim: Vector2, targets: Array, origin: Node2D = null) -> void:
	var parent: Node2D = main.fx_layer
	var who: Node2D = origin if origin != null else main.player
	if parent == null or who == null:
		return
	var c: Array = palette(def)
	var main_c: Color = c[0]
	var acc: Color = c[1]
	var from: Vector2 = who.position + ANCHOR
	var rng := float(def.get("range", 125))
	if origin == null and is_grand(def):
		if GrandCast.play(main, def, from, aim, targets) and GrandFx.has(str(def.get("id", ""))):
			return   # đại chiêu có bản quy mô lớn: dựng lúc bùng nổ (GrandFx), bỏ hiệu ứng nhỏ
	if _vfx_cast(main, parent, str(def.get("id", "")), aim, from, rng, targets):
		Fx.glow(parent, from + aim * 14.0, 10.0, 40.0, main_c, 0.16)
		return
	if _special(main, parent, str(def.get("id", "")), aim, from, rng, targets, main_c, acc):
		Fx.glow(parent, from + aim * 14.0, 12.0, 52.0, main_c, 0.2)
		return
	match str(def.get("shape", "single")):
		"cone":
			_slash(parent, from, aim, minf(rng * 0.8, 150.0), main_c, acc, false)
			_slash(parent, from, aim, minf(rng * 0.6, 118.0), acc, Color.WHITE, true)
		"line":
			_beam(parent, from, aim, rng, main_c, acc)
		"burst":
			var at: Vector2 = from + aim * rng * 0.6
			if not targets.is_empty():
				at = (targets[0].position as Vector2) + Vector2(0, -20)
			_burst(parent, at, 115.0, main_c, acc)
		"ring":
			var foot: Vector2 = who.position
			Fx.ring(parent, foot, 10.0, rng, main_c, 0.45, 0.55, 6.0)
			Fx.ring(parent, foot, 6.0, rng * 0.7, acc, 0.35, 0.55, 3.0)
			Fx.glow(parent, from, 24.0, rng * 0.9, main_c, 0.3)
		_:
			var to: Vector2 = from + aim * minf(rng, 220.0)
			if not targets.is_empty():
				to = (targets[0].position as Vector2) + Vector2(0, -24)
			_bolt(parent, from, to, main_c, acc)
	Fx.glow(parent, from + aim * 14.0, 12.0, 52.0, main_c, 0.2)


## Va chạm tại điểm trúng.
static func hit(main: Node, pos: Vector2, def: Dictionary, critical: bool) -> void:
	var parent: Node2D = main.fx_layer
	if parent == null:
		return
	if Vfx.play(parent, "crit" if critical else "hit", pos, 0.0) != null:
		return
	var c: Array = palette(def)
	var col: Color = Color(1.0, 0.9, 0.5) if critical else c[0]
	Fx.cross(parent, pos, col, 40.0 if critical else 26.0)
	Fx.burst(parent, pos, c[1], 12 if critical else 7, 120.0 if critical else 85.0, 0.3, 2.6)
	if critical:
		Fx.glow(parent, pos, 14.0, 70.0, Color(1.0, 0.9, 0.5), 0.25)


## Pháp trận hiện ra khi triệu hồi.
static func summon(main: Node, def: Dictionary) -> void:
	var parent: Node2D = main.fx_layer
	if parent == null or main.player == null:
		return
	if str(def.get("id", "")) in ["hon_clone", "nine_swords"] and Vfx.has("summon"):
		return   # đã dựng ở _vfx_cast
	var c: Array = palette(def)
	var sigil := Sigil.new()
	sigil.position = main.player.position
	sigil.col = c[0]
	sigil.acc = c[1]
	parent.add_child(sigil)


## Động tác nhân vật đơn giản: dùng khung chém có sẵn nếu trang phục có, nếu không thì lao nhẹ về phía trước.
static func body_motion(main: Node, def: Dictionary, aim: Vector2, who: Node2D = null) -> void:
	if who != null:
		return   # NPC: dùng khung đánh sẵn có của quái, không dịch lớp nhân vật
	var player: Node2D = main.player
	if player == null:
		return
	if str(def.get("shape", "")) == "cone" and player.has_method("play_oneshot") and player.has_method("has_motion"):
		if player.has_motion("slash", main.direction):
			player.play_oneshot("slash", main.direction, 1.35)
			return
	lunge(player, aim, 9.0 if str(def.get("shape", "")) in ["cone", "single", "line"] else 5.0)


## Lao nhẹ các lớp thân/tóc/áo về hướng ra chiêu rồi về lại (không đổi vị trí thật, không va chạm).
static func lunge(player: Node2D, dir: Vector2, amount: float) -> void:
	if player == null:
		return
	var tw := player.create_tween()
	tw.tween_method(_lunge_step.bind(player, dir), 0.0, amount, 0.06)
	tw.tween_method(_lunge_step.bind(player, dir), amount, 0.0, 0.14)


static func _lunge_step(v: float, player: Node2D, dir: Vector2) -> void:
	if not is_instance_valid(player):
		return
	for n in ["HairBack", "Body", "Clothes", "Shoes", "HairFront"]:
		var node := player.get_node_or_null(n) as Node2D
		if node != null:
			node.position = Vector2(0, -29) + dir * v


## Hiệu ứng pixel-art dựng sẵn (assets/vfx, xem Vfx) cho các chiêu đặc trưng. Trả false nếu chiêu không có hoặc thiếu tài nguyên.
static func _vfx_cast(main: Node, parent: Node2D, id: String, aim: Vector2, from: Vector2, rng: float, targets: Array) -> bool:
	var foot: Vector2 = from - ANCHOR
	var ang := aim.angle()
	var tip: Vector2 = foot + aim * rng * 0.75
	var tgt: Vector2 = from + aim * minf(rng, 220.0)
	if not targets.is_empty():
		tgt = (targets[0].position as Vector2) + Vector2(0, -24)
	var ok := false
	match id:
		"kiem_cut":
			ok = Vfx.play(parent, "slash_kiem", from + aim * 6.0, ang) != null
		"kiem_wave":
			ok = Vfx.play(parent, "lance", from, ang) != null
			Vfx.play(parent, "slash_kiem", from + aim * 4.0, ang)
		"dao_cut":
			ok = Vfx.play(parent, "slash_dao", from + aim * 6.0, ang) != null
			_shake(main, foot, 1.5, 0.1)
		"dao_break":
			ok = Vfx.play(parent, "slash_dao", from + aim * 6.0, ang) != null
			Vfx.play(parent, "impact_ring", tip, 0.0)
			_shake(main, foot, 4.0, 0.2)
		"the_fist":
			ok = Vfx.play(parent, "impact_ring", foot + aim * rng * 0.8, 0.0) != null
			Vfx.play(parent, "hit", from + aim * rng * 0.8, 0.0)
		"ngu_fire":
			ok = Vfx.play(parent, "fireball", tgt, 0.0) != null
		"ngu_water":
			ok = Vfx.play(parent, "water_jet", from, ang, 0.7) != null
		"the_quake":
			ok = Vfx.play(parent, "quake", foot + Vector2(0, 4), 0.0) != null
			_shake(main, foot, 5.0, 0.25)
		"hon_seal":
			ok = Vfx.play(parent, "orb_arcane", from, ang, 0.3, tgt - from) != null
			Vfx.play(parent, "sigil", tgt + Vector2(0, 24), 0.0, 0.9)
		"hon_clone":
			ok = Vfx.play(parent, "summon", foot + Vector2(0, 6), 0.0) != null
		"soul_bell":
			ok = Vfx.play(parent, "bell", foot + Vector2(0, 6), 0.0) != null
			_shake(main, foot, 2.5, 0.2)
		"qi_pearl":
			ok = Vfx.play(parent, "orb_green", from, ang, 0.3, tgt - from) != null
		"nine_swords":
			ok = Vfx.play(parent, "swords", from + Vector2(0, -8), 0.0, 1.3) != null
	return ok


## Hiệu ứng riêng cho từng chiêu đặc trưng. Trả true nếu đã tự dựng đủ (bỏ qua hiệu ứng theo hình dạng chung).
static func _special(main: Node, parent: Node2D, id: String, aim: Vector2, from: Vector2, rng: float, targets: Array, col: Color, acc: Color) -> bool:
	var foot: Vector2 = from - ANCHOR
	var tip: Vector2 = from + aim * rng * 0.7
	var tgt: Vector2 = tip
	if not targets.is_empty():
		tgt = (targets[0].position as Vector2) + Vector2(0, -22)
	match id:
		"kiem_wave":
			_anim(parent, "crescent", from, aim.angle(), col, acc, 0.3, rng)
			return true
		"ngu_water":
			_anim(parent, "stream", from, aim.angle(), col, acc, 0.4, rng)
			return true
		"ngu_fire":
			_anim(parent, "fireball", tgt, 0.0, col, acc, 0.6, 70.0)
			Fx.ring(parent, tgt + Vector2(0, 22), 8.0, 105.0, col, 0.4, 0.55, 5.0)
			Fx.glow(parent, tgt, 20.0, 130.0, col, 0.35)
			return true
		"hon_seal":
			_anim(parent, "seal", tgt, 0.0, col, acc, 0.75, 30.0)
			Fx.glow(parent, tgt, 10.0, 70.0, col, 0.3)
			return true
		"the_quake":
			_anim(parent, "cracks", foot, 0.0, col, acc, 0.7, rng)
			Fx.burst(parent, foot + Vector2(0, -6), Color(0.78, 0.65, 0.45), 16, 150.0, 0.5, 3.5)
			_shake(main, foot, 5.0, 0.25)
			return true
		"soul_bell":
			_anim(parent, "bell", foot + Vector2(0, -8), 0.0, col, acc, 0.8, rng)
			Fx.glow(parent, from, 18.0, rng * 0.8, col, 0.3)
			_shake(main, foot, 2.5, 0.2)
			return true
		"nine_swords":
			_anim(parent, "swords", from + Vector2(0, -16), 0.0, col, acc, 1.1, 56.0)
			return true
		"dao_break":
			_slash(parent, from, aim, minf(rng * 0.85, 160.0), col, acc, false)
			_slash(parent, from, aim, minf(rng * 0.65, 128.0), acc, Color.WHITE, true)
			Fx.ring(parent, tip + Vector2(0, 26), 6.0, 90.0, col, 0.4, 0.5, 6.0)
			Fx.burst(parent, tip + Vector2(0, 10), Color(0.85, 0.75, 0.6), 10, 130.0, 0.4, 3.0)
			_shake(main, foot, 4.0, 0.2)
			return true
		"dao_cut":
			_slash(parent, from, aim, minf(rng * 0.95, 150.0), col, acc, false)
			_slash(parent, from, aim, minf(rng * 0.72, 118.0), acc, Color.WHITE, true)
			_shake(main, foot, 1.5, 0.1)
			return true
		"the_fist":
			_slash(parent, from, aim, minf(rng * 0.7, 90.0), col, acc, false)
			Fx.ring(parent, from + aim * rng * 0.8 + Vector2(0, 20), 4.0, 48.0, acc, 0.3, 0.55, 4.0)
			Fx.cross(parent, from + aim * rng * 0.8, Color.WHITE, 30.0)
			return true
	return false


static func _anim(parent: Node, kind: String, at: Vector2, rot: float, col: Color, acc: Color, life: float, size: float) -> void:
	var a := Anim.new()
	a.kind = kind
	a.position = at
	a.rotation = rot
	a.col = col
	a.acc = acc
	a.life = life
	a.size = size
	parent.add_child(a)


## Rung màn hình chỉ khi kẻ tung chiêu ở sát người chơi (NPC xa không làm rung).
static func _shake(main: Node, at: Vector2, strength: float, dur: float) -> void:
	if main.school != null and main.player != null and main.player.position.distance_to(at) < 90.0:
		main.school.shake(strength, dur)


## Tàn ảnh: bản chụp các lớp nhân vật ở khung hiện tại, nhuộm màu, mờ dần rồi biến mất.
static func afterimage(main: Node, tint: Color, alpha := 0.55, life := 0.3) -> void:
	var player: Node2D = main.player
	var parent: Node2D = main.fx_layer
	if player == null or parent == null:
		return
	var ghost := Ghost.new()
	ghost.position = player.position
	ghost.life = life
	ghost.start_alpha = alpha
	ghost.modulate = Color(tint.r, tint.g, tint.b, alpha)
	for n in ["HairBack", "Body", "Clothes", "Shoes", "HairFront"]:
		var src := player.get_node_or_null(n) as AnimatedSprite2D
		if src == null or not src.visible or src.sprite_frames == null:
			continue
		var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.position = src.position
		sp.centered = src.centered
		sp.offset = src.offset
		sp.scale = src.scale
		sp.flip_h = src.flip_h
		ghost.add_child(sp)
	if ghost.get_child_count() == 0:
		ghost.free()
		return
	parent.add_child(ghost)


## Né hoàn hảo: bóng trắng lóe, vòng sóng, chữ thập, vài tia; màn hình nháy nhẹ và khựng một nhịp.
static func perfect_dodge(main: Node, def: Dictionary) -> void:
	var parent: Node2D = main.fx_layer
	if parent == null or main.player == null:
		return
	var c: Array = palette(def)
	var at: Vector2 = main.player.position + ANCHOR
	afterimage(main, Color(1, 1, 1), 0.9, 0.35)
	Vfx.play(parent, "crit", at, 0.0)
	Fx.ring(parent, main.player.position, 8.0, 74.0, Color.WHITE, 0.4, 0.55, 4.0)
	Fx.ring(parent, main.player.position, 4.0, 48.0, c[0], 0.3, 0.55, 3.0)
	Fx.cross(parent, at, Color.WHITE, 46.0)
	Fx.burst(parent, at, c[1], 10, 150.0, 0.35, 2.6)
	if main.school != null:
		main.school.flash(Color(0.8, 0.95, 1.0), 0.18, 0.14)
		main.school.hitstop(0.05)


# ---------------------------------------------------------------- dựng hiệu ứng
static func _slash(parent: Node, from: Vector2, aim: Vector2, radius: float, col: Color, acc: Color, flip: bool) -> void:
	var s := Slash.new()
	s.position = from
	s.rotation = aim.angle()
	s.radius = radius
	s.col = col
	s.acc = acc
	s.flip = flip
	parent.add_child(s)


static func _beam(parent: Node, from: Vector2, aim: Vector2, length: float, col: Color, acc: Color) -> void:
	var b := Beam.new()
	b.position = from
	b.rotation = aim.angle()
	b.length = length
	b.col = col
	b.acc = acc
	parent.add_child(b)


static func _burst(parent: Node, at: Vector2, radius: float, col: Color, acc: Color) -> void:
	Fx.ring(parent, at + Vector2(0, 22), 8.0, radius, col, 0.4, 0.55, 6.0)
	Fx.ring(parent, at + Vector2(0, 22), 4.0, radius * 0.6, acc, 0.3, 0.55, 3.0)
	Fx.glow(parent, at, 18.0, radius * 1.1, col, 0.3)
	Fx.cross(parent, at, acc, 60.0)
	Fx.burst(parent, at, acc, 14, 160.0, 0.45, 3.0)


static func _bolt(parent: Node, from: Vector2, to: Vector2, col: Color, acc: Color) -> void:
	var b := Bolt.new()
	b.position = from
	b.target = to
	b.col = col
	b.acc = acc
	parent.add_child(b)


# ---------------------------------------------------------------- các nút hiệu ứng
## Vệt chém cung quét ngang theo hướng ra chiêu.
class Slash extends Node2D:
	var radius := 110.0
	var col := Color.WHITE
	var acc := Color.WHITE
	var flip := false
	var life := 0.26
	var half := 1.05
	var _t := 0.0

	func _ready() -> void:
		material = Fx.additive()
		z_index = 120

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var sweep := 1.0 - pow(1.0 - minf(k * 1.8, 1.0), 3.0)   # quét nhanh ở đầu rồi chậm
		var a0 := half if flip else -half
		var a1 := -half if flip else half
		var fade := 1.0 - k * k
		var n := 16
		for layer in [[1.0, col, 9.0], [0.86, acc, 5.0], [0.94, Color.WHITE, 2.5]]:
			var prev := Vector2.ZERO
			for i in n + 1:
				var u := float(i) / float(n)
				var ang := lerpf(a0, a1, u * sweep)
				var p := Vector2(cos(ang), sin(ang)) * radius * float(layer[0])
				if i > 0:
					var w := lerpf(0.6, 1.0, u) * float(layer[2]) * (1.0 - 0.5 * k)   # đuôi mảnh, đầu dày
					draw_line(prev, p, Color(layer[1], 0.9 * fade), w)
				prev = p


## Tia thẳng: một vệt sáng dày co lại, kèm đầu mút.
class Beam extends Node2D:
	var length := 300.0
	var col := Color.WHITE
	var acc := Color.WHITE
	var life := 0.22
	var _t := 0.0

	func _ready() -> void:
		material = Fx.additive()
		z_index = 120

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var reach := length * minf(k * 4.0, 1.0)
		var w := lerpf(22.0, 3.0, k)
		var a := 1.0 - k
		draw_line(Vector2(10, 0), Vector2(reach, 0), Color(col, 0.45 * a), w * 2.2)
		draw_line(Vector2(10, 0), Vector2(reach, 0), Color(acc, 0.85 * a), w)
		draw_line(Vector2(10, 0), Vector2(reach, 0), Color(1, 1, 1, a), maxf(2.0, w * 0.35))
		draw_circle(Vector2(reach, 0), 9.0 * a + 3.0, Color(1, 1, 1, 0.9 * a))
		for i in 4:
			var x := reach * (0.2 + 0.2 * float(i))
			draw_line(Vector2(x, -w), Vector2(x - 10.0, -w - 8.0), Color(col, 0.7 * a), 2.0)
			draw_line(Vector2(x, w), Vector2(x - 10.0, w + 8.0), Color(col, 0.7 * a), 2.0)


## Viên đạn bay nhanh tới mục tiêu có vệt đuôi.
class Bolt extends Node2D:
	var target := Vector2.ZERO
	var col := Color.WHITE
	var acc := Color.WHITE
	var travel := 0.14
	var _t := 0.0
	var _origin := Vector2.ZERO
	var _trail: Array = []

	func _ready() -> void:
		material = Fx.additive()
		z_index = 120
		_origin = position

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / travel, 0.0, 1.0)
		var p := _origin.lerp(target, k)
		_trail.append(p)
		if _trail.size() > 7:
			_trail.pop_front()
		position = Vector2.ZERO
		if _t >= travel + 0.1:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for i in _trail.size():
			var u := float(i + 1) / float(_trail.size())
			var p: Vector2 = _trail[i]
			draw_circle(p - _origin * 0.0, 3.0 + 5.0 * u, Color(col, 0.25 + 0.5 * u))
		if _trail.size() > 0 and _t < travel + 0.05:
			var head: Vector2 = _trail[_trail.size() - 1]
			draw_circle(head, 7.0, Color(acc, 0.9))
			draw_circle(head, 3.5, Color(1, 1, 1, 1))


## Hiệu ứng riêng từng chiêu, vẽ thủ tục theo `kind`: crescent, stream, fireball, seal, cracks, bell, swords.
class Anim extends Node2D:
	var kind := ""
	var col := Color.WHITE
	var acc := Color.WHITE
	var life := 0.5
	var size := 100.0
	var _t := 0.0
	var _seed := randf() * 10.0

	func _ready() -> void:
		material = Fx.additive()
		z_index = 120

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var fade := 1.0 - k
		match kind:
			"crescent":
				# lưỡi kiếm khí hình trăng khuyết lao dọc hướng ra chiêu, kéo vệt phía sau
				var reach := minf(k * 1.5, 1.0)
				for i in 6:
					var kk := maxf(reach - float(i) * 0.05, 0.0)
					var a := (1.0 - float(i) / 6.0) * fade
					var x := size * kk
					var w := 5.0 - float(i) * 0.6
					draw_arc(Vector2(x - 26.0, 0), 34.0, -0.95, 0.95, 18, Color(col, 0.9 * a), maxf(w, 1.5))
				var xh := size * reach
				draw_arc(Vector2(xh - 26.0, 0), 34.0, -0.95, 0.95, 18, Color(1, 1, 1, fade), 2.0)
				draw_line(Vector2(xh - 40.0, 0), Vector2(xh + 8.0, 0), Color(acc, 0.8 * fade), 2.0)
			"stream":
				# dòng nước uốn lượn đâm ra, tụ bọt ở đầu
				var reach2 := minf(k * 3.0, 1.0)
				var pts := PackedVector2Array()
				var n := 22
				for i in n + 1:
					var x := size * reach2 * float(i) / float(n)
					var amp := 7.0 * sin(float(i) / float(n) * PI)
					pts.append(Vector2(x, sin(x * 0.09 - _t * 28.0) * amp))
				draw_polyline(pts, Color(col, 0.55 * fade), 12.0)
				draw_polyline(pts, Color(acc, 0.9 * fade), 5.0)
				draw_polyline(pts, Color(1, 1, 1, 0.8 * fade), 1.5)
				var head: Vector2 = pts[pts.size() - 1]
				for i in 5:
					var ang := _seed + float(i) * 1.3 + _t * 9.0
					draw_circle(head + Vector2(cos(ang), sin(ang)) * (6.0 + 12.0 * k), 2.5, Color(acc, 0.9 * fade))
			"fireball":
				# cầu lửa nở ra, tàn lửa bay lên
				var r := size * (0.35 + 0.65 * minf(k * 2.5, 1.0))
				draw_circle(Vector2.ZERO, r, Color(col, 0.35 * fade))
				draw_circle(Vector2.ZERO, r * 0.7, Color(acc, 0.5 * fade))
				draw_circle(Vector2.ZERO, r * 0.35, Color(1, 1, 0.9, 0.9 * fade))
				for i in 12:
					var ang := float(i) * 2.399 + _seed
					var d := size * 0.8 * (0.3 + 0.7 * fmod(float(i) * 0.37, 1.0))
					var p := Vector2(cos(ang) * d * k, sin(ang) * d * 0.4 * k - 90.0 * k * k)
					draw_circle(p, 3.0 * fade + 1.0, Color(acc, 0.9 * fade))
			"seal":
				# ấn chú: vòng ngoài quay thuận, hình sao quay ngược, phát sáng rồi co lại
				var pulse := 1.0 + 0.25 * sin(k * 20.0) * fade
				var r2 := size * pulse * (0.6 + 0.4 * minf(k * 4.0, 1.0)) * (1.0 - 0.35 * maxf(k - 0.7, 0.0) / 0.3)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.8))
				draw_arc(Vector2.ZERO, r2, 0.0, TAU, 40, Color(col, 0.95 * fade), 2.5)
				draw_arc(Vector2.ZERO, r2 * 0.72, 0.0, TAU, 36, Color(acc, 0.8 * fade), 1.5)
				for i in 8:
					var ang := _t * 3.0 + float(i) * TAU / 8.0
					var d2 := Vector2(cos(ang), sin(ang))
					draw_line(d2 * r2, d2 * r2 * 1.18, Color(1, 1, 1, 0.9 * fade), 2.0)
				for i in 6:
					var a1 := -_t * 2.5 + float(i) * TAU / 6.0
					var a2 := a1 + TAU / 3.0
					draw_line(Vector2(cos(a1), sin(a1)) * r2 * 0.72, Vector2(cos(a2), sin(a2)) * r2 * 0.72, Color(acc, 0.7 * fade), 1.5)
			"cracks":
				# nứt đất tỏa ra từ chân, rồi tối dần
				var grow := minf(k * 4.0, 1.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
				for i in 9:
					var ang2 := float(i) * TAU / 9.0 + 0.2
					var dir := Vector2(cos(ang2), sin(ang2))
					var ln := size * (0.55 + 0.45 * fmod(float(i) * 0.61, 1.0)) * grow
					var p0 := Vector2.ZERO
					for s in 5:
						var p1 := p0 + dir * ln / 5.0 + Vector2(-dir.y, dir.x) * sin(float(i * 5 + s) * 1.7) * 7.0
						draw_line(p0, p1, Color(0, 0, 0, 0.8 * fade), 5.0)
						draw_line(p0, p1, Color(col, 0.95 * fade), 2.0)
						p0 = p1
				draw_arc(Vector2.ZERO, size * grow, 0.0, TAU, 48, Color(acc, 0.5 * fade), 3.0)
			"bell":
				# tiếng chuông: ba đợt sóng nở ra liên tiếp
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
				for i in 3:
					var kk2 := clampf((_t - float(i) * 0.12) / (life - 0.3), 0.0, 1.0)
					if kk2 <= 0.0 or kk2 >= 1.0:
						continue
					var rr := size * kk2
					draw_arc(Vector2.ZERO, rr, 0.0, TAU, 56, Color(col if i % 2 == 0 else acc, 0.9 * (1.0 - kk2)), 5.0 - float(i))
			"swords":
				# chín thanh kiếm xoay quanh người rồi bắn ra ngoài
				var out := maxf((k - 0.75) / 0.25, 0.0)
				var spin := _t * 7.0 + k * k * 8.0
				var rad := size * (0.8 + 0.2 * sin(_t * 6.0)) + out * size * 3.0
				for i in 9:
					var ang3 := spin + float(i) * TAU / 9.0
					var d3 := Vector2(cos(ang3), sin(ang3) * 0.55)
					var c0 := d3 * rad
					var tang := Vector2(-sin(ang3), cos(ang3) * 0.55).normalized()
					var a3 := minf(k * 5.0, 1.0) * (1.0 - out * 0.8)
					draw_line(c0 - tang * 13.0, c0 + tang * 13.0, Color(col, 0.95 * a3), 7.0)
					draw_line(c0 - tang * 12.0, c0 + tang * 15.0, Color(1, 1, 1, 0.95 * a3), 2.5)
					draw_circle(c0 - tang * 14.0, 3.0, Color(acc, a3))


## Tàn ảnh nhân vật: mờ dần theo thời gian rồi tự xóa.
class Ghost extends Node2D:
	var life := 0.3
	var start_alpha := 0.5
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		modulate.a = start_alpha * (1.0 - _t / life)


## Pháp trận hiện ra rồi tan khi triệu hồi.
class Sigil extends Node2D:
	var col := Color.WHITE
	var acc := Color.WHITE
	var life := 0.8
	var _t := 0.0

	func _ready() -> void:
		material = Fx.additive()
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var a := 1.0 - k
		var r := 62.0 * (0.5 + 0.5 * minf(k * 3.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col, 0.9 * a), 3.0)
		draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 40, Color(acc, 0.8 * a), 2.0)
		for i in 6:
			var ang := _t * 2.0 + float(i) * TAU / 6.0
			var d := Vector2(cos(ang), sin(ang))
			draw_line(d * r * 0.7, d * r, Color(1, 1, 1, 0.8 * a), 2.0)
			draw_circle(d * r * 0.85, 3.0, Color(acc, a))
