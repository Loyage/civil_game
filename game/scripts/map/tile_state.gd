class_name TileState
extends RefCounted

var tile_key: String
var offset
var terrain_id: String
var elevation: float
var rainfall: float
var temperature: float
var ruggedness: float
var moisture: float
var has_river: bool
var river_flow: Vector2i
var river_strength: float
var river_path_points: PackedVector2Array
var ridge_path_points: PackedVector2Array
var features: PackedStringArray
var owner_city_id: String
var is_city_center: bool

func _init(
	init_key: String = "",
	init_offset = null,
	init_terrain_id: String = "plains"
) -> void:
	tile_key = init_key
	offset = init_offset
	terrain_id = init_terrain_id
	elevation = 0.0
	rainfall = 0.0
	temperature = 0.0
	ruggedness = 0.0
	moisture = 0.0
	has_river = false
	river_flow = Vector2i.ZERO
	river_strength = 0.0
	river_path_points = PackedVector2Array()
	ridge_path_points = PackedVector2Array()
	features = PackedStringArray()
	owner_city_id = ""
	is_city_center = false

func is_water() -> bool:
	return terrain_id == "ocean"

func is_mountain() -> bool:
	return features.has("mountain")

func is_lake() -> bool:
	return features.has("lake")

func is_hill() -> bool:
	return features.has("hill")

func is_swamp() -> bool:
	return features.has("swamp")

func is_desert() -> bool:
	return terrain_id == "desert"

func has_feature(feature_id: String) -> bool:
	return features.has(feature_id)

func add_feature(feature_id: String) -> void:
	if not features.has(feature_id):
		features.append(feature_id)
