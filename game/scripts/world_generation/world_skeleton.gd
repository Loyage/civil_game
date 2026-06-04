class_name WorldSkeleton
extends RefCounted

var seed: int
var big_map_size: int
var sub_map_size: int
var sea_level: int
var continent_bias: float
var mountain_ridges: Array
var rivers: Array
var mountains_by_tile: Dictionary
var rivers_by_tile: Dictionary

func _init() -> void:
	seed = 0
	big_map_size = 40
	sub_map_size = 256
	sea_level = 0
	continent_bias = 0.26
	mountain_ridges = []
	rivers = []
	mountains_by_tile = {}
	rivers_by_tile = {}

func tile_key(tile_x: int, tile_y: int) -> String:
	return "%d:%d" % [tile_x, tile_y]

func add_mountain_to_tile(tile_x: int, tile_y: int, ridge_id: int) -> void:
	var key := tile_key(tile_x, tile_y)
	if not mountains_by_tile.has(key):
		mountains_by_tile[key] = []
	if not mountains_by_tile[key].has(ridge_id):
		mountains_by_tile[key].append(ridge_id)

func add_river_to_tile(tile_x: int, tile_y: int, river_id: int) -> void:
	var key := tile_key(tile_x, tile_y)
	if not rivers_by_tile.has(key):
		rivers_by_tile[key] = []
	if not rivers_by_tile[key].has(river_id):
		rivers_by_tile[key].append(river_id)
