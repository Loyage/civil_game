class_name MapState
extends RefCounted

var width: int
var height: int
var tiles_by_key: Dictionary
var keys_by_offset: Dictionary
var start_city_tile_key: String
var start_city_name: String

func _init(init_width: int = 0, init_height: int = 0) -> void:
	width = init_width
	height = init_height
	tiles_by_key = {}
	keys_by_offset = {}
	start_city_tile_key = ""
	start_city_name = ""

func add_tile(tile) -> void:
	tiles_by_key[tile.tile_key] = tile
	keys_by_offset[_offset_key(tile.offset.col, tile.offset.row)] = tile.tile_key

func get_tile(tile_key: String):
	return tiles_by_key.get(tile_key)

func get_tile_by_offset(col: int, row: int):
	var tile_key: String = keys_by_offset.get(_offset_key(col, row), "")
	if tile_key == "":
		return null
	return get_tile(tile_key)

func contains_offset(col: int, row: int) -> bool:
	return col >= 0 and col < width and row >= 0 and row < height

func _offset_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]
