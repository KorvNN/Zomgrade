extends Node3D
## Şato katı: labirent + odalar üretir, KayKit parçalarıyla döşer, düşman doğurur,
## çıkışa ulaşınca sonraki kata geçirir.

const CELL := 4.0
const WALL_H := 4.0
const KAYKIT := "res://addons/kaykit_dungeon_remastered/assets/gltf/"
const CHEST_SCRIPT := preload("res://scripts/chest.gd")

const FLOOR_PIECES := {
	"floor_tile_large.gltf.glb": 90,
	"floor_tile_large_rocks.gltf.glb": 10,
}
const WALL_PIECES := {
	"wall.gltf.glb": 90,
	"wall_cracked.gltf.glb": 10,
}
const PROP_PIECES := [
	"barrel_large.gltf.glb", "box_stacked.gltf.glb", "crates_stacked.gltf.glb",
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
var _exit_near := false
var _exit_prompt: Label3D
var _exit_screen_prompt: Control
var _exit_open := Vector3(0, 0, 1)   ## koridorun çıkışa bağlandığı açık yön
var _exit_back := Vector3(0, 0, -1)  ## kemerin/odanın açıldığı arka yön


func _ready() -> void:
	if Game.run_seed == 0:
		Game.run_seed = randi()
	rng.seed = Game.run_seed + Game.stage * 7919
	Music.play_game()

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

	_compute_exit_dirs()
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
			# çıkış hücresi: halkanın altı pürüzsüz kalsın diye hep düz karo
			var fp := "floor_tile_large.gltf.glb" if Vector2i(x, y) == maze.exit \
					else _pick_weighted(FLOOR_PIECES)
			var tile := _spawn_piece(fp, nav)
			tile.position = _cell_center(Vector2i(x, y))
			# tutarlı ızgara görünümü: serbest dönüş yok

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
	# tutarlı yönelim: rastgele çevirme yok

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


func _compute_exit_dirs() -> void:
	var exit: Vector2i = maze.exit
	# tercih: arka yön ızgaranın dışına (sınır kenarına) baksın → oda dışarı açılır
	var boundary_back := Vector2i.ZERO
	var have_boundary := false
	for d: Vector2i in MazeGen.DIRS:
		var n: Vector2i = exit + d
		if n.x < 0 or n.x >= int(maze.w) or n.y < 0 or n.y >= int(maze.h):
			boundary_back = d
			have_boundary = true
			break
	if have_boundary:
		_exit_back = Vector3(boundary_back.x, 0, boundary_back.y)
		_exit_open = -_exit_back
	else:
		var open_dir := Vector2i(0, 1)
		for d: Vector2i in MazeGen.DIRS:
			var n: Vector2i = exit + d
			if n.x >= 0 and n.x < int(maze.w) and n.y >= 0 and n.y < int(maze.h) \
					and not MazeGen.has_wall_between(maze.v_walls, maze.h_walls, exit, n):
				open_dir = d
				break
		_exit_open = Vector3(open_dir.x, 0, open_dir.y)
		_exit_back = -_exit_open
	# arka duvarı kaldır: kemerin açıklığı oraya gelecek, arkası duvar olmasın
	var back_cell := exit + Vector2i(int(_exit_back.x), int(_exit_back.z))
	_set_wall_open(exit, back_cell)


func _set_wall_open(a: Vector2i, b: Vector2i) -> void:
	if b.x == a.x + 1:
		maze.v_walls[a.x + 1][a.y] = false
	elif b.x == a.x - 1:
		maze.v_walls[a.x][a.y] = false
	elif b.y == a.y + 1:
		maze.h_walls[a.x][a.y + 1] = false
	else:
		maze.h_walls[a.x][a.y] = false


func _build_exit() -> void:
	var center := _cell_center(maze.exit)
	var open_dir := _exit_open
	var back_dir := _exit_back

	# açık kemerli geçit — içi görünür, arkadaki odaya bakar (arkası artık duvar değil)
	var arch := _spawn_piece("wall_doorway.glb", self)
	arch.position = center + back_dir * (CELL / 2.0)
	arch.rotation.y = atan2(open_dir.x, open_dir.z)

	_build_exit_beyond(center, open_dir, back_dir)

	# yerde yatay parlayan mavi neon halka
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.25, 0.7, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.3, 0.75, 1.0)
	ring_mat.emission_energy_multiplier = 4.0
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.25
	var ring := MeshInstance3D.new()
	ring.mesh = torus  # varsayılan: yatay (XZ düzlemi) — tam istenen
	ring.material_override = ring_mat
	ring.position = center + back_dir * 0.4 + Vector3(0, 0.12, 0)
	add_child(ring)

	# içteki parıltı diski (yerde)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	disc_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.3)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.95
	disc_mesh.bottom_radius = 0.95
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	disc.material_override = disc_mat
	disc.position = ring.position
	add_child(disc)

	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.7, 1.0)
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.position = ring.position + Vector3(0, 1.6, 0)
	add_child(light)

	var spin := ring.create_tween().set_loops()
	spin.tween_method(func(a: float) -> void: ring.rotation.y = a, 0.0, TAU, 5.0)
	var pulse := light.create_tween().set_loops()
	pulse.tween_property(light, "light_energy", 4.0, 1.1)
	pulse.tween_property(light, "light_energy", 2.0, 1.1)

	_exit_prompt = Label3D.new()
	_exit_prompt.text = "ÇIKIŞ"
	_exit_prompt.font = MenuUI.FONT
	_exit_prompt.font_size = 110
	_exit_prompt.pixel_size = 0.006
	_exit_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exit_prompt.modulate = Color(0.45, 0.85, 1.0)
	_exit_prompt.outline_size = 18
	_exit_prompt.position = ring.position + Vector3(0, 2.4, 0)
	add_child(_exit_prompt)

	# yakınlık alanı: girince [E] yaz, çıkınca "ÇIKIŞ"
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL * 0.7, 3.0, CELL * 0.7)
	shape.shape = box
	area.add_child(shape)
	area.position = ring.position + Vector3(0, 1.0, 0)
	area.body_entered.connect(_on_exit_near.bind(true))
	area.body_exited.connect(_on_exit_near.bind(false))
	add_child(area)


