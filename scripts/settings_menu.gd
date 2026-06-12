class_name SettingsMenu
extends CanvasLayer

## Crosshair seçimi + diğer görsel ayarlar.
## ConfigFile ile kalıcı kaydeder: user://settings.cfg

const CFG_PATH := "user://settings.cfg"
const CROSSHAIR_DIR := "res://assets/crosshairs/"
const FONT := preload("res://assets/fonts/ui_font.tres")  # Kenney + Türkçe (İŞĞ) fallback

# Kaydedilen ayarlar (global erişim için statik)
static var crosshair_path := "res://assets/crosshairs/crosshair007.png"
static var _loaded := false

signal closed

var _grid: GridContainer
var _preview: TextureRect
var _crosshair_paths: Array[String] = []
var _selected_index := 0


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		crosshair_path = cfg.get_value("display", "crosshair", crosshair_path)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("display", "crosshair", crosshair_path)
	cfg.save(CFG_PATH)


func _ready() -> void:
	load_settings()
	_build_ui()
	_load_crosshair_list()
	_populate_grid()


func _build_ui() -> void:
	layer = 10

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.set_deferred("custom_minimum_size", Vector2(700, 520))
	root.position = Vector2(-350, -260)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var title := Label.new()
	title.text = "AYARLAR"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.5, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sep := HSeparator.new()
	root.add_child(sep)

	var ch_label := Label.new()
	ch_label.text = "NİŞANGAH"
	ch_label.add_theme_font_override("font", FONT)
	ch_label.add_theme_font_size_override("font_size", 22)
	ch_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	root.add_child(ch_label)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)

	# Sol: scroll + grid
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	# Sağ: büyük önizleme
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 320)
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)

	var pv_label := Label.new()
	pv_label.text = "ÖNİZLEME"
	pv_label.add_theme_font_override("font", FONT)
	pv_label.add_theme_font_size_override("font_size", 18)
	pv_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(pv_label)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(100, 100)
	_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.modulate = Color.WHITE
	right.add_child(_preview)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	# Geri butonu
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "KAPAT"
	back_btn.add_theme_font_override("font", FONT)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.custom_minimum_size = Vector2(180, 44)
	back_btn.pressed.connect(_on_close)
	btn_row.add_child(back_btn)


func _load_crosshair_list() -> void:
	_crosshair_paths.clear()
	var dir := DirAccess.open(CROSSHAIR_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			_crosshair_paths.append(CROSSHAIR_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_crosshair_paths.sort()

	# Şu anki seçimi bul
	_selected_index = 0
	for i in _crosshair_paths.size():
		if _crosshair_paths[i] == crosshair_path:
			_selected_index = i
			break


func _populate_grid() -> void:
	for ch in _grid.get_children():
		ch.queue_free()

	for i in _crosshair_paths.size():
		var path := _crosshair_paths[i]
		var tex: Texture2D = load(path)
		if tex == null:
			continue

		var btn := TextureButton.new()
		btn.texture_normal = tex
		btn.custom_minimum_size = Vector2(40, 40)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.modulate = Color(0.4, 1.0, 0.4) if i == _selected_index else Color.WHITE
		btn.pressed.connect(_on_select.bind(i))
		_grid.add_child(btn)

	_update_preview()


func _on_select(index: int) -> void:
	Music.click()
	_selected_index = index
	crosshair_path = _crosshair_paths[index]
	save_settings()

	# Grid renklendirmesi
	for i in _grid.get_child_count():
		_grid.get_child(i).modulate = Color(0.4, 1.0, 0.4) if i == index else Color.WHITE

	_update_preview()
	# HUD crosshair'ını canlı güncelle (oyun içindeyse)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var hud: Node = player.get_node_or_null("HUD")
		if hud and hud.has_method("update_crosshair"):
			hud.update_crosshair(crosshair_path)


func _update_preview() -> void:
	if _selected_index < _crosshair_paths.size():
		_preview.texture = load(_crosshair_paths[_selected_index])


func _on_close() -> void:
	Music.click()
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
