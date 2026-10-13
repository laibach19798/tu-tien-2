extends SceneTree
## NPC thông minh V1 bước 1: tính cách 6 đặc điểm + bộ pháp V1 hợp luật, tất định, lưu/tải, quan sát.
const Data = preload("res://scripts/v1/catalog.gd")
const Origin = preload("res://scripts/v1/origin.gd")
const Progression = preload("res://scripts/v1/progression.gd")
var main: Node
var W: NpcWorld
var failures := 0
var checks := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	OS.set_environment("TUTIEN_FRESH_GAME", "1")
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS " + label)


func names_of(p: Progression) -> String:
	var names: Array = []
	for slot in ["cong", "cong2", "tam", "than", "weapon", "armor", "artifact"]:
		names.append(str(p.item_for(slot).get("definition", "")))
	return ",".join(names)


func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.dialogue.open = false
	W = main.npc_world
	var ids: Array = W.agent_ids()
	check(ids.size() >= 12, "có đủ NPC để lập hồ sơ (%d)" % ids.size())

	# --- tính cách
	var traits_ok := true
	for id in ids:
		var t: Dictionary = W.traits_of(str(id))
		traits_ok = traits_ok and t.size() == 6
		for k in NpcProfile.TRAIT_IDS:
			traits_ok = traits_ok and t.has(k) and int(t[k]) >= 0 and int(t[k]) <= 100
	check(traits_ok, "mọi NPC có đủ 6 đặc điểm trong 0–100")
	var qd: Dictionary = W.traits_of("quan_dao")
	var lv: Dictionary = W.traits_of("luc_van")
	check(int(qd.greed) > int(lv.greed) and int(qd.caution) < int(lv.caution), "tính cách khác nhau theo dữ liệu (Quan Đạo tham, Lục Vân thận trọng)")
	check(NpcProfile.trait_words(qd).has("tham lam") and NpcProfile.trait_words(lv).has("thận trọng"), "mô tả tính cách bằng lời")

	# --- bộ pháp hợp luật
	var legal_ok := true
	var book_sets := {}
	var styles := {}
	for id in ids:
		var d: Dictionary = W.def_of(str(id))
		var p: Progression = W.profile_of(str(id))
		legal_ok = legal_ok and p != null and Origin.valid(p.origin)
		var sect := NpcProfile.sect_of(d)
		var step := int(d.get("step", 0))
		var elder: bool = bool(d.get("elder", false)) or step >= 25
		for slot in p.equipped:
			var uid: String = str(p.equipped[slot])
			if uid == "":
				continue
			var item: Dictionary = p.instances[uid]
			var def: Dictionary = Data.definition(str(item.definition))
			legal_ok = legal_ok and bool(item.learned) and NpcProfile.legal(def, sect, step, elder)
			legal_ok = legal_ok and (str(def.slot) == slot or (slot == "cong2" and str(def.slot) == "cong"))
		legal_ok = legal_ok and not p.item_for("cong").is_empty() and not p.item_for("tam").is_empty() and not p.item_for("than").is_empty()
		book_sets[str(p.item_for("cong").get("definition", "")) + "/" + str(p.item_for("tam").get("definition", ""))] = true
		styles[W.style_of(str(id))] = true
	check(legal_ok, "mọi NPC: tiên thiên hợp lệ, bí tịch đúng ô, đã học, đúng luật phổ truyền/nội truyền, đủ cảnh giới")
	check(book_sets.size() >= 5, "bộ pháp đa dạng, không ai cùng một khuôn (%d bộ Công/Tâm khác nhau)" % book_sets.size())
	var style_ok := true
	for s in styles:
		style_ok = style_ok and NpcProfile.STYLES.has(s)
	check(style_ok and styles.size() >= 3, "lối đánh thuộc 6 phong cách và có ít nhất 3 kiểu khác nhau (%d)" % styles.size())

	# --- luật bí tịch
	var secret := Data.definition("thien_mach_quyet")
	var inner := Data.definition("kiem_wave")
	var public := Data.definition("kiem_cut")
	check(NpcProfile.legal(public, "", 0), "Phổ Truyền: tán tu cũng có thể có")
	check(not NpcProfile.legal(inner, "dao_mon", 20) and NpcProfile.legal(inner, "kiem_tong", 20), "Nội Truyền: chỉ đệ tử cùng tông")
	check(not NpcProfile.legal(inner, "kiem_tong", 3), "chưa đủ cảnh giới thì không học được")
	check(not NpcProfile.legal(secret, "ngu_hanh", 40, false) and NpcProfile.legal(secret, "ngu_hanh", 40, true), "Trấn Phái: chỉ trưởng lão cùng tông")
	var mt: Progression = W.profile_of("mac_tran")
	check(str(mt.sect) == "kiem_tong", "Sư phụ Mặc Trần thuộc Kiếm Tông")

	# --- tất định + lưu/tải
	var before := {}
	for id in ids:
		before[str(id)] = names_of(W.profile_of(str(id)))
	var again := {}
	for id in ids:
		again[str(id)] = names_of(NpcProfile.build(str(id), W.def_of(str(id))))
	check(before == again, "dựng lại từ id cho đúng cùng một bộ pháp (tất định)")
	var saved: Dictionary = W.to_dict()
	var W2 := NpcWorld.new()
	W2.main = main
	W2._data = W._data
	W2.from_dict(JSON.parse_string(JSON.stringify(saved)))
	var same := true
	for id in ids:
		same = same and names_of(W2.profile_of(str(id))) == before[str(id)]
		for k in NpcProfile.TRAIT_IDS:
			same = same and int(W2.traits_of(str(id))[k]) == int(W.traits_of(str(id))[k])
	check(same, "lưu/tải giữ nguyên bộ pháp và tính cách")
	W2.free()
	var old_state: Dictionary = JSON.parse_string(JSON.stringify(W.to_dict()))
	for id in old_state["states"]:
		(old_state["states"][id] as Dictionary).erase("v1")
		(old_state["states"][id] as Dictionary).erase("traits")
	var W3 := NpcWorld.new()
	W3.main = main
	W3._data = W._data
	W3.from_dict(old_state)
	var okold := true
	for id in ids:
		okold = okold and W3.profile_of(str(id)) != null and W3.traits_of(str(id)).size() == 6
		okold = okold and names_of(W3.profile_of(str(id))) == before[str(id)]
	check(okold, "bản lưu cũ chưa có hồ sơ: tự bổ sung đúng cùng bộ pháp")
	W3.free()

	# --- tính cách nghiêng lựa chọn bí tịch (không tuyệt đối)
	var fighter := {"name": "Thử", "step": 20, "strength": 2, "sect": "", "role": "tán tu"}
	var calm_cnt := 0
	var aggro_cnt := 0
	var ta := {"ambition": 50, "greed": 50, "righteous": 50, "caution": 5, "aggression": 100, "curiosity": 20}
	var tc := {"ambition": 50, "greed": 50, "righteous": 50, "caution": 100, "aggression": 5, "curiosity": 20}
	for n in 60:
		var idn := "thu_%d" % n
		var def_a := fighter.duplicate()
		def_a["traits"] = ta
		var def_c := fighter.duplicate()
		def_c["traits"] = tc
		if NpcProfile.style_of(NpcProfile.build(idn, def_a), ta) == "approach":
			aggro_cnt += 1
		if NpcProfile.style_of(NpcProfile.build(idn, def_c), tc) in ["counter", "survive"]:
			calm_cnt += 1
	check(aggro_cnt >= 40, "hiếu chiến cao nghiêng về lối áp sát (%d/60)" % aggro_cnt)
	check(calm_cnt >= 30, "thận trọng cao nghiêng về phản công / sinh tồn (%d/60)" % calm_cnt)

	# --- hội thoại quan sát
	var node := EncounterNode.new()
	node.setup("wnpc_luc_van", {"name": "Lục Vân", "kind": "figure"})
	W.talk(node)
	check(main.dialogue.open, "mở hội thoại với NPC")
	main.dialogue.open = false
	W._observe("luc_van")
	check(main.dialogue.open, "quan sát NPC hiện thông tin")
	main.dialogue.open = false
	node.free()

	print("NPC PROFILE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