func _build_exit_beyond(center: Vector3, _open_dir: Vector3, back_dir: Vector3) -> void:
	# kemerin arkasında salt görsel oda: aşağı inen merdiven + sıcak ışık →
	# "başka bir yere" açılıyormuş hissi. Navmesh'e dahil değil (self'e eklenir).
	var perp := Vector3(-back_dir.z, 0, back_dir.x)
	var yaw := atan2(back_dir.x, back_dir.z)

	var landing := _spawn_piece(_pick_weighted(FLOOR_PIECES), self)
	landing.position = center + back_dir * CELL

	var stairs := _spawn_piece("stairs_wide.gltf.glb", self)
	stairs.position = center + back_dir * (CELL * 1.9) + Vector3(0, -0.05, 0)
	stairs.rotation.y = yaw

	var lower := _spawn_piece(_pick_weighted(FLOOR_PIECES), self)
	lower.position = center + back_dir * (CELL * 2.9) + Vector3(0, -1.5, 0)

	# karanlık çerçeve: yan duvarlar + arka + tavan (dış boşluk görünmesin)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.06, 0.055, 0.05)
	for s in [-1.0, 1.0]:
		var side := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(1.0, WALL_H + 1.0, CELL * 3.2)
		side.mesh = sbox
		side.material_override = frame_mat
		side.position = center + back_dir * (CELL * 1.8) \
				+ perp * s * (CELL * 0.55) + Vector3(0, WALL_H / 2.0 - 0.8, 0)
		side.rotation.y = yaw
		add_child(side)
	var back_wall := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(CELL * 1.5, WALL_H + 1.0, 1.0)
	back_wall.mesh = bbox
	back_wall.material_override = frame_mat
	back_wall.position = center + back_dir * (CELL * 3.4) + Vector3(0, WALL_H / 2.0 - 0.8, 0)
	back_wall.rotation.y = yaw
	add_child(back_wall)
	var top := MeshInstance3D.new()
	var tbox := BoxMesh.new()
	tbox.size = Vector3(CELL * 1.5, 0.5, CELL * 3.4)
	top.mesh = tbox
	top.material_override = frame_mat
	top.position = center + back_dir * (CELL * 1.8) + Vector3(0, WALL_H - 0.3, 0)
	top.rotation.y = yaw
	add_child(top)

	# derinde sıcak titrek ışık + meşale
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.66, 0.32)
	glow.light_energy = 2.6
	glow.omni_range = 7.0
	glow.position = center + back_dir * (CELL * 2.6) + Vector3(0, 0.5, 0)
	add_child(glow)
	var torch := _spawn_piece("torch_mounted.gltf.glb", self)
	torch.position = center + back_dir * (CELL * 3.25) + Vector3(0, 2.2, 0)
	torch.rotation.y = yaw + PI
	var flick := glow.create_tween().set_loops()
	flick.tween_property(glow, "light_energy", 3.1, 0.5)
	flick.tween_property(glow, "light_energy", 2.2, 0.6)


func _build_rooms() -> void:
	for room: Dictionary in maze.rooms:
		var rect: Rect2i = room.rect
		var center := Vector3(
				(rect.position.x + rect.size.x / 2.0) * CELL, 0,
				(rect.position.y + rect.size.y / 2.0) * CELL)
		match room.type:
			"depo":
				for i in rng.randi_range(3, 5):
					_spawn_prop(PROP_PIECES[rng.randi() % PROP_PIECES.size()],
							center + _scatter(rect), rng.randf() * TAU)
			"sapel":
				_spawn_prop("table_long_tablecloth.gltf.glb", center, 0.0)
				var candle := _spawn_piece("candle_triple.gltf.glb", nav)
				candle.position = center + Vector3(0, 1.0, 0)
				var banner := _spawn_piece("banner_patternA_blue.gltf.glb", nav)
				banner.position = center + Vector3(0, 1.8, -2.4)
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
	# prop'ları odanın KENARINA yasla, merkez geçit açık kalsın (tıkanma olmasın)
	var hw := rect.size.x * CELL / 2.0 - 1.0
	var hh := rect.size.y * CELL / 2.0 - 1.0
	if rng.randf() < 0.5:
		return Vector3((hw if rng.randf() < 0.5 else -hw), 0, rng.randf_range(-hh, hh))
	return Vector3(rng.randf_range(-hw, hw), 0, (hh if rng.randf() < 0.5 else -hh))


