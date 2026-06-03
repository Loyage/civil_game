class_name MapLoader
extends RefCounted

const CONFIG_PATH := "res://game/data/maps/map_generation_config.json"
const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const MapGeneratorScript := preload("res://game/scripts/map_generation/map_generator.gd")
const MapGenerationDebugWriterScript := preload("res://game/scripts/map_generation/map_generation_debug_writer.gd")

func load_generated_map():
	var raw_config := _read_json(CONFIG_PATH)
	var config = MapGenerationConfigScript.new()
	config.load_from_dictionary(raw_config)
	var map_state = MapGeneratorScript.new().generate(config)
	MapGenerationDebugWriterScript.new().write_generated_map(config, map_state)
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
