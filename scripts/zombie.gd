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

@export var max_health := 30.0
@export var speed := 3.0
@export var attack_damage := 10.0
@export var attack_range := 1.8
@export var attack_cooldown := 1.3
@export var xp_value := 20

@onready var agent: NavigationAgent3D = $Agent
@onready var mount: Node3D = $ModelMount

var state := State.SPAWNING
var health: float
var anim: AnimationPlayer
var player: Node3D
var _attack_timer := 0.0
var _hit_flash_timer := 0.0


func _ready() -> void:
	health = max_health
	speed *= randf_range(0.85, 1.25)
	player = get_tree().get_first_node_in_group("player")

	# rastgele erkek/dişi model, yerin altından doğsun
	var model: Node3D = (load(MODELS[randi() % MODELS.size()]) as PackedScene).instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation_degrees.y = 180.0
	mount.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)

	_apply_zombie_skin(model)

	# topraktan yükselme efekti
	mount.position.y = -1.6
	anim.play("StandUp")
	var rise := create_tween()
	rise.tween_property(mount, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC)
	await rise.finished
	if state != State.DEAD:
		state = State.CHASE
		anim.play("Run")
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
		if anim.current_animation != "Run":
			anim.play("Run")

	move_and_slide()


func _attack() -> void:
	state = State.ATTACK
	_attack_timer = attack_cooldown
	anim.play("Punch")
	await get_tree().create_timer(0.45).timeout
	if state == State.DEAD or player == null:
		return
	if global_position.distance_to(player.global_position) <= attack_range + 0.5:
		player.take_damage(attack_damage)
	await get_tree().create_timer(0.3).timeout
	if state == State.ATTACK:
		state = State.CHASE


func is_headshot(point: Vector3) -> bool:
	return point.y - global_position.y > HEAD_HEIGHT


func take_damage(amount: float, _headshot := false) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		_die()
	elif state != State.ATTACK:
		# kısa irkilme animasyonu
		anim.play("RecieveHit")


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	$Collision.set_deferred("disabled", true)
	anim.speed_scale = 1.0
	anim.play("Death")
	Game.add_kill(xp_value)
	died.emit()
	await get_tree().create_timer(2.0).timeout
	var tween := create_tween()
	tween.tween_property(mount, "position:y", -1.5, 0.8)
	tween.tween_callback(queue_free)
