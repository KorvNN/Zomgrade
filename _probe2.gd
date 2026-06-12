extends SceneTree
var _t := 0.0
var _started := false
var _step := 0
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
		change_scene_to_file("res://scenes/main/dungeon.tscn")
		return false
	_t += delta
	var lvl: Node3D = root.get_node_or_null("Dungeon")
	if lvl == null:
		return false
	if _t > 4.0 and _step == 0:
		root.get_texture().get_image().save_png("res://_v4_castle_intro.png")
		_step = 1
		Input.action_press("interact")
	elif _step == 1 and _t > 4.3:
		Input.action_release("interact")
		_step = 2
	elif _step == 2 and _t > 4.8:
		_cam = Camera3D.new()
		lvl.add_child(_cam)
		_cam.global_position = Vector3(7.0, 1.7, 2.0)
		_cam.look_at(Vector3(-4.0, 1.9, 2.0))
		_cam.make_current()
		_step = 3
	elif _step == 3 and _t > 5.2:
		root.get_texture().get_image().save_png("res://_v5_entrance.png")
		return true
	return false
