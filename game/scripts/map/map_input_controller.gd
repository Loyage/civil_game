class_name MapInputController
extends RefCounted

var map_state
var terrain_layer: TileMapLayer

func _init(init_map_state = null, init_terrain_layer: TileMapLayer = null) -> void:
	map_state = init_map_state
	terrain_layer = init_terrain_layer

func tile_from_global_position(global_position: Vector2):
	if map_state == null or terrain_layer == null:
		return null

	var local_position := terrain_layer.to_local(global_position)
	var map_coord := terrain_layer.local_to_map(local_position)
	return map_state.get_tile_by_offset(map_coord.x, map_coord.y)
