extends SceneTree
func _init() -> void:
	var ids := ["slash","qi","fly","storm","hit","hit_big","mhurt","mdie","hurt","death","pickup","coin","ui_open","ui_close","ui_click","toast","heal","levelup","breakthrough","fail","craft","step_grass","step_stone","step_rock"]
	for id in ids:
		var w: AudioStreamWAV = Sfx._make(id)
		if w == null:
			print("NULL ", id); continue
		var d := w.data; var peak := 0; var n := d.size() / 2
		for i in n: peak = maxi(peak, absi(d.decode_s16(i * 2)))
		var tail := absi(d.decode_s16((n - 1) * 2))
		print("%s dur=%.2fs peak=%d tail=%d" % [id, float(n) / Sfx.RATE, peak, tail])
	var s := Sfx.new()
	for theme in Sfx.THEMES:
		var t := Time.get_ticks_msec()
		s._build_theme(theme)
		var m: AudioStreamWAV = Sfx._built[theme]; var pk := 0
		for i in range(0, m.data.size() / 2, 7): pk = maxi(pk, absi(m.data.decode_s16(i * 2)))
		print("music %s %.1fs peak=%d build=%dms seam=%d,%d" % [theme, m.data.size() / 2.0 / Sfx.MUSIC_RATE, pk, Time.get_ticks_msec() - t, m.data.decode_s16(0), m.data.decode_s16(m.data.size() - 2)])
	quit()
