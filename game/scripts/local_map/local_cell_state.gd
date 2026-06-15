class_name LocalCellState
extends RefCounted

var x: int
var y: int
var global_x: int
var global_y: int
var height: int
var slope: int
var is_water: bool
var has_river: bool
var terrain_flags: int
var resources: Array

func _init() -> void:
	x = 0
	y = 0
	global_x = 0
	global_y = 0
	height = 0
	slope = 0
	is_water = false
	has_river = false
	terrain_flags = 0
	resources = []
