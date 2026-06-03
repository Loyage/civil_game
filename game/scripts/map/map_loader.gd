class_name MapLoader
extends RefCounted

const CONFIG_PATH := "res://game/data/maps/map_generation_config.json"
const OffsetCoordScript := preload("res://game/scripts/map/offset_coord.gd")
const GridLayoutScript := preload("res://game/scripts/map/grid_layout.gd")
const MapStateScript := preload("res://game/scripts/map/map_state.gd")
const TileStateScript := preload("res://game/scripts/map/tile_state.gd")

func load_generated_map():
	var config := _read_json(CONFIG_PATH)
	var map_state = _generate_map_state(config)
	_write_generated_map(config, map_state)
	return map_state

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open map file: %s" % path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Cannot parse map JSON: %s" % json.get_error_message())
		return {}

	return json.data

func _generate_map_state(config: Dictionary):
	var width := int(config.get("width", 40))
	var height := int(config.get("height", 20))
	var seed := int(config.get("seed", Time.get_unix_time_from_system()))
	var map_state = MapStateScript.new(width, height)
	map_state.world_seed = seed
	var start_city: Dictionary = config.get("start_city", {})
	var start_col := int(start_city.get("col", 0))
	var start_row := int(start_city.get("row", 0))
	map_state.start_city_name = String(start_city.get("name", "Capital"))

	var values := {}
	for row in range(height):
		for col in range(width):
			values[_point_key(col, row)] = _generate_base_values(config, seed, col, row, width, height)

	_add_rivers(config, seed, values, width, height)

	for row in range(height):
		for col in range(width):
			var offset = OffsetCoordScript.new(col, row)
			var point_key := _point_key(col, row)
			var tile = TileStateScript.new(point_key, offset, "plains")
			_apply_values_to_tile(config, values, point_key, tile, width, height)
			tile.is_city_center = col == start_col and row == start_row

			if tile.is_city_center:
				tile.owner_city_id = "player_capital"
				map_state.start_city_tile_key = tile.tile_key

			map_state.add_tile(tile)

	_build_render_paths(map_state)
	return map_state

func _generate_base_values(config: Dictionary, seed: int, col: int, row: int, width: int, height: int) -> Dictionary:
	var x: float = float(col) / max(1.0, float(width - 1))
	var y: float = float(row) / max(1.0, float(height - 1))
	var center_distance: float = Vector2(x - 0.5, y - 0.5).length() * 1.3
	var continent_bias: float = float(config.get("generation", {}).get("continent_bias", 0.26))
	var elevation: float = 0.64 - center_distance * continent_bias
	elevation += _centered_noise(seed, col, row, 0) * 0.26
	elevation += _centered_smooth_noise(seed, col, row, 1) * 0.32
	elevation = clampf(elevation, 0.0, 1.0)

	var rainfall: float = 0.48 + _centered_smooth_noise(seed, col, row, 2) * 0.62 - max(0.0, elevation - 0.62) * 0.16
	rainfall = clampf(rainfall, 0.0, 1.0)

	var temperature: float = 0.82 - abs(y - 0.5) * 1.25 + _centered_smooth_noise(seed, col, row, 3) * 0.22 - elevation * 0.18
	temperature = clampf(temperature, 0.0, 1.0)

	return {
		"elevation": elevation,
		"rainfall": rainfall,
		"temperature": temperature,
		"river_strength": 0.0,
		"river_flow_x": 0,
		"river_flow_y": 0
	}

func _apply_values_to_tile(config: Dictionary, values: Dictionary, point_key: String, tile, width: int, height: int) -> void:
	var thresholds: Dictionary = config.get("terrain_thresholds", {})
	var value: Dictionary = values[point_key]
	tile.elevation = float(value.get("elevation", 0.0))
	tile.rainfall = float(value.get("rainfall", 0.0))
	tile.temperature = float(value.get("temperature", 0.0))
	tile.river_strength = float(value.get("river_strength", 0.0))
	tile.has_river = tile.river_strength > 0.0
	tile.river_flow = Vector2i(int(value.get("river_flow_x", 0)), int(value.get("river_flow_y", 0)))
	tile.ruggedness = _ruggedness(values, tile.offset.col, tile.offset.row, width, height)
	tile.moisture = clampf(tile.rainfall + tile.river_strength * 0.25, 0.0, 1.0)

	var ocean_threshold := float(thresholds.get("ocean_elevation", 0.32))
	var mountain_threshold := float(thresholds.get("mountain_ruggedness", 0.34))
	var hill_threshold := float(thresholds.get("hill_ruggedness", 0.16))
	var lake_threshold := float(thresholds.get("lake_elevation", 0.38))
	var desert_threshold := float(thresholds.get("desert_rainfall", 0.24))
	var swamp_threshold := float(thresholds.get("swamp_rainfall", 0.74))

	if tile.elevation <= ocean_threshold:
		tile.terrain_id = "ocean"
		return

	if tile.rainfall <= desert_threshold and tile.temperature > 0.45:
		tile.terrain_id = "desert"
	elif tile.temperature < 0.28:
		tile.terrain_id = "tundra"
	elif tile.rainfall > 0.55:
		tile.terrain_id = "grassland"
	else:
		tile.terrain_id = "plains"

	if tile.ruggedness >= mountain_threshold and tile.elevation > ocean_threshold + 0.18:
		tile.add_feature("mountain")
	elif tile.ruggedness >= hill_threshold and tile.elevation > ocean_threshold + 0.08:
		tile.add_feature("hill")

	if tile.elevation <= lake_threshold and tile.has_river and tile.terrain_id != "ocean":
		tile.add_feature("lake")

	if tile.rainfall >= swamp_threshold and tile.terrain_id != "ocean" and (tile.elevation <= lake_threshold + 0.15 or tile.has_river):
		tile.add_feature("swamp")

	if tile.rainfall > 0.50 and tile.terrain_id in ["grassland", "plains"] and not tile.is_mountain():
		tile.add_feature("forest")

