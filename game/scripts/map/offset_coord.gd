class_name OffsetCoord
extends RefCounted

var col: int
var row: int

func _init(init_col: int = 0, init_row: int = 0) -> void:
	col = init_col
	row = init_row

func to_vector() -> Vector2i:
	return Vector2i(col, row)
