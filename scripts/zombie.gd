extends CharacterBody3D
## Temel düşman: yerden doğar, oyuncuyu kovalar, yakına gelince yumruk atar.

signal died

enum State { SPAWNING, CHASE, ATTACK, DEAD }

const MODELS := [
	"res://assets/characters/Zombie_Male.gltf",
	"res://assets/characters/Zombie_Female.gltf",
]
const MODEL_SCALE := 0.6
const HEAD_HEIGHT := 1.35  ## bu yüksekliğin üstüne isabet = kafa vuruşu

## mantıksal anim adı -> aday listesi: zombi modeli ilkini, KayKit iskeletleri ikincisini bulur
const ANIM_FALLBACKS := {
	"Run": ["Run", "Running_A"],
	"Punch": ["Punch", "Unarmed_Melee_Attack_Punch_A"],
	"Death": ["Death", "Death_A"],
	"RecieveHit": ["RecieveHit", "Hit_A"],
	"StandUp": ["StandUp", "Spawn_Ground"],
}

const SND_GROAN := [
	preload("res://assets/audio/zombie/zombie_groan_0.wav"),
	preload("res://assets/audio/zombie/zombie_groan_1.wav"),
	preload("res://assets/audio/zombie/zombie_groan_2.wav"),
]
const SND_ATTACK := [
	preload("res://assets/audio/zombie/zombie_attack_0.wav"),
	preload("res://assets/audio/zombie/zombie_attack_1.wav"),
]
const SND_HURT := [
	preload("res://assets/audio/zombie/zombie_hurt_0.wav"),
	preload("res://assets/audio/zombie/zombie_hurt_1.wav"),
]
const SND_DEATH := preload("res://assets/audio/zombie/zombie_death.wav")
const PICKUP := preload("res://scripts/pickup.gd")

@export var max_health := 30.0
@export var speed := 3.0
@export var attack_damage := 10.0
@export var attack_range := 1.8
@export var attack_cooldown := 1.3
@export var xp_value := 20
@export var gold_value := 6
@export var model_path := ""  ## boşsa rastgele zombi; iskelet vb. için doldur
@export var model_scale := 0.6  ## boss için büyütülür
@export var base_scale := 0.6  ## modelin "normal insan boyu" ölçeği (zombi 0.6, iskelet 0.85)
@export var is_boss := false

signal health_changed(health: float, max_health: float)

@onready var agent: NavigationAgent3D = $Agent
@onready var mount: Node3D = $ModelMount

var state := State.SPAWNING
var health: float
var anim: AnimationPlayer
var _anim := {}  ## mantıksal ad -> bu modeldeki gerçek anim adı
var player: Node3D
var _attack_timer := 0.0
var _hit_flash_timer := 0.0
var _voice: AudioStreamPlayer3D
var _groan_timer := 0.0
var _vocal := false  ## sadece bazı zombiler ara ara homurdanır


func _ready() -> void:
	health = max_health
	speed *= randf_range(0.85, 1.25)
	player = get_tree().get_first_node_in_group("player")

	# model: belirtilmişse o (iskelet vb.), yoksa rastgele erkek/dişi zombi
	var path: String = model_path if model_path != "" else MODELS[randi() % MODELS.size()]
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees.y = 180.0
	mount.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for logical: String in ANIM_FALLBACKS:
		for cand: String in ANIM_FALLBACKS[logical]:
			if anim.has_animation(cand):
				_anim[logical] = cand
				break

	# boss: collision kapsülü model oranında büyüsün
	if model_scale > base_scale + 0.01:
		var k := model_scale / base_scale
		var cap: CapsuleShape3D = $Collision.shape.duplicate()
		cap.radius *= k
		cap.height *= k
		$Collision.shape = cap
		$Collision.position.y *= k

	if model_path == "":
		_apply_zombie_skin(model)  # yeşil tonlama sadece zombilere

	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 3.5
	_voice.max_distance = 24.0
	_voice.volume_db = -8.0
	_voice.position.y = 1.2
	add_child(_voice)
	_vocal = randf() < 0.45
	_groan_timer = randf_range(4.0, 12.0)

	# topraktan yükselme efekti (boss daha derinden çıkar — modeli gömülü kalmasın)
	mount.position.y = -1.6 * (model_scale / base_scale)
	anim.play(_anim["StandUp"])
	var rise := create_tween()
	rise.tween_property(mount, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC)
	await rise.finished
	if state != State.DEAD:
		state = State.CHASE
		anim.play(_anim["Run"])
		anim.speed_scale = randf_range(0.9, 1.2)


