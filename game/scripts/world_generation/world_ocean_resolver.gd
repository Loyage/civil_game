class_name WorldOceanResolver
extends RefCounted

const WorldGenerationMathScript := preload("res://game/scripts/world_generation/world_generation_math.gd")

const MIN_OCEAN_COMPONENT_TILES := 8
const MIN_OCEAN_COMPONENT_RATIO := 0.01

func resolve_sea_level(config, skeleton) -> int:
	var heights: Dictionary = _sample_tile_heights(config, skeleton)
	if heights.is_empty():
		skeleton.ocean_tiles = {}
		skeleton.ocean_distance_by_tile = {}
		return config.sea_level

	var sorted_heights: Array[int] = []
	for raw_height in heights.values():
		sorted_heights.append(int(raw_height))
	sorted_heights.sort()
	var target_count: int = clampi(int(round(float(sorted_heights.size()) * skeleton.ocean_ratio)), 0, sorted_heights.size())
	if target_count <= 0:
		skeleton.ocean_tiles = {}
		skeleton.ocean_distance_by_tile = {}
		return sorted_heights[0]

	var min_component_size: int = _min_component_size(config)
	var selected_threshold: int = _select_threshold(config, heights, sorted_heights, target_count, min_component_size)
	var ocean_tiles: Dictionary = _qualified_ocean_tiles(config, heights, selected_threshold, min_component_size)
	skeleton.ocean_tiles = ocean_tiles
	skeleton.ocean_distance_by_tile = _ocean_distance_by_tile(config, ocean_tiles)
	return selected_threshold

func _sample_tile_heights(config, skeleton) -> Dictionary:
	var heights := {}
	for row in range(config.big_map_size):
		for col in range(config.big_map_size):
			var world_x: int = int((float(col) + 0.5) * float(config.sub_map_size))
			var world_y: int = int((float(row) + 0.5) * float(config.sub_map_size))
			var tile := Vector2i(col, row)
			heights[WorldGenerationMathScript.tile_coord_key(tile)] = WorldGenerationMathScript.sample_height_after_mountains(config.seed, skeleton, world_x, world_y)
	return heights

func _min_component_size(config) -> int:
	var tile_count: int = int(config.big_map_size) * int(config.big_map_size)
	return maxi(MIN_OCEAN_COMPONENT_TILES, int(ceil(float(tile_count) * MIN_OCEAN_COMPONENT_RATIO)))

func _select_threshold(config, heights: Dictionary, sorted_heights: Array[int], target_count: int, min_component_size: int) -> int:
	var low := 0
	var high: int = sorted_heights.size() - 1
	var best_threshold: int = sorted_heights[clampi(target_count - 1, 0, sorted_heights.size() - 1)]
	var best_count := -1
	while low <= high:
		var mid: int = int(floor(float(low + high) * 0.5))
		var threshold: int = sorted_heights[mid]
		var ocean_tiles: Dictionary = _qualified_ocean_tiles(config, heights, threshold, min_component_size)
		var count: int = ocean_tiles.size()
		if _is_better_count(count, best_count, target_count):
			best_count = count
			best_threshold = threshold
		if count < target_count:
			low = mid + 1
		else:
			high = mid - 1
	return best_threshold

func _is_better_count(count: int, best_count: int, target_count: int) -> bool:
	if best_count < 0:
		return true
	var delta: int = abs(count - target_count)
	var best_delta: int = abs(best_count - target_count)
	if delta == best_delta:
		return count >= target_count and best_count < target_count
	return delta < best_delta

func _qualified_ocean_tiles(config, heights: Dictionary, threshold: int, min_component_size: int) -> Dictionary:
	var candidates := {}
	for key in heights.keys():
		if int(heights[key]) <= threshold:
			candidates[key] = true

	var result := {}
	var visited := {}
	for key in candidates.keys():
		if visited.has(key):
			continue
		var component: Array[Vector2i] = _collect_component(config, candidates, visited, _tile_from_key(String(key)))
		if component.size() < min_component_size:
			continue
		for tile in component:
			result[WorldGenerationMathScript.tile_coord_key(tile)] = true
	return result

func _collect_component(config, candidates: Dictionary, visited: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var queue: Array[Vector2i] = []
	queue.append(start)
	visited[WorldGenerationMathScript.tile_coord_key(start)] = true
	var head := 0
	while head < queue.size():
		var tile: Vector2i = queue[head]
		head += 1
		result.append(tile)
		for direction in WorldGenerationMathScript.directions8():
			var next := tile + direction
			if not _is_in_bounds(config, next):
				continue
			var key := WorldGenerationMathScript.tile_coord_key(next)
			if visited.has(key) or not candidates.has(key):
				continue
			visited[key] = true
			queue.append(next)
	return result

func _ocean_distance_by_tile(config, ocean_tiles: Dictionary) -> Dictionary:
	var distance_by_tile := {}
	var queue: Array[Vector2i] = []
	for key in ocean_tiles.keys():
		var tile: Vector2i = _tile_from_key(String(key))
		if _is_coastal_ocean_tile(config, ocean_tiles, tile):
			distance_by_tile[key] = 0
			queue.append(tile)

	var head := 0
	while head < queue.size():
		var tile: Vector2i = queue[head]
		head += 1
		var distance: int = int(distance_by_tile[WorldGenerationMathScript.tile_coord_key(tile)])
		for direction in WorldGenerationMathScript.directions8():
			var next := tile + direction
			var next_key := WorldGenerationMathScript.tile_coord_key(next)
			if not ocean_tiles.has(next_key) or distance_by_tile.has(next_key):
				continue
			distance_by_tile[next_key] = distance + 1
			queue.append(next)
	return distance_by_tile

func _is_coastal_ocean_tile(config, ocean_tiles: Dictionary, tile: Vector2i) -> bool:
	for direction in WorldGenerationMathScript.directions8():
		var next := tile + direction
		if not _is_in_bounds(config, next):
			return true
		if not ocean_tiles.has(WorldGenerationMathScript.tile_coord_key(next)):
			return true
	return false

func _tile_from_key(key: String) -> Vector2i:
	var parts := key.split(":")
	return Vector2i(int(parts[0]), int(parts[1]))

func _is_in_bounds(config, tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < int(config.big_map_size) and tile.y < int(config.big_map_size)
