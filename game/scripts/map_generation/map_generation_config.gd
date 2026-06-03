class_name MapGenerationConfig
extends RefCounted

var version: int
var width: int
var height: int
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
	height = 20
	seed = 260603
	generated_output_path = "user://generated_map.json"
	start_city_col = 0
	start_city_row = 0
	start_city_name = "Capital"
	terrain_thresholds = {
		"ocean_elevation": 0.32,
		"mountain_ruggedness": 0.34,
		"hill_ruggedness": 0.16,
		"lake_elevation": 0.38,
		"desert_rainfall": 0.24,
		"swamp_rainfall": 0.74
	}
	generation_params = {
		"continent_bias": 0.26,
		"river_count": 5,
		"river_max_steps": 80
	}

func load_from_dictionary(data: Dictionary) -> void:
	version = int(data.get("version", version))
	width = int(data.get("width", width))
	height = int(data.get("height", height))
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
