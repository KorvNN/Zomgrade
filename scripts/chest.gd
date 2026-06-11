extends StaticBody3D
## Altınla açılan loot sandığı. Yaklaş + E → altın yeterse açılır.

const CHEST_MODEL := "res://addons/kaykit_dungeon_remastered/assets/gltf/chest.glb"
const GOLD_MODEL := "res://addons/kaykit_dungeon_remastered/assets/gltf/chest_gold.glb"

var cost := 30
var opened := false
var _player_near := false
var _player: Node3D
var _prompt: Label3D
var _model: Node3D


func _ready() -> void:
	cost = 25 + 10 * (Game.stage - 1)

	_model = (load(CHEST_MODEL) as PackedScene).instantiate()
	add_child(_model)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.3, 1.5)
	col.shape = box
	col.position.y = 0.65
	add_child(col)

	var area := Area3D.new()
	var ashape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	ashape.shape = sphere
	area.add_child(ashape)
	area.position.y = 0.6
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)
	add_child(area)

	_prompt = Label3D.new()
	_prompt.text = "[E] AÇ — %d ALTIN" % cost
	_prompt.font_size = 64
	_prompt.pixel_size = 0.004
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.95, 0.8, 0.3)
	_prompt.outline_size = 12
	_prompt.position.y = 1.9
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	if _player_near and not opened and Input.is_action_just_pressed("interact"):
		_try_open()


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player") and not opened:
		_player_near = true
		_player = body
		_prompt.visible = true
		_refresh_prompt()


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt.visible = false


func _refresh_prompt() -> void:
	if Game.gold >= cost:
		_prompt.text = "[E] AÇ — %d ALTIN" % cost
		_prompt.modulate = Color(0.5, 0.95, 0.4)
	else:
		_prompt.text = "%d ALTIN GEREK (sende %d)" % [cost, Game.gold]
		_prompt.modulate = Color(0.9, 0.35, 0.3)


func _try_open() -> void:
	_refresh_prompt()
	if not Game.spend_gold(cost):
		return
	opened = true

	# altın sandığa dönüş + parlama
	_model.queue_free()
	_model = (load(GOLD_MODEL) as PackedScene).instantiate()
	add_child(_model)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.position.y = 1.0
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.6, 1.2)

	_give_loot()


func _give_loot() -> void:
	var roll := randf()
	if roll < 0.40:
		_prompt.text = "BONUS KART!"
		_prompt.modulate = Color(0.7, 0.5, 1.0)
		await get_tree().create_timer(0.6).timeout
		Game.bonus_draw.emit()
	elif roll < 0.70:
		_prompt.text = "+50 CAN"
		_prompt.modulate = Color(0.4, 0.95, 0.4)
		_player.heal(50.0)
	else:
		_prompt.text = "+80 MERMİ"
		_prompt.modulate = Color(0.95, 0.9, 0.4)
		var weapon := _player.get_node("%Gun")
		weapon.reserve += 80
		weapon.refresh_stats()
	await get_tree().create_timer(2.0).timeout
	_prompt.visible = false
