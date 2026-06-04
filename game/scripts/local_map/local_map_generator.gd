class_name LocalMapGenerator
extends RefCounted

const LocalMapStateScript := preload("res://game/scripts/local_map/local_map_state.gd")

const SEA_LEVEL := 0
const MIN_HEIGHT := -256
const MAX_HEIGHT := 256
const TILE_GLOBAL_STEP := 255

var world_seed: int

func _init(init_world_seed: int = 0) -> void:
	world_seed = init_world_seed

func generate(tile):
	var state = LocalMapStateScript.new()
	state.world_seed = world_seed
	state.tile_key = tile.tile_key
	state.tile_col = tile.offset.col
	state.tile_row = tile.offset.row
	state.resize_arrays()

	_generate_heights(state, tile)
	_apply_river(state, tile)
	_derive_flags_and_slopes(state)
	return state

func _generate_heights(state, tile) -> void:
	var total = 0
	var target_height = _tile_elevation_to_height(tile.elevation)
	for y in range(state.height):
		for x in range(state.width):
			var global_x = state.tile_col * TILE_GLOBAL_STEP + x
			var global_y = state.tile_row * TILE_GLOBAL_STEP + y
			var height = _sample_height(global_x, global_y, target_height, tile, _edge_weight(state, x, y))
			var index = state.index(x, y)
			state.heights[index] = height
			total += height
	state.average_height = int(round(float(total) / float(state.width * state.height)))

func _sample_height(global_x: int, global_y: int, target_height: int, tile, edge_weight: float) -> int:
	var low = _centered_smooth_noise(global_x, global_y, 0, 24) * 90.0
	var mid = _centered_smooth_noise(global_x, global_y, 1, 8) * 42.0
	var high = _centered_smooth_noise(global_x, global_y, 2, 3) * 16.0
	var height = low + mid + high
	height += float(target_height) * edge_weight

	if tile.is_mountain():
		height += (72.0 + _value_noise(global_x, global_y, 6) * 58.0) * edge_weight
	elif tile.is_hill():
		height += (24.0 + _value_noise(global_x, global_y, 7) * 28.0) * edge_weight

	if tile.is_water():
		height -= 96.0 * edge_weight
	elif tile.is_lake() or tile.is_swamp():
		height -= 32.0 * edge_weight

	return clampi(int(round(height)), MIN_HEIGHT, MAX_HEIGHT)

func _edge_weight(state, x: int, y: int) -> float:
	var distance_to_edge = min(min(x, y), min(state.width - 1 - x, state.height - 1 - y))
	return clampf(float(distance_to_edge) / 32.0, 0.0, 1.0)

func _apply_river(state, tile) -> void:
	if not tile.has_river:
		return

	var path = _find_river_path(state, tile)
	for point in path:
		_carve_river_at(state, point.x, point.y)

func _find_river_path(state, tile) -> Array[Vector2i]:
	var start = _river_start_cell(tile)
	var goal = _river_goal_cell(tile)
	if start == goal:
		return [start]

	var open: Array[Vector2i] = [start]
	var came_from = {}
	var cost_so_far = {}
	came_from[_cell_key(start)] = Vector2i(-1, -1)
	cost_so_far[_cell_key(start)] = 0.0

	while not open.is_empty():
		var current = _pop_lowest_cost(open, cost_so_far, goal)
		if current == goal:
			break

		for next in _river_neighbors(current, state.width, state.height):
			var new_cost: float = float(cost_so_far[_cell_key(current)]) + _river_step_cost(state, current, next, goal)
			var next_key = _cell_key(next)
			if not cost_so_far.has(next_key) or new_cost < float(cost_so_far[next_key]):
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				open.append(next)

	return _reconstruct_path(came_from, start, goal)

func _river_start_cell(tile) -> Vector2i:
	var incoming = _incoming_direction_from_path(tile)
	if incoming != Vector2i.ZERO:
		return _edge_cell(incoming)
	return _normalized_to_cell(_river_point(tile, 0, Vector2(0.5, 0.5)))

func _river_goal_cell(tile) -> Vector2i:
	if tile.is_lake():
		return _normalized_to_cell(_river_point(tile, 1, Vector2(0.5, 0.5)))
	if tile.river_flow != Vector2i.ZERO:
		return _edge_cell(tile.river_flow)
	return _normalized_to_cell(_river_point(tile, max(0, tile.river_path_points.size() - 1), Vector2(0.5, 0.5)))

func _incoming_direction_from_path(tile) -> Vector2i:
	if tile.river_path_points.is_empty():
		return Vector2i.ZERO
	var point: Vector2 = tile.river_path_points[0]
	var delta = point - Vector2(0.5, 0.5)
	if delta.length() < 0.32:
		return Vector2i.ZERO
	return Vector2i(_axis_sign(delta.x), _axis_sign(delta.y))

func _river_point(tile, index: int, fallback: Vector2) -> Vector2:
	if index >= 0 and index < tile.river_path_points.size():
		return tile.river_path_points[index]
	return fallback

