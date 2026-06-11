extends Node3D
## Şato katı: labirent + odalar üretir, KayKit parçalarıyla döşer, düşman doğurur,
## çıkışa ulaşınca sonraki kata geçirir.

const CELL := 4.0
const WALL_H := 4.0
const KAYKIT := "res://addons/kaykit_dungeon_remastered/assets/gltf/"
const CHEST_SCRIPT := preload("res://scripts/chest.gd")

const FLOOR_PIECES := {
	"floor_tile_large.gltf.glb": 80,
	"floor_tile_large_rocks.gltf.glb": 10,
	"floor_dirt_large.gltf.glb": 10,
}
const WALL_PIECES := {
	"wall.gltf.glb": 86,
	"wall_cracked.gltf.glb": 14,
}
const PROP_PIECES := [
	"barrel_large.gltf.glb", "barrel_small_stack.gltf.glb",
	"box_stacked.gltf.glb", "crates_stacked.gltf.glb", "keg.gltf.glb",
]
const EXIT_KINDS := [
	{ "piece": "stairs.gltf.glb", "label": "YUKARI ÇIK", "rot_random": true },
	{ "piece": "stairs_walled.gltf.glb", "label": "YUKARI ÇIK", "rot_random": true },
	{ "piece": "floor_tile_big_grate_open.gltf.glb", "label": "MAHZEN GEÇİDİ", "rot_random": true },
	{ "piece": "wall_gated.gltf.glb", "label": "ŞATO KAPISI", "rot_random": true },
]
const MAX_TORCHES := 30

@export var zombie_scene: PackedScene
@export var maze_w := 9
@export var maze_h := 9

@onready var nav: NavigationRegion3D = $NavRegion

var maze := {}
var rng := RandomNumberGenerator.new()
var player: Node3D
var _alive := 0
var _stage_over := false
var _torch_count := 0
var _piece_cache := {}
var _stage_label: Label
var _fade: ColorRect


func _ready() -> void:
	if Game.run_seed == 0:
		Game.run_seed = randi()
	rng.seed = Game.run_seed + Game.stage * 7919

	var grow := mini(Game.stage - 1, 4)
	maze = MazeGen.generate(maze_w + grow, maze_h + grow, rng.randi(), 0.25)

	player = get_tree().get_first_node_in_group("player")
	player.died.connect(_on_player_died)
	player.global_position = _cell_center(Vector2i.ZERO) + Vector3(0, 0.2, 0)
	for d: Vector2i in MazeGen.DIRS:
		var n: Vector2i = Vector2i.ZERO + d
		if n.x >= 0 and n.x < int(maze.w) and n.y >= 0 and n.y < int(maze.h) \
				and not MazeGen.has_wall_between(maze.v_walls, maze.h_walls, Vector2i.ZERO, n):
			player.rotation.y = atan2(-float(d.x), -float(d.y))
			break

	_build_floors_and_walls()
	_build_ceiling()
	_build_exit()
	_build_rooms()
	_build_props_and_chests()
	_build_stage_ui()

	nav.bake_navigation_mesh()
	await nav.bake_finished

	var timer := Timer.new()
	timer.wait_time = maxf(2.4 - 0.2 * (Game.stage - 1), 0.9)
	timer.timeout.connect(_spawn_zombie)
	add_child(timer)
	timer.start()
	_spawn_zombie()


# ---------- inşaat ----------

