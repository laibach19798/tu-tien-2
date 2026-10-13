extends RefCounted
class_name GrandFx
## Hiệu ứng quy mô lớn cho đại chiêu (bước 2): mưa kiếm phủ màn hình, cự kiếm trời giáng, trận pháp dưới chân, cột sáng.
## Dư chấn (bước 3): vết nứt / cháy sém / rune ở lại trên mặt đất vài giây, khói bụi, kiếm cắm lại, quái bị hất văng.
## Tầm đánh khớp hình ảnh: Runtime lấy `reach` / `impact_radius` ở đây để lọc mục tiêu, nên vùng hình ảnh = vùng trúng đòn.
## Gọi từ GrandCast lúc "bùng nổ", id không có ở đây thì GrandCast bỏ qua.

const IDS := ["nine_swords", "kiem_wave", "the_quake", "thien_mach_quyet", "soul_bell", "hon_clone", "dao_break"]
const SWORD := "res://assets/props/xt_sword.png"
const SWORD_REGION := Rect2(0, 0, 121, 165)   # phần thân kiếm, bỏ đế đá


## Hệ số sát thương cho mục tiêu thứ hai trở đi của chiêu triệu hồi diện rộng (mưa kiếm).
const SUMMON_FALLOFF := 0.15
## Mục tiêu chỉ dính vùng nổ (ngoài đường tia) nhận một phần sát thương.
const SPLASH_FALLOFF := 0.2
const SUMMON_MAX_TARGETS := 6
const IMPACT_RADIUS := {"kiem_wave": 210.0, "thien_mach_quyet": 170.0}
const REACH_MULT := {"the_quake": 1.5, "soul_bell": 1.4, "dao_break": 1.5}
const AREA_SUMMONS := ["nine_swords"]


static func has(id: String) -> bool:
	return id in IDS


## Tầm đánh quanh người tung chiêu (hình ảnh lan tới đâu thì trúng tới đó). 0 = dùng `range` gốc của chiêu.
static func reach(def: Dictionary) -> float:
	var id := str(def.get("id", ""))
	if REACH_MULT.has(id):
		return float(def.get("range", 125)) * float(REACH_MULT[id])
	return 0.0


## Bán kính vùng nổ quanh điểm rơi (cự kiếm, cột sáng). 0 = không có.
static func impact_radius(def: Dictionary) -> float:
	return float(IMPACT_RADIUS.get(str(def.get("id", "")), 0.0))


static func is_area_summon(def: Dictionary) -> bool:
	return str(def.get("id", "")) in AREA_SUMMONS


## at: tâm người tung chiêu (toạ độ thế giới, đã cộng ANCHOR); foot: chân. targets: vị trí mục tiêu (Vector2).
static func release(main: Node, def: Dictionary, at: Vector2, aim: Vector2, targets: Array) -> void:
	var parent: Node2D = main.fx_layer
	if parent == null:
		return
	var id := str(def.get("id", ""))
	var c: Array = SkillFx.palette(def)
	var col: Color = c[0]
	var acc: Color = c[1]
	var foot := at + Vector2(0, 30)
	var rng := float(def.get("range", 125))
	var area := reach(def)
	var tgt: Vector2 = at + aim * minf(rng * 0.9, 220.0) + Vector2(0, 24)
	if not targets.is_empty():
		tgt = (targets[0] as Vector2) + Vector2(0, 20)
	match id:
		"nine_swords":
			_sword_rain(main, parent, foot, tgt, targets, rng, col, acc)
		"kiem_wave":
			_giant_sword(main, parent, at, foot, tgt, aim, rng, col, acc)
		"the_quake":
			_array(main, parent, foot, area, col, acc, Color(0.85, 0.7, 0.45))
		"thien_mach_quyet":
			_pillars(main, parent, foot, tgt, col, acc)
		"soul_bell":
			_big_bell(main, parent, foot, area, col, acc)
		"hon_clone":
			_big_summon(main, parent, foot, col, acc)
		"dao_break":
			_giant_slash(main, parent, at, aim, area, col, acc)


