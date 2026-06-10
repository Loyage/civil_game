class_name WorldOceanResolver
extends RefCounted

const WorldGenerationMathScript := preload("res://game/scripts/world_generation/world_generation_math.gd")

func resolve_sea_level(config, skeleton) -> int:
	var heights: Array[int] = []
	for row in range(config.big_map_size):
		for col in range(config.big_map_size):
			var world_x: int = int((float(col) + 0.5) * float(config.sub_map_size))
			var world_y: int = int((float(row) + 0.5) * float(config.sub_map_size))
			heights.append(WorldGenerationMathScript.sample_height_after_mountains(config.seed, skeleton, world_x, world_y))
	if heights.is_empty():
		return config.sea_level
	heights.sort()
	var index := clampi(int(round(float(heights.size() - 1) * skeleton.ocean_ratio)), 0, heights.size() - 1)
	return heights[index]
