extends SceneTree
## So SkinLibrary dựng từ PNG với các file .tres hiện có: cùng animation, số frame, vùng cắt.
## Chạy: godot --headless --path . --script tools/skin_test.gd

func _init() -> void:
	var bad := 0
	for path in DirAccess.get_files_at("res://character/hd/frames"):
		if not path.ends_with(".tres"):
			continue
		var base := path.get_basename()          # vd clothes_robe
		var parts := base.split("_", true, 1)
		var ref: SpriteFrames = load("res://character/hd/frames/" + path)
		if ref == null:
			print("SKIP ", base, ": .tres hỏng (thiếu ảnh tham chiếu)")
			continue
		var got := SkinLibrary.build(parts[0], parts[1])
		if got == null:
			print("FAIL ", base, ": không dựng được")
			bad += 1
			continue
		for anim in ref.get_animation_names():
			if not got.has_animation(anim) or got.get_frame_count(anim) != ref.get_frame_count(anim):
				print("FAIL ", base, " ", anim)
				bad += 1
				continue
			for i in ref.get_frame_count(anim):
				var a: AtlasTexture = ref.get_frame_texture(anim, i)
				var b: AtlasTexture = got.get_frame_texture(anim, i)
				if a.region != b.region or a.atlas.resource_path != b.atlas.resource_path:
					print("FAIL ", base, " ", anim, " frame ", i)
					bad += 1
					break
		print("ok   ", base)
	print("TONG LOI: ", bad)
	quit(1 if bad > 0 else 0)
