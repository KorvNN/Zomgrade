extends SceneTree
var _t := 0.0
var _started := false
var _cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
func _process(delta: float) -> bool:
	if not _started:
		_started = true
		var game := root.get_node("Game")
		game.set("run_seed", 12345)
		game.set("stage", 7)
		game.set("intro_shown", true)
		game.set("castle_intro_shown", true)
		change_scene_to_file("res://scenes/main/dungeon.tscn")
		return false
	_t += delta
	var lvl: Node3D = root.get_node_or_null("Dungeon")
	if lvl == null:
		return false
	if _t > 4.5 and _cam == null:
		print("EXIT CELL: ", lvl.get("maze").exit)
		_cam = Camera3D.new()
		lvl.add_child(_cam)
		_cam.global_position = Vector3(2, 16.0, 2)
		_cam.look_at(Vector3(2.01, 0, 2))
		_cam.make_current()
	if _t > 5.0:
		root.get_texture().get_image().save_png("res://_v6_topdown.png")
		return true
	return false
