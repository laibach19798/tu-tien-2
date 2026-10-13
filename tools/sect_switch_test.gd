extends SceneTree
## Chọn tông V1 khác Kiếm Tông: sân tông của người chơi đổi theo, chiến sự và map vẫn hợp lệ.
const Origin = preload("res://scripts/v1/origin.gd")
var main: Node
var failures := 0

func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var rt = main.cultivation_v1
	check(SectWar.PLAYER == "kiem_tong", "mặc định Kiếm Tông")
	rt.state.origin = Origin.sample()
	rt.state.origin.confirmed = false
	rt.state.sect = ""
	rt.confirm_origin(Origin.sample(), "dao_mon")
	check(SectWar.PLAYER == "xich_viem", "chọn Đao Môn → tông người chơi là Xích Viêm")
	check(Maps.DEFS["sect_xich_viem"]["tiles"] == "xv" and Maps.DEFS["sect_kiem_tong"]["tiles"] == "jade", "mỗi tông có bộ gạch sân riêng; chọn tông khác Kiếm Tông không làm mất bố cục")
	main.switch_map_now("sect_xich_viem", Maps.COMPOUND_ENTRY)
	await process_frame
	check(main.current_map == "sect_xich_viem" and main.npcs.size() > 0, "vào được sân tông mới, có NPC các điện")
	check(main.war.owned_by_player().size() > 0, "người chơi có địa bàn khởi đầu")
	var saved: Dictionary = rt.state.to_dict()
	SectWar.set_player("kiem_tong")
	Maps.refresh_sects()
	rt.restore({"cultivation_v1": saved})
	check(SectWar.PLAYER == "xich_viem", "tải bản lưu khôi phục tông của người chơi")
	print("SECT SWITCH: %d failures" % failures)
	quit(1 if failures else 0)
