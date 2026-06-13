class_name LocalMapGenerator
extends RefCounted

const LocalMapStateScript := preload("res://game/scripts/local_map/local_map_state.gd")
const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")
const WorldSkeletonGeneratorScript := preload("res://game/scripts/world_generation/world_skeleton_generator.gd")
const WorldFunctionSamplerScript := preload("res://game/scripts/world_generation/world_function_sampler.gd")

const SEA_LEVEL := 0
const MIN_HEIGHT := -256
const MAX_HEIGHT := 256
const RIVER_START_WIDTH := 3.0
const RIVER_MAX_WIDTH := 12.0
const RIVER_DISTANCE_WIDTH_GROWTH := 0.42
const RIVER_STRENGTH_WIDTH_GROWTH := 0.24
const RIVER_MIN_DEPTH := 10.0
const RIVER_MAX_DEPTH := 42.0

var world_seed: int
var config
var skeleton
var sampler
var local_map_size: int

func _init(init_world_seed: int = 0, init_config = null) -> void:
	world_seed = init_world_seed
	config = _build_config(init_config)
	local_map_size = max(2, int(config.sub_map_size))
	skeleton = WorldSkeletonGeneratorScript.new().generate(config)
	sampler = WorldFunctionSamplerScript.new(skeleton)

func generate(tile):
	_prepare_sampler_for_tile(tile)
	var state = LocalMapStateScript.new()
	state.world_seed = world_seed
	state.tile_key = tile.tile_key
	state.tile_col = tile.offset.col
	state.tile_row = tile.offset.row
	state.width = local_map_size
	state.height = local_map_size
	state.resize_arrays()

	_generate_heights(state, tile)
	_apply_river(state, tile)
	_derive_flags_and_slopes(state)
	_derive_terrain_flags(state, tile)
	return state

func _generate_heights(state, tile) -> void:
	var total := 0
	for y in range(state.height):
		for x in range(state.width):
			var global_x: int = state.global_cell_x(x)
			var global_y: int = state.global_cell_y(y)
			var height: int = _sample_height(global_x, global_y)
			var index: int = state.index(x, y)
			state.heights[index] = height
			total += height
	state.average_height = int(round(float(total) / float(state.width * state.height)))

func _sample_height(global_x: int, global_y: int) -> int:
	return clampi(sampler.sample_height(global_x, global_y), MIN_HEIGHT, MAX_HEIGHT)

func _prepare_sampler_for_tile(tile) -> void:
	var local_skeleton = WorldSkeletonScript.new()
	local_skeleton.seed = skeleton.seed
	local_skeleton.big_map_size = skeleton.big_map_size
	local_skeleton.sub_map_size = skeleton.sub_map_size
	local_skeleton.sea_level = skeleton.sea_level
	local_skeleton.continent_bias = skeleton.continent_bias
	local_skeleton.ocean_tiles = skeleton.ocean_tiles
	local_skeleton.ocean_distance_by_tile = skeleton.ocean_distance_by_tile
	local_skeleton.mountain_ridges = _filter_structures_for_tile(tile, skeleton.mountain_ridges)
	local_skeleton.rivers = _filter_structures_for_tile(tile, skeleton.rivers)
	sampler = WorldFunctionSamplerScript.new(local_skeleton)

func _filter_structures_for_tile(tile, structures: Array) -> Array:
	var result: Array = []
	var tile_rect: Rect2 = _tile_world_rect(tile)
	for structure in structures:
		var influence_width: float = float(structure.get("width", 0.0))
		if _polyline_intersects_rect(structure["points"], tile_rect, influence_width + 4.0):
			result.append(structure)
	return result

func _polyline_intersects_rect(points: Array, rect: Rect2, padding: float) -> bool:
	if points.is_empty():
		return false
	for index in range(points.size() - 1):
		if _segment_bounds(points[index], points[index + 1]).grow(padding).intersects(rect):
			return true
	return false

func _segment_bounds(a: Vector2, b: Vector2) -> Rect2:
	var min_point := Vector2(min(a.x, b.x), min(a.y, b.y))
	var max_point := Vector2(max(a.x, b.x), max(a.y, b.y))
	return Rect2(min_point, max_point - min_point)

