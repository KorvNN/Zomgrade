extends CanvasLayer
## HUD: can, XP, mermi, kill sayacı, hitmarker ve hasar vinyeti.

const SettingsMenuScript := preload("res://scripts/settings_menu.gd")
const DEATH_SND := preload("res://assets/audio/sfx/player_death.wav")

@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var kills_label: Label = $KillsLabel
@onready var gold_label: Label = $GoldLabel
@onready var hitmarker: TextureRect = $Hitmarker
@onready var vignette: ColorRect = $HurtVignette
@onready var death_label: Label = $DeathLabel

@onready var player: Node = get_parent()
@onready var weapon: Node = get_node("%Gun")

var _reload_bar: ProgressBar
var _reload_label: Label
var _reload_tween: Tween


func _ready() -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	_build_reload_ui()
	weapon_label.text = weapon.data.display_name
	SettingsMenuScript.load_settings()
	update_crosshair(SettingsMenuScript.crosshair_path)
	player.health_changed.connect(_on_health_changed)
	player.hurt.connect(_on_hurt)
	player.died.connect(_on_died)
	Game.xp_changed.connect(_on_xp_changed)
	Game.leveled_up.connect(_on_leveled_up)
	Game.kills_changed.connect(_on_kills_changed)
	Game.gold_changed.connect(_on_gold_changed)
	gold_label.text = "%d ⬤" % Game.gold

	_on_ammo_changed(weapon.current_ammo, weapon.reserve)
	_on_health_changed(player.health, player.max_health)
	_on_xp_changed(Game.xp, Game.xp_needed())
	level_label.text = "SEVİYE %d" % Game.level
	kills_label.text = "KILL: %d" % Game.kills


func _on_ammo_changed(current: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [current, reserve]


func _build_reload_ui() -> void:
	# nişangahın hemen altında: "DOLDURULUYOR" + dolan çubuk
	_reload_label = Label.new()
	_reload_label.text = "DOLDURULUYOR"
	_reload_label.add_theme_font_override("font", load("res://assets/fonts/ui_font.tres"))
	_reload_label.add_theme_font_size_override("font_size", 18)
	_reload_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_label.set_anchors_preset(Control.PRESET_CENTER)
	_reload_label.position = Vector2(-100, 34)
	_reload_label.custom_minimum_size = Vector2(200, 0)
	_reload_label.visible = false
	add_child(_reload_label)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.82, 0.35)
	bar_fill.set_corner_radius_all(3)

	_reload_bar = ProgressBar.new()
	_reload_bar.show_percentage = false
	_reload_bar.add_theme_stylebox_override("background", bar_bg)
	_reload_bar.add_theme_stylebox_override("fill", bar_fill)
	_reload_bar.set_anchors_preset(Control.PRESET_CENTER)
	_reload_bar.position = Vector2(-70, 58)
	_reload_bar.custom_minimum_size = Vector2(140, 8)
	_reload_bar.size = Vector2(140, 8)
	_reload_bar.max_value = 1.0
	_reload_bar.visible = false
	add_child(_reload_bar)


func _on_reload_started(duration: float) -> void:
	_reload_label.visible = true
	_reload_bar.visible = true
	_reload_bar.value = 0.0
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_property(_reload_bar, "value", 1.0, duration)


func _on_reload_finished() -> void:
	_reload_label.visible = false
	_reload_bar.visible = false


func _on_weapon_changed(display_name: String) -> void:
	weapon_label.text = display_name
	# kısa parlama
	weapon_label.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(weapon_label, "scale", Vector2.ONE, 0.3)


func _on_health_changed(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health


func _on_xp_changed(xp: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = xp


func _on_leveled_up(new_level: int) -> void:
	level_label.text = "SEVİYE %d" % new_level


func _on_kills_changed(kills: int) -> void:
	kills_label.text = "KILL: %d" % kills


func _on_gold_changed(gold: int) -> void:
	gold_label.text = "%d ⬤" % gold
	gold_label.scale = Vector2(1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(gold_label, "scale", Vector2.ONE, 0.15)


func _on_hit_confirmed(headshot: bool) -> void:
	hitmarker.modulate = Color(1, 0.2, 0.15, 1) if headshot else Color(1, 1, 1, 1)
	var pop := 1.7 if headshot else 1.25
	hitmarker.scale = Vector2(pop, pop)
	var tween := create_tween().set_parallel()
	tween.tween_property(hitmarker, "modulate:a", 0.0, 0.22 if headshot else 0.18)
	tween.tween_property(hitmarker, "scale", Vector2.ONE, 0.22 if headshot else 0.18)


func _on_hurt() -> void:
	$HurtSfx.play()
	if player.dead:
		return  # ölümde vignette kalıcı, soldurma
	vignette.modulate.a = 0.55
	var tween := create_tween()
	tween.tween_property(vignette, "modulate:a", 0.0, 0.4)


func update_crosshair(path: String) -> void:
	var tex: Texture2D = load(path)
	if tex:
		$Crosshair.texture = tex


func _on_died() -> void:
	# nişangah ve oyun göstergeleri ölüyken anlamsız
	$Crosshair.hide()
	hitmarker.hide()
	ammo_label.hide()
	$WeaponLabel.hide()
	_reload_label.hide()
	_reload_bar.hide()

	var snd := AudioStreamPlayer.new()
	snd.stream = DEATH_SND
	snd.volume_db = -3.0
	add_child(snd)
	snd.play()

	# kırmızı karartma kademeli koyulaşsın
	var vt := create_tween()
	vt.tween_property(vignette, "modulate:a", 0.6, 1.2)

	# animasyonlu "ÖLDÜN": büyükten otursun + sürekli hafif nabız
	death_label.pivot_offset = Vector2(300, 60)
	death_label.scale = Vector2(2.6, 2.6)
	death_label.modulate.a = 0.0
	death_label.show()
	var t := create_tween().set_parallel()
	t.tween_property(death_label, "scale", Vector2.ONE, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(death_label, "modulate:a", 1.0, 0.45)
	t.chain().tween_callback(_pulse_death)


func _pulse_death() -> void:
	var p := death_label.create_tween().set_loops()
	p.tween_property(death_label, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_SINE)
	p.tween_property(death_label, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
