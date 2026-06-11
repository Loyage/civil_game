class_name WorldRiverGenerator
extends RefCounted

const WorldGenerationMathScript := preload("res://game/scripts/world_generation/world_generation_math.gd")

const RIVER_START_WIDTH := 3.0
const RIVER_MAX_WIDTH := 12.0
const RIVER_DISTANCE_WIDTH_GROWTH := 0.42
const RIVER_MERGE_WIDTH_GROWTH := 0.16
const RIVER_SOURCE_MIN_DISTANCE_TILES := 4.0
const RIVER_MAX_UPHILL_STEP := 72

func generate(config, skeleton) -> void:
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

func generate_async(owner: Node, config, skeleton, progress_callback: Callable, cancel_callback: Callable) -> bool:
	var total: int = max(1, int(config.river_source_count))
	if config.river_source_count <= 0:
		if progress_callback.is_valid():
			progress_callback.call(1, total)
		await owner.get_tree().process_frame
		return cancel_callback.is_valid() and bool(cancel_callback.call())

	for id in range(config.river_source_count):
		if cancel_callback.is_valid() and bool(cancel_callback.call()):
			return true
		var source_tile: Vector2i = _pick_river_source_tile(config, skeleton, id)
		if source_tile != Vector2i(-1, -1):
			var river: Dictionary = _trace_river(config, skeleton, id, source_tile)
			if river["points"].size() >= 2:
				river["id"] = skeleton.rivers.size()
				skeleton.river_sources.append(source_tile)
				skeleton.rivers.append(river)
		if progress_callback.is_valid():
			progress_callback.call(id + 1, total)
		await owner.get_tree().process_frame
	return cancel_callback.is_valid() and bool(cancel_callback.call())

