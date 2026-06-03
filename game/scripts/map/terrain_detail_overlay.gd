class_name TerrainDetailOverlay
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
	if map_state == null or terrain_layer == null or _is_far_view():
		return

	for tile in map_state.tiles_by_key.values():
		if tile.is_lake():
			_draw_lake(tile)
		if tile.is_mountain():
			_draw_mountain_ridge(tile)
		elif tile.is_hill():
			_draw_hill_contours(tile)
		if tile.has_feature("forest"):
			_draw_forest_texture(tile)
		if tile.is_swamp():
			_draw_swamp_texture(tile)

func _draw_lake(tile) -> void:
	var center := _tile_center(tile)
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	var points := PackedVector2Array([
		center + Vector2(-0.30, -0.12) * half_size,
		center + Vector2(-0.12, -0.34) * half_size,
		center + Vector2(0.22, -0.30) * half_size,
		center + Vector2(0.40, -0.04) * half_size,
		center + Vector2(0.24, 0.28) * half_size,
		center + Vector2(-0.20, 0.32) * half_size,
		center + Vector2(-0.42, 0.08) * half_size
	])
	draw_colored_polygon(points, Color("#3b82c4cc"))
	draw_polyline(points, Color("#8ec6ec"), 2.0, true)

func _draw_mountain_ridge(tile) -> void:
	if tile.ridge_path_points.size() < 2:
		return
	var points := _tile_points_to_local(tile, tile.ridge_path_points)
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], Color("#45484a"), 6.0, true)
		draw_line(points[index] + Vector2(-2.0, -2.0), points[index + 1] + Vector2(-2.0, -2.0), Color("#b9b4a4"), 2.0, true)

func _draw_hill_contours(tile) -> void:
	var center := _tile_center(tile)
	draw_arc(center + Vector2(-10.0, 10.0), 18.0, PI * 1.08, TAU * 0.96, 14, Color("#746a44aa"), 2.5)
	draw_arc(center + Vector2(12.0, 6.0), 13.0, PI * 1.05, TAU * 0.92, 12, Color("#8a7d4c88"), 2.0)

func _draw_forest_texture(tile) -> void:
	var center := _tile_center(tile)
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	for index in range(8):
		var offset := _stable_offset(tile, index, 31) * half_size * 0.78
		var radius := 5.0 + _stable_value(tile, index, 32) * 5.0
		draw_circle(center + offset, radius, Color("#265f34a8"))

func _draw_swamp_texture(tile) -> void:
	var center := _tile_center(tile)
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	for index in range(5):
		var offset := _stable_offset(tile, index, 41) * half_size * 0.72
		var radius := 7.0 + _stable_value(tile, index, 42) * 6.0
		draw_circle(center + offset, radius, Color("#2d827b78"))

func _tile_points_to_local(tile, normalized_points: PackedVector2Array) -> PackedVector2Array:
	var center := _tile_center(tile)
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	var points := PackedVector2Array()
	for normalized in normalized_points:
		points.append(center + Vector2(
			(normalized.x - 0.5) * half_size.x * 2.0,
			(normalized.y - 0.5) * half_size.y * 2.0
		))
	return points

func _tile_center(tile) -> Vector2:
	return terrain_layer.map_to_local(tile.offset.to_vector())

func _is_far_view() -> bool:
	return map_camera != null and map_camera.zoom.x < DETAIL_ZOOM_THRESHOLD

func _stable_offset(tile, index: int, salt: int) -> Vector2:
	return Vector2(
		_stable_value(tile, index, salt) - 0.5,
		_stable_value(tile, index, salt + 17) - 0.5
	)

func _stable_value(tile, index: int, salt: int) -> float:
	var n := int(tile.offset.col * 374761393) ^ int(tile.offset.row * 668265263) ^ int(index * 1442695041) ^ int(salt * 1274126177)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
