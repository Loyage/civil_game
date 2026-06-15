class_name TileState
extends RefCounted

var tile_key: String
var offset
var biome: String
var elevation: int
var avg_height: int
var min_height: int
var max_height: int
var temperature: float
var moisture: float
var has_river: bool
var river_flow: Vector2i
var river_strength: float
var river_path_points: PackedVector2Array
var ridge_path_points: PackedVector2Array
var terrain_tags: PackedStringArray
var resource_ids: PackedStringArray
var owner_city_id: String
var is_city_center: bool

func _init(
	init_key: String = "",
	init_offset = null,
	init_biome: String = "plain"
) -> void:
	tile_key = init_key
	offset = init_offset
	biome = init_biome
	elevation = 0
	avg_height = 0
	min_height = 0
	max_height = 0
	temperature = 0.0
	moisture = 0.0
	has_river = false
	river_flow = Vector2i.ZERO
	river_strength = 0.0
	river_path_points = PackedVector2Array()
	ridge_path_points = PackedVector2Array()
	terrain_tags = PackedStringArray()
	resource_ids = PackedStringArray()
	owner_city_id = ""
	is_city_center = false

func is_water() -> bool:
	return biome == "ocean" or terrain_tags.has("water")

func is_mountain() -> bool:
	return biome in ["mountain", "snow_mountain"] or terrain_tags.has("mountain")

func is_lake() -> bool:
	return terrain_tags.has("lake")

func is_hill() -> bool:
	return biome == "hill" or terrain_tags.has("hill")

func is_swamp() -> bool:
	return terrain_tags.has("swamp")

func is_desert() -> bool:
	return biome == "desert"

func has_feature(tag_id: String) -> bool:
	return terrain_tags.has(tag_id)

func add_feature(tag_id: String) -> void:
	if not terrain_tags.has(tag_id):
		terrain_tags.append(tag_id)

func has_resource(resource_id: String) -> bool:
	return resource_ids.has(resource_id)
