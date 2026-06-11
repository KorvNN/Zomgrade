class_name MazeGen
extends RefCounted
## Grid hücre labirenti üretici (recursive backtracker + braid).
## v_walls[x][y]: (x-1,y) ile (x,y) hücreleri arasındaki dikey duvar (x: 0..w)
## h_walls[x][y]: (x,y-1) ile (x,y) hücreleri arasındaki yatay duvar (y: 0..h)

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(w: int, h: int, rng_seed: int, braid := 0.25) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var v_walls: Array = []
	for x in w + 1:
		v_walls.append(_filled(h))
	var h_walls: Array = []
	for x in w:
		h_walls.append(_filled(h + 1))

	# --- recursive backtracker ---
	var visited := { Vector2i.ZERO: true }
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[rng.randi() % options.size()]
		_open_between(v_walls, h_walls, c, nxt)
		visited[nxt] = true
		stack.append(nxt)

	# --- braid: çıkmaz sokakların bir kısmını açıp döngüler yarat ---
	for x in w:
		for y in h:
			var c := Vector2i(x, y)
			if _wall_count(v_walls, h_walls, c, w, h) >= 3 and rng.randf() < braid:
				var closed: Array[Vector2i] = []
				for d: Vector2i in DIRS:
					var n: Vector2i = c + d
					if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h \
							and has_wall_between(v_walls, h_walls, c, n):
						closed.append(n)
				if not closed.is_empty():
					_open_between(v_walls, h_walls, c, closed[rng.randi() % closed.size()])

	# --- odalar: labirentin içine açık alanlar oy ---
	var rooms: Array[Dictionary] = []
	var room_cells := {}
	var room_types := ["depo", "sapel", "yemekhane", "hazine", "yatakhane"]
	var attempts := 0
	while rooms.size() < 4 and attempts < 30:
		attempts += 1
		var rw := rng.randi_range(2, 3)
		var rh := rng.randi_range(2, 3)
		var rx := rng.randi_range(0, w - rw)
		var ry := rng.randi_range(0, h - rh)
		var rect := Rect2i(rx, ry, rw, rh)
		if rect.has_point(Vector2i.ZERO):
			continue
		var clash := false
		for r: Dictionary in rooms:
			if (r.rect as Rect2i).grow(1).intersects(rect):
				clash = true
				break
		if clash:
			continue
		# oda içindeki tüm duvarları kaldır
		for x2 in range(rx, rx + rw):
			for y2 in range(ry, ry + rh):
				room_cells[Vector2i(x2, y2)] = true
				if x2 + 1 < rx + rw:
					v_walls[x2 + 1][y2] = false
				if y2 + 1 < ry + rh:
					h_walls[x2][y2 + 1] = false
		rooms.append({
			"rect": rect,
			"type": room_types[rng.randi() % room_types.size()],
		})

	# --- BFS: başlangıçtan uzaklıklar, en uzak hücre = çıkış ---
	var dist := { Vector2i.ZERO: 0 }
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var far := Vector2i.ZERO
	while not queue.is_empty():
		var c2: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = c2 + d
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h \
					and not dist.has(n) and not has_wall_between(v_walls, h_walls, c2, n):
				dist[n] = dist[c2] + 1
				if dist[n] > dist[far]:
					far = n
				queue.append(n)

	# --- kalan çıkmaz sokaklar (sandık/ganimet adayları) ---
	var dead_ends: Array[Vector2i] = []
	for x in w:
		for y in h:
			var c3 := Vector2i(x, y)
			if c3 != Vector2i.ZERO and c3 != far and not room_cells.has(c3) \
					and _wall_count(v_walls, h_walls, c3, w, h) >= 3:
				dead_ends.append(c3)

	return {
		"w": w, "h": h,
		"v_walls": v_walls, "h_walls": h_walls,
		"exit": far, "dist": dist, "dead_ends": dead_ends,
		"rooms": rooms, "room_cells": room_cells,
	}


static func has_wall_between(v_walls: Array, h_walls: Array, a: Vector2i, b: Vector2i) -> bool:
	if b.x == a.x + 1:
		return v_walls[a.x + 1][a.y]
	if b.x == a.x - 1:
		return v_walls[a.x][a.y]
	if b.y == a.y + 1:
		return h_walls[a.x][a.y + 1]
	return h_walls[a.x][a.y]


static func _open_between(v_walls: Array, h_walls: Array, a: Vector2i, b: Vector2i) -> void:
	if b.x == a.x + 1:
		v_walls[a.x + 1][a.y] = false
	elif b.x == a.x - 1:
		v_walls[a.x][a.y] = false
	elif b.y == a.y + 1:
		h_walls[a.x][a.y + 1] = false
	else:
		h_walls[a.x][a.y] = false


static func _wall_count(v_walls: Array, h_walls: Array, c: Vector2i, w: int, h: int) -> int:
	var count := 0
	for d: Vector2i in DIRS:
		var n: Vector2i = c + d
		if n.x < 0 or n.x >= w or n.y < 0 or n.y >= h:
			count += 1
		elif has_wall_between(v_walls, h_walls, c, n):
			count += 1
	return count


static func _filled(n: int) -> Array:
	var arr := []
	for i in n:
		arr.append(true)
	return arr
