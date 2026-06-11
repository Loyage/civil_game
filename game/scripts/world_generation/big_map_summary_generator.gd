class_name BigMapSummaryGenerator
extends RefCounted

const OffsetCoordScript := preload("res://game/scripts/map/offset_coord.gd")
const GridLayoutScript := preload("res://game/scripts/map/grid_layout.gd")
const MapStateScript := preload("res://game/scripts/map/map_state.gd")
const TileStateScript := preload("res://game/scripts/map/tile_state.gd")
const WorldFunctionSamplerScript := preload("res://game/scripts/world_generation/world_function_sampler.gd")
const PipelineResultScript := preload("res://game/scripts/map_generation/map_generation_pipeline_result.gd")

func generate(config, skeleton, stage_id: String = PipelineResultScript.STAGE_FINAL):
	var map_state = MapStateScript.new(config.big_map_size, config.big_map_size)
	map_state.world_seed = config.seed
	map_state.start_city_name = config.start_city_name
	var sampler = WorldFunctionSamplerScript.new(skeleton)
	for row in range(config.big_map_size):
		for col in range(config.big_map_size):
			var tile = _generate_tile_summary(config, skeleton, sampler, col, row, stage_id)
			tile.is_city_center = col == config.start_city_col and row == config.start_city_row
			if tile.is_city_center:
				tile.owner_city_id = "player_capital"
				map_state.start_city_tile_key = tile.tile_key
			map_state.add_tile(tile)
	return map_state

func generate_async(owner: Node, config, skeleton, stage_id: String, progress_callback: Callable, cancel_callback: Callable):
	var map_state = MapStateScript.new(config.big_map_size, config.big_map_size)
	map_state.world_seed = config.seed
	map_state.start_city_name = config.start_city_name
	var sampler = WorldFunctionSamplerScript.new(skeleton)
	for row in range(config.big_map_size):
		if cancel_callback.is_valid() and bool(cancel_callback.call()):
			return null
		for col in range(config.big_map_size):
			var tile = _generate_tile_summary(config, skeleton, sampler, col, row, stage_id)
			tile.is_city_center = col == config.start_city_col and row == config.start_city_row
			if tile.is_city_center:
				tile.owner_city_id = "player_capital"
				map_state.start_city_tile_key = tile.tile_key
			map_state.add_tile(tile)
		if progress_callback.is_valid():
			progress_callback.call(row + 1, config.big_map_size)
		await owner.get_tree().process_frame
	return map_state

func _generate_tile_summary(config, skeleton, sampler, col: int, row: int, stage_id: String):
	var offset = OffsetCoordScript.new(col, row)
	var tile = TileStateScript.new(GridLayoutScript.tile_key(col, row), offset)
	var heights: Array[int] = []
	var biome_counts := {}
	var temp_total := 0.0
	var moisture_total := 0.0
	var river_total := 0.0
	var resolution: int = int(config.summary_sample_resolution)
	for sy in range(resolution):
		for sx in range(resolution):
			var local_x := int(floor((float(sx) + 0.5) * float(config.sub_map_size) / float(resolution)))
			var local_y := int(floor((float(sy) + 0.5) * float(config.sub_map_size) / float(resolution)))
			var world_x: int = col * int(config.sub_map_size) + local_x
			var world_y: int = row * int(config.sub_map_size) + local_y
			var height: int = _sample_stage_height(sampler, world_x, world_y, stage_id)
			var biome: String = _sample_stage_biome(skeleton, sampler, world_x, world_y, stage_id)
			heights.append(height)
			biome_counts[biome] = int(biome_counts.get(biome, 0)) + 1
			temp_total += sampler.sample_temperature(world_x, world_y)
			moisture_total += sampler.sample_moisture(world_x, world_y)
			river_total += sampler.sample_river_strength(world_x, world_y)

	var total: int = max(1, heights.size())
	tile.min_height = _min_int(heights)
	tile.max_height = _max_int(heights)
	tile.avg_height = int(round(_sum_ints(heights) / float(total)))
	tile.elevation = tile.avg_height
	tile.temperature = temp_total / float(total)
	tile.moisture = moisture_total / float(total)
	tile.river_strength = river_total / float(total)
	tile.has_river = _stage_includes_rivers(stage_id) and skeleton.rivers_by_tile.has(tile.tile_key)
	tile.biome = _dominant_biome(biome_counts)
	tile.terrain_tags = _terrain_tags(tile)
	if _stage_includes_mountains(stage_id):
		_apply_mountain_summary(skeleton, tile)
	if _stage_includes_rivers(stage_id):
		_apply_river_summary(skeleton, tile)
	if _stage_includes_rivers(stage_id):
		_apply_lake_summary(skeleton, tile)
	return tile

