class_name WorldSkeletonGenerator
extends RefCounted

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")
const RIVER_START_WIDTH := 3.0
const RIVER_MAX_WIDTH := 12.0
const RIVER_SOURCE_MIN_DISTANCE_TILES := 4.0
const RIVER_MAX_UPHILL_STEP := 72

func generate(config):
	var skeleton = WorldSkeletonScript.new()
	skeleton.seed = config.seed
	skeleton.big_map_size = config.big_map_size
	skeleton.sub_map_size = config.sub_map_size
	skeleton.ocean_ratio = clampf(float(config.ocean_ratio), 0.0, 0.95)
	skeleton.continent_bias = float(config.generation_params.get("continent_bias", skeleton.continent_bias))
	_generate_mountain_ridges(config, skeleton)
	skeleton.sea_level = _resolve_sea_level(config, skeleton)
	_generate_rivers(config, skeleton)
	_build_skeleton_tile_index(skeleton)
	return skeleton

func _resolve_sea_level(config, skeleton) -> int:
	var heights: Array[int] = []
	for row in range(config.big_map_size):
		for col in range(config.big_map_size):
			var world_x: int = int((float(col) + 0.5) * float(config.sub_map_size))
			var world_y: int = int((float(row) + 0.5) * float(config.sub_map_size))
			heights.append(_sample_height_after_mountains(config.seed, skeleton, world_x, world_y))
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

func _generate_rivers(config, skeleton) -> void:
	for id in range(config.river_source_count):
		var source_tile: Vector2i = _pick_river_source_tile(config, skeleton, id)
		if source_tile == Vector2i(-1, -1):
			continue
		var river: Dictionary = _trace_river(config, skeleton, id, source_tile)
		if river["points"].size() < 2:
			continue
		river["id"] = skeleton.rivers.size()
		skeleton.river_sources.append(source_tile)
		skeleton.rivers.append(river)

