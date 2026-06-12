extends SceneTree
func _initialize() -> void:
	for p in ["res://scripts/game.gd", "res://scripts/dungeon_level.gd"]:
		var r = load(p)
		print("OK " if r != null else "FAIL ", p)
	quit()
