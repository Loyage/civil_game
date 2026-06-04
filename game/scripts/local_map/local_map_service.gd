class_name LocalMapService
extends RefCounted

const CACHE_VERSION := 2
const CACHE_MAGIC := "CLM1"
const CACHE_ROOT := "user://local_maps"
const MAP_CONFIG_PATH := "res://game/data/maps/map_generation_config.json"

const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const LocalMapStateScript := preload("res://game/scripts/local_map/local_map_state.gd")
const LocalMapGeneratorScript := preload("res://game/scripts/local_map/local_map_generator.gd")

var world_seed: int

func _init(init_world_seed: int = 0) -> void:
	world_seed = init_world_seed

func load_or_generate(tile):
	var cached = _load_cache(tile)
	if cached != null:
		return cached

	var generator = LocalMapGeneratorScript.new(world_seed, _load_generation_config())
	var state = generator.generate(tile)
	_write_cache(state)
	return state

func _cache_path(tile) -> String:
	return "%s/%d/v%d/%s.bin" % [CACHE_ROOT, world_seed, CACHE_VERSION, tile.tile_key]

func _load_cache(tile):
	var path = _cache_path(tile)
	if not FileAccess.file_exists(path):
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot read local map cache: %s" % path)
		return null

	if file.get_buffer(4).get_string_from_ascii() != CACHE_MAGIC:
		return null
	var version = file.get_32()
	if version != CACHE_VERSION:
		return null

	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return null

	var state = LocalMapStateScript.new()
	state.version = version
	state.world_seed = int(data.get("world_seed", 0))
	state.tile_key = String(data.get("tile_key", ""))
	state.tile_col = int(data.get("tile_col", 0))
	state.tile_row = int(data.get("tile_row", 0))
	state.width = int(data.get("width", 0))
	state.height = int(data.get("height", 0))
	state.average_height = int(data.get("average_height", 0))

	if state.world_seed != world_seed or state.tile_key != tile.tile_key or state.width != LocalMapStateScript.WIDTH or state.height != LocalMapStateScript.HEIGHT:
		return null

	state.heights = data.get("heights", PackedInt32Array())
	state.water_flags = data.get("water_flags", PackedByteArray())
	state.river_flags = data.get("river_flags", PackedByteArray())
	state.slope_values = data.get("slope_values", PackedInt32Array())
	if state.heights.size() != state.width * state.height or state.water_flags.size() != state.heights.size() or state.river_flags.size() != state.heights.size() or state.slope_values.size() != state.heights.size():
		return null

	return state

func _write_cache(state) -> void:
	var path = "%s/%d/v%d" % [CACHE_ROOT, state.world_seed, CACHE_VERSION]
	var error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("Cannot create local map cache directory: %s" % path)
		return

	var file = FileAccess.open(_cache_path_from_state(state), FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write local map cache: %s" % _cache_path_from_state(state))
		return

	file.store_buffer(CACHE_MAGIC.to_ascii_buffer())
	file.store_32(CACHE_VERSION)
	file.store_var({
		"world_seed": state.world_seed,
		"tile_key": state.tile_key,
		"tile_col": state.tile_col,
		"tile_row": state.tile_row,
		"width": state.width,
		"height": state.height,
		"average_height": state.average_height,
		"heights": state.heights,
		"water_flags": state.water_flags,
		"river_flags": state.river_flags,
		"slope_values": state.slope_values
	})

func _cache_path_from_state(state) -> String:
	return "%s/%d/v%d/%s.bin" % [CACHE_ROOT, state.world_seed, CACHE_VERSION, state.tile_key]

func _load_generation_config():
	var config = MapGenerationConfigScript.new()
	var file := FileAccess.open(MAP_CONFIG_PATH, FileAccess.READ)
	if file == null:
		config.seed = world_seed
		return config

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		config.seed = world_seed
		return config

	config.load_from_dictionary(json.data)
	config.seed = world_seed
	return config
