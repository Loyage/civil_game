class_name WorldMountainGenerator
extends RefCounted

const WorldGenerationMathScript := preload("res://game/scripts/world_generation/world_generation_math.gd")

func generate(config, skeleton) -> void:
	var world_size := float(config.big_map_size * config.sub_map_size)
	for id in range(config.mountain_count):
		var start := Vector2(
			WorldGenerationMathScript.hash01(config.seed, 101 + id, 0, 0) * world_size,
			WorldGenerationMathScript.hash01(config.seed, 101 + id, 1, 0) * world_size
		)
		var angle := WorldGenerationMathScript.hash01(config.seed, 102 + id, 0, 0) * TAU
		var length := world_size * (0.38 + WorldGenerationMathScript.hash01(config.seed, 103 + id, 0, 0) * 0.45)
		var direction := Vector2(cos(angle), sin(angle))
		var normal := Vector2(-direction.y, direction.x)
		var points: Array[Vector2] = []
		for point_index in range(5):
			var t := float(point_index) / 4.0
			var bend := (WorldGenerationMathScript.hash01(config.seed, 104 + id, point_index, 0) - 0.5) * world_size * 0.16
			points.append(start + direction * (t - 0.5) * length + normal * bend)
		skeleton.mountain_ridges.append({
			"id": id,
			"points": points,
			"width": 52.0 + WorldGenerationMathScript.hash01(config.seed, 105 + id, 0, 0) * 72.0,
			"strength": 0.62 + WorldGenerationMathScript.hash01(config.seed, 106 + id, 0, 0) * 0.38,
			"roughness": 0.35 + WorldGenerationMathScript.hash01(config.seed, 107 + id, 0, 0) * 0.50
		})
