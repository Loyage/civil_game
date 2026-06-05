class_name MapGenerationConfig
extends RefCounted

var version: int
var width: int
var height: int
var big_map_size: int
var sub_map_size: int
var sea_level: int
var ocean_ratio: float
var mountain_count: int
var river_source_count: int
var summary_sample_resolution: int
var seed: int
var generated_output_path: String
var start_city_col: int
var start_city_row: int
var start_city_name: String
var terrain_thresholds: Dictionary
var generation_params: Dictionary

func _init() -> void:
	version = 1
	width = 40
	height = 40
	big_map_size = 40
	sub_map_size = 256
	sea_level = 0
	ocean_ratio = 0.30
	mountain_count = 6
	river_source_count = 8
	summary_sample_resolution = 4
	seed = 260603
	generated_output_path = "user://generated_map.json"
	start_city_col = 0
	start_city_row = 0
	start_city_name = "Capital"
	terrain_thresholds = {
		"ocean_elevation": 0,
		"mountain_height": 150,
		"hill_height": 86,
		"lake_elevation": 0,
		"desert_moisture": 0.22,
		"swamp_moisture": 0.75
	}
	generation_params = {
		"continent_bias": 0.26
	}

func load_from_dictionary(data: Dictionary) -> void:
	version = int(data.get("version", version))
	width = int(data.get("width", width))
	height = int(data.get("height", height))
	big_map_size = int(data.get("big_map_size", data.get("bigMapSize", max(width, height))))
	width = big_map_size
	height = big_map_size
	sub_map_size = int(data.get("sub_map_size", data.get("subMapSize", sub_map_size)))
	sea_level = int(data.get("sea_level", data.get("seaLevel", sea_level)))
	ocean_ratio = float(data.get("ocean_ratio", data.get("oceanRatio", ocean_ratio)))
	mountain_count = int(data.get("mountain_count", data.get("mountainCount", mountain_count)))
	river_source_count = int(data.get("river_source_count", data.get("riverSourceCount", river_source_count)))
	summary_sample_resolution = int(data.get("summary_sample_resolution", data.get("summarySampleResolution", summary_sample_resolution)))
	seed = int(data.get("seed", seed))
	generated_output_path = String(data.get("generated_output_path", generated_output_path))

	var start_city: Dictionary = data.get("start_city", {})
	start_city_col = int(start_city.get("col", start_city_col))
	start_city_row = int(start_city.get("row", start_city_row))
	start_city_name = String(start_city.get("name", start_city_name))

	terrain_thresholds.merge(data.get("terrain_thresholds", {}), true)
	generation_params.merge(data.get("generation", {}), true)

func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"width": width,
		"height": height,
		"big_map_size": big_map_size,
		"sub_map_size": sub_map_size,
		"sea_level": sea_level,
		"ocean_ratio": ocean_ratio,
		"mountain_count": mountain_count,
		"river_source_count": river_source_count,
		"summary_sample_resolution": summary_sample_resolution,
		"seed": seed,
		"generated_output_path": generated_output_path,
		"start_city": {
			"col": start_city_col,
			"row": start_city_row,
			"name": start_city_name
		},
		"terrain_thresholds": terrain_thresholds.duplicate(true),
		"generation": generation_params.duplicate(true)
	}

func get_threshold(key: String, default_value: float) -> float:
	return float(terrain_thresholds.get(key, default_value))

func get_generation_param(key: String, default_value: float) -> float:
	return float(generation_params.get(key, default_value))
