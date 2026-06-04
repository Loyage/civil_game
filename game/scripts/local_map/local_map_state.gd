class_name LocalMapState
extends RefCounted

const DEFAULT_SIZE := 256

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
var slope_values: PackedInt32Array
var average_height: int

func _init() -> void:
	version = 2
	world_seed = 0
	tile_key = ""
	tile_col = 0
	tile_row = 0
	width = DEFAULT_SIZE
	height = DEFAULT_SIZE
	heights = PackedInt32Array()
	water_flags = PackedByteArray()
	river_flags = PackedByteArray()
	slope_values = PackedInt32Array()
	average_height = 0

func resize_arrays() -> void:
	var count = width * height
	heights.resize(count)
	water_flags.resize(count)
	river_flags.resize(count)
	slope_values.resize(count)

func index(x: int, y: int) -> int:
	return y * width + x

func is_valid_cell(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func global_cell_x(x: int) -> int:
	return tile_col * max(1, width - 1) + x

func global_cell_y(y: int) -> int:
	return tile_row * max(1, height - 1) + y