func _build_floors_and_walls() -> void:
	var walls_body := StaticBody3D.new()
	walls_body.name = "WallColliders"
	nav.add_child(walls_body)

	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(maze.w * CELL + 8.0, 1.0, maze.h * CELL + 8.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(maze.w * CELL / 2.0, -0.5, maze.h * CELL / 2.0)
	walls_body.add_child(floor_shape)

	for x in maze.w:
		for y in maze.h:
			var tile := _spawn_piece(_pick_weighted(FLOOR_PIECES), nav)
			tile.position = _cell_center(Vector2i(x, y))
			tile.rotation.y = (rng.randi() % 4) * PI / 2.0

	for x in maze.w + 1:
		for y in maze.h:
			if maze.v_walls[x][y]:
				_place_wall(walls_body, Vector3(x * CELL, 0, (y + 0.5) * CELL), true)
	for x in maze.w:
		for y in maze.h + 1:
			if maze.h_walls[x][y]:
				_place_wall(walls_body, Vector3((x + 0.5) * CELL, 0, y * CELL), false)

	# kavşak noktalarına sütun: dik duvarların buluştuğu köşe boşluklarını kapatır
	for x in maze.w + 1:
		for y in maze.h + 1:
			var v_count := 0
			var h_count := 0
			if y < int(maze.h) and maze.v_walls[x][y]:
				v_count += 1
			if y > 0 and maze.v_walls[x][y - 1]:
				v_count += 1
			if x < int(maze.w) and maze.h_walls[x][y]:
				h_count += 1
			if x > 0 and maze.h_walls[x - 1][y]:
				h_count += 1
			if v_count > 0 and h_count > 0:
				var pillar := _spawn_piece("pillar.gltf.glb", nav)
				pillar.position = Vector3(x * CELL, 0, y * CELL)


func _place_wall(walls_body: StaticBody3D, pos: Vector3, vertical: bool) -> void:
	var piece := _spawn_piece(_pick_weighted(WALL_PIECES), nav)
	piece.position = pos
	if vertical:
		piece.rotation.y = PI / 2.0
	if rng.randf() < 0.5:
		piece.rotation.y += PI

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL, WALL_H, 1.0) if not vertical else Vector3(1.0, WALL_H, CELL)
	col.shape = box
	col.position = pos + Vector3(0, WALL_H / 2.0, 0)
	walls_body.add_child(col)

	if _torch_count < MAX_TORCHES and rng.randf() < 0.16:
		_torch_count += 1
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var offset := Vector3(side * 0.62, 0, 0) if vertical else Vector3(0, 0, side * 0.62)
		var torch := _spawn_piece("torch_mounted.gltf.glb", nav)
		torch.position = pos + offset + Vector3(0, 2.4, 0)
		torch.rotation.y = (0.0 if vertical else PI / 2.0) + (PI if side < 0 else 0.0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.3)
		light.light_energy = 2.4
		light.omni_range = 6.0
		light.position = torch.position + offset.normalized() * 0.4 + Vector3(0, 0.45, 0)
		nav.add_child(light)


func _build_ceiling() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(maze.w * CELL + 8.0, 0.5, maze.h * CELL + 8.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.09, 0.085)
	box.material = mat
	mesh.mesh = box
	mesh.position = Vector3(maze.w * CELL / 2.0, WALL_H + 0.25, maze.h * CELL / 2.0)
	add_child(mesh)


func _build_exit() -> void:
	var exit_cell: Vector2i = maze.exit
	var center := _cell_center(exit_cell)
	var kind: Dictionary = EXIT_KINDS[rng.randi() % EXIT_KINDS.size()]

	var piece := _spawn_piece(kind.piece, nav)
	piece.position = center
	if kind.rot_random:
		piece.rotation.y = (rng.randi() % 4) * PI / 2.0

	var label := Label3D.new()
	label.text = "ÇIKIŞ\n%s" % kind.label
	label.font_size = 96
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.55, 1.0, 0.5)
	label.outline_size = 16
	label.position = center + Vector3(0, 2.8, 0)
	add_child(label)

	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 1.0, 0.45)
	light.light_energy = 2.0
	light.omni_range = 4.5
	light.shadow_enabled = true
	light.position = center + Vector3(0, 2.2, 0)
	add_child(light)

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL * 0.7, 3.0, CELL * 0.7)
	shape.shape = box
	area.add_child(shape)
	area.position = center + Vector3(0, 1.5, 0)
	area.body_entered.connect(_on_exit_entered)
	add_child(area)


func _build_rooms() -> void:
	for room: Dictionary in maze.rooms:
		var rect: Rect2i = room.rect
		var center := Vector3(
				(rect.position.x + rect.size.x / 2.0) * CELL, 0,
				(rect.position.y + rect.size.y / 2.0) * CELL)
		match room.type:
			"depo":
				for i in rng.randi_range(4, 7):
					_spawn_prop(PROP_PIECES[rng.randi() % PROP_PIECES.size()],
							center + _scatter(rect), rng.randf() * TAU)
			"sapel":
				_spawn_prop("table_long_tablecloth.gltf.glb", center, 0.0)
				var candle := _spawn_piece("candle_triple.gltf.glb", nav)
				candle.position = center + Vector3(0, 1.0, 0)
				for i in 4:
					var chair := _spawn_piece("chair.gltf.glb", nav)
					chair.position = center + Vector3(-1.5 + i, 0, 2.2)
					chair.rotation.y = PI
			"yemekhane":
				_spawn_prop("table_long_decorated_A.gltf.glb", center + Vector3(-1.2, 0, 0), 0.0)
				_spawn_prop("table_long_tablecloth_decorated_A.gltf.glb", center + Vector3(1.6, 0, 0), 0.0)
				_spawn_prop("keg_decorated.gltf.glb", center + _scatter(rect), rng.randf() * TAU)
			"yatakhane":
				for i in rng.randi_range(2, 3):
					_spawn_prop("bed_decorated.gltf.glb", center + _scatter(rect), (rng.randi() % 4) * PI / 2.0)
			"hazine":
				var chest := StaticBody3D.new()
				chest.set_script(CHEST_SCRIPT)
				nav.add_child(chest)
				chest.position = center
				for i in rng.randi_range(2, 4):
					var coins := _spawn_piece("coin_stack_medium.gltf.glb", nav)
					coins.position = center + _scatter(rect)
				var glow := OmniLight3D.new()
				glow.light_color = Color(1.0, 0.85, 0.45)
				glow.light_energy = 1.4
				glow.omni_range = 5.0
				glow.position = center + Vector3(0, 2.0, 0)
				nav.add_child(glow)


