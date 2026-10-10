extends SceneTree
## Xoá nền đặc của ảnh Pixellab: flood fill từ mọi pixel ở viền, mỗi vùng nền phẳng một màu.
## Chạy: godot --headless --path . --script res://tools/clean_bg.gd -- <tên prop> [<tên prop>...]
const TOL := 0.075

func _init() -> void:
	var names := OS.get_cmdline_user_args()
	for n in names:
		var path := ProjectSettings.globalize_path("res://assets/props/%s.png" % n)
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var seen := PackedByteArray()
		seen.resize(w * h)
		var cleared := 0
		var seeds: Array = []
		for x in w:
			seeds.append(Vector2i(x, 0))
			seeds.append(Vector2i(x, h - 1))
		for y in h:
			seeds.append(Vector2i(0, y))
			seeds.append(Vector2i(w - 1, y))
		for sd in seeds:
			if seen[sd.y * w + sd.x] == 1 or img.get_pixelv(sd).a < 0.5:
				continue
			var ref := img.get_pixelv(sd)
			var stack: Array = [sd]
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x] == 1:
					continue
				var c := img.get_pixelv(p)
				if c.a < 0.5 or absf(c.r - ref.r) + absf(c.g - ref.g) + absf(c.b - ref.b) > TOL * 3.0:
					continue
				seen[p.y * w + p.x] = 1
				img.set_pixelv(p, Color(0, 0, 0, 0))
				cleared += 1
				stack.append(p + Vector2i(1, 0))
				stack.append(p + Vector2i(-1, 0))
				stack.append(p + Vector2i(0, 1))
				stack.append(p + Vector2i(0, -1))
		# bỏ các mảnh nhỏ rời (chữ ký / watermark của công cụ vẽ)
		var comp := PackedByteArray()
		comp.resize(w * h)
		for y0 in h:
			for x0 in w:
				if comp[y0 * w + x0] == 1 or img.get_pixel(x0, y0).a < 0.5:
					continue
				var cells: Array = []
				var st: Array = [Vector2i(x0, y0)]
				while not st.is_empty():
					var q: Vector2i = st.pop_back()
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or comp[q.y * w + q.x] == 1 or img.get_pixelv(q).a < 0.5:
						continue
					comp[q.y * w + q.x] = 1
					cells.append(q)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
						st.append(q + d)
				if cells.size() < 220:
					for q in cells:
						img.set_pixelv(q, Color(0, 0, 0, 0))
		# cắt sát phần còn lại để chân tòa nhà nằm đúng đáy ảnh
		var used := img.get_used_rect()
		if used.size.x > 0:
			img = img.get_region(used)
		print(n, ": cleared ", cleared, " of ", w * h, " -> ", img.get_width(), "x", img.get_height())
		img.save_png(path)
	quit()
