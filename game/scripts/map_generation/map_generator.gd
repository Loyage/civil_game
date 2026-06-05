class_name MapGenerator
extends RefCounted

const WorldSkeletonGeneratorScript := preload("res://game/scripts/world_generation/world_skeleton_generator.gd")
const BigMapSummaryGeneratorScript := preload("res://game/scripts/world_generation/big_map_summary_generator.gd")
const PipelineResultScript := preload("res://game/scripts/map_generation/map_generation_pipeline_result.gd")

func generate(config):
	return generate_pipeline(config).final_map

func generate_pipeline(config):
	var skeleton = WorldSkeletonGeneratorScript.new().generate(config)
	var summary_generator = BigMapSummaryGeneratorScript.new()
	var result = PipelineResultScript.new()
	for stage_id in PipelineResultScript.STAGE_ORDER:
		result.set_stage(stage_id, summary_generator.generate(config, skeleton, stage_id))
	return result
