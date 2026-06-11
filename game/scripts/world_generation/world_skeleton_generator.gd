class_name WorldSkeletonGenerator
extends RefCounted

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")
const WorldMountainGeneratorScript := preload("res://game/scripts/world_generation/world_mountain_generator.gd")
const WorldOceanResolverScript := preload("res://game/scripts/world_generation/world_ocean_resolver.gd")
const WorldRiverGeneratorScript := preload("res://game/scripts/world_generation/world_river_generator.gd")
const WorldSkeletonTileIndexerScript := preload("res://game/scripts/world_generation/world_skeleton_tile_indexer.gd")

func generate(config):
	var skeleton = WorldSkeletonScript.new()
	skeleton.seed = config.seed
	skeleton.big_map_size = config.big_map_size
	skeleton.sub_map_size = config.sub_map_size
	skeleton.ocean_ratio = clampf(float(config.ocean_ratio), 0.0, 0.95)
	skeleton.continent_bias = float(config.generation_params.get("continent_bias", skeleton.continent_bias))

	WorldMountainGeneratorScript.new().generate(config, skeleton)
	skeleton.sea_level = WorldOceanResolverScript.new().resolve_sea_level(config, skeleton)
	WorldRiverGeneratorScript.new().generate(config, skeleton)
	WorldSkeletonTileIndexerScript.new().build(skeleton)

	return skeleton
