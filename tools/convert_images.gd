extends SceneTree
## Đổi ảnh (webp/jpg/...) sang png và in kích thước.
## Dùng: Godot_console.exe --headless --path . --script res://tools/convert_images.gd -- <vào> <ra.png> [<vào> <ra.png> ...]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i + 1 < args.size():
		var img := Image.load_from_file(args[i])
		if img == null or img.is_empty():
			printerr("Khong doc duoc: ", args[i])
		else:
			img.convert(Image.FORMAT_RGBA8)
			img.save_png(args[i + 1])
			print("%s -> %s  %dx%d" % [args[i], args[i + 1], img.get_width(), img.get_height()])
		i += 2
	quit()
