extends SceneTree
var _t := 0.0
var _started := false
var _stage := 1
var _shot1 := false
var _pressed := false
var _shot2 := false
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	_stage = int(OS.get_environment("SHOT_STAGE"))
func _process(delta: float) -> bool:
	if not _started:
		_started = true
		var game := root.get_node("Game")
		game.set("run_seed", 12345)
		game.set("stage", _stage)
		change_scene_to_file("res://scenes/main/dungeon.tscn")
		return false
	_t += delta
	if _stage == 1:
		if _t > 4.2 and not _shot1:
			_shot1 = true
			root.get_texture().get_image().save_png("res://_levelshot_intro.png")
		if _t > 4.5 and not _pressed:
			_pressed = true
			Input.action_press("interact")
		if _t > 4.7:
			Input.action_release("interact")
		if _t > 7.5 and not _shot2:
			_shot2 = true
			root.get_texture().get_image().save_png("res://_levelshot_1.png")
			return true
	elif _t > 5.0 and not _shot2:
		_shot2 = true
		root.get_texture().get_image().save_png("res://_levelshot_%d.png" % _stage)
		return true
	return false
