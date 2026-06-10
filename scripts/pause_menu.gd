extends CanvasLayer
## ESC ile aç/kapa duraklatma menüsü. Kart ekranı duraklatmışsa devreye girmez.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _root: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		_resume()
	elif not get_tree().paused:
		_pause()
	# tree başka bir şeyce duraklatıldıysa (kart ekranı) dokunma
	get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()


func _resume() -> void:
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.hide()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	vbox.add_child(MenuUI.make_title("DURAKLATILDI", 52))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	vbox.add_child(MenuUI.make_button("DEVAM ET", _resume))
	vbox.add_child(MenuUI.make_button("YENİDEN BAŞLA", _restart))
	vbox.add_child(MenuUI.make_button("ANA MENÜ", _to_menu))
	vbox.add_child(MenuUI.make_button("ÇIKIŞ", get_tree().quit))


func _restart() -> void:
	get_tree().paused = false
	Game.reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
