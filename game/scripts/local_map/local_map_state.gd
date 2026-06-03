class_name LocalMapState
extends RefCounted

const WIDTH := 256
const HEIGHT := 256
const CELL_COUNT := WIDTH * HEIGHT
const TILE_GLOBAL_STEP := 255

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
	version = 1
	world_seed = 0
	tile_key = ""
	tile_col = 0
	tile_row = 0
	width = WIDTH
	height = HEIGHT
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
	return tile_col * TILE_GLOBAL_STEP + x

func global_cell_y(y: int) -> int:
	return tile_row * TILE_GLOBAL_STEP + y
