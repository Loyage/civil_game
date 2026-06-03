class_name MapOverlay
extends Node2D

const GridLayoutScript := preload("res://game/scripts/map/grid_layout.gd")

var map_state
var terrain_layer: TileMapLayer
var selected_tile_key: String = ""
var city_tile_key: String = ""
var mode: String = "selection"
var show_debug_symbols: bool = false

func setup(init_map_state, init_terrain_layer: TileMapLayer, init_mode: String) -> void:
	map_state = init_map_state
	terrain_layer = init_terrain_layer
	mode = init_mode
	queue_redraw()

func set_debug_symbols_visible(is_visible: bool) -> void:
	show_debug_symbols = is_visible
	queue_redraw()

func set_selected_tile(tile_key: String) -> void:
	selected_tile_key = tile_key
	queue_redraw()

func set_city_tile(tile_key: String) -> void:
	city_tile_key = tile_key
	queue_redraw()

func _draw() -> void:
	if map_state == null or terrain_layer == null:
		return

	match mode:
		"features":
			if show_debug_symbols:
				_draw_debug_symbols()
		"rivers":
			if show_debug_symbols:
				_draw_debug_rivers()
		"selection":
			_draw_selection()
		"city":
			_draw_city()
		"border":
			_draw_border()

func _draw_debug_rivers() -> void:
	for tile in map_state.tiles_by_key.values():
		if tile.tile_key != selected_tile_key:
			continue
		if not tile.has_river:
			continue
		var center := _tile_center(tile)
		var flow := Vector2(tile.river_flow) * 32.0
		if flow == Vector2.ZERO:
			draw_circle(center, 8.0, Color("#3677c8"))
		else:
			draw_line(center - flow * 0.45, center + flow * 0.45, Color("#3677c8"), 5.0 + tile.river_strength * 3.0)

func _draw_debug_symbols() -> void:
	for tile in map_state.tiles_by_key.values():
		if tile.tile_key != selected_tile_key:
			continue
		var center := _tile_center(tile)
		if tile.is_lake():
			draw_circle(center, 22.0, Color("#3f87c688"))
		if tile.is_mountain():
			var points := PackedVector2Array([
				center + Vector2(0.0, -28.0),
				center + Vector2(24.0, 22.0),
				center + Vector2(-24.0, 22.0)
			])
			draw_colored_polygon(points, Color("#6f737488"))
		elif tile.is_hill():
			draw_arc(center, 20.0, PI, TAU, 16, Color("#776f4888"), 4.0)
		if tile.has_feature("forest"):
			draw_circle(center + Vector2(-16.0, -10.0), 5.0, Color("#2f6f3f88"))
			draw_circle(center + Vector2(0.0, -12.0), 5.0, Color("#2f6f3f88"))
			draw_circle(center + Vector2(14.0, -8.0), 5.0, Color("#2f6f3f88"))
		if tile.is_swamp():
			draw_line(center + Vector2(-22.0, 18.0), center + Vector2(22.0, 18.0), Color("#2e806688"), 4.0)

func _draw_selection() -> void:
	var tile = map_state.get_tile(selected_tile_key)
	if tile == null:
		return
	_draw_square_outline(_tile_center(tile), Color("#fff0a6"), 3.0)

func _draw_city() -> void:
	var tile = map_state.get_tile(city_tile_key)
	if tile == null:
		return
	var center := _tile_center(tile)
	draw_circle(center, 13.0, Color("#f2d16b"))
	draw_circle(center, 8.0, Color("#72511e"))

func _draw_border() -> void:
	for tile in map_state.tiles_by_key.values():
		if tile.owner_city_id != "":
			_draw_square_outline(_tile_center(tile), Color("#f2d16b88"), 2.0)

func _draw_square_outline(center: Vector2, color: Color, width: float) -> void:
	var half_size := Vector2(GridLayoutScript.TILE_PIXEL_SIZE) / 2.0
	var points := PackedVector2Array([
		center + Vector2(-half_size.x, -half_size.y),
		center + Vector2(half_size.x, -half_size.y),
		center + Vector2(half_size.x, half_size.y),
		center + Vector2(-half_size.x, half_size.y)
	])
	for i in range(4):
		draw_line(points[i], points[(i + 1) % 4], color, width)

func _tile_center(tile) -> Vector2:
	return terrain_layer.map_to_local(tile.offset.to_vector())