# ---------------------------------------------------------------- các chiêu
## Mưa kiếm: sân kiếm trên không rơi phủ một vùng lớn quanh mục tiêu, mỗi mục tiêu bị một chùm kiếm găm xuống.
static func _sword_rain(main: Node, parent: Node2D, foot: Vector2, tgt: Vector2, targets: Array, area: float, col: Color, acc: Color) -> void:
	_clip(parent, "sigil", foot, 0.0, maxf(area * 0.009, 2.0), col, 1.4)
	_clip(parent, "swords", foot + Vector2(0, -40), 0.0, 2.4, col, 1.2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var center := foot + (tgt - foot).limit_length(area * 0.45)
	for i in 30:
		var p := center + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).limit_length(1.0) * Vector2(area * 0.95, area * 0.55)
		_blade(main, parent, p, rng.randf_range(0.0, 0.75), 0.5 + rng.randf() * 0.25, 360.0, col, acc, false)
	_scar(main, "rune", foot, area, 3.5, col)
	_later(parent, 0.55, func() -> void: _knock(main, foot, area * 0.9, 220.0))
	for t in targets.slice(0, 6):
		var tp: Vector2 = (t as Vector2) + Vector2(0, 18)
		for k in 3:
			_blade(main, parent, tp + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-8.0, 8.0)), 0.15 + 0.12 * k, 0.8, 420.0, acc, col, true)
	_shake(main, 5.0, 0.6)


## Cự kiếm trời giáng: một thanh kiếm khổng lồ cắm xuống điểm mục tiêu, nứt đất, sóng xung kích.
static func _giant_sword(main: Node, parent: Node2D, at: Vector2, foot: Vector2, tgt: Vector2, aim: Vector2, rng: float, col: Color, acc: Color) -> void:
	_clip(parent, "lance", at, aim.angle(), rng / 245.0, col, 1.0)   # dài đúng tầm tia (anchor ~12px, thân ~248px)
	_blade(main, parent, tgt, 0.12, 2.6, 760.0, col.lerp(Color.WHITE, 0.35), acc, true)
	_later(parent, 0.12 + 0.24, func() -> void:
		_clip(parent, "quake", tgt + Vector2(0, 6), 0.0, 2.6, acc, 1.0)
		_clip(parent, "impact_ring", tgt + Vector2(0, 4), 0.0, 2.2, col, 1.0)
		Fx.ring(parent, tgt, 10.0, 210.0, col, 0.6, 0.55, 8.0)
		Fx.ring(parent, tgt, 6.0, 140.0, acc, 0.45, 0.55, 5.0)
		Fx.glow(parent, tgt + Vector2(0, -60), 40.0, 320.0, col, 0.45)
		Fx.burst(parent, tgt + Vector2(0, -10), Color(0.85, 0.8, 0.7), 26, 260.0, 0.6, 4.0)
		_scar(main, "crack", tgt, 200.0, 6.0, col)
		_scar(main, "scorch", tgt, 70.0, 4.0, acc)
		_dust(main, tgt, 150.0, 1.6)
		_knock(main, tgt, 210.0, 340.0)
		_shake(main, 11.0, 0.5))


## Trận địa: pháp trận khổng lồ dưới chân, sóng đá lan ba nhịp, đất nứt.
static func _array(main: Node, parent: Node2D, foot: Vector2, area: float, col: Color, acc: Color, dust: Color) -> void:
	_clip(parent, "sigil", foot + Vector2(0, 6), 0.0, area * 0.013, col, 1.5)
	_clip(parent, "quake", foot + Vector2(0, 4), 0.0, area * 0.0104, acc, 1.0)
	for i in 3:
		_later(parent, 0.12 * float(i), func() -> void:
			Fx.ring(parent, foot, 10.0, area * (0.6 + 0.2 * float(i)), col.lerp(acc, 0.4), 0.55, 0.55, 8.0 - 2.0 * float(i))
			Fx.burst(parent, foot + Vector2(0, -6), dust, 14, 190.0 + 60.0 * float(i), 0.6, 4.0)
			_shake(main, 8.0 - 2.0 * float(i), 0.3))
	Fx.glow(parent, foot + Vector2(0, -20), 40.0, area * 2.0, col, 0.55)
	_scar(main, "crack", foot, area * 0.92, 7.0, acc)
	_scar(main, "rune", foot, area * 0.8, 4.0, col)
	_dust(main, foot, area * 0.6, 2.2)
	_knock(main, foot, area, 320.0)