func _add_rivers(config: Dictionary, seed: int, values: Dictionary, width: int, height: int) -> void:
	var river_count: int = int(config.get("generation", {}).get("river_count", 5))
	var max_steps: int = int(config.get("generation", {}).get("river_max_steps", 80))
	var starts: Array = _highest_points(values, width, height, river_count)
	for index in range(starts.size()):
		_trace_river(seed + index * 97, starts[index], values, width, height, max_steps)

func _trace_river(seed: int, start: Vector2i, values: Dictionary, width: int, height: int, max_steps: int) -> void:
	var current: Vector2i = start
	var visited := {}
	for step in range(max_steps):
		var key := _point_key(current.x, current.y)
		if visited.has(key):
			return
		visited[key] = true
		var value: Dictionary = values[key]
		value["river_strength"] = max(float(value.get("river_strength", 0.0)), 1.0 - float(step) / float(max_steps))

		var next: Vector2i = _lowest_neighbor(seed, current, values, width, height)
		if next == current:
			return

		value["river_flow_x"] = next.x - current.x
		value["river_flow_y"] = next.y - current.y
		if float(values[_point_key(next.x, next.y)].get("elevation", 0.0)) <= 0.32:
			return
		current = next

func _highest_points(values: Dictionary, width: int, height: int, count: int) -> Array:
	var selected: Array = []
	var selected_scores: Array = []
	for row in range(height):
		for col in range(width):
			var point := Vector2i(col, row)
			var score: float = float(values[_point_key(col, row)].get("elevation", 0.0))
			if score <= 0.58:
				continue
			_insert_ranked_point(selected, selected_scores, point, score, count)
	return selected

func _insert_ranked_point(points: Array, scores: Array, point: Vector2i, score: float, limit: int) -> void:
	var insert_at := points.size()
	for index in range(points.size()):
		if score > float(scores[index]):
			insert_at = index
			break
	points.insert(insert_at, point)
	scores.insert(insert_at, score)
	while points.size() > limit:
		points.pop_back()
		scores.pop_back()

func _lowest_neighbor(seed: int, current: Vector2i, values: Dictionary, width: int, height: int) -> Vector2i:
	var best: Vector2i = current
	var best_score: float = float(values[_point_key(current.x, current.y)].get("elevation", 0.0))
	for direction in _directions8():
		var next: Vector2i = current + direction
		if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
			continue
		var next_elevation: float = float(values[_point_key(next.x, next.y)].get("elevation", 0.0))
		var score: float = next_elevation + _value_noise(seed, next.x, next.y, 8) * 0.025
		if score < best_score:
			best_score = score
			best = next
	return best

func _ruggedness(values: Dictionary, col: int, row: int, width: int, height: int) -> float:
	var center: float = float(values[_point_key(col, row)].get("elevation", 0.0))
	var max_delta: float = 0.0
	for direction in _directions8():
		var next: Vector2i = Vector2i(col + direction.x, row + direction.y)
		if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
			continue
		var neighbor: float = float(values[_point_key(next.x, next.y)].get("elevation", 0.0))
		max_delta = max(max_delta, abs(center - neighbor))
	return max_delta

func _smooth_noise(seed: int, col: int, row: int, salt: int) -> float:
	var total: float = 0.0
	var weight: float = 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var distance: int = abs(dx) + abs(dy) + 1
			var sample_weight: float = 1.0 / float(distance)
			total += _value_noise(seed, col + dx, row + dy, salt) * sample_weight
			weight += sample_weight
	return total / weight

func _centered_smooth_noise(seed: int, col: int, row: int, salt: int) -> float:
	return _smooth_noise(seed, col, row, salt) - 0.5

func _value_noise(seed: int, col: int, row: int, salt: int) -> float:
	var n := int(seed) ^ int(col * 374761393) ^ int(row * 668265263) ^ int(salt * 1442695041)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0

func _centered_noise(seed: int, col: int, row: int, salt: int) -> float:
	return _value_noise(seed, col, row, salt) - 0.5

