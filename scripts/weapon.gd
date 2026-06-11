extends Node3D
## Hitscan silah. İki katman:
##  - base_data: şu an kuşanılan silahın temel statları (evrimle değişir)
##  - weapon_mods: kartlardan biriken çarpan/eklemeler (silah değişse de korunur)
## data = base_data + tüm mods → her atışta okunan efektif statlar.

signal ammo_changed(current: int, reserve: int)
signal hit_confirmed(headshot: bool)
signal weapon_changed(display_name: String)

const IMPACT_SCENE := preload("res://scenes/fx/impact.tscn")
const AMMO_PER_KILL := 3  ## her öldürmede yedeğe dönen mermi

@export var data: WeaponData  ## başlangıç silahı (pistol)

@onready var ray: RayCast3D = %Ray
@onready var muzzle_flash: MeshInstance3D = %MuzzleFlash
@onready var muzzle_light: OmniLight3D = %MuzzleLight

var base_data: WeaponData
var weapon_mods: Array[Dictionary] = []  ## her biri {mul:{}, add:{}}

var current_ammo := 0
var reserve := 0

var _cooldown := 0.0
var _reloading := false
var _base_z := 0.0
var _gun_anim: AnimationPlayer


func _ready() -> void:
	base_data = data.duplicate()
	_base_z = position.z
	ray.add_exception(owner)
	_grab_model_anim()
	_recompute(false)
	Game.kills_changed.connect(_on_kill)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or owner.dead:
		return

	var wants_fire := Input.is_action_pressed("shoot") if data.auto \
			else Input.is_action_just_pressed("shoot")
	if wants_fire and _cooldown == 0.0 and not _reloading:
		if current_ammo > 0:
			_fire()
		else:
			reload()

	if Input.is_action_just_pressed("reload"):
		reload()


# ---- kart arayüzü ----

func add_weapon_mod(mul: Dictionary, add: Dictionary) -> void:
	weapon_mods.append({"mul": mul, "add": add})
	_recompute()


func equip(new_base: WeaponData) -> void:
	base_data = new_base.duplicate()
	_swap_model(new_base)
	_recompute(false)  # yeni silah dolu şarjörle gelir
	weapon_changed.emit(data.display_name)


func refresh_stats() -> void:
	ammo_changed.emit(current_ammo, reserve)


# ---- iç mantık ----

func _recompute(keep_ammo := true) -> void:
	data = base_data.duplicate()
	for m in weapon_mods:
		for k: String in m["mul"]:
			data.set(k, data.get(k) * m["mul"][k])
		for k: String in m["add"]:
			data.set(k, data.get(k) + m["add"][k])
	if not keep_ammo:
		current_ammo = data.mag_size
		reserve = data.reserve_ammo
	current_ammo = mini(current_ammo, data.mag_size)
	ammo_changed.emit(current_ammo, reserve)


func _fire() -> void:
	current_ammo -= 1
	_cooldown = 1.0 / data.fire_rate
	ammo_changed.emit(current_ammo, reserve)
	_kick()
	_muzzle_flash()
	owner.add_recoil()
	_play_gun_anim("Fire")
	$ShootSfx.pitch_scale = randf_range(0.95, 1.05)
	$ShootSfx.play()

	var any_hit := false
	var any_headshot := false
	for i in maxi(data.pellets, 1):
		if _fire_ray():
			any_hit = true
			if _last_headshot:
				any_headshot = true
	if any_hit:
		hit_confirmed.emit(any_headshot)
		$HitSfx.pitch_scale = 1.5 if any_headshot else 1.0
		$HitSfx.play()


var _last_headshot := false

func _fire_ray() -> bool:
	# saçılma: ışını rastgele küçük açıyla sapt
	var dir := Vector3(0, 0, -100)
	if data.spread_deg > 0.0:
		var s := deg_to_rad(data.spread_deg)
		dir = dir.rotated(Vector3.RIGHT, randf_range(-s, s)).rotated(Vector3.UP, randf_range(-s, s))
	ray.target_position = dir
	ray.force_raycast_update()
	_last_headshot = false
	if not ray.is_colliding():
		return false
	var hit := ray.get_collider()
	var point := ray.get_collision_point()
	_spawn_impact(point, ray.get_collision_normal())
	if hit and hit.has_method("take_damage"):
		var headshot: bool = hit.has_method("is_headshot") and hit.is_headshot(point)
		var dmg: float = data.damage * (data.headshot_mult if headshot else 1.0)
		hit.take_damage(dmg, headshot)
		owner.on_dealt_damage(dmg)
		_last_headshot = headshot
		return true
	return false


func _muzzle_flash() -> void:
	muzzle_flash.rotation.z = randf() * TAU
	muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	muzzle_flash.visible = true
	muzzle_light.visible = true
	await get_tree().create_timer(0.05).timeout
	muzzle_flash.visible = false
	muzzle_light.visible = false


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var fx := IMPACT_SCENE.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = point
	if normal.length() > 0.01:
		# normal tam dikeyse UP ile çakışıp uyarı verir; o durumda başka eksen kullan
		var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		fx.look_at(point + normal, up)


func reload() -> void:
	if _reloading or current_ammo == data.mag_size or reserve <= 0:
		return
	_reloading = true
	$ReloadSfx.play()
	_play_gun_anim("Reload", data.reload_time)
	await get_tree().create_timer(data.reload_time).timeout
	if not is_instance_valid(self):
		return
	var taken: int = mini(data.mag_size - current_ammo, reserve)
	current_ammo += taken
	reserve -= taken
	_reloading = false
	ammo_changed.emit(current_ammo, reserve)


func _on_kill(_total: int) -> void:
	reserve += AMMO_PER_KILL
	ammo_changed.emit(current_ammo, reserve)


func _swap_model(new_data: WeaponData) -> void:
	var old := get_node_or_null("GunModel")
	if old:
		old.name = "GunModel_old"
		old.queue_free()
	var model: Node3D = new_data.model_scene.instantiate()
	model.name = "GunModel"
	add_child(model)
	move_child(model, 0)
	model.transform = new_data.view_transform()
	_apply_gunmetal(model)
	_grab_model_anim()
	if new_data.fire_sound:
		$ShootSfx.stream = new_data.fire_sound
		$ShootSfx.volume_db = new_data.fire_volume_db


func _grab_model_anim() -> void:
	var gm := get_node_or_null("GunModel")
	_gun_anim = gm.find_child("AnimationPlayer", true, false) if gm else null


func _apply_gunmetal(root: Node) -> void:
	var gunmetal := StandardMaterial3D.new()
	gunmetal.albedo_color = Color(0.16, 0.17, 0.19)
	gunmetal.metallic = 0.55
	gunmetal.roughness = 0.45
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = gunmetal


func _play_gun_anim(action: String, fit_time := 0.0) -> void:
	if _gun_anim == null:
		return
	for anim_name in _gun_anim.get_animation_list():
		if anim_name.ends_with("|" + action) or anim_name == action:
			_gun_anim.stop()
			if fit_time > 0.0:
				var alen := _gun_anim.get_animation(anim_name).length
				_gun_anim.speed_scale = alen / fit_time
			else:
				_gun_anim.speed_scale = 1.0
			_gun_anim.play(anim_name)
			return


func _kick() -> void:
	position.z = _base_z + 0.07
	var tween := create_tween()
	tween.tween_property(self, "position:z", _base_z, 0.08)