func _sample_stage_height(sampler, world_x: int, world_y: int, stage_id: String) -> int:
	match stage_id:
		PipelineResultScript.STAGE_BASE:
			return sampler.sample_base_height(world_x, world_y)
		PipelineResultScript.STAGE_MOUNTAINS:
			return sampler.sample_height_after_mountains(world_x, world_y)
		_:
			return sampler.sample_final_height(world_x, world_y)

func _sample_stage_biome(skeleton, sampler, world_x: int, world_y: int, stage_id: String) -> String:
	match stage_id:
		PipelineResultScript.STAGE_BASE:
			return "plain"
		PipelineResultScript.STAGE_MOUNTAINS:
			return _terrain_biome_from_height(sampler.sample_height_after_mountains(world_x, world_y), skeleton.sea_level, false)
		PipelineResultScript.STAGE_OCEAN:
			return _terrain_biome_from_height(sampler.sample_final_height(world_x, world_y), skeleton.sea_level, true)
		PipelineResultScript.STAGE_RIVERS:
			if sampler.sample_river_strength(world_x, world_y) > 0.08:
				return "river"
			return _terrain_biome_from_height(sampler.sample_final_height(world_x, world_y), skeleton.sea_level, true)
		PipelineResultScript.STAGE_ENVIRONMENT:
			return sampler.sample_biome(world_x, world_y)
		_:
			return sampler.sample_biome(world_x, world_y)

func _terrain_biome_from_height(height: int, sea_level: int, include_ocean: bool) -> String:
	if include_ocean and height < sea_level:
		return "ocean"
	if height > 210:
		return "snow_mountain"
	if height > 150:
		return "mountain"
	if height > 86:
		return "hill"
	return "plain"

func _apply_river_summary(skeleton, tile) -> void:
	var ids: Array = skeleton.rivers_by_tile.get(tile.tile_key, [])
	if ids.is_empty():
		return
	var river: Dictionary = skeleton.rivers[int(ids[0])]
	tile.has_river = true
	tile.river_flow = _polyline_direction_for_tile(river["points"], tile.offset.col, tile.offset.row, skeleton.sub_map_size)
	tile.river_path_points = _normalized_polyline_points(river["points"], tile.offset.col, tile.offset.row, skeleton.sub_map_size)
	if not tile.terrain_tags.has("river"):
		tile.terrain_tags.append("river")

func _apply_mountain_summary(skeleton, tile) -> void:
	var ids: Array = skeleton.mountains_by_tile.get(tile.tile_key, [])
	if ids.is_empty():
		return
	var ridge: Dictionary = skeleton.mountain_ridges[int(ids[0])]
	tile.ridge_path_points = _normalized_polyline_points(ridge["points"], tile.offset.col, tile.offset.row, skeleton.sub_map_size)
	if not tile.terrain_tags.has("mountain"):
		tile.terrain_tags.append("mountain")

func _apply_lake_summary(skeleton, tile) -> void:
	if not skeleton.lakes_by_tile.has(tile.tile_key):
		return
	if not tile.terrain_tags.has("lake"):
		tile.terrain_tags.append("lake")
	if not tile.terrain_tags.has("water"):
		tile.terrain_tags.append("water")

