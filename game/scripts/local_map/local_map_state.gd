class_name LocalMapState
extends RefCounted

const LocalCellStateScript := preload("res://game/scripts/local_map/local_cell_state.gd")

const DEFAULT_SIZE := 64
const TERRAIN_GRASS := 1
const TERRAIN_FOREST := 2
const TERRAIN_WETLAND := 4
const TERRAIN_ROCK := 8
const TERRAIN_SAND := 16
const TERRAIN_SNOW := 32

var version: int
var world_seed: int
var tile_key: String
var tile_col: int
var tile_row: int
var width: int
var height: int
var heights: PackedInt32Array
var water_flags: PackedByteArray
var river_flags: PackedByteArray
var terrain_flags: PackedInt32Array
var slope_values: PackedInt32Array
var river_carve_points: Array
var average_height: int

func _init() -> void:
	version = 8
	world_seed = 0
	tile_key = ""
	tile_col = 0
	tile_row = 0
	width = DEFAULT_SIZE
	height = DEFAULT_SIZE
	heights = PackedInt32Array()
	water_flags = PackedByteArray()
	river_flags = PackedByteArray()
	terrain_flags = PackedInt32Array()
	slope_values = PackedInt32Array()
	river_carve_points = []
	average_height = 0

func resize_arrays() -> void:
	var count: int = width * height
	heights.resize(count)
	water_flags.resize(count)
	river_flags.resize(count)
	terrain_flags.resize(count)
	slope_values.resize(count)

func index(x: int, y: int) -> int:
	return y * width + x

func is_valid_cell(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func global_cell_x(x: int) -> int:
	return tile_col * max(1, width) + x

func global_cell_y(y: int) -> int:
	return tile_row * max(1, height) + y

func cell_state_at(x: int, y: int):
	var result = LocalCellStateScript.new()
	if not is_valid_cell(x, y):
		return result
	var cell_index: int = index(x, y)
	result.x = x
	result.y = y
	result.global_x = global_cell_x(x)
	result.global_y = global_cell_y(y)
	result.height = heights[cell_index]
	result.slope = slope_values[cell_index] if cell_index < slope_values.size() else 0
	result.is_water = cell_index < water_flags.size() and water_flags[cell_index] == 1
	result.has_river = cell_index < river_flags.size() and river_flags[cell_index] == 1
	result.terrain_flags = terrain_flags[cell_index] if cell_index < terrain_flags.size() else 0
	return result
