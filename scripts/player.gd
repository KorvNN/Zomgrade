extends CharacterBody3D
## First-person oyuncu: hareket, can, kart statları (hız, can çalma).

signal health_changed(health: float, max_health: float)
signal hurt
signal died

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.002
@export var max_health := 100.0

var health: float
var lifesteal := 0.0  ## kartlarla artar; verilen hasarın bu oranı kadar iyileşir
var dead := false

@onready var camera: Camera3D = %Camera

var _aim_pitch := 0.0              ## mouse ile kontrol edilen dikey bakış
var _recoil := Vector2.ZERO        ## geçici recoil ofseti (pitch, yaw)
var _shake := 0.0                  ## anlık sarsıntı şiddeti


func _ready() -> void:
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_aim_pitch = clampf(_aim_pitch - event.relative.y * mouse_sensitivity, -PI / 2.0, PI / 2.0)


func _process(delta: float) -> void:
	# recoil yumuşakça sıfıra döner
	_recoil = _recoil.lerp(Vector2.ZERO, delta * 8.0)
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	var shake_off := Vector2(randf() - 0.5, randf() - 0.5) * _shake
	camera.rotation.x = _aim_pitch + _recoil.y + shake_off.y
	camera.rotation.z = _recoil.x * 0.3 + shake_off.x


func add_recoil() -> void:
	_recoil += Vector2(randf_range(-0.006, 0.006), 0.018)
	_shake = minf(_shake + 0.05, 0.12)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func take_damage(amount: float) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	hurt.emit()
	if health == 0.0:
		_die()


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func on_dealt_damage(amount: float) -> void:
	if lifesteal > 0.0:
		heal(amount * lifesteal)


func refresh_stats() -> void:
	health_changed.emit(health, max_health)


func _die() -> void:
	dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit()
