class_name MapQueryService
extends RefCounted

const DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1)
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
		var neighbor_col: int = tile.offset.col + direction.x
		var neighbor_row: int = tile.offset.row + direction.y
		if map_state.contains_offset(neighbor_col, neighbor_row):
			var neighbor = map_state.get_tile_by_offset(neighbor_col, neighbor_row)
			if neighbor != null:
				result.append(neighbor)

	return result

func get_distance(a_key: String, b_key: String) -> int:
	var a = map_state.get_tile(a_key)
	var b = map_state.get_tile(b_key)
	if a == null or b == null:
		return -1

	return max(abs(a.offset.col - b.offset.col), abs(a.offset.row - b.offset.row))

func get_tiles_in_radius(center_key: String, radius: int) -> Array:
	var center = map_state.get_tile(center_key)
	var result: Array = []
	if center == null:
		return result

	for row in range(center.offset.row - radius, center.offset.row + radius + 1):
		for col in range(center.offset.col - radius, center.offset.col + radius + 1):
			if max(abs(col - center.offset.col), abs(row - center.offset.row)) > radius:
				continue
			if map_state.contains_offset(col, row):
				var tile = map_state.get_tile_by_offset(col, row)
				if tile != null:
					result.append(tile)

	return result

func get_movement_cost(a_key: String, b_key: String) -> int:
	var a = map_state.get_tile(a_key)
	var b = map_state.get_tile(b_key)
	if a == null or b == null:
		return -1
	if get_distance(a_key, b_key) != 1:
		return -1
	if a.is_water() or b.is_water() or a.is_lake() or b.is_lake():
		return -1
	if a.is_mountain() or b.is_mountain():
		return 12

	var cost := 10
	if abs(a.offset.col - b.offset.col) == 1 and abs(a.offset.row - b.offset.row) == 1:
		cost += 4
	if a.is_hill() or b.is_hill():
		cost += 3
	if a.has_feature("forest") or b.has_feature("forest"):
		cost += 2
	if a.is_swamp() or b.is_swamp():
		cost += 4
	if a.has_river or b.has_river:
		cost += 1
	return cost