func _apply_river(state, tile) -> void:
	if not tile.has_river:
		return

	var river: Dictionary = _river_for_tile(tile)
	var path: Array[Vector2i] = _find_refined_river_path(state, tile)
	if path.is_empty():
		return

	for index in range(path.size()):
		var point: Vector2i = path[index]
		var width: float = _river_width_at(tile, state, point, index, path.size(), river)
		var depth: float = _river_depth_at(width, index, path.size())
		_record_river_carve(state, point, width, depth)
		_carve_river_at(state, point.x, point.y, width, depth)

func _find_refined_river_path(state, tile) -> Array[Vector2i]:
	var controls := _river_control_cells(tile)
	if controls.size() < 2:
		return controls

	var result: Array[Vector2i] = []
	for index in range(controls.size() - 1):
		var segment := _find_river_path_segment(state, controls[index], controls[index + 1])
		for segment_index in range(segment.size()):
			if not result.is_empty() and segment_index == 0 and result[result.size() - 1] == segment[segment_index]:
				continue
			result.append(segment[segment_index])
	return result

func _river_control_cells(tile) -> Array[Vector2i]:
	var global_controls: Array[Vector2i] = _river_control_cells_from_global_path(tile)
	if global_controls.size() >= 2:
		return global_controls

	var result: Array[Vector2i] = []
	_append_unique_cell(result, _river_start_cell(tile))
	for point in tile.river_path_points:
		_append_unique_cell(result, _normalized_to_cell(point))
	_append_unique_cell(result, _river_goal_cell(tile))
	return result

func _river_control_cells_from_global_path(tile) -> Array[Vector2i]:
	var river: Dictionary = _river_for_tile(tile)
	if river.is_empty():
		return _empty_vector2i_array()
	var points: Array = river.get("points", [])
	if points.size() < 2:
		return _empty_vector2i_array()

	var result: Array[Vector2i] = []
	var tile_rect: Rect2 = _tile_world_rect(tile)
	for index in range(points.size() - 1):
		var clipped: Array[Vector2] = _clip_segment_to_rect(points[index], points[index + 1], tile_rect)
		if clipped.is_empty():
			continue
		_append_unique_cell(result, _world_point_to_cell(tile, clipped[0]))
		_append_unique_cell(result, _world_point_to_cell(tile, clipped[1]))
	return result

func _river_for_tile(tile) -> Dictionary:
	var ids: Array = skeleton.rivers_by_tile.get(tile.tile_key, [])
	if ids.is_empty():
		return {}
	var river_id: int = int(ids[0])
	if river_id < 0 or river_id >= skeleton.rivers.size():
		return {}
	return skeleton.rivers[river_id]

func _tile_world_rect(tile) -> Rect2:
	return Rect2(
		Vector2(float(tile.offset.col * config.sub_map_size), float(tile.offset.row * config.sub_map_size)),
		Vector2(float(config.sub_map_size), float(config.sub_map_size))
	)

func _world_point_to_cell(tile, point: Vector2) -> Vector2i:
	var origin: Vector2 = Vector2(float(tile.offset.col * config.sub_map_size), float(tile.offset.row * config.sub_map_size))
	var normalized: Vector2 = (point - origin) / float(config.sub_map_size)
	return _normalized_to_cell(Vector2(clampf(normalized.x, 0.0, 1.0), clampf(normalized.y, 0.0, 1.0)))

func _clip_segment_to_rect(a: Vector2, b: Vector2, rect: Rect2) -> Array[Vector2]:
	var t0: float = 0.0
	var t1: float = 1.0
	var delta: Vector2 = b - a
	var clip: Array[float] = _clip_axis(-delta.x, a.x - rect.position.x, t0, t1)
	if clip.is_empty():
		return _empty_vector2_array()
	t0 = float(clip[0])
	t1 = float(clip[1])
	clip = _clip_axis(delta.x, rect.position.x + rect.size.x - a.x, t0, t1)
	if clip.is_empty():
		return _empty_vector2_array()
	t0 = float(clip[0])
	t1 = float(clip[1])
	clip = _clip_axis(-delta.y, a.y - rect.position.y, t0, t1)
	if clip.is_empty():
		return _empty_vector2_array()
	t0 = float(clip[0])
	t1 = float(clip[1])
	clip = _clip_axis(delta.y, rect.position.y + rect.size.y - a.y, t0, t1)
	if clip.is_empty():
		return _empty_vector2_array()
	t0 = float(clip[0])
	t1 = float(clip[1])
	var result: Array[Vector2] = []
	result.append(a + delta * t0)
	result.append(a + delta * t1)
	return result