func _pick_river_source_tile(config, skeleton, river_id: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for candidate_index in range(48):
		var tile := Vector2i(
			clampi(int(floor(WorldGenerationMathScript.hash01(config.seed, 211 + river_id, candidate_index, 0) * float(config.big_map_size))), 0, config.big_map_size - 1),
			clampi(int(floor(WorldGenerationMathScript.hash01(config.seed, 211 + river_id, candidate_index, 1) * float(config.big_map_size))), 0, config.big_map_size - 1)
		)
		if not _is_valid_river_source_spacing(skeleton, tile):
			continue
		var point: Vector2 = WorldGenerationMathScript.tile_center(config, tile)
		var height: int = WorldGenerationMathScript.sample_layered_height(config.seed, skeleton, int(point.x), int(point.y))
		var mountain: float = WorldGenerationMathScript.sample_mountain_influence(skeleton, int(point.x), int(point.y))
		if height <= skeleton.sea_level + 24 or mountain <= 0.08:
			continue
		var score: float = float(height) + mountain * 160.0 + WorldGenerationMathScript.hash01(config.seed, 212 + river_id, candidate_index, 0) * 16.0
		if score > best_score:
			best = tile
			best_score = score
	if not skeleton.lakes.is_empty() and WorldGenerationMathScript.hash01(config.seed, 213 + river_id, 0, 0) < 0.35:
		var lake_index := int(floor(WorldGenerationMathScript.hash01(config.seed, 214 + river_id, 0, 0) * float(skeleton.lakes.size())))
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
	elif not WorldGenerationMathScript.is_ocean_tile(config, skeleton, tiles[tiles.size() - 1]) and merge_target < 0:
		_register_lake(skeleton, tiles[tiles.size() - 1])
	var points: Array[Vector2] = _tiles_to_points(config, tiles)
	return {
		"id": river_id,
		"points": points,
		"width_profile": _river_width_profile(tiles.size(), merge_target >= 0),
		"width": RIVER_MAX_WIDTH,
		"flow": 1.0,
		"merge_target": merge_target,
		"reached_ocean": not tiles.is_empty() and WorldGenerationMathScript.is_ocean_tile(config, skeleton, tiles[tiles.size() - 1])
	}

func _find_river_path_to_ocean(config, skeleton, source_tile: Vector2i) -> Array[Vector2i]:
	var open: Array[Vector2i] = []
	open.append(source_tile)
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	var source_key: String = WorldGenerationMathScript.tile_coord_key(source_tile)
	came_from[source_key] = Vector2i(-1, -1)
	cost_so_far[source_key] = 0.0

	while not open.is_empty():
		var current: Vector2i = _pop_lowest_river_cost(open, cost_so_far, config, skeleton)
		if current != source_tile and WorldGenerationMathScript.is_ocean_tile(config, skeleton, current):
			return _reconstruct_tile_path(came_from, source_tile, current)

		for direction in WorldGenerationMathScript.directions8():
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= config.big_map_size or next.y >= config.big_map_size:
				continue
			var step_cost: float = _river_step_cost(config, skeleton, current, next)
			if step_cost >= INF:
				continue
			var current_key: String = WorldGenerationMathScript.tile_coord_key(current)
			var next_key: String = WorldGenerationMathScript.tile_coord_key(next)
			var new_cost: float = float(cost_so_far[current_key]) + step_cost
			if not cost_so_far.has(next_key) or new_cost < float(cost_so_far[next_key]):
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				open.append(next)

	return _single_tile_array(source_tile)

func _pop_lowest_river_cost(open: Array[Vector2i], cost_so_far: Dictionary, config, skeleton) -> Vector2i:
	var best_index: int = 0
	var best_score: float = INF
	for index in range(open.size()):
		var tile: Vector2i = open[index]
		var score: float = float(cost_so_far[WorldGenerationMathScript.tile_coord_key(tile)]) + _river_ocean_heuristic(config, skeleton, tile)
		if score < best_score:
			best_score = score
			best_index = index
	var best: Vector2i = open[best_index]
	open.remove_at(best_index)
	return best

func _river_ocean_heuristic(config, skeleton, tile: Vector2i) -> float:
	var height: int = WorldGenerationMathScript.tile_height(config, skeleton, tile)
	var height_bias: float = maxf(0.0, float(height - skeleton.sea_level)) * 0.02
	var edge_distance: int = mini(mini(tile.x, tile.y), mini(config.big_map_size - 1 - tile.x, config.big_map_size - 1 - tile.y))
	return height_bias + float(edge_distance) * 0.08

func _river_step_cost(config, skeleton, current: Vector2i, next: Vector2i) -> float:
	var current_height: int = WorldGenerationMathScript.tile_height(config, skeleton, current)
	var next_height: int = WorldGenerationMathScript.tile_height(config, skeleton, next)
	var uphill: int = maxi(0, next_height - current_height)
	if uphill > RIVER_MAX_UPHILL_STEP and not WorldGenerationMathScript.is_ocean_tile(config, skeleton, next):
		return INF
	var downhill: int = maxi(0, current_height - next_height)
	var diagonal: float = 1.4 if current.x != next.x and current.y != next.y else 1.0
	var point: Vector2 = WorldGenerationMathScript.tile_center(config, next)
	var mountain: float = WorldGenerationMathScript.sample_mountain_influence(skeleton, int(point.x), int(point.y))
	var cut_cost: float = float(uphill) * 0.035
	var highland_cost: float = maxf(0.0, float(next_height - skeleton.sea_level)) * 0.006
	var mountain_cost: float = mountain * 5.0
	var downhill_bonus: float = minf(0.55, float(downhill) * 0.006)
	var ocean_bonus: float = -1.2 if WorldGenerationMathScript.is_ocean_tile(config, skeleton, next) else 0.0
	return maxf(0.08, diagonal + cut_cost + highland_cost + mountain_cost + ocean_bonus - downhill_bonus)

func _reconstruct_tile_path(came_from: Dictionary, source_tile: Vector2i, target_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current: Vector2i = target_tile
	while current != Vector2i(-1, -1):
		result.push_front(current)
		if current == source_tile:
			break
		current = came_from[WorldGenerationMathScript.tile_coord_key(current)]
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
	var point: Vector2 = WorldGenerationMathScript.tile_center(config, tile)
	for river in skeleton.rivers:
		var distance: float = WorldGenerationMathScript.distance_to_polyline(point, river["points"])
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
		var merge_growth: float = RIVER_MERGE_WIDTH_GROWTH if has_merge else 0.0
		result.append(lerpf(RIVER_START_WIDTH, RIVER_MAX_WIDTH, clampf(distance_growth * RIVER_DISTANCE_WIDTH_GROWTH + merge_growth, 0.0, 1.0)))
	return result

func _tiles_to_points(config, tiles: Array[Vector2i]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for tile in tiles:
		result.append(WorldGenerationMathScript.tile_center(config, tile))
	return result

func _single_tile_array(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(tile)
	return result
