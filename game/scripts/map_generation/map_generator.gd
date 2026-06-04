class_name MapGenerator
extends RefCounted

const WorldSkeletonGeneratorScript := preload("res://game/scripts/world_generation/world_skeleton_generator.gd")
const BigMapSummaryGeneratorScript := preload("res://game/scripts/world_generation/big_map_summary_generator.gd")

func generate(config):
	var skeleton = WorldSkeletonGeneratorScript.new().generate(config)
	return BigMapSummaryGeneratorScript.new().generate(config, skeleton)