func _pick_river_source_tile(config, skeleton, river_id: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for candidate_index in range(48):
		var tile := Vector2i(
			clampi(int(floor(_hash01(config.seed, 211 + river_id, candidate_index, 0) * float(config.big_map_size))), 0, config.big_map_size - 1),
			clampi(int(floor(_hash01(config.seed, 211 + river_id, candidate_index, 1) * float(config.big_map_size))), 0, config.big_map_size - 1)
		)
		if not _is_valid_river_source_spacing(skeleton, tile):
			continue
		var point: Vector2 = _tile_center(config, tile)
		var height: int = _sample_layered_height(config.seed, skeleton, int(point.x), int(point.y))
		var mountain: float = _sample_mountain_influence(skeleton, int(point.x), int(point.y))
		if height <= skeleton.sea_level + 24 or mountain <= 0.08:
			continue
		var score: float = float(height) + mountain * 160.0 + _hash01(config.seed, 212 + river_id, candidate_index, 0) * 16.0
		if score > best_score:
			best = tile
			best_score = score
	if not skeleton.lakes.is_empty() and _hash01(config.seed, 213 + river_id, 0, 0) < 0.35:
		var lake_index := int(floor(_hash01(config.seed, 214 + river_id, 0, 0) * float(skeleton.lakes.size())))
		var lake: Dictionary = skeleton.lakes[clampi(lake_index, 0, skeleton.lakes.size() - 1)]
		var lake_tile: Variant = lake.get("tile", best)
		if typeof(lake_tile) == TYPE_VECTOR2I and _is_valid_river_source_spacing(skeleton, lake_tile as Vector2i):
			best = lake_tile as Vector2i
	return best

func _is_valid_river_source_spacing(skeleton, tile: Vector2i) -> bool:
	for source in skeleton.river_sources:
		if Vector2(tile - source).length() < RIVER_SOURCE_MIN_DISTANCE_TILES:
			return false
	return true

func _trace_river(config, skeleton, river_id: int, source_tile: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = _find_river_path_to_ocean(config, skeleton, source_tile)
	var merge_target: int = _trim_path_at_existing_river(config, skeleton, tiles)
	if tiles.size() < 2:
		_register_lake(skeleton, source_tile)
	elif not _is_ocean_tile(config, skeleton, tiles[tiles.size() - 1]) and merge_target < 0:
		_register_lake(skeleton, tiles[tiles.size() - 1])
	var points: Array[Vector2] = _tiles_to_points(config, tiles)
	return {
		"id": river_id,
		"points": points,
		"width_profile": _river_width_profile(tiles.size(), merge_target >= 0),
		"width": RIVER_MAX_WIDTH,
		"flow": 1.0,
		"merge_target": merge_target,
		"reached_ocean": not tiles.is_empty() and _is_ocean_tile(config, skeleton, tiles[tiles.size() - 1])
	}

func _find_river_path_to_ocean(config, skeleton, source_tile: Vector2i) -> Array[Vector2i]:
	var open: Array[Vector2i] = [source_tile]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	var source_key: String = _tile_coord_key(source_tile)
	came_from[source_key] = Vector2i(-1, -1)
	cost_so_far[source_key] = 0.0

	while not open.is_empty():
		var current: Vector2i = _pop_lowest_river_cost(open, cost_so_far, config, skeleton)
		if current != source_tile and _is_ocean_tile(config, skeleton, current):
			return _reconstruct_tile_path(came_from, source_tile, current)

		for direction in _directions8():
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= config.big_map_size or next.y >= config.big_map_size:
				continue
			var step_cost: float = _river_step_cost(config, skeleton, current, next)
			if step_cost >= INF:
				continue
			var current_key: String = _tile_coord_key(current)
			var next_key: String = _tile_coord_key(next)
			var new_cost: float = float(cost_so_far[current_key]) + step_cost
			if not cost_so_far.has(next_key) or new_cost < float(cost_so_far[next_key]):
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				open.append(next)

	return [source_tile]

func _pop_lowest_river_cost(open: Array[Vector2i], cost_so_far: Dictionary, config, skeleton) -> Vector2i:
	var best_index: int = 0
	var best_score: float = INF
	for index in range(open.size()):
		var tile: Vector2i = open[index]
		var score: float = float(cost_so_far[_tile_coord_key(tile)]) + _river_ocean_heuristic(config, skeleton, tile)
		if score < best_score:
			best_score = score
			best_index = index
	var best: Vector2i = open[best_index]
	open.remove_at(best_index)
	return best

func _river_ocean_heuristic(config, skeleton, tile: Vector2i) -> float:
	var height: int = _tile_height(config, skeleton, tile)
	var height_bias: float = maxf(0.0, float(height - skeleton.sea_level)) * 0.02
	var edge_distance: int = mini(mini(tile.x, tile.y), mini(config.big_map_size - 1 - tile.x, config.big_map_size - 1 - tile.y))
	return height_bias + float(edge_distance) * 0.08

func _river_step_cost(config, skeleton, current: Vector2i, next: Vector2i) -> float:
	var current_height: int = _tile_height(config, skeleton, current)
	var next_height: int = _tile_height(config, skeleton, next)
	var uphill: int = maxi(0, next_height - current_height)
	if uphill > RIVER_MAX_UPHILL_STEP and not _is_ocean_tile(config, skeleton, next):
		return INF
	var downhill: int = maxi(0, current_height - next_height)
	var diagonal: float = 1.4 if current.x != next.x and current.y != next.y else 1.0
	var point: Vector2 = _tile_center(config, next)
	var mountain: float = _sample_mountain_influence(skeleton, int(point.x), int(point.y))
	var cut_cost: float = float(uphill) * 0.035
	var highland_cost: float = maxf(0.0, float(next_height - skeleton.sea_level)) * 0.006
	var mountain_cost: float = mountain * 5.0
	var downhill_bonus: float = minf(0.55, float(downhill) * 0.006)
	var ocean_bonus: float = -1.2 if _is_ocean_tile(config, skeleton, next) else 0.0
	return maxf(0.08, diagonal + cut_cost + highland_cost + mountain_cost + ocean_bonus - downhill_bonus)

func _reconstruct_tile_path(came_from: Dictionary, source_tile: Vector2i, target_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current: Vector2i = target_tile
	while current != Vector2i(-1, -1):
		result.push_front(current)
		if current == source_tile:
			break
		current = came_from[_tile_coord_key(current)]
	return result

func _trim_path_at_existing_river(config, skeleton, tiles: Array[Vector2i]) -> int:
	for index in range(1, tiles.size()):
		var joined_river: int = _near_existing_river(config, skeleton, tiles[index])
		if joined_river >= 0:
			while tiles.size() > index + 1:
				tiles.remove_at(tiles.size() - 1)
			return joined_river
	return -1

func _near_existing_river(config, skeleton, tile: Vector2i) -> int:
	var point: Vector2 = _tile_center(config, tile)
	for river in skeleton.rivers:
		var distance: float = _distance_to_polyline(point, river["points"])
		if distance <= float(river.get("width", RIVER_MAX_WIDTH)):
			return int(river["id"])
	return -1

func _register_lake(skeleton, tile: Vector2i) -> void:
	var lake_id: int = skeleton.lakes.size()
	skeleton.lakes.append({
		"id": lake_id,
		"tile": tile
	})
	skeleton.add_lake_to_tile(tile.x, tile.y, lake_id)

func _river_width_profile(tile_count: int, has_merge: bool) -> Array[float]:
	var result: Array[float] = []
	var growth_denominator: float = max(1.0, float(tile_count - 1))
	for index in range(tile_count):
		var distance_growth: float = float(index) / growth_denominator
		var merge_growth: float = 0.22 if has_merge else 0.0
		result.append(lerpf(RIVER_START_WIDTH, RIVER_MAX_WIDTH, clampf(distance_growth * 0.78 + merge_growth, 0.0, 1.0)))
	return result

func _tiles_to_points(config, tiles: Array[Vector2i]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for tile in tiles:
		result.append(_tile_center(config, tile))
	return result

func _tile_center(config, tile: Vector2i) -> Vector2:
	return Vector2(
		(float(tile.x) + 0.5) * float(config.sub_map_size),
		(float(tile.y) + 0.5) * float(config.sub_map_size)
	)

func _tile_height(config, skeleton, tile: Vector2i) -> int:
	var point: Vector2 = _tile_center(config, tile)
	return _sample_layered_height(config.seed, skeleton, int(point.x), int(point.y))

func _is_ocean_tile(config, skeleton, tile: Vector2i) -> bool:
	var point: Vector2 = _tile_center(config, tile)
	return _sample_height_after_mountains(config.seed, skeleton, int(point.x), int(point.y)) < skeleton.sea_level

func _tile_coord_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

func _build_skeleton_tile_index(skeleton) -> void:
	for ridge in skeleton.mountain_ridges:
		_index_polyline(skeleton, ridge["points"], int(ridge["id"]), true)
	for river in skeleton.rivers:
		_index_river_path(skeleton, river["points"], int(river["id"]))

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

func _index_river_path(skeleton, points: Array, id: int) -> void:
	for point in points:
		var tile_x := clampi(int(floor(point.x / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		var tile_y := clampi(int(floor(point.y / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		skeleton.add_river_to_tile(tile_x, tile_y, id)

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
	var height_after_mountains: int = _sample_height_after_mountains(seed, skeleton, world_x, world_y)
	if height_after_mountains >= skeleton.sea_level:
		return height_after_mountains
	var depth := clampf(float(skeleton.sea_level - height_after_mountains) / 180.0, 0.0, 1.0)
	return clampi(min(height_after_mountains, skeleton.sea_level - 4 - int(round(pow(depth, 1.35) * 96.0))), -256, 256)

func _sample_height_after_mountains(seed: int, skeleton, world_x: int, world_y: int) -> int:
	return clampi(
		int(round(_sample_base_height(seed, skeleton, world_x, world_y))) + int(round(_sample_mountain_influence(skeleton, world_x, world_y) * 150.0)),
		-256,
		256
	)

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

func _directions8() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1)
	]
