extends SceneTree
func _init() -> void:
	var ids := ["slash","qi","fly","storm","hit","hit_big","mhurt","mdie","hurt","death","pickup","coin","ui_open","ui_close","ui_click","toast","heal","levelup","breakthrough","fail","craft"]
	for id in ids:
		var w: AudioStreamWAV = Sfx._make(id)
		if w == null:
			print("NULL ", id); continue
		var d := w.data; var peak := 0; var n := d.size() / 2
		for i in n: peak = maxi(peak, absi(d.decode_s16(i * 2)))
		var tail := absi(d.decode_s16((n - 1) * 2))
		print("%s dur=%.2fs peak=%d tail=%d" % [id, float(n) / Sfx.RATE, peak, tail])
	var t := Time.get_ticks_msec()
	var s := Sfx.new(); s._build_music()
	var m := s._music_stream; var pk := 0
	for i in range(0, m.data.size() / 2, 7): pk = maxi(pk, absi(m.data.decode_s16(i * 2)))
	print("music %.1fs peak=%d build=%dms ends=%d,%d" % [m.data.size() / 2.0 / Sfx.MUSIC_RATE, pk, Time.get_ticks_msec() - t, m.data.decode_s16(0), m.data.decode_s16(m.data.size() - 2)])
	quit()
