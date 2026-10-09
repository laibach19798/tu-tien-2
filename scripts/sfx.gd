extends Node
class_name Sfx
## Âm thanh: hiệu ứng và nhạc nền đều được tổng hợp bằng code (không cần file âm thanh).
## Dùng: Sfx.setup(node) một lần khi vào game, sau đó Sfx.play("hit") ở bất cứ đâu.

const RATE := 22050
const MUSIC_RATE := 11025
const VOICES := 10
const SETTINGS_PATH := "user://settings.cfg"

static var _inst: Sfx
static var _cache := {}
static var _last := {}
static var sfx_on := true
static var music_on := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _task := -1


static func setup(parent: Node) -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_on = bool(cfg.get_value("audio", "sfx", true))
		music_on = bool(cfg.get_value("audio", "music", true))
	_inst = Sfx.new()
	_inst.name = "Sfx"
	_inst.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(_inst)


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -17.0
	add_child(_music)
	_task = WorkerThreadPool.add_task(_build_music)   # nhạc nền mất vài giây để dựng nên làm ở luồng phụ


func _process(_dt: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_music.stream = _music_stream
		_apply_music()


static func _apply_music() -> void:
	if _inst == null or _inst._music.stream == null:
		return
	if music_on and not _inst._music.playing:
		_inst._music.play()
	elif not music_on:
		_inst._music.stop()


static func set_sfx(on: bool) -> void:
	sfx_on = on
	_save()


static func set_music(on: bool) -> void:
	music_on = on
	_apply_music()
	_save()


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.set_value("audio", "music", music_on)
	cfg.save(SETTINGS_PATH)


## Phát một hiệu ứng. pitch/vol_db để biến thể hoá; cùng một tiếng không phát lại trong 45 ms.
static func play(id: String, pitch := 1.0, vol_db := 0.0) -> void:
	if _inst == null or not sfx_on or not is_instance_valid(_inst):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -1000)) < 45:
		return
	_last[id] = now
	if not _cache.has(id):
		_cache[id] = _make(id)
	var stream: AudioStreamWAV = _cache[id]
	if stream == null:
		return
	var p: AudioStreamPlayer = _inst._players[_inst._next]
	_inst._next = (_inst._next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = -4.0 + vol_db
	p.play()


# ---------------------------------------------------------------- tổng hợp
static func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


## fn(t, k) -> mẫu; t = giây, k = t / dur (0..1)
static func _gen(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var fade := minf(1.0, (dur - t) / 0.012)   # tắt dần 12 ms cuối để không bị tiếng click
		s[i] = tanh(float(fn.call(t, t / dur)) * 0.8) * fade
	return _wav(s, RATE)


static func _sine(f: float, t: float) -> float:
	return sin(TAU * f * t)


static func _noise() -> float:
	return randf() * 2.0 - 1.0


static func _tone(f: float, t: float, decay: float) -> float:
	return (_sine(f, t) + 0.35 * _sine(f * 2.0, t)) * exp(-t * decay)


static func _make(id: String) -> AudioStreamWAV:
	var st := [0.0, 0.0]
	match id:
		"slash":
			return _gen(0.22, func(t, k):
				st[0] += lerpf(0.55, 0.08, k) * (_noise() - st[0])
				return st[0] * 2.6 * sin(PI * pow(k, 0.7)))
		"qi":
			return _gen(0.32, func(t, k):
				var f := lerpf(480.0, 1250.0, k)
				st[0] += f / RATE
				return (sin(TAU * st[0]) + 0.3 * sin(TAU * st[0] * 2.0)) * 0.5 * sin(PI * k))
		"fly":
			return _gen(0.4, func(t, k):
				st[0] += lerpf(0.4, 0.05, k) * (_noise() - st[0])
				st[1] += lerpf(900.0, 300.0, k) / RATE
				return (st[0] * 1.8 + sin(TAU * st[1]) * 0.25) * sin(PI * pow(k, 0.6)))
		"storm":
			return _gen(0.9, func(t, k):
				st[0] += 0.03 * (_noise() - st[0])
				var crack := _noise() * 0.5 if randf() < 0.012 else 0.0
				return (st[0] * 5.0 + _sine(58.0, t) * 0.4 + crack) * sin(PI * pow(k, 0.5)) * (1.0 - k * 0.4))
		"hit":
			return _gen(0.15, func(t, k):
				st[1] += lerpf(190.0, 60.0, k) / RATE
				return (sin(TAU * st[1]) * 0.8 + _noise() * 0.5 * exp(-t * 60.0)) * exp(-t * 18.0))
		"hit_big":
			return _gen(0.3, func(t, k):
				st[1] += lerpf(150.0, 42.0, k) / RATE
				return (sin(TAU * st[1]) * 1.0 + _noise() * 0.6 * exp(-t * 40.0)) * exp(-t * 9.0))
		"mhurt":
			return _gen(0.14, func(t, k):
				st[1] += lerpf(330.0, 170.0, k) / RATE
				return (signf(sin(TAU * st[1])) * 0.25 + sin(TAU * st[1]) * 0.4) * exp(-t * 14.0))
		"mdie":
			return _gen(0.5, func(t, k):
				st[1] += lerpf(280.0, 55.0, k) / RATE
				var saw := fmod(st[1], 1.0) * 2.0 - 1.0
				return (saw * 0.35 + sin(TAU * st[1]) * 0.4) * (1.0 - k) * (1.0 - k))
		"hurt":
			return _gen(0.28, func(t, k):
				st[1] += lerpf(160.0, 70.0, k) / RATE
				return (sin(TAU * st[1]) * 0.7 + _noise() * 0.35 * exp(-t * 30.0)) * exp(-t * 9.0))
		"death":
			return _gen(1.4, func(t, k):
				st[1] += lerpf(230.0, 45.0, k) / RATE
				return sin(TAU * st[1]) * 0.6 * (1.0 - k))
		"pickup":
			return _gen(0.22, func(t, k):
				return _tone(880.0 if t < 0.07 else 1320.0, t if t < 0.07 else t - 0.07, 14.0) * 0.55)
		"coin":
			return _gen(0.3, func(t, k):
				return _tone(1568.0 if t < 0.06 else 2093.0, t if t < 0.06 else t - 0.06, 11.0) * 0.4)
		"ui_open":
			return _gen(0.12, func(t, k):
				st[1] += lerpf(500.0, 800.0, k) / RATE
				return sin(TAU * st[1]) * 0.35 * sin(PI * k))
		"ui_close":
			return _gen(0.12, func(t, k):
				st[1] += lerpf(800.0, 500.0, k) / RATE
				return sin(TAU * st[1]) * 0.35 * sin(PI * k))
		"ui_click":
			return _gen(0.06, func(t, k): return _tone(720.0, t, 40.0) * 0.45)
		"toast":
			return _gen(0.14, func(t, k): return _tone(1000.0 if t < 0.05 else 1250.0, t if t < 0.05 else t - 0.05, 24.0) * 0.3)
		"heal":
			return _gen(0.5, func(t, k):
				var idx := mini(int(t / 0.1), 3)
				return _tone([523.0, 659.0, 784.0, 1047.0][idx], t - idx * 0.1, 7.0) * 0.4)
		"levelup":
			return _gen(0.8, func(t, k):
				var idx := mini(int(t / 0.12), 4)
				return _tone([392.0, 523.0, 659.0, 784.0, 1047.0][idx], t - idx * 0.12, 5.0) * 0.45)
		"breakthrough":
			return _gen(2.2, func(t, k):
				var swell := sin(PI * pow(k, 0.8))
				var s := 0.0
				for f in [196.0, 294.0, 392.0, 523.0, 659.0]:
					s += _sine(f, t) * 0.12 + _sine(f * 2.004, t) * 0.04
				return (s + _sine(1568.0, t) * 0.06 * exp(-pow((t - 0.5) * 3.0, 2.0))) * swell)
		"fail":
			return _gen(0.7, func(t, k):
				st[1] += lerpf(330.0, 100.0, k) / RATE
				var tri := absf(fmod(st[1], 1.0) * 4.0 - 2.0) - 1.0
				return tri * 0.5 * (1.0 - k))
		"craft":
			return _gen(1.0, func(t, k):
				return (_sine(1047.0, t) + 0.5 * _sine(1047.0 * 2.76, t) * exp(-t * 6.0)) * exp(-t * 5.0) * 0.4)
		"meditate":
			return _gen(1.2, func(t, k):
				return (_sine(220.0, t) * 0.3 + _sine(330.0, t) * 0.2 + _sine(440.0, t) * 0.1) * sin(PI * k))
	return null


## Làm tròn tần số về bội của 1/24 Hz để vòng nhạc 24 giây nối liền, không bị click.
static func _loopf(f: float) -> float:
	return roundf(f * 24.0) / 24.0


# ---------------------------------------------------------------- nhạc nền (ngũ cung, chậm, như đàn tranh + pad)
func _build_music() -> void:
	var len_s := 24.0
	var n := int(len_s * MUSIC_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	# 4 hợp âm, mỗi hợp âm sống 12 giây, cách nhau 6 giây, cửa sổ sin² nên nối vòng liền mạch
	var chords := [[220.0, 261.63, 329.63], [196.0, 261.63, 293.66], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
	var scale := [440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5].map(_loopf)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var notes: Array = []   # [thời điểm, tần số]
	for k in 14:
		if rng.randf() < 0.78:
			notes.append([k * 1.5 + (0.0 if rng.randf() < 0.7 else 0.75), scale[rng.randi_range(0, scale.size() - 1)]])
	for i in n:
		var t := float(i) / MUSIC_RATE
		var v := 0.0
		for c in 4:
			var u := fposmod(t - c * 6.0, len_s)
			if u < 12.0:
				var w := pow(sin(PI * u / 12.0), 2.0)
				for f in chords[c]:
					f = _loopf(f)
					var vib := 1.0 + 0.002 * sin(TAU * 4.5 * t)
					v += w * (sin(TAU * f * t * vib) * 0.05 + sin(TAU * _loopf(f * 2.003) * t) * 0.018)
		for nt in notes:
			var d := fposmod(t - float(nt[0]), len_s)
			if d < 3.0:
				var f: float = nt[1]
				v += (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) * exp(-d * 6.0) + 0.15 * sin(TAU * f * 3.0 * t) * exp(-d * 9.0)) * exp(-d * 1.8) * 0.07
		s[i] = v
	var w := _wav(s, MUSIC_RATE)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_music_stream = w
