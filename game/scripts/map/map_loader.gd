class_name MapLoader
extends RefCounted

const MAP_PATH := "res://game/data/maps/start_map.json"
const OffsetCoordScript := preload("res://game/scripts/map/offset_coord.gd")
const HexLayoutScript := preload("res://game/scripts/map/hex_layout.gd")
const MapStateScript := preload("res://game/scripts/map/map_state.gd")
const TileStateScript := preload("res://game/scripts/map/tile_state.gd")

func load_start_map():
	var data := _read_json(MAP_PATH)
	return _build_map_state(data)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open map file: %s" % path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Cannot parse map JSON: %s" % json.get_error_message())
		return {}

	return json.data

func _build_map_state(data: Dictionary):
	var width := int(data.get("width", 40))
	var height := int(data.get("height", 20))
	var map_state = MapStateScript.new(width, height)
	var start_city: Dictionary = data.get("start_city", {})
	var start_col := int(start_city.get("col", 0))
	var start_row := int(start_city.get("row", 0))
	map_state.start_city_name = String(start_city.get("name", "Capital"))

	var lake_lookup := _build_point_lookup(data.get("lakes", []))
	var mountain_lookup := _build_mountain_lookup(data.get("mountain_paths", []))
	var feature_lookup := _build_feature_lookup(data.get("feature_patches", []), width, height)
	var river_lookup := _build_river_lookup(data.get("river_edges", []))

	for row in range(height):
		for col in range(width):
			var offset = OffsetCoordScript.new(col, row)
			var axial = HexLayoutScript.offset_to_axial(offset)
			var tile = TileStateScript.new(axial.key(), axial, offset, _terrain_for(data, col, row))

			var point_key := _point_key(col, row)
			if mountain_lookup.has(point_key):
				tile.terrain_id = "mountain"
			if lake_lookup.has(point_key):
				tile.terrain_id = "ocean"

			var features: Dictionary = feature_lookup.get(point_key, {})
			tile.has_forest = bool(features.get("forest", false)) and tile.terrain_id != "ocean" and tile.terrain_id != "mountain"
			tile.has_hill = bool(features.get("hill", false)) and tile.terrain_id != "ocean" and tile.terrain_id != "mountain"
			tile.river_edges = river_lookup.get(point_key, PackedStringArray())
			tile.is_city_center = col == start_col and row == start_row

			if tile.is_city_center:
				tile.owner_city_id = "player_capital"
				map_state.start_city_tile_key = tile.tile_key

			map_state.add_tile(tile)

	return map_state

func _terrain_for(data: Dictionary, col: int, row: int) -> String:
	var continent: Dictionary = data.get("continent", {})
	var center_col := float(continent.get("center_col", 20))
	var center_row := float(continent.get("center_row", 10))
	var radius_col := float(continent.get("radius_col", 19))
	var radius_row := float(continent.get("radius_row", 9))
	var dx := (float(col) - center_col) / radius_col
	var dy := (float(row) - center_row) / radius_row

	if dx * dx + dy * dy > 1.0:
		return String(data.get("default_terrain", "ocean"))

	var mix_value := (col * 17 + row * 31) % 10
	return "grassland" if mix_value < 5 else "plains"

func _build_point_lookup(points: Array) -> Dictionary:
	var lookup := {}
	for point in points:
		lookup[_point_key(int(point.get("col", 0)), int(point.get("row", 0)))] = true
	return lookup

func _build_mountain_lookup(paths: Array) -> Dictionary:
	var lookup := {}
	for path in paths:
		var points: Array = path.get("points", [])
		for index in range(points.size() - 1):
			var start: Array = points[index]
			var end: Array = points[index + 1]
			for point in _line_points(Vector2i(start[0], start[1]), Vector2i(end[0], end[1])):
				lookup[_point_key(point.x, point.y)] = true
	return lookup

func _line_points(start: Vector2i, end: Vector2i) -> Array:
	var points: Array = []
	var delta: Vector2i = end - start
	var steps: int = max(abs(delta.x), abs(delta.y))
	if steps == 0:
		return [start]

	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		points.append(Vector2i(roundi(lerpf(start.x, end.x, t)), roundi(lerpf(start.y, end.y, t))))

	return points

func _build_feature_lookup(patches: Array, width: int, height: int) -> Dictionary:
	var lookup := {}
	for patch in patches:
		var feature := String(patch.get("feature", ""))
		var center_col := int(patch.get("center_col", 0))
		var center_row := int(patch.get("center_row", 0))
		var radius := int(patch.get("radius", 1))
		for row in range(center_row - radius, center_row + radius + 1):
			for col in range(center_col - radius, center_col + radius + 1):
				if col < 0 or col >= width or row < 0 or row >= height:
					continue
				var distance: int = abs(col - center_col) + abs(row - center_row)
				if distance <= radius:
					var key := _point_key(col, row)
					if not lookup.has(key):
						lookup[key] = {}
					lookup[key][feature] = true
	return lookup

func _build_river_lookup(entries: Array) -> Dictionary:
	var lookup := {}
	for entry in entries:
		var key := _point_key(int(entry.get("col", 0)), int(entry.get("row", 0)))
		var edges := PackedStringArray()
		for edge in entry.get("edges", []):
			edges.append(String(edge))
		lookup[key] = edges
	return lookup

func _point_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]