func _spawn_prop(piece_file: String, pos: Vector3, rot: float) -> void:
	var body := StaticBody3D.new()
	nav.add_child(body)
	body.position = pos
	body.rotation.y = rot
	var model := _spawn_piece(piece_file, body)
	model.position = Vector3.ZERO

	# collision'ı modelin gerçek AABB'sine göre boyutla (içine girilemesin)
	var aabb := _local_aabb(body, model)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(aabb.size.x, 0.4), maxf(aabb.size.y, 0.6), maxf(aabb.size.z, 0.4))
	col.shape = box
	col.position = aabb.position + aabb.size * 0.5
	body.add_child(col)


func _local_aabb(body: Node3D, model: Node3D) -> AABB:
	var binv := body.global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var a := (binv * mesh.global_transform) * mesh.get_aabb()
		merged = a if first else merged.merge(a)
		first = false
	return merged


func _build_props_and_chests() -> void:
	# çıkmaz sokaklara SADECE sandık (yolu tıkamaz; terminal hücre).
	# barreller koridorlara konmuyor — geçişi engelliyordu.
	for cell: Vector2i in maze.dead_ends:
		if rng.randf() < 0.5:
			var chest := StaticBody3D.new()
			chest.set_script(CHEST_SCRIPT)
			nav.add_child(chest)
			chest.position = _cell_center(cell)
			chest.rotation.y = (rng.randi() % 4) * PI / 2.0


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

	_build_exit_screen_prompt(layer)

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


func _build_exit_screen_prompt(layer: CanvasLayer) -> void:
	# çıkışa yaklaşınca alt-ortada beliren etkileşim promptu: [E] SONRAKİ KATA GEÇ
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -150
	holder.offset_bottom = -90
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	layer.add_child(holder)
	_exit_screen_prompt = holder

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)

	# [E] tuş rozeti
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.5, 0.95, 0.4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", sb)
	row.add_child(badge)

	var key := Label.new()
	key.text = "E"
	key.add_theme_font_override("font", MenuUI.FONT)
	key.add_theme_font_size_override("font_size", 34)
	key.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(key)

	var text := Label.new()
	text.text = "SONRAKİ KATA GEÇ"
	text.add_theme_font_override("font", MenuUI.FONT)
	text.add_theme_font_size_override("font_size", 30)
	text.add_theme_color_override("font_color", Color(0.92, 0.95, 0.9))
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	text.add_theme_constant_override("outline_size", 6)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)

	# nazik nabız: dikkat çeksin ama rahatsız etmesin
	var pulse := holder.create_tween().set_loops()
	pulse.tween_property(holder, "modulate:a", 0.55, 0.7)
	pulse.tween_property(holder, "modulate:a", 1.0, 0.7)


# ---------- akış ----------

func _spawn_zombie() -> void:
	if _stage_over or _alive >= 10 + 3 * Game.stage:
		return
	# sadece oyuncuya yol bağlantısı olan (ulaşılabilir) hücrelerden doğur
	var cell := Vector2i(rng.randi() % int(maze.w), rng.randi() % int(maze.h))
	var tries := 0
	while not maze.dist.has(cell) and tries < 12:
		cell = Vector2i(rng.randi() % int(maze.w), rng.randi() % int(maze.h))
		tries += 1
	if not maze.dist.has(cell):
		return
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


func _process(_delta: float) -> void:
	if _exit_near and not _stage_over and Input.is_action_just_pressed("interact"):
		_finish_stage()


func _on_exit_near(body: Node3D, near: bool) -> void:
	if not body.is_in_group("player"):
		return
	_exit_near = near
	if _stage_over:
		return
	_exit_screen_prompt.visible = near
	_exit_prompt.modulate = Color(0.5, 0.95, 0.4) if near else Color(0.45, 0.85, 1.0)


func _finish_stage() -> void:
	_stage_over = true
	_exit_screen_prompt.visible = false
	Music.transition()  # E'ye basınca anında geçiş sesi
	_exit_prompt.text = "KAT %d TAMAMLANDI!" % Game.stage
	_stage_label.text = "KAT %d TAMAMLANDI!" % Game.stage
	_stage_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.4))
	_stage_label.scale = Vector2(1.5, 1.5)
	var pop := _stage_label.create_tween()
	pop.tween_property(_stage_label, "scale", Vector2.ONE, 0.4)
	# kısa gecikme sonrası hızlı karart, sonra sonraki kata geç
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(_fade, "color:a", 1.0, 0.65)
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
