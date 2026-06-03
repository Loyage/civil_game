class_name TileState
extends RefCounted

var tile_key: String
var coord
var offset
var terrain_id: String
var has_forest: bool
var has_hill: bool
var river_edges: PackedStringArray
var owner_city_id: String
var is_city_center: bool

func _init(
	init_key: String = "",
	init_coord = null,
	init_offset = null,
	init_terrain_id: String = "ocean"
) -> void:
	tile_key = init_key
	coord = init_coord
	offset = init_offset
	terrain_id = init_terrain_id
	has_forest = false
	has_hill = false
	river_edges = PackedStringArray()
	owner_city_id = ""
	is_city_center = false

func is_water() -> bool:
	return terrain_id == "ocean"

func is_mountain() -> bool:
	return terrain_id == "mountain"

func has_river() -> bool:
	return river_edges.size() > 0
