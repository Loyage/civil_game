class_name GridLayout
extends RefCounted

const TILE_PIXEL_SIZE := Vector2i(96, 84)

static func tile_key(col: int, row: int) -> String:
	return "%d:%d" % [col, row]

static func offset_to_pixel(offset) -> Vector2:
	return Vector2(
		float(offset.col * TILE_PIXEL_SIZE.x),
		float(offset.row * TILE_PIXEL_SIZE.y)
	)

static func edge_vertices(edge: String) -> PackedVector2Array:
	var half_width := TILE_PIXEL_SIZE.x / 2.0
	var half_height := TILE_PIXEL_SIZE.y / 2.0
	match edge:
		"E":
			return PackedVector2Array([Vector2(half_width, -half_height), Vector2(half_width, half_height)])
		"NE":
			return PackedVector2Array([Vector2(0.0, -half_height), Vector2(half_width, -half_height)])
		"N":
			return PackedVector2Array([Vector2(-half_width, -half_height), Vector2(half_width, -half_height)])
		"NW":
			return PackedVector2Array([Vector2(-half_width, -half_height), Vector2(0.0, -half_height)])
		"W":
			return PackedVector2Array([Vector2(-half_width, -half_height), Vector2(-half_width, half_height)])
		"SW":
			return PackedVector2Array([Vector2(-half_width, half_height), Vector2(0.0, half_height)])
		"S":
			return PackedVector2Array([Vector2(-half_width, half_height), Vector2(half_width, half_height)])
		"SE":
			return PackedVector2Array([Vector2(0.0, half_height), Vector2(half_width, half_height)])
		_:
			return PackedVector2Array()