func _normalized_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(round(point.x * float(LocalMapStateScript.WIDTH - 1))), 0, LocalMapStateScript.WIDTH - 1),
		clampi(int(round(point.y * float(LocalMapStateScript.HEIGHT - 1))), 0, LocalMapStateScript.HEIGHT - 1)
	)

func _edge_cell(direction: Vector2i) -> Vector2i:
	var x = 127
	var y = 127
	if direction.x < 0:
		x = 0
	elif direction.x > 0:
		x = LocalMapStateScript.WIDTH - 1
	if direction.y < 0:
		y = 0
	elif direction.y > 0:
		y = LocalMapStateScript.HEIGHT - 1
	return Vector2i(x, y)

func _river_neighbors(cell: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in _directions8():
		var next = cell + direction
		if next.x >= 0 and next.x < width and next.y >= 0 and next.y < height:
			result.append(next)
	return result

func _pop_lowest_cost(open: Array[Vector2i], cost_so_far: Dictionary, goal: Vector2i) -> Vector2i:
	var best_index = 0
	var best_score = INF
	for index in range(open.size()):
		var cell = open[index]
		var score: float = float(cost_so_far[_cell_key(cell)]) + Vector2(cell - goal).length() * 0.35
		if score < best_score:
			best_score = score
			best_index = index
	var best: Vector2i = open[best_index]
	open.remove_at(best_index)
	return best

func _river_step_cost(state, current: Vector2i, next: Vector2i, goal: Vector2i) -> float:
	var current_height = state.heights[state.index(current.x, current.y)]
	var next_height = state.heights[state.index(next.x, next.y)]
	var uphill = max(0, next_height - current_height)
	var diagonal = 1.4 if current.x != next.x and current.y != next.y else 1.0
	var goal_bias = Vector2(next - goal).length() * 0.03
	return diagonal + float(uphill) * 0.08 + max(0.0, float(next_height - SEA_LEVEL)) * 0.01 + goal_bias

func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var goal_key = _cell_key(goal)
	if not came_from.has(goal_key):
		return _straight_path(start, goal)

	var path: Array[Vector2i] = []
	var current = goal
	while current != Vector2i(-1, -1):
		path.push_front(current)
		if current == start:
			break
		current = came_from[_cell_key(current)]
	return path

func _straight_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var steps: int = int(max(abs(goal.x - start.x), abs(goal.y - start.y)))
	for step in range(steps + 1):
		var t = float(step) / max(1.0, float(steps))
		path.append(Vector2i(int(round(lerpf(start.x, goal.x, t))), int(round(lerpf(start.y, goal.y, t)))))
	return path

func _carve_river_at(state, center_x: int, center_y: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x = center_x + dx
			var y = center_y + dy
			if not state.is_valid_cell(x, y):
				continue
			var distance = Vector2(dx, dy).length()
			if distance > 2.2:
				continue
			var index = state.index(x, y)
			state.river_flags[index] = 1
			if x == 0 or y == 0 or x == state.width - 1 or y == state.height - 1:
				continue
			var target = -8 if distance <= 1.1 else -2
			state.heights[index] = min(state.heights[index], target)

func _derive_flags_and_slopes(state) -> void:
	var total = 0
	for y in range(state.height):
		for x in range(state.width):
			var index = state.index(x, y)
			var height = state.heights[index]
			state.water_flags[index] = 1 if height < SEA_LEVEL else 0
			state.slope_values[index] = _slope_at(state, x, y)
			total += height
	state.average_height = int(round(float(total) / float(state.width * state.height)))

func _slope_at(state, x: int, y: int) -> int:
	var center = state.heights[state.index(x, y)]
	var max_delta = 0
	for direction in _directions8():
		var nx = x + direction.x
		var ny = y + direction.y
		if not state.is_valid_cell(nx, ny):
			continue
		max_delta = max(max_delta, abs(center - state.heights[state.index(nx, ny)]))
	return max_delta

func _tile_elevation_to_height(elevation: float) -> int:
	if elevation < -1.0 or elevation > 1.0:
		return clampi(int(round(elevation)), MIN_HEIGHT, MAX_HEIGHT)
	return clampi(int(round(lerpf(float(MIN_HEIGHT), float(MAX_HEIGHT), elevation))), MIN_HEIGHT, MAX_HEIGHT)

func _centered_smooth_noise(global_x: int, global_y: int, salt: int, radius: int) -> float:
	var total = 0.0
	var weight = 0.0
	var stride: int = maxi(1, int(radius / 4))
	for dy in range(-radius, radius + 1, stride):
		for dx in range(-radius, radius + 1, stride):
			var distance = Vector2(dx, dy).length() + 1.0
			var sample_weight = 1.0 / distance
			total += _value_noise(global_x + dx, global_y + dy, salt) * sample_weight
			weight += sample_weight
	return total / weight - 0.5

func _value_noise(global_x: int, global_y: int, salt: int) -> float:
	var n = int(world_seed) ^ int(global_x * 374761393) ^ int(global_y * 668265263) ^ int(salt * 1442695041)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _axis_sign(value: float) -> int:
	if value < -0.1:
		return -1
	if value > 0.1:
		return 1
	return 0

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
