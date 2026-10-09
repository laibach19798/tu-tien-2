extends SceneTree
## Kiem tra vung moi: so luong quai theo loai, NPC moi, nhiem vu moi, tham vung, boss.
var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 6:
		var by := {}
		for m in main.monsters:
			by[m.kind_id] = int(by.get(m.kind_id, 0)) + 1
		print("quai theo loai: ", by)
		var ids := []
		for n in main.npcs:
			ids.append(n.npc_id)
		print("npc: ", ids)
		print("world: ", main.WORLD, " blockers: ", main.blockers.size(), " props: ", main.prop_log.size(), " herbs: ", main.herbs.size())
		# tham vung
		main.player.position = WorldExpansion.SECT_C
		main._check_regions()
		main.player.position = WorldExpansion.CAVE
		main._check_regions()
		print("visited: ", main.quests.visited)
		# nhiem vu moi
		main.quests.states["q5"] = "done"
		main.quests.states["q6"] = "done"
		main.quests.states["q8"] = "active"
		print("q8 status: ", main.quests.status(_idx("q8")), "  q9: ", main.quests.status(_idx("q9")), "  q10: ", main.quests.status(_idx("q10")))
		# boss
		for m in main.monsters:
			if m.kind_id == "wolf_king":
				main.player.position = m.position + Vector2(150, 0)
				print("boss hp ", m.hp, " tai ", m.position, " khu an toan: ", main.is_safe(m.position))
				var before: int = main.quests.kills.get("wolf_king", 0)
				m.take_hit(99999.0, main.player.position)
				print("giet boss: kills ", before, " -> ", main.quests.kills.get("wolf_king", 0))
		print("an toan tai trai: ", main.is_safe(WorldExpansion.CAMP), " tai san kiem tong: ", main.is_safe(WorldExpansion.SECT_C))
		print("=== EXPANSION TEST XONG ===")
		quit()
	return false


func _idx(id: String) -> int:
	for i in QuestLog.QUESTS.size():
		if QuestLog.QUESTS[i]["id"] == id:
			return i
	return -1