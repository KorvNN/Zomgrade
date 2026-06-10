extends Control
## Ana menü: oyunu başlat / çık.

const LEVEL_SCENE := "res://scenes/main/test_room.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.reset()
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	vbox.add_child(MenuUI.make_title("ZOMGRADE"))

	var subtitle := MenuUI.make_title("zombi dalgalarından sağ çık", 22, Color(0.6, 0.62, 0.65))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	vbox.add_child(MenuUI.make_button("BAŞLA", _on_start))
	vbox.add_child(MenuUI.make_button("ÇIKIŞ", _on_quit))

	var hint := MenuUI.make_title("WASD hareket • Fare nişan • Sol tık ateş • R doldur • ESC duraklat",
			16, Color(0.45, 0.47, 0.5))
	var hint_spacer := Control.new()
	hint_spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(hint_spacer)
	vbox.add_child(hint)


func _on_start() -> void:
	Game.reset()
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_quit() -> void:
	get_tree().quit()