func _directions8() -> Array:
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

func _build_render_paths(map_state) -> void:
	for tile in map_state.tiles_by_key.values():
		if tile.has_river:
			tile.river_path_points = _river_path_points_for_tile(map_state, tile)
		if tile.is_mountain():
			tile.ridge_path_points = _ridge_path_points_for_tile(map_state, tile)

func _river_path_points_for_tile(map_state, tile) -> PackedVector2Array:
	var points := PackedVector2Array()
	var incoming_direction := _strongest_incoming_river_direction(map_state, tile)
	var outgoing_direction: Vector2i = tile.river_flow

	if incoming_direction != Vector2i.ZERO:
		points.append(_normalized_edge_point(incoming_direction))
	else:
		points.append(Vector2(0.5, 0.5))

	points.append(_normalized_river_midpoint(tile))

	if not tile.is_lake() and outgoing_direction != Vector2i.ZERO:
		points.append(_normalized_edge_point(outgoing_direction))

	return points

func _strongest_incoming_river_direction(map_state, tile) -> Vector2i:
	var best_direction := Vector2i.ZERO
	var best_strength := -1.0
	for direction in _directions8():
		var neighbor = map_state.get_tile_by_offset(tile.offset.col + direction.x, tile.offset.row + direction.y)
		if neighbor == null or not neighbor.has_river:
			continue
		if neighbor.river_flow != -direction:
			continue
		if neighbor.river_strength > best_strength:
			best_strength = neighbor.river_strength
			best_direction = direction
	return best_direction

func _ridge_path_points_for_tile(map_state, tile) -> PackedVector2Array:
	var connected_directions: Array[Vector2i] = []
	for direction in _directions8():
		var neighbor = map_state.get_tile_by_offset(tile.offset.col + direction.x, tile.offset.row + direction.y)
		if neighbor == null or not neighbor.is_mountain():
			continue
		connected_directions.append(direction)

	if connected_directions.is_empty():
		return PackedVector2Array([
			Vector2(0.24, 0.68),
			Vector2(0.50, 0.26),
			Vector2(0.76, 0.68)
		])

	var start_direction: Vector2i = connected_directions[0]
	var end_direction: Vector2i = connected_directions[0]
	var best_distance := -1.0
	for a in connected_directions:
		for b in connected_directions:
			var distance := Vector2(a - b).length_squared()
			if distance > best_distance:
				best_distance = distance
				start_direction = a
				end_direction = b

	return PackedVector2Array([
		_normalized_edge_point(start_direction),
		_normalized_ridge_midpoint(tile),
		_normalized_edge_point(end_direction)
	])

func _normalized_edge_point(direction: Vector2i) -> Vector2:
	var vector := Vector2(direction)
	if vector == Vector2.ZERO:
		return Vector2(0.5, 0.5)
	vector = vector.normalized()
	return Vector2(0.5, 0.5) + vector * 0.47

func _normalized_river_midpoint(tile) -> Vector2:
	var bend := _value_noise(19, tile.offset.col, tile.offset.row, 21) - 0.5
	return Vector2(
		clampf(0.5 + bend * 0.18, 0.34, 0.66),
		clampf(0.5 - bend * 0.12, 0.34, 0.66)
	)

func _normalized_ridge_midpoint(tile) -> Vector2:
	var bend := _value_noise(23, tile.offset.col, tile.offset.row, 22) - 0.5
	return Vector2(
		clampf(0.5 + bend * 0.16, 0.30, 0.70),
		clampf(0.5 - tile.elevation * 0.14, 0.22, 0.58)
	)

func _write_generated_map(config: Dictionary, map_state) -> void:
	var path := String(config.get("generated_output_path", "user://generated_map.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write generated map: %s" % path)
		return
	var tiles: Array = []
	for tile in map_state.tiles_by_key.values():
		tiles.append({
			"col": tile.offset.col,
			"row": tile.offset.row,
			"terrain_id": tile.terrain_id,
			"elevation": tile.elevation,
			"rainfall": tile.rainfall,
			"temperature": tile.temperature,
			"ruggedness": tile.ruggedness,
			"moisture": tile.moisture,
			"has_river": tile.has_river,
			"river_flow": [tile.river_flow.x, tile.river_flow.y],
			"river_strength": tile.river_strength,
			"river_path_points": _serialize_vector2_array(tile.river_path_points),
			"ridge_path_points": _serialize_vector2_array(tile.ridge_path_points),
			"features": Array(tile.features)
		})
	file.store_string(JSON.stringify({
		"version": 1,
		"seed": config.get("seed", null),
		"width": map_state.width,
		"height": map_state.height,
		"tiles": tiles
	}, "\t"))

func _point_key(col: int, row: int) -> String:
	return GridLayoutScript.tile_key(col, row)

func _serialize_vector2_array(points: PackedVector2Array) -> Array:
	var serialized: Array = []
	for point in points:
		serialized.append([point.x, point.y])
	return serialized
