class_name HexLayout
extends RefCounted

const TILE_PIXEL_SIZE := Vector2i(96, 84)
const HEX_RADIUS := 48.0
const OffsetCoordScript := preload("res://game/scripts/map/offset_coord.gd")
const HexCoordScript := preload("res://game/scripts/map/hex_coord.gd")

static func offset_to_axial(offset):
	var q: int = offset.col
	var r: int = offset.row - int((offset.col - (offset.col & 1)) / 2)
	return HexCoordScript.new(q, r)

static func axial_to_offset(coord):
	var col: int = coord.q
	var row: int = coord.r + int((coord.q - (coord.q & 1)) / 2)
	return OffsetCoordScript.new(col, row)

static func offset_key(col: int, row: int) -> String:
	var coord = offset_to_axial(OffsetCoordScript.new(col, row))
	return coord.key()

static func axial_to_pixel(coord) -> Vector2:
	var x := HEX_RADIUS * 1.5 * float(coord.q)
	var y := HEX_RADIUS * sqrt(3.0) * (float(coord.r) + float(coord.q) / 2.0)
	return Vector2(x, y)

static func edge_vertices(edge: String, radius: float) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i)
		vertices.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	match edge:
		"E":
			return PackedVector2Array([vertices[5], vertices[1]])
		"NE":
			return PackedVector2Array([vertices[0], vertices[2]])
		"NW":
			return PackedVector2Array([vertices[1], vertices[3]])
		"W":
			return PackedVector2Array([vertices[2], vertices[4]])
		"SW":
			return PackedVector2Array([vertices[3], vertices[5]])
		"SE":
			return PackedVector2Array([vertices[4], vertices[0]])
		_:
			return PackedVector2Array()
