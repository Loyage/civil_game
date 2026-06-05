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
	tile.has_river = stage_id in [PipelineResultScript.STAGE_RIVERS, PipelineResultScript.STAGE_FINAL] and (tile.river_strength > 0.08 or skeleton.rivers_by_tile.has(tile.tile_key))
	tile.biome = _dominant_biome(biome_counts)
	tile.terrain_tags = _terrain_tags(tile)
	if stage_id in [PipelineResultScript.STAGE_MOUNTAINS, PipelineResultScript.STAGE_FINAL]:
		_apply_mountain_summary(skeleton, tile)
	if stage_id in [PipelineResultScript.STAGE_RIVERS, PipelineResultScript.STAGE_FINAL]:
		_apply_river_summary(skeleton, tile)
	return tile

func _sample_stage_height(sampler, world_x: int, world_y: int, stage_id: String) -> int:
	match stage_id:
		PipelineResultScript.STAGE_BASE:
			return sampler.sample_base_height(world_x, world_y)
		PipelineResultScript.STAGE_OCEAN:
			return sampler.sample_ocean_height(world_x, world_y)
		PipelineResultScript.STAGE_MOUNTAINS:
			return sampler.sample_mountain_delta(world_x, world_y)
		PipelineResultScript.STAGE_RIVERS:
			return 0
		_:
			return sampler.sample_final_height(world_x, world_y)

func _sample_stage_biome(skeleton, sampler, world_x: int, world_y: int, stage_id: String) -> String:
	match stage_id:
		PipelineResultScript.STAGE_BASE:
			return "plain"
		PipelineResultScript.STAGE_OCEAN:
			return "ocean" if sampler.sample_base_height(world_x, world_y) < skeleton.sea_level else "plain"
		PipelineResultScript.STAGE_MOUNTAINS:
			return "mountain" if sampler.sample_mountain_influence(world_x, world_y) > 0.12 else "plain"
		PipelineResultScript.STAGE_RIVERS:
			return "river" if sampler.sample_river_strength(world_x, world_y) > 0.08 else "plain"
		PipelineResultScript.STAGE_ENVIRONMENT:
			return "forest" if sampler.sample_moisture(world_x, world_y) > 0.55 else "plain"
		_:
			return sampler.sample_biome(world_x, world_y)

func _apply_river_summary(skeleton, tile) -> void:
	var ids: Array = skeleton.rivers_by_tile.get(tile.tile_key, [])
	if ids.is_empty():
		return
	var river: Dictionary = skeleton.rivers[int(ids[0])]
	tile.has_river = true
	tile.river_flow = _polyline_direction(river["points"])
	tile.river_path_points = _normalized_polyline_points(river["points"], tile.offset.col, tile.offset.row, skeleton.sub_map_size)

func _apply_mountain_summary(skeleton, tile) -> void:
	var ids: Array = skeleton.mountains_by_tile.get(tile.tile_key, [])
	if ids.is_empty():
		return
	var ridge: Dictionary = skeleton.mountain_ridges[int(ids[0])]
	tile.ridge_path_points = _normalized_polyline_points(ridge["points"], tile.offset.col, tile.offset.row, skeleton.sub_map_size)
	if not tile.terrain_tags.has("mountain"):
		tile.terrain_tags.append("mountain")

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