func _clip_axis(p: float, q: float, t0: float, t1: float) -> Array[float]:
	if is_zero_approx(p):
		if q >= 0.0:
			return _float_pair(t0, t1)
		return _empty_float_array()
	var r: float = q / p
	if p < 0.0:
		if r > t1:
			return _empty_float_array()
		t0 = maxf(t0, r)
	else:
		if r < t0:
			return _empty_float_array()
		t1 = minf(t1, r)
	return _float_pair(t0, t1)

func _float_pair(a: float, b: float) -> Array[float]:
	var result: Array[float] = []
	result.append(a)
	result.append(b)
	return result

func _empty_float_array() -> Array[float]:
	var result: Array[float] = []
	return result

func _empty_vector2_array() -> Array[Vector2]:
	var result: Array[Vector2] = []
	return result

func _empty_vector2i_array() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	return result

func _single_vector2i_array(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(cell)
	return result

func _append_unique_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	if cells.is_empty() or cells[cells.size() - 1] != cell:
		cells.append(cell)

func _find_river_path_segment(state, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return _single_vector2i_array(start)

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
		clampi(int(round(point.x * float(local_map_size - 1))), 0, local_map_size - 1),
		clampi(int(round(point.y * float(local_map_size - 1))), 0, local_map_size - 1)
	)

func _edge_cell(direction: Vector2i) -> Vector2i:
	var x: int = int(local_map_size / 2)
	var y: int = int(local_map_size / 2)
	if direction.x < 0:
		x = 0
	elif direction.x > 0:
		x = local_map_size - 1
	if direction.y < 0:
		y = 0
	elif direction.y > 0:
		y = local_map_size - 1
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
	var downhill = max(0, current_height - next_height)
	var diagonal = 1.4 if current.x != next.x and current.y != next.y else 1.0
	var goal_bias = Vector2(next - goal).length() * 0.03
	var cut_cost: float = float(uphill) * 0.018
	var highland_cost: float = maxf(0.0, float(next_height - SEA_LEVEL)) * 0.004
	var mountain_cost: float = maxf(0.0, float(next_height - 150)) * 0.05
	var downhill_bonus: float = minf(0.45, float(downhill) * 0.004)
	return maxf(0.1, diagonal + cut_cost + highland_cost + mountain_cost + goal_bias - downhill_bonus)

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

func _river_width_at(tile, state, point: Vector2i, index: int, path_size: int, river: Dictionary) -> float:
	if not river.is_empty():
		return _river_width_at_world_point(state, point, river)
	return _local_river_width_at(tile, index, path_size)

func _local_river_width_at(tile, index: int, path_size: int) -> float:
	var distance_growth: float = float(index) / maxf(1.0, float(path_size - 1))
	var strength_growth: float = clampf(float(tile.river_strength) * 1.0, 0.0, RIVER_STRENGTH_WIDTH_GROWTH)
	return lerpf(RIVER_START_WIDTH, RIVER_MAX_WIDTH, clampf(distance_growth * RIVER_DISTANCE_WIDTH_GROWTH + strength_growth, 0.0, 1.0))

func _river_width_at_world_point(state, cell: Vector2i, river: Dictionary) -> float:
	var points: Array = river.get("points", [])
	var width_profile: Array = river.get("width_profile", [])
	var fallback_width: float = float(river.get("width", RIVER_START_WIDTH))
	if points.size() < 2:
		return fallback_width

	var world_point: Vector2 = Vector2(float(state.global_cell_x(cell.x)), float(state.global_cell_y(cell.y)))
	var best_distance_sq: float = INF
	var best_width: float = fallback_width
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var t: float = _segment_projection_t(world_point, start, end)
		var closest: Vector2 = start.lerp(end, t)
		var distance_sq: float = closest.distance_squared_to(world_point)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			var start_width: float = _river_profile_width(width_profile, index, fallback_width)
			var end_width: float = _river_profile_width(width_profile, index + 1, start_width)
			best_width = lerpf(start_width, end_width, t)
	return clampf(best_width, RIVER_START_WIDTH, RIVER_MAX_WIDTH)

func _river_profile_width(width_profile: Array, index: int, fallback_width: float) -> float:
	if index >= 0 and index < width_profile.size():
		return float(width_profile[index])
	return fallback_width

func _segment_projection_t(point: Vector2, start: Vector2, end: Vector2) -> float:
	var delta: Vector2 = end - start
	var length_sq: float = delta.length_squared()
	if is_zero_approx(length_sq):
		return 0.0
	return clampf((point - start).dot(delta) / length_sq, 0.0, 1.0)

func _river_depth_at(width: float, index: int, path_size: int) -> float:
	var distance_growth: float = float(index) / maxf(1.0, float(path_size - 1))
	var width_growth: float = clampf((width - RIVER_START_WIDTH) / maxf(1.0, RIVER_MAX_WIDTH - RIVER_START_WIDTH), 0.0, 1.0)
	return lerpf(RIVER_MIN_DEPTH, RIVER_MAX_DEPTH, clampf(distance_growth * 0.45 + width_growth * 0.55, 0.0, 1.0))

func _record_river_carve(state, cell: Vector2i, width: float, depth: float) -> void:
	state.river_carve_points.append({
		"cell_x": cell.x,
		"cell_y": cell.y,
		"global_x": state.global_cell_x(cell.x),
		"global_y": state.global_cell_y(cell.y),
		"width": width,
		"depth": depth
	})

func _carve_river_at(state, center_x: int, center_y: int, width: float, depth: float) -> void:
	var radius: float = maxf(1.0, width * 0.5)
	var limit: int = int(ceil(radius)) + 1
	for dy in range(-limit, limit + 1):
		for dx in range(-limit, limit + 1):
			var x = center_x + dx
			var y = center_y + dy
			if not state.is_valid_cell(x, y):
				continue
			var distance: float = Vector2(dx, dy).length()
			if distance > radius:
				continue
			var index = state.index(x, y)
			state.river_flags[index] = 1
			var falloff: float = 1.0 - clampf(distance / radius, 0.0, 1.0)
			var cut_amount: int = int(round(depth * falloff))
			var water_target: int = SEA_LEVEL - maxi(2, int(round(depth * 0.35 * falloff)))
			var target: int = mini(state.heights[index] - cut_amount, water_target)
			state.heights[index] = min(state.heights[index], target)

func _derive_flags_and_slopes(state) -> void:
	var total = 0
	var is_ocean_tile: bool = skeleton.ocean_tiles.has(state.tile_key)
	for y in range(state.height):
		for x in range(state.width):
			var index = state.index(x, y)
			var height = state.heights[index]
			state.water_flags[index] = 1 if is_ocean_tile and height < skeleton.sea_level else 0
			state.slope_values[index] = _slope_at(state, x, y)
			total += height
	state.average_height = int(round(float(total) / float(state.width * state.height)))

func _derive_terrain_flags(state, tile) -> void:
	var initial_flags: PackedInt32Array = PackedInt32Array()
	initial_flags.resize(state.width * state.height)
	for y in range(state.height):
		for x in range(state.width):
			var index: int = state.index(x, y)
			initial_flags[index] = _initial_terrain_flags(state, tile, x, y)

	for y in range(state.height):
		for x in range(state.width):
			var index: int = state.index(x, y)
			if state.water_flags[index] == 1:
				state.terrain_flags[index] = 0
				continue
			var flags: int = initial_flags[index]
			flags = _smooth_terrain_flag(initial_flags, state, x, y, flags, LocalMapStateScript.TERRAIN_FOREST)
			flags = _smooth_terrain_flag(initial_flags, state, x, y, flags, LocalMapStateScript.TERRAIN_WETLAND)
			flags = _smooth_terrain_flag(initial_flags, state, x, y, flags, LocalMapStateScript.TERRAIN_ROCK)
			flags = _smooth_terrain_flag(initial_flags, state, x, y, flags, LocalMapStateScript.TERRAIN_SAND)
			flags = _smooth_terrain_flag(initial_flags, state, x, y, flags, LocalMapStateScript.TERRAIN_SNOW)
			if (flags & (LocalMapStateScript.TERRAIN_SAND | LocalMapStateScript.TERRAIN_ROCK | LocalMapStateScript.TERRAIN_SNOW)) == 0:
				flags |= LocalMapStateScript.TERRAIN_GRASS
			state.terrain_flags[index] = flags

func _initial_terrain_flags(state, tile, x: int, y: int) -> int:
	var index: int = state.index(x, y)
	if state.water_flags[index] == 1:
		return 0

	var global_x: int = state.global_cell_x(x)
	var global_y: int = state.global_cell_y(y)
	var height: int = state.heights[index]
	var slope: int = state.slope_values[index]
	var moisture: float = sampler.sample_moisture(global_x, global_y)
	var temperature: float = sampler.sample_temperature(global_x, global_y)
	var mountain: float = sampler.sample_mountain_influence(global_x, global_y)
	var block_noise: float = _terrain_noise(801, global_x, global_y, 8)
	var flags: int = 0

	var biome: String = String(tile.biome)
	var forest_bias: float = 0.18 if biome in ["forest", "rainforest"] else 0.0
	if moisture + forest_bias > 0.62 and height >= skeleton.sea_level + 4 and height < 150 and block_noise > 0.28:
		flags |= LocalMapStateScript.TERRAIN_FOREST

	if _near_water_or_river(state, x, y, 3) and height < skeleton.sea_level + 36 and moisture > 0.42:
		flags |= LocalMapStateScript.TERRAIN_WETLAND

	if slope >= 42 or height >= 152 or mountain > 0.42:
		flags |= LocalMapStateScript.TERRAIN_ROCK

	if moisture < 0.26 and temperature > 0.56 and height >= skeleton.sea_level + 4:
		flags |= LocalMapStateScript.TERRAIN_SAND

	if height >= 210 or (temperature < 0.18 and height >= 96):
		flags |= LocalMapStateScript.TERRAIN_SNOW

	return flags

func _smooth_terrain_flag(initial_flags: PackedInt32Array, state, x: int, y: int, flags: int, flag: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx: int = x + dx
			var ny: int = y + dy
			if not state.is_valid_cell(nx, ny):
				continue
			if (initial_flags[state.index(nx, ny)] & flag) != 0:
				count += 1
	if count >= 4:
		return flags | flag
	if count <= 1:
		return flags & ~flag
	return flags

func _near_water_or_river(state, x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if Vector2(dx, dy).length() > float(radius):
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if not state.is_valid_cell(nx, ny):
				continue
			var index: int = state.index(nx, ny)
			if state.water_flags[index] == 1 or state.river_flags[index] == 1:
				return true
	return false

func _terrain_noise(salt: int, global_x: int, global_y: int, scale: int) -> float:
	return _hash01(salt, int(floor(float(global_x) / float(scale))), int(floor(float(global_y) / float(scale))))

func _hash01(salt: int, x: int, y: int) -> float:
	var n: int = int(world_seed) ^ int(salt * 1442695041) ^ int(x * 374761393) ^ int(y * 668265263)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0

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

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _build_config(init_config):
	var result = MapGenerationConfigScript.new()
	if init_config != null:
		result.load_from_dictionary(init_config.to_dictionary())
	result.seed = world_seed
	result.sub_map_size = max(2, int(result.sub_map_size))
	return result

func _axis_sign(value: float) -> int:
	if value < -0.1:
		return -1
	if value > 0.1:
		return 1
	return 0

func _directions8() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(Vector2i(1, 0))
	result.append(Vector2i(1, -1))
	result.append(Vector2i(0, -1))
	result.append(Vector2i(-1, -1))
	result.append(Vector2i(-1, 0))
	result.append(Vector2i(-1, 1))
	result.append(Vector2i(0, 1))
	result.append(Vector2i(1, 1))
	return result
