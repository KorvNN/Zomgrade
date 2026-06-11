extends SceneTree

func _init() -> void:
	await process_frame
	for p in ["chest.glb", "chest_gold.glb", "wall_pillar.gltf.glb", "column.gltf.glb",
			"floor_tile_big_grate_open.gltf.glb", "stairs_walled.gltf.glb",
			"banner_patternA_red.gltf.glb", "table_long_tablecloth.gltf.glb",
			"candle_triple.gltf.glb", "bed_frame.gltf.glb", "shelf_large.gltf.glb"]:
		var packed: PackedScene = load("res://addons/kaykit_dungeon_remastered/assets/gltf/" + p)
		if packed == null:
			print(p, " LOAD FAIL")
			continue
		var n: Node3D = packed.instantiate()
		root.add_child(n)
		await process_frame
		var anim := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var merged := AABB()
		var first := true
		for mesh: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var aabb := mesh.global_transform * mesh.get_aabb()
			merged = aabb if first else merged.merge(aabb)
			first = false
		print(p, " size=", merged.size, " anims=", anim.get_animation_list() if anim else [])
		n.queue_free()
	quit()
