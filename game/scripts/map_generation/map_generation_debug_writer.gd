class_name MapGenerationDebugWriter
extends RefCounted

func write_generated_map(config, map_state) -> void:
	var file := FileAccess.open(config.generated_output_path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write generated map: %s" % config.generated_output_path)
		return

	var tiles: Array = []
	for tile in map_state.tiles_by_key.values():
		tiles.append({
			"col": tile.offset.col,
			"row": tile.offset.row,
			"biome": tile.biome,
			"elevation": tile.elevation,
			"avg_height": tile.avg_height,
			"min_height": tile.min_height,
			"max_height": tile.max_height,
			"temperature": tile.temperature,
			"moisture": tile.moisture,
			"has_river": tile.has_river,
			"river_flow": [tile.river_flow.x, tile.river_flow.y],
			"river_strength": tile.river_strength,
			"river_path_points": _serialize_vector2_array(tile.river_path_points),
			"ridge_path_points": _serialize_vector2_array(tile.ridge_path_points),
			"terrain_tags": Array(tile.terrain_tags),
			"resource_ids": Array(tile.resource_ids)
		})

	file.store_string(JSON.stringify({
		"version": config.version,
		"seed": config.seed,
		"width": map_state.width,
		"height": map_state.height,
		"tiles": tiles
	}, "\t"))

func _serialize_vector2_array(points: PackedVector2Array) -> Array:
	var serialized: Array = []
	for point in points:
		serialized.append([point.x, point.y])
	return serialized