## Cột sáng đánh từ trời: một vòng cột quanh mục tiêu rồi một cột trụ lớn ở tâm.
static func _pillars(main: Node, parent: Node2D, foot: Vector2, tgt: Vector2, col: Color, acc: Color) -> void:
	_clip(parent, "sigil", tgt + Vector2(0, 6), 0.0, 3.0, col, 1.2)
	var n := 7
	for i in n:
		var a := TAU * float(i) / float(n) + 0.3
		var p := tgt + Vector2(cos(a) * 140.0, sin(a) * 78.0)
		_later(parent, 0.05 * float(i), func() -> void:
			var pl := Pillar.new()
			pl.position = p
			pl.col = col
			pl.half = 15.0
			pl.life = 0.55
			parent.add_child(pl)
			Fx.ring(parent, p, 4.0, 60.0, acc, 0.35, 0.55, 3.0))
	_later(parent, 0.4, func() -> void:
		var big := Pillar.new()
		big.position = tgt
		big.col = col.lerp(Color.WHITE, 0.5)
		big.half = 46.0
		big.life = 0.7
		parent.add_child(big)
		_clip(parent, "crit", tgt + Vector2(0, -30), 0.0, 3.4, acc, 1.0)
		_scar(main, "scorch", tgt, 120.0, 5.0, col, true)
		_scar(main, "rune", tgt, 165.0, 4.0, acc)
		_knock(main, tgt, 170.0, 300.0)
		Fx.ring(parent, tgt, 10.0, 180.0, col, 0.6, 0.55, 8.0)
		Fx.glow(parent, tgt + Vector2(0, -40), 50.0, 300.0, col, 0.5)
		_shake(main, 12.0, 0.55))


## Đại chung rơi xuống: chuông lớn, sóng âm ba vòng.
static func _big_bell(main: Node, parent: Node2D, foot: Vector2, area: float, col: Color, acc: Color) -> void:
	_clip(parent, "bell", foot + Vector2(0, 6), 0.0, 2.8, col, 1.0)
	for i in 3:
		_later(parent, 0.18 * float(i), func() -> void:
			Fx.ring(parent, foot, 12.0, area * (0.6 + 0.2 * float(i)), col, 0.7, 0.55, 6.0)
			_shake(main, 6.0, 0.3))
	Fx.glow(parent, foot + Vector2(0, -30), 30.0, area * 1.8, acc, 0.6)
	_scar(main, "rune", foot, area * 0.85, 3.5, col)
	_knock(main, foot, area, 230.0)


static func _big_summon(main: Node, parent: Node2D, foot: Vector2, col: Color, acc: Color) -> void:
	_clip(parent, "sigil", foot + Vector2(0, 6), 0.0, 3.0, col, 1.2)
	_clip(parent, "summon", foot + Vector2(0, 6), 0.0, 1.8, acc, 1.0)
	Fx.ring(parent, foot, 10.0, 240.0, col, 0.6, 0.55, 6.0)
	Fx.glow(parent, foot + Vector2(0, -30), 30.0, 280.0, col, 0.5)
	_scar(main, "rune", foot, 200.0, 3.5, col)
	_shake(main, 5.0, 0.3)


## Nhát đao khổng lồ chém ngang cả màn: hai vệt chéo nhau, xung kích ở đầu vệt.
static func _giant_slash(main: Node, parent: Node2D, at: Vector2, aim: Vector2, area: float, col: Color, acc: Color) -> void:
	var ang := aim.angle()
	var sc := maxf(area * 0.0085, 1.4)   # vệt chém ~100px bán kính ở tỉ lệ 1, cộng điểm đặt cách người 60px
	_clip(parent, "slash_dao", at + aim * 60.0, ang, sc, col, 1.0)
	_later(parent, 0.07, func() -> void:
		var n := _clip(parent, "slash_dao", at + aim * 66.0, ang, sc * 0.85, acc, 1.0, true)
		if n != null:
			n.rotation = ang)
	var tip := at + aim * area * 0.9 + Vector2(0, 28)
	_later(parent, 0.1, func() -> void:
		_clip(parent, "impact_ring", tip, 0.0, 2.2, col, 1.0)
		Fx.ring(parent, tip, 8.0, area * 0.5, col, 0.5, 0.55, 8.0)
		Fx.burst(parent, tip + Vector2(0, -10), Color(0.9, 0.78, 0.6), 22, 240.0, 0.5, 3.6)
		_scar(main, "gash", at + aim * area * 0.5 + Vector2(0, 30), area * 0.5, 5.0, col, true, ang)
		_scar(main, "crack", tip, area * 0.35, 5.0, col)
		_dust(main, tip, area * 0.3, 1.0)
		_knock(main, tip, area * 0.5, 300.0)
		_shake(main, 9.0, 0.35))


# ---------------------------------------------------------------- tiện ích
static func _clip(parent: Node, name: String, pos: Vector2, rot: float, sc: float, tint: Color, hold := 1.0, flip := false) -> Node2D:
	var n := Vfx.play(parent, name, pos, rot, hold, Vector2.ZERO, flip)
	if n != null:
		n.scale = Vector2(sc, -sc if flip else sc)
		n.modulate = Color(tint.lerp(Color.WHITE, 0.35), 1.0)
	return n


