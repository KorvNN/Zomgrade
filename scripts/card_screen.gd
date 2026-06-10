extends CanvasLayer
## Level atlayınca oyunu durdurup 3 kart sunan ekran.

const RARITY_COLORS: Array[Color] = [
	Color(0.55, 0.58, 0.62),
	Color(0.30, 0.58, 0.95),
	Color(0.68, 0.36, 0.90),
	Color(0.97, 0.72, 0.20),
]
const RARITY_NAMES := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
const RARITY_WEIGHTS := [60.0, 26.0, 10.0, 4.0]

var pool: Array[UpgradeCard] = []
var _queue := 0
var _showing := false
var _font: FontFile

@onready var player: Node = get_parent()
@onready var weapon: Node = get_node("%Gun")

var _root: Control
var _title: Label
var _card_row: HBoxContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/Kenney Future Narrow.ttf")
	_load_pool()
	_build_ui()
	Game.leveled_up.connect(_on_leveled_up)


func _load_pool() -> void:
	for file in DirAccess.get_files_at("res://resources/cards"):
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			pool.append(load("res://resources/cards/" + file.trim_suffix(".remap")))


func _on_leveled_up(_new_level: int) -> void:
	_queue += 1
	if not _showing:
		_show_next()


func _show_next() -> void:
	_showing = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$LevelUpSfx.play()

	_title.text = "SEVİYE %d — BİR KART SEÇ" % Game.level
	for child in _card_row.get_children():
		child.queue_free()

	var choices := _draw_cards(3)
	for i in choices.size():
		var card_ui := _make_card(choices[i])
		_card_row.add_child(card_ui)
		card_ui.modulate.a = 0.0
		var tween := card_ui.create_tween()
		tween.tween_interval(0.07 * i)
		tween.tween_property(card_ui, "modulate:a", 1.0, 0.18)
	_root.show()


func _draw_cards(count: int) -> Array[UpgradeCard]:
	var eligible := pool.filter(func(c: UpgradeCard) -> bool: return c.is_available())
	var result: Array[UpgradeCard] = []
	while result.size() < count and not eligible.is_empty():
		var total := 0.0
		for c: UpgradeCard in eligible:
			total += RARITY_WEIGHTS[c.rarity]
		var roll := randf() * total
		for c: UpgradeCard in eligible:
			roll -= RARITY_WEIGHTS[c.rarity]
			if roll <= 0.0:
				result.append(c)
				eligible.erase(c)
				break
	return result


func _pick(card: UpgradeCard) -> void:
	var prev_max_hp: float = player.max_health
	card.apply(player, weapon)
	Game.picked_cards[card.id] = Game.card_count(card.id) + 1
	# max can arttıysa farkı aynen iyileştir
	if player.max_health > prev_max_hp:
		player.heal(player.max_health - prev_max_hp)
	weapon.refresh_stats()
	player.refresh_stats()
	$PickSfx.play()

	_queue -= 1
	if _queue > 0:
		_show_next()
	else:
		_root.hide()
		_showing = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.hide()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 24)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_card_row)


func _make_card(card: UpgradeCard) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(230, 310)
	btn.focus_mode = Control.FOCUS_NONE

	var color := RARITY_COLORS[card.rarity]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	var hover := style.duplicate()
	hover.bg_color = Color(0.14, 0.16, 0.20)
	hover.set_border_width_all(5)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14
	vbox.offset_right = -14
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var rarity_label := Label.new()
	rarity_label.text = RARITY_NAMES[card.rarity]
	rarity_label.add_theme_font_override("font", _font)
	rarity_label.add_theme_font_size_override("font_size", 15)
	rarity_label.add_theme_color_override("font_color", color)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_label)

	var title_label := Label.new()
	title_label.text = card.title
	title_label.add_theme_font_override("font", _font)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var desc_label := Label.new()
	desc_label.text = card.description
	var stacks := Game.card_count(card.id)
	if stacks > 0:
		desc_label.text += "\n\n(Sahip: %d/%d)" % [stacks, card.max_stacks]
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	btn.pressed.connect(_pick.bind(card))
	return btn
