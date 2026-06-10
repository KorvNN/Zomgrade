extends Node3D
## Stage yöneticisi: navmesh'i pişirir, düşman doğurur, oyuncu ölünce yeniden başlatır.

@export var zombie_scene: PackedScene
@export var max_zombies := 8
@export var spawn_interval := 3.0

@onready var nav: NavigationRegion3D = $NavRegion

var _alive := 0


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	player.died.connect(_on_player_died)

	nav.bake_navigation_mesh()
	await nav.bake_finished

	var timer := Timer.new()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_zombie)
	add_child(timer)
	timer.start()
	_spawn_zombie()


func _spawn_zombie() -> void:
	if _alive >= max_zombies:
		return
	var zombie := zombie_scene.instantiate()
	add_child(zombie)
	var points := $SpawnPoints.get_children()
	zombie.global_position = (points[randi() % points.size()] as Marker3D).global_position
	_alive += 1
	zombie.died.connect(func() -> void: _alive -= 1)


func _on_player_died() -> void:
	await get_tree().create_timer(2.5).timeout
	Game.reset()
	get_tree().reload_current_scene()