static func _blade(main: Node, parent: Node2D, target: Vector2, delay: float, sc: float, height: float, col: Color, acc: Color, big: bool) -> void:
	var b := Blade.new()
	b.main = main
	b.position = target
	b.delay = delay
	b.sc = sc
	b.height = height
	b.col = col
	b.acc = acc
	b.big = big
	parent.add_child(b)


static func _later(node: Node, sec: float, fn: Callable) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.get_tree().create_timer(sec).timeout.connect(fn)


## Vết ghi trên mặt đất (dưới chân nhân vật): crack | scorch | rune | gash | pit. life: giây tồn tại.
static func _scar(main: Node, kind: String, pos: Vector2, radius: float, life: float, col: Color, embers := false, ang := 0.0) -> void:
	var host: Node = main.get("layer_shadows")
	if host == null:
		return
	var sc := Scar.new()
	sc.kind = kind
	sc.radius = radius
	sc.life = life
	sc.col = col
	sc.embers = embers
	sc.ang = ang
	sc.fx = main.fx_layer
	sc.position = pos
	host.add_child(sc)


## Quái trong bán kính bị hất văng ra khỏi tâm (dùng đà bật của Monster._knock).
static func _knock(main: Node, center: Vector2, radius: float, force: float) -> void:
	if main.get_tree() == null:
		return
	for m in main.get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(m) or not ("_knock" in m) or not bool(m.get("alive")):
			continue
		var d: Vector2 = (m as Node2D).position - center
		if d.length() > radius:
			continue
		var dir := d.normalized() if d.length() > 1.0 else Vector2.RIGHT
		m.set("_knock", dir * force * (1.0 - 0.5 * d.length() / radius))


## Mây bụi bốc lên chậm tại điểm nổ: vài đợt hạt đất nâu nối nhau.
static func _dust(main: Node, at: Vector2, radius: float, dur: float) -> void:
	var parent: Node2D = main.fx_layer
	if parent == null:
		return
	var n := int(dur / 0.22)
	for i in n:
		_later(parent, 0.22 * float(i), func() -> void:
			var p := at + Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * radius
			Fx.burst(parent, p, Color(0.62, 0.55, 0.45), 6, 60.0, 0.9, 4.5)
			Fx.glow(parent, p + Vector2(0, -10), 10.0, 46.0, Color(0.55, 0.5, 0.42), 0.8))


static func _shake(main: Node, strength: float, dur: float) -> void:
	if main.get("school") != null:
		main.school.shake(strength, dur)


# ---------------------------------------------------------------- các nút hiệu ứng
## Một thanh kiếm từ trời rơi xuống `target` (gốc nút = mũi kiếm trên mặt đất), có bóng báo trước, cắm lại rồi mờ dần.
class Blade extends Node2D:
	var main: Node
	var delay := 0.0
	var sc := 1.0
	var height := 400.0
	var col := Color.WHITE
	var acc := Color.WHITE
	var big := false
	var fall := 0.2
	var _t := 0.0
	var _landed := false
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 130
		_t = 0.0
		fall = 0.28 if big else 0.2
		var tex := AtlasTexture.new()
		tex.atlas = load(GrandFx.SWORD) as Texture2D
		tex.region = GrandFx.SWORD_REGION
		_spr = Sprite2D.new()
		_spr.texture = tex
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_spr.centered = false
		_spr.offset = Vector2(-60.5, -165.0)
		_spr.scale = Vector2.ONE * sc
		_spr.modulate = Color(col.lerp(Color.WHITE, 0.4), 0.0)
		add_child(_spr)

	func _process(delta: float) -> void:
		_t += delta
		if _t < delay:
			return
		var u := clampf((_t - delay) / fall, 0.0, 1.0)
		if not _landed:
			_spr.position = Vector2(0, -height * (1.0 - u * u))
			_spr.modulate.a = minf(1.0, u * 4.0)
			if u >= 1.0:
				_landed = true
				_land()
		else:
			var k := (_t - delay - fall) / (1.8 if big else 1.2)
			_spr.modulate.a = clampf(1.0 - k, 0.0, 1.0)
			if k >= 1.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		if _landed or _t < delay:
			return
		var u := clampf((_t - delay) / fall, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, (26.0 if not big else 70.0) * sc * 0.5 * (0.4 + 0.6 * u), Color(0, 0, 0, 0.35 * u))

	func _land() -> void:
		var parent := get_parent()
		Fx.ring(parent, position, 4.0, (38.0 if not big else 120.0) * sc * 0.6, col, 0.35, 0.55, 3.0)
		Fx.burst(parent, position + Vector2(0, -6), acc, 6 if not big else 14, 120.0, 0.35, 2.4)
		Vfx.play(parent, "hit", position + Vector2(0, -12), 0.0)
		Fx.glow(parent, position + Vector2(0, -10), 8.0, 50.0 * sc, col, 0.25)
		GrandFx._scar(main, "pit", position, (16.0 if not big else 46.0) * maxf(sc, 0.6), 3.0, col)


