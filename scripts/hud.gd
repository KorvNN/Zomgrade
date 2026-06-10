extends CanvasLayer
## HUD: can, XP, mermi, kill sayacı, hitmarker ve hasar vinyeti.

@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $LevelLabel
@onready var kills_label: Label = $KillsLabel
@onready var hitmarker: TextureRect = $Hitmarker
@onready var vignette: ColorRect = $HurtVignette
@onready var death_label: Label = $DeathLabel

@onready var player: Node = get_parent()
@onready var weapon: Node = get_node("%Gun")


func _ready() -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	weapon_label.text = weapon.data.display_name
	player.health_changed.connect(_on_health_changed)
	player.hurt.connect(_on_hurt)
	player.died.connect(_on_died)
	Game.xp_changed.connect(_on_xp_changed)
	Game.leveled_up.connect(_on_leveled_up)
	Game.kills_changed.connect(_on_kills_changed)

	_on_ammo_changed(weapon.current_ammo, weapon.reserve)
	_on_health_changed(player.health, player.max_health)
	_on_xp_changed(Game.xp, Game.xp_needed())
	level_label.text = "SEVİYE %d" % Game.level
	kills_label.text = "KILL: %d" % Game.kills


func _on_ammo_changed(current: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [current, reserve]


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


func _on_hit_confirmed(headshot: bool) -> void:
	hitmarker.modulate = Color(1, 0.2, 0.15, 1) if headshot else Color(1, 1, 1, 1)
	var pop := 1.7 if headshot else 1.25
	hitmarker.scale = Vector2(pop, pop)
	var tween := create_tween().set_parallel()
	tween.tween_property(hitmarker, "modulate:a", 0.0, 0.22 if headshot else 0.18)
	tween.tween_property(hitmarker, "scale", Vector2.ONE, 0.22 if headshot else 0.18)


func _on_hurt() -> void:
	vignette.modulate.a = 0.55
	var tween := create_tween()
	tween.tween_property(vignette, "modulate:a", 0.0, 0.4)
	$HurtSfx.play()


func _on_died() -> void:
	death_label.show()
