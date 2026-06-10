class_name WorldSkeletonTileIndexer
extends RefCounted

func build(skeleton) -> void:
	for ridge in skeleton.mountain_ridges:
		_index_polyline(skeleton, ridge["points"], int(ridge["id"]), true)
	for river in skeleton.rivers:
		_index_river_path(skeleton, river["points"], int(river["id"]))

func _index_polyline(skeleton, points: Array, id: int, is_mountain: bool) -> void:
	for point in points:
		var tile_x := clampi(int(floor(point.x / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		var tile_y := clampi(int(floor(point.y / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := tile_x + dx
				var ny := tile_y + dy
				if nx < 0 or ny < 0 or nx >= skeleton.big_map_size or ny >= skeleton.big_map_size:
					continue
				if is_mountain:
					skeleton.add_mountain_to_tile(nx, ny, id)
				else:
					skeleton.add_river_to_tile(nx, ny, id)

func _index_river_path(skeleton, points: Array, id: int) -> void:
	for point in points:
		var tile_x := clampi(int(floor(point.x / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		var tile_y := clampi(int(floor(point.y / float(skeleton.sub_map_size))), 0, skeleton.big_map_size - 1)
		skeleton.add_river_to_tile(tile_x, tile_y, id)
