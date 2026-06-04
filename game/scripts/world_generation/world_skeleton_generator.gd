class_name WorldSkeletonGenerator
extends RefCounted

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")

func generate(config):
	var skeleton = WorldSkeletonScript.new()
	skeleton.seed = config.seed
	skeleton.big_map_size = config.big_map_size
	skeleton.sub_map_size = config.sub_map_size
	skeleton.sea_level = config.sea_level
	skeleton.continent_bias = float(config.generation_params.get("continent_bias", skeleton.continent_bias))
	_generate_mountain_ridges(config, skeleton)
	_generate_major_rivers(config, skeleton)
	_build_skeleton_tile_index(skeleton)
	return skeleton

func _generate_mountain_ridges(config, skeleton) -> void:
	var world_size := float(config.big_map_size * config.sub_map_size)
	for id in range(config.mountain_count):
		var start := Vector2(
			_hash01(config.seed, 101 + id, 0, 0) * world_size,
			_hash01(config.seed, 101 + id, 1, 0) * world_size
		)
		var angle := _hash01(config.seed, 102 + id, 0, 0) * TAU
		var length := world_size * (0.38 + _hash01(config.seed, 103 + id, 0, 0) * 0.45)
		var direction := Vector2(cos(angle), sin(angle))
		var normal := Vector2(-direction.y, direction.x)
		var points: Array[Vector2] = []
		for point_index in range(5):
			var t := float(point_index) / 4.0
			var bend := (_hash01(config.seed, 104 + id, point_index, 0) - 0.5) * world_size * 0.16
			points.append(start + direction * (t - 0.5) * length + normal * bend)
		skeleton.mountain_ridges.append({
			"id": id,
			"points": points,
			"width": 52.0 + _hash01(config.seed, 105 + id, 0, 0) * 72.0,
			"strength": 0.62 + _hash01(config.seed, 106 + id, 0, 0) * 0.38,
			"roughness": 0.35 + _hash01(config.seed, 107 + id, 0, 0) * 0.50
		})

func _generate_major_rivers(config, skeleton) -> void:
	var world_size := float(config.big_map_size * config.sub_map_size)
	for id in range(config.major_river_count):
		var start := Vector2(
			_hash01(config.seed, 201 + id, 0, 0) * world_size,
			_hash01(config.seed, 201 + id, 1, 0) * world_size * 0.65
		)
		var points: Array[Vector2] = []
		for point_index in range(7):
			var t := float(point_index) / 6.0
			var drift := (_hash01(config.seed, 202 + id, point_index, 0) - 0.5) * world_size * 0.20
			points.append(Vector2(
				clampf(start.x + drift, 0.0, world_size - 1.0),
				clampf(start.y + t * world_size * 0.80, 0.0, world_size - 1.0)
			))
		skeleton.rivers.append({
			"id": id,
			"points": points,
			"width": 18.0 + _hash01(config.seed, 203 + id, 0, 0) * 24.0,
			"flow": 0.65 + _hash01(config.seed, 204 + id, 0, 0) * 0.35
		})

func _build_skeleton_tile_index(skeleton) -> void:
	for ridge in skeleton.mountain_ridges:
		_index_polyline(skeleton, ridge["points"], int(ridge["id"]), true)
	for river in skeleton.rivers:
		_index_polyline(skeleton, river["points"], int(river["id"]), false)

func _index_polyline(skeleton, points: Array, id: int, is_mountain: bool) -> void:
	for point in points:
		var tile_x := clampi(int(floor(point.x / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		var tile_y := clampi(int(floor(point.y / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := tile_x + dx
				var ny := tile_y + dy
				if nx < 0 or ny < 0 or nx >= skeleton.big_map_size or ny >= skeleton.big_map_size:
					continue
				if is_mountain:
					skeleton.add_mountain_to_tile(nx, ny, id)
				else:
					skeleton.add_river_to_tile(nx, ny, id)

func _hash01(seed: int, salt: int, x: int, y: int) -> float:
	var n := int(seed) ^ int(salt * 1442695041) ^ int(x * 374761393) ^ int(y * 668265263)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
