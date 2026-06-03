class_name MapOverlay
extends Node2D

const HexLayoutScript := preload("res://game/scripts/map/hex_layout.gd")

var map_state
var terrain_layer: TileMapLayer
var selected_tile_key: String = ""
var city_tile_key: String = ""
var mode: String = "selection"

func setup(init_map_state, init_terrain_layer: TileMapLayer, init_mode: String) -> void:
	map_state = init_map_state
	terrain_layer = init_terrain_layer
	mode = init_mode
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
		"rivers":
			_draw_rivers()
		"selection":
			_draw_selection()
		"city":
			_draw_city()
		"border":
			_draw_border()

func _draw_rivers() -> void:
	for tile in map_state.tiles_by_key.values():
		for edge in tile.river_edges:
			var points := HexLayoutScript.edge_vertices(edge, 43.0)
			if points.size() != 2:
				continue
			var center := _tile_center(tile)
			draw_line(center + points[0], center + points[1], Color("#3677c8"), 5.0)

func _draw_selection() -> void:
	var tile = map_state.get_tile(selected_tile_key)
	if tile == null:
		return
	_draw_hex_outline(_tile_center(tile), 44.0, Color("#fff0a6"), 3.0)

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
			_draw_hex_outline(_tile_center(tile), 45.0, Color("#f2d16b88"), 2.0)

func _draw_hex_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	for i in range(6):
		draw_line(points[i], points[(i + 1) % 6], color, width)

func _tile_center(tile) -> Vector2:
	return terrain_layer.map_to_local(tile.offset.to_vector())
