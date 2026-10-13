extends SceneTree
## Dọn ảnh prop: giữ lại mảng pixel liền lớn nhất (bỏ mây/mảnh rời), cắt gọn viền trong suốt.
## Chạy: godot --headless --path . --script res://tools/tidy_prop.gd -- <tên prop> [<tên prop>...]
func _init() -> void:
	for n in OS.get_cmdline_user_args():
		var path := ProjectSettings.globalize_path("res://assets/props/%s.png" % n)
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var label := PackedInt32Array()
		label.resize(w * h)
		var sizes: Array = [0]
		var next := 0
		for y0 in h:
			for x0 in w:
				if label[y0 * w + x0] != 0 or img.get_pixel(x0, y0).a < 0.16:
					continue
				next += 1
				var count := 0
				var stack: Array = [Vector2i(x0, y0)]
				label[y0 * w + x0] = next
				while not stack.is_empty():
					var p: Vector2i = stack.pop_back()
					count += 1
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var q := Vector2i(p.x + dx, p.y + dy)
							if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or label[q.y * w + q.x] != 0:
								continue
							if img.get_pixel(q.x, q.y).a < 0.16:
								continue
							label[q.y * w + q.x] = next
							stack.append(q)
				sizes.append(count)
		var best := 1
		for i in range(1, sizes.size()):
			if int(sizes[i]) > int(sizes[best]):
				best = i
		var minx := w
		var miny := h
		var maxx := 0
		var maxy := 0
		var removed := 0
		for y in h:
			for x in w:
				if label[y * w + x] != best:
					if img.get_pixel(x, y).a > 0.0:
						removed += 1
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					minx = mini(minx, x)
					miny = mini(miny, y)
					maxx = maxi(maxx, x)
					maxy = maxi(maxy, y)
		var out := img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
		out.save_png(path)
		print("%s: %d mảnh, giữ mảng lớn nhất, bỏ %d pixel -> %dx%d" % [n, next, removed, out.get_width(), out.get_height()])
	quit()