## Cột sáng thẳng đứng từ trời đánh xuống `position`, nở ra rồi thu mảnh.
class Pillar extends Node2D:
	var col := Color.WHITE
	var half := 20.0
	var life := 0.5
	var _t := 0.0

	func _ready() -> void:
		z_index = 125
		material = Fx.additive()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u := _t / life
		var w := half * (1.0 + 0.6 * sin(minf(u * 2.0, 1.0) * PI * 0.5)) * (1.0 - maxf(0.0, u - 0.5) * 2.0)
		var a := 0.85 * (1.0 - u * u)
		var top := -820.0
		draw_polygon(PackedVector2Array([Vector2(-w, top), Vector2(w, top), Vector2(w, 0), Vector2(-w, 0)]),
			PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, a), Color(col, a)]))
		var w2 := w * 0.4
		draw_polygon(PackedVector2Array([Vector2(-w2, top), Vector2(w2, top), Vector2(w2, 0), Vector2(-w2, 0)]),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, a), Color(1, 1, 1, a)]))


## Vết dư chấn trên mặt đất: nứt toạc (lõi nóng nguội dần), cháy sém có tàn lửa, vòng rune mờ, vết chém dài, hố kiếm cắm.
class Scar extends Node2D:
	var kind := "crack"
	var radius := 100.0
	var life := 5.0
	var col := Color.WHITE
	var embers := false
	var ang := 0.0
	var fx: Node2D
	var _t := 0.0
	var _emit := 0.0
	var _rays: Array = []   # mỗi tia: mảng điểm

	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.randomize()
		match kind:
			"crack", "pit":
				var n := 8 if kind == "crack" else 4
				for i in n:
					var a := TAU * float(i) / float(n) + r.randf_range(-0.25, 0.25)
					var pts: Array = [Vector2.ZERO]
					var seg_len := radius * r.randf_range(0.55, 1.0)
					var steps := 5
					var cur := Vector2.ZERO
					for k in steps:
						a += r.randf_range(-0.35, 0.35)
						cur += Vector2(cos(a), sin(a)) * seg_len / float(steps)
						pts.append(cur)
					_rays.append(pts)
			"gash":
				for j in 3:
					var pts: Array = []
					var off := Vector2(r.randf_range(-6.0, 6.0), r.randf_range(-10.0, 10.0))
					for k in 8:
						var u := float(k) / 7.0 - 0.5
						pts.append(Vector2(u * radius * 2.0, 0.0) + off + Vector2(0, r.randf_range(-3.0, 3.0)))
					_rays.append(pts)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		if embers and fx != null and is_instance_valid(fx):
			_emit -= delta
			if _emit <= 0.0:
				_emit = 0.18
				var p := global_position + Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * radius * 0.7
				Fx.burst(fx, p, col.lerp(Color(1.0, 0.7, 0.3), 0.5), 2, 40.0, 0.8, 2.2)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((life - _t) / (life * 0.45), 0.0, 1.0) * clampf(_t / 0.08, 0.0, 1.0)
		var heat := clampf(1.0 - _t / (life * 0.7), 0.0, 1.0)   # lõi nóng nguội dần
		var pulse := 0.8 + 0.2 * sin(_t * 6.0)
		if kind == "gash":
			draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		match kind:
			"crack", "pit", "gash":
				if kind != "gash":
					draw_circle(Vector2.ZERO, radius * 0.16, Color(0.05, 0.04, 0.04, 0.5 * fade))
				for pts in _rays:
					var arr := PackedVector2Array(pts)
					draw_polyline(arr, Color(0.06, 0.04, 0.04, 0.9 * fade), 5.0)
					draw_polyline(arr, Color(col, 0.9 * fade * heat * pulse), 2.4)
			"scorch":
				draw_circle(Vector2.ZERO, radius, Color(0.03, 0.02, 0.02, 0.38 * fade))
				draw_circle(Vector2.ZERO, radius * 0.62, Color(0.03, 0.02, 0.02, 0.35 * fade))
				draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 40, Color(col, 0.5 * fade * heat * pulse), 3.0)
			"rune":
				var rot := _t * 0.5
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(col, 0.42 * fade), 2.0)
				draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(col, 0.3 * fade), 2.0)
				for i in 8:
					var a := rot + TAU * float(i) / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(d * radius * 0.72, d * radius, Color(col, 0.4 * fade), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
