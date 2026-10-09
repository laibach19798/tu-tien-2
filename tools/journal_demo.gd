extends SceneTree
## Chup so tay: Godot_console.exe --path . --script res://tools/journal_demo.gd --write-movie <thu muc>/f.png --fixed-fps 30 --quit-after 120

var main: Node
var frame := 0


func _initialize() -> void:
	OS.set_environment("TUTIEN_NO_SAVE", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.school.joined = true
		main.quests.states["q1"] = "done"
		main.quests.states["q2"] = "done"
		main.quests.states["q3"] = "active"
		main.quests.kills["wolf"] = 2
		main.quests.states["q6"] = "active"
		main.journal.open_ui("char")
	if frame == 40:
		main.journal.open_ui("quest")
	if frame == 80:
		main.journal._sel_quest = "q6"
		main.journal.open_ui("quest")
	return false