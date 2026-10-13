extends SceneTree
## Xoá các vùng nền trắng kín nằm BÊN TRONG ảnh (ví dụ khoảng trống dưới vòm cổng).
## Chạy: godot --headless --path . --script res://tools/clean_interior.gd -- <tên prop>...
func _init() -> void:
	for n in OS.get_cmdline_user_args():
		var path := ProjectSettings.globalize_path("res://assets/props/%s.png" % n)
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var seen := PackedByteArray()
		seen.resize(w * h)
		var cleared := 0
		for y0 in h:
			for x0 in w:
				if seen[y0 * w + x0] == 1:
					continue
				var c0 := img.get_pixel(x0, y0)
				if c0.a < 0.5 or c0.r < 0.9 or c0.g < 0.9 or c0.b < 0.9:
					continue
				var cells: Array = []
				var st: Array = [Vector2i(x0, y0)]
				while not st.is_empty():
					var q: Vector2i = st.pop_back()
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen[q.y * w + q.x] == 1:
						continue
					var c := img.get_pixelv(q)
					if c.a < 0.5 or c.r < 0.9 or c.g < 0.9 or c.b < 0.9:
						continue
					seen[q.y * w + q.x] = 1
					cells.append(q)
					st.append(q + Vector2i(1, 0))
					st.append(q + Vector2i(-1, 0))
					st.append(q + Vector2i(0, 1))
					st.append(q + Vector2i(0, -1))
				if cells.size() > 500:
					for q in cells:
						img.set_pixelv(q, Color(0, 0, 0, 0))
					cleared += cells.size()
		print(n, ": interior cleared ", cleared)
		img.save_png(path)
	quit()