func _apply_zombie_skin(model: Node3D) -> void:
	# karakteri yeşilimsi/soluk zombi tonuna boya
	var tint := Color(0.45, 0.55, 0.38) if randf() < 0.5 else Color(0.5, 0.5, 0.55)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var base := mesh.mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = m.albedo_color * tint
				mesh.set_surface_override_material(i, m)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or player == null:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if _vocal and (state == State.CHASE or state == State.ATTACK):
		_groan_timer -= delta
		if _groan_timer <= 0.0:
			_groan_timer = randf_range(9.0, 20.0)
			_say(SND_GROAN, 0.82, 1.18)

	if state == State.SPAWNING:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > 0.1:
		look_at(player.global_position * Vector3(1, 0, 1) + global_position * Vector3(0, 1, 0), Vector3.UP)

	if dist <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_timer == 0.0 and not player.dead:
			_attack()
	elif state != State.ATTACK or not anim.is_playing():
		state = State.CHASE
		agent.target_position = player.global_position
		var next := agent.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if anim.current_animation != _anim["Run"]:
			anim.play(_anim["Run"])

	move_and_slide()


func _attack() -> void:
	state = State.ATTACK
	_attack_timer = attack_cooldown
	anim.play(_anim["Punch"])
	if randf() < 0.5:  # her vuruşta değil — sürekli ses sinir bozucu oluyordu
		_say(SND_ATTACK, 0.95, 1.12, true)
	await get_tree().create_timer(0.45).timeout
	if state == State.DEAD or player == null:
		return
	if global_position.distance_to(player.global_position) <= attack_range + 0.5:
		player.take_damage(attack_damage)
	await get_tree().create_timer(0.3).timeout
	if state == State.ATTACK:
		state = State.CHASE


func is_headshot(point: Vector3) -> bool:
	return point.y - global_position.y > HEAD_HEIGHT * (model_scale / base_scale)


func take_damage(amount: float, _headshot := false) -> void:
	if state == State.DEAD:
		return
	health -= amount
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		_die()
	elif state != State.ATTACK:
		# kısa irkilme animasyonu
		anim.play(_anim["RecieveHit"])
		if randf() < 0.5:
			_say(SND_HURT, 0.95, 1.15, true)


func _say(streams, lo: float, hi: float, force := false) -> void:
	if _voice == null or (_voice.playing and not force):
		return
	_voice.stream = streams[randi() % streams.size()] if streams is Array else streams
	_voice.pitch_scale = randf_range(lo, hi)
	_voice.play()


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	$Collision.set_deferred("disabled", true)
	anim.speed_scale = 1.0
	anim.play(_anim["Death"])
	_say(SND_DEATH, 0.85, 1.05, true)
	Game.add_kill()
	_drop_loot()
	died.emit()
	await get_tree().create_timer(2.0).timeout
	var tween := create_tween()
	tween.tween_property(mount, "position:y", -1.5, 0.8)
	tween.tween_callback(queue_free)


func _drop_loot() -> void:
	## XP küresi + altın yere saçılır; oyuncu yürüyerek/mıknatısla toplar
	var origin := global_position + Vector3(0, 1.0, 0)
	var holder := get_parent()
	PICKUP.spawn(holder, origin, "xp", xp_value)
	var gold_left := gold_value
	var coins := 1 + randi() % 2 if not is_boss else 6
	for i in coins:
		var amount := gold_left / (coins - i)
		gold_left -= amount
		if amount > 0:
			PICKUP.spawn(holder, origin, "gold", amount)
