class_name RiverOverlay
extends Node2D

const GridLayoutScript := preload("res://game/scripts/map/grid_layout.gd")

const DETAIL_ZOOM_THRESHOLD := 0.85

var map_state
var terrain_layer: TileMapLayer
var map_camera: Camera2D

func setup(init_map_state, init_terrain_layer: TileMapLayer, init_map_camera: Camera2D = null) -> void:
	map_state = init_map_state
	terrain_layer = init_terrain_layer
	map_camera = init_map_camera
	queue_redraw()

func _draw() -> void:
	if map_state == null or terrain_layer == null:
		return

	for tile in map_state.tiles_by_key.values():
		if not tile.has_river or tile.river_path_points.size() < 2:
			continue
		if _is_far_view() and tile.river_strength < 0.42:
			continue
		_draw_river_path(tile)

func _draw_river_path(tile) -> void:
	var points := _tile_points_to_local(tile, tile.river_path_points)
	var width: float = 3.0 + tile.river_strength * 5.5
	if _is_far_view():
		width = 2.5 + tile.river_strength * 3.0

	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], Color("#245f9f"), width + 2.0, true)
		draw_line(points[index], points[index + 1], Color("#3f91dd"), width, true)

func _tile_points_to_local(tile, normalized_points: PackedVector2Array) -> PackedVector2Array:
	var center := terrain_layer.map_to_local(tile.offset.to_vector())
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	var points := PackedVector2Array()
	for normalized in normalized_points:
		points.append(center + Vector2(
			(normalized.x - 0.5) * half_size.x * 2.0,
			(normalized.y - 0.5) * half_size.y * 2.0
		))
	return points

func _is_far_view() -> bool:
	return map_camera != null and map_camera.zoom.x < DETAIL_ZOOM_THRESHOLD
