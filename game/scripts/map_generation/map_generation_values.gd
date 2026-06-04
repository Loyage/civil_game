class_name MapGenerationValues
extends RefCounted

var elevation: float
var rainfall: float
var temperature: float
var river_strength: float
var river_flow: Vector2i

func _init(
	init_elevation: float = 0.0,
	init_rainfall: float = 0.0,
	init_temperature: float = 0.0
) -> void:
	elevation = init_elevation
	rainfall = init_rainfall
	temperature = init_temperature
	river_strength = 0.0
	river_flow = Vector2i.ZERO
