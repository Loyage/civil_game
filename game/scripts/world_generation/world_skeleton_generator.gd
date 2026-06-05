class_name WorldSkeletonGenerator
extends RefCounted

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")
const RIVER_START_WIDTH := 3.0
const RIVER_MAX_WIDTH := 12.0
const RIVER_SOURCE_MIN_DISTANCE_TILES := 4.0

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
	var best := Vector2i(-1, -1)
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
	var tiles: Array[Vector2i] = [source_tile]
	var current := source_tile
	var merge_target := -1
	var max_steps: int = int(config.big_map_size) * 3
	for step in range(max_steps):
		if _is_ocean_tile(config, skeleton, current):
			break
		var joined_river: int = _near_existing_river(config, skeleton, current)
		if joined_river >= 0:
			merge_target = joined_river
			break
		var next: Vector2i = _next_downhill_tile(config, skeleton, current)
		if next == current:
			_register_lake(skeleton, current)
			break
		current = next
		if tiles.has(current):
			_register_lake(skeleton, current)
			break
		tiles.append(current)
	var points: Array[Vector2] = _tiles_to_points(config, tiles)
	return {
		"id": river_id,
		"points": points,
		"width_profile": _river_width_profile(tiles.size(), merge_target >= 0),
		"width": RIVER_MAX_WIDTH,
		"flow": 1.0,
		"merge_target": merge_target
	}

func _next_downhill_tile(config, skeleton, tile: Vector2i) -> Vector2i:
	var current_height: int = _tile_height(config, skeleton, tile)
	var best := tile
	var best_height := current_height
	for direction in _directions8():
		var candidate := tile + direction
		if candidate.x < 0 or candidate.y < 0 or candidate.x >= config.big_map_size or candidate.y >= config.big_map_size:
			continue
		var height: int = _tile_height(config, skeleton, candidate)
		if height < best_height:
			best = candidate
			best_height = height
	return best

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
	return int(round(_sample_base_height(config.seed, skeleton, int(point.x), int(point.y)))) < skeleton.sea_level

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