func _stage_includes_mountains(stage_id: String) -> bool:
	return stage_id in [
		PipelineResultScript.STAGE_MOUNTAINS,
		PipelineResultScript.STAGE_OCEAN,
		PipelineResultScript.STAGE_RIVERS,
		PipelineResultScript.STAGE_ENVIRONMENT,
		PipelineResultScript.STAGE_FINAL
	]

func _stage_includes_rivers(stage_id: String) -> bool:
	return stage_id in [
		PipelineResultScript.STAGE_RIVERS,
		PipelineResultScript.STAGE_ENVIRONMENT,
		PipelineResultScript.STAGE_FINAL
	]

func _normalized_polyline_points(points: Array, tile_x: int, tile_y: int, sub_map_size: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var origin := Vector2(float(tile_x * sub_map_size), float(tile_y * sub_map_size))
	for point in points:
		var normalized: Vector2 = (point - origin) / float(sub_map_size)
		if normalized.x >= -0.2 and normalized.y >= -0.2 and normalized.x <= 1.2 and normalized.y <= 1.2:
			result.append(Vector2(clampf(normalized.x, 0.0, 1.0), clampf(normalized.y, 0.0, 1.0)))
	if result.size() < 2:
		result.append(Vector2(0.5, 0.5))
		result.append(Vector2(0.5, 0.5))
	return result

func _polyline_direction(points: Array) -> Vector2i:
	if points.size() < 2:
		return Vector2i.ZERO
	var delta: Vector2 = points[points.size() - 1] - points[0]
	return Vector2i(_axis_sign(delta.x), _axis_sign(delta.y))

func _polyline_direction_for_tile(points: Array, tile_x: int, tile_y: int, sub_map_size: int) -> Vector2i:
	if points.size() < 2:
		return Vector2i.ZERO
	var tile_rect: Rect2 = Rect2(
		Vector2(float(tile_x * sub_map_size), float(tile_y * sub_map_size)),
		Vector2(float(sub_map_size), float(sub_map_size))
	)
	var tile_center: Vector2 = tile_rect.get_center()
	var best_delta: Vector2 = Vector2.ZERO
	var best_distance: float = INF
	for index in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		if not _segment_bounds(a, b).grow(float(sub_map_size) * 0.12).intersects(tile_rect):
			continue
		var midpoint: Vector2 = (a + b) * 0.5
		var distance: float = midpoint.distance_squared_to(tile_center)
		if distance < best_distance:
			best_distance = distance
			best_delta = b - a
	if best_delta == Vector2.ZERO:
		return _polyline_direction(points)
	return Vector2i(_axis_sign(best_delta.x), _axis_sign(best_delta.y))

func _segment_bounds(a: Vector2, b: Vector2) -> Rect2:
	var min_point: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var max_point: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(min_point, max_point - min_point)

func _dominant_biome(biome_counts: Dictionary) -> String:
	var best := "plain"
	var best_count := -1
	for biome in biome_counts.keys():
		var count := int(biome_counts[biome])
		if count > best_count:
			best = String(biome)
			best_count = count
	return best

func _terrain_tags(tile) -> PackedStringArray:
	var tags := PackedStringArray()
	match tile.biome:
		"ocean":
			tags.append("water")
		"river":
			tags.append("river")
		"snow_mountain", "mountain":
			tags.append("mountain")
		"hill":
			tags.append("hill")
		"forest", "rainforest":
			tags.append("forest")
		"desert":
			tags.append("desert")
		"tundra":
			tags.append("tundra")
		_:
			pass
	return tags

func _sum_ints(values: Array[int]) -> float:
	var result := 0.0
	for value in values:
		result += float(value)
	return result

func _min_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var result: int = values[0]
	for value in values:
		result = mini(result, value)
	return result

func _max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var result: int = values[0]
	for value in values:
		result = maxi(result, value)
	return result

func _axis_sign(value: float) -> int:
	if value < -0.1:
		return -1
	if value > 0.1:
		return 1
	return 0
