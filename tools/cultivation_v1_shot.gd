extends SceneTree
var main: Node

func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")

func shot(page: String) -> void:
	main.cultivation_v1.ui.open_ui(page)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/v1_" + page + ".png")

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await shot("origin")
	main.cultivation_v1.confirm_origin(preload("res://scripts/v1/origin.gd").sample(), "kiem_tong")
	for page in ["loadout", "books", "gear", "acquire"]:
		await shot(page)
	main.cultivation_v1.ui.hide()
	main.journal.open_ui("char")
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/v1_character.png")
	quit()
