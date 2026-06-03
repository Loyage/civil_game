class_name MapInputController
extends RefCounted

var map_state
var terrain_layer: TileMapLayer
var camera: Camera2D

func _init(init_map_state = null, init_terrain_layer: TileMapLayer = null, init_camera: Camera2D = null) -> void:
	map_state = init_map_state
	terrain_layer = init_terrain_layer
	camera = init_camera

func tile_from_screen_position(screen_position: Vector2):
	if map_state == null or terrain_layer == null or camera == null:
		return null

	var world_position: Vector2 = terrain_layer.get_canvas_transform().affine_inverse() * screen_position
	var local_position: Vector2 = terrain_layer.to_local(world_position)
	var map_coord: Vector2i = terrain_layer.local_to_map(local_position)
	return map_state.get_tile_by_offset(map_coord.x, map_coord.y)
