class_name HexCoord
extends RefCounted

var q: int
var r: int

func _init(init_q: int = 0, init_r: int = 0) -> void:
	q = init_q
	r = init_r

func key() -> String:
	return "%d:%d" % [q, r]

func to_vector() -> Vector2i:
	return Vector2i(q, r)
