class_name MenuUI
extends RefCounted
## Menü butonu/başlık üretimi için ortak yardımcılar (ana menü + duraklatma).

const FONT := preload("res://assets/fonts/ui_font.tres")  # Kenney + Türkçe (İŞĞ) fallback


static func make_title(text: String, size := 84, color := Color(0.5, 0.85, 0.3)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func make_button(text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(340, 58)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 26)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.17)
	normal.border_color = Color(0.5, 0.85, 0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.5, 0.85, 0.3)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.4, 0.7, 0.25)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.1, 0.08))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.1, 0.08))

	# tıklama sesi (kalıcı autoload'dan çalar → sahne değişse de kesilmez), sonra eylem
	btn.pressed.connect(func() -> void:
		Music.click()
		on_press.call())
	return btn
