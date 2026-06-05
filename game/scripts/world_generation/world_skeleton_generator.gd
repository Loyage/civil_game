class_name WorldSkeletonGenerator
extends RefCounted

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")

func generate(config):
	var skeleton = WorldSkeletonScript.new()
	skeleton.seed = config.seed
	skeleton.big_map_size = config.big_map_size
	skeleton.sub_map_size = config.sub_map_size
	skeleton.ocean_ratio = clampf(float(config.ocean_ratio), 0.0, 0.95)
	skeleton.continent_bias = float(config.generation_params.get("continent_bias", skeleton.continent_bias))
	skeleton.sea_level = _resolve_sea_level(config, skeleton)
	_generate_mountain_ridges(config, skeleton)
	_generate_major_rivers(config, skeleton)
	_build_skeleton_tile_index(skeleton)
	return skeleton

func _resolve_sea_level(config, skeleton) -> int:
	var heights: Array[int] = []
	for row in range(config.big_map_size):
		for col in range(config.big_map_size):
			var world_x: int = int((float(col) + 0.5) * float(config.sub_map_size))
			var world_y: int = int((float(row) + 0.5) * float(config.sub_map_size))
			heights.append(int(round(_sample_base_height(config.seed, skeleton, world_x, world_y))))
	if heights.is_empty():
		return config.sea_level
	heights.sort()
	var index := clampi(int(round(float(heights.size() - 1) * skeleton.ocean_ratio)), 0, heights.size() - 1)
	return heights[index]

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
		var start := _pick_river_source(config, skeleton, id)
		var mouth := _pick_river_mouth(config, skeleton, id, start)
		var main_direction := (mouth - start).normalized()
		var normal := Vector2(-main_direction.y, main_direction.x)
		var points: Array[Vector2] = []
		for point_index in range(7):
			var t := float(point_index) / 6.0
			var drift := (_hash01(config.seed, 202 + id, point_index, 0) - 0.5) * world_size * 0.10
			var point := start.lerp(mouth, t) + normal * drift * sin(t * PI)
			points.append(Vector2(
				clampf(point.x, 0.0, world_size - 1.0),
				clampf(point.y, 0.0, world_size - 1.0)
			))
		skeleton.rivers.append({
			"id": id,
			"points": points,
			"width": 18.0 + _hash01(config.seed, 203 + id, 0, 0) * 24.0,
			"flow": 0.65 + _hash01(config.seed, 204 + id, 0, 0) * 0.35
		})

func _pick_river_source(config, skeleton, river_id: int) -> Vector2:
	var world_size := float(config.big_map_size * config.sub_map_size)
	var best := Vector2(world_size * 0.5, world_size * 0.25)
	var best_score := -INF
	for candidate_index in range(32):
		var point := Vector2(
			_hash01(config.seed, 211 + river_id, candidate_index, 0) * world_size,
			_hash01(config.seed, 211 + river_id, candidate_index, 1) * world_size
		)
		var height := _sample_layered_height(config.seed, skeleton, int(point.x), int(point.y))
		if height <= skeleton.sea_level + 24:
			continue
		var score := float(height) + _hash01(config.seed, 212 + river_id, candidate_index, 0) * 32.0
		if score > best_score:
			best = point
			best_score = score
	return best

func _pick_river_mouth(config, skeleton, river_id: int, source: Vector2) -> Vector2:
	var world_size := float(config.big_map_size * config.sub_map_size)
	var best := Vector2(source.x, world_size - 1.0)
	var best_score := -INF
	for candidate_index in range(48):
		var point := Vector2(
			_hash01(config.seed, 221 + river_id, candidate_index, 0) * world_size,
			_hash01(config.seed, 221 + river_id, candidate_index, 1) * world_size
		)
		var base_height := int(round(_sample_base_height(config.seed, skeleton, int(point.x), int(point.y))))
		if base_height >= skeleton.sea_level:
			continue
		var distance_score: float = source.distance_to(point) / max(1.0, world_size)
		var score: float = distance_score * 120.0 + _hash01(config.seed, 222 + river_id, candidate_index, 0) * 24.0
		if score > best_score:
			best = point
			best_score = score
	return best

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

func _sample_base_height(seed: int, skeleton, world_x: int, world_y: int) -> float:
	var world_size := float(skeleton.big_map_size * skeleton.sub_map_size)
	var normalized := Vector2(float(world_x) / world_size - 0.5, float(world_y) / world_size - 0.5)
	var bias: float = clampf(float(skeleton.continent_bias), 0.0, 1.0)
	var island_falloff := 1.0 - clampf(normalized.length() * lerpf(1.80, 1.15, bias), 0.0, 1.0)
	var continent := lerpf(-140.0, 130.0, island_falloff)
	var detail := (
		(_hash01(seed, 301, world_x / 64, world_y / 64) - 0.5) * 92.0 +
		(_hash01(seed, 302, world_x / 24, world_y / 24) - 0.5) * 48.0 +
		(_hash01(seed, 303, world_x / 8, world_y / 8) - 0.5) * 20.0
	)
	return continent + detail

func _sample_layered_height(seed: int, skeleton, world_x: int, world_y: int) -> int:
	var base := int(round(_sample_base_height(seed, skeleton, world_x, world_y)))
	var ocean := base
	if base < skeleton.sea_level:
		var depth := clampf(float(skeleton.sea_level - base) / 180.0, 0.0, 1.0)
		ocean = min(base, skeleton.sea_level - 4 - int(round(pow(depth, 1.35) * 96.0)))
	return clampi(ocean + int(round(_sample_mountain_influence(skeleton, world_x, world_y) * 150.0)), -256, 256)

func _sample_mountain_influence(skeleton, world_x: int, world_y: int) -> float:
	var point := Vector2(float(world_x), float(world_y))
	var result := 0.0
	for ridge in skeleton.mountain_ridges:
		var distance := _distance_to_polyline(point, ridge["points"])
		var t := distance / float(ridge["width"])
		if t < 1.0:
			result += float(ridge["strength"]) * _falloff(t)
	return clampf(result, 0.0, 1.0)

func _distance_to_polyline(point: Vector2, points: Array) -> float:
	if points.is_empty():
		return INF
	var best := INF
	for index in range(points.size() - 1):
		best = min(best, _distance_to_segment(point, points[index], points[index + 1]))
	return best

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if is_zero_approx(length_sq):
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _falloff(t: float) -> float:
	if t >= 1.0:
		return 0.0
	return (1.0 - t) * (1.0 - t)