func _scatter(rect: Rect2i) -> Vector3:
	var half_w := rect.size.x * CELL / 2.0 - 1.2
	var half_h := rect.size.y * CELL / 2.0 - 1.2
	return Vector3(rng.randf_range(-half_w, half_w), 0, rng.randf_range(-half_h, half_h))


func _spawn_prop(piece_file: String, pos: Vector3, rot: float) -> void:
	var body := StaticBody3D.new()
	nav.add_child(body)
	body.position = pos
	body.rotation.y = rot
	var model := _spawn_piece(piece_file, body)
	model.position = Vector3.ZERO
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.8, 1.5)
	col.shape = box
	col.position.y = 0.9
	body.add_child(col)


func _build_props_and_chests() -> void:
	for cell: Vector2i in maze.dead_ends:
		var roll := rng.randf()
		var pos := _cell_center(cell)
		if roll < 0.30:
			var chest := StaticBody3D.new()
			chest.set_script(CHEST_SCRIPT)
			nav.add_child(chest)
			chest.position = pos
			chest.rotation.y = (rng.randi() % 4) * PI / 2.0
		elif roll < 0.60:
			_spawn_prop(PROP_PIECES[rng.randi() % PROP_PIECES.size()],
					pos + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)),
					rng.randf() * TAU)


func _build_stage_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_stage_label = Label.new()
	_stage_label.text = "KAT %d" % Game.stage
	_stage_label.add_theme_font_override("font", MenuUI.FONT)
	_stage_label.add_theme_font_size_override("font_size", 26)
	_stage_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stage_label.position = Vector2(-60, 36)
	layer.add_child(_stage_label)

	# kat giriş animasyonu: siyahtan açıl + büyük başlık
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	var intro := Label.new()
	intro.text = "ŞATO — KAT %d" % Game.stage
	intro.add_theme_font_override("font", MenuUI.FONT)
	intro.add_theme_font_size_override("font_size", 64)
	intro.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	intro.set_anchors_preset(Control.PRESET_CENTER)
	intro.position += Vector2(-220, -40)
	layer.add_child(intro)

	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.set_parallel()
	tween.tween_property(_fade, "color:a", 0.0, 0.8)
	tween.tween_property(intro, "modulate:a", 0.0, 1.1)


# ---------- akış ----------

func _spawn_zombie() -> void:
	if _stage_over or _alive >= 10 + 3 * Game.stage:
		return
	var cell := Vector2i(rng.randi() % int(maze.w), rng.randi() % int(maze.h))
	var pos := _cell_center(cell) + Vector3(0, 0.1, 0)
	if pos.distance_to(player.global_position) < 9.0:
		return
	var z := zombie_scene.instantiate()
	var hp_scale := 1.0 + 0.15 * (Game.stage - 1)
	z.max_health = 40.0 * hp_scale
	z.speed = 3.0 + 0.15 * (Game.stage - 1)
	z.xp_value = 20 + 4 * (Game.stage - 1)
	add_child(z)
	z.global_position = pos
	_alive += 1
	z.died.connect(func() -> void: _alive -= 1)


func _on_exit_entered(body: Node3D) -> void:
	if _stage_over or not body.is_in_group("player"):
		return
	_stage_over = true
	_stage_label.text = "KAT %d TAMAMLANDI!" % Game.stage
	_stage_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.4))
	_stage_label.scale = Vector2(1.5, 1.5)
	var pop := _stage_label.create_tween()
	pop.tween_property(_stage_label, "scale", Vector2.ONE, 0.4)
	# karart ve sonraki kata geç
	await get_tree().create_timer(1.0).timeout
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.7)
	await tween.finished
	Game.next_stage()
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	var tween := create_tween()
	tween.tween_property(_fade, "color", Color(0.25, 0.0, 0.0, 1.0), 1.2)
	await tween.finished
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ---------- yardımcılar ----------

func _cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)


func _spawn_piece(piece_file: String, parent: Node) -> Node3D:
	if not _piece_cache.has(piece_file):
		_piece_cache[piece_file] = load(KAYKIT + piece_file)
	var node: Node3D = (_piece_cache[piece_file] as PackedScene).instantiate()
	parent.add_child(node)
	return node


func _pick_weighted(table: Dictionary) -> String:
	var total := 0
	for k: String in table:
		total += table[k]
	var roll := rng.randi() % total
	for k: String in table:
		roll -= table[k]
		if roll < 0:
			return k
	return table.keys()[0]
