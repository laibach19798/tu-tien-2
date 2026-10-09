extends SceneTree
func _init() -> void:
	Sfx.setup(root)
	var s: Sfx = Sfx._inst
	for step in 3:
		await create_timer(2.5).timeout
		print("t=%.1f built=%s cur=%s" % [(step + 1) * 2.5, Sfx._built.keys(), s._cur])
	Sfx.set_theme("cave"); await create_timer(0.3).timeout
	print("cave -> cur=%s front playing=%s vol=%.1f" % [s._cur, s._music[s._front].playing, s._music[s._front].volume_db])
	await create_timer(3.0).timeout
	print("after fade vol=%.1f old playing=%s" % [s._music[s._front].volume_db, s._music[1 - s._front].playing])
	Sfx.set_music(false); await create_timer(0.2).timeout
	print("music off -> playing=%s %s" % [s._music[0].playing, s._music[1].playing])
	Sfx.set_music(true); Sfx.set_theme("sect"); await create_timer(0.3).timeout
	print("music on -> cur=%s" % s._cur)
	Sfx.step("rock", true)
	quit()
