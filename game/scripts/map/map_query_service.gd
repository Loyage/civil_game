class_name MapQueryService
extends RefCounted

const HexCoordScript := preload("res://game/scripts/map/hex_coord.gd")
const HexLayoutScript := preload("res://game/scripts/map/hex_layout.gd")

const DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1)
]

var map_state

func _init(init_map_state = null) -> void:
	map_state = init_map_state

func get_tile(tile_key: String):
	return map_state.get_tile(tile_key)

func get_neighbors(tile_key: String) -> Array:
	var tile = map_state.get_tile(tile_key)
	var result: Array = []
	if tile == null:
		return result

	for direction in DIRECTIONS:
		var neighbor_coord = HexCoordScript.new(tile.coord.q + direction.x, tile.coord.r + direction.y)
		var neighbor_offset = HexLayoutScript.axial_to_offset(neighbor_coord)
		if map_state.contains_offset(neighbor_offset.col, neighbor_offset.row):
			var neighbor = map_state.get_tile_by_offset(neighbor_offset.col, neighbor_offset.row)
			if neighbor != null:
				result.append(neighbor)

	return result

func get_distance(a_key: String, b_key: String) -> int:
	var a = map_state.get_tile(a_key)
	var b = map_state.get_tile(b_key)
	if a == null or b == null:
		return -1

	var aq: int = a.coord.q
	var ar: int = a.coord.r
	var as_: int = -aq - ar
	var bq: int = b.coord.q
	var br: int = b.coord.r
	var bs: int = -bq - br
	return int((abs(aq - bq) + abs(ar - br) + abs(as_ - bs)) / 2)

func get_tiles_in_radius(center_key: String, radius: int) -> Array:
	var center = map_state.get_tile(center_key)
	var result: Array = []
	if center == null:
		return result

	for dq in range(-radius, radius + 1):
		for dr in range(max(-radius, -dq - radius), min(radius, -dq + radius) + 1):
			var coord = HexCoordScript.new(center.coord.q + dq, center.coord.r + dr)
			var offset = HexLayoutScript.axial_to_offset(coord)
			if map_state.contains_offset(offset.col, offset.row):
				var tile = map_state.get_tile_by_offset(offset.col, offset.row)
				if tile != null:
					result.append(tile)

	return result
