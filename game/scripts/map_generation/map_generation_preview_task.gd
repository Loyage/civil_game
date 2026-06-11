class_name MapGenerationPreviewTask
extends RefCounted

signal progress_changed(message: String, current: int, total: int)

const WorldSkeletonScript := preload("res://game/scripts/world_generation/world_skeleton.gd")
const WorldMountainGeneratorScript := preload("res://game/scripts/world_generation/world_mountain_generator.gd")
const WorldOceanResolverScript := preload("res://game/scripts/world_generation/world_ocean_resolver.gd")
const WorldRiverGeneratorScript := preload("res://game/scripts/world_generation/world_river_generator.gd")
const WorldSkeletonTileIndexerScript := preload("res://game/scripts/world_generation/world_skeleton_tile_indexer.gd")
const BigMapSummaryGeneratorScript := preload("res://game/scripts/world_generation/big_map_summary_generator.gd")
const PipelineResultScript := preload("res://game/scripts/map_generation/map_generation_pipeline_result.gd")

const SKELETON_FIXED_STEP_COUNT := 3

var cancelled := false
var total_units := 0
var completed_units := 0

func cancel() -> void:
	cancelled = true

func run(owner: Node, config):
	cancelled = false
	completed_units = 0
	total_units = SKELETON_FIXED_STEP_COUNT + _river_progress_units(config) + PipelineResultScript.STAGE_ORDER.size() * int(config.big_map_size)

	_emit_progress("准备生成地图", 0)
	await owner.get_tree().process_frame
	if cancelled:
		return null

	var skeleton = _build_skeleton(config)
	var skeleton_cancelled: bool = await _run_skeleton_steps(owner, config, skeleton)
	if skeleton_cancelled:
		return null

	var result = PipelineResultScript.new()
	var summary_generator = BigMapSummaryGeneratorScript.new()
	for stage_id in PipelineResultScript.STAGE_ORDER:
		if cancelled:
			return null
		_on_summary_row_generated(0, int(config.big_map_size), stage_id)
		await owner.get_tree().process_frame
		if cancelled:
			return null
		var stage_map = await summary_generator.generate_async(
			owner,
			config,
			skeleton,
			stage_id,
			Callable(self, "_on_summary_row_generated").bind(stage_id),
			Callable(self, "_is_cancelled")
		)
		if cancelled or stage_map == null:
			return null
		result.set_stage(stage_id, stage_map)

	_emit_progress("地图生成完成", total_units)
	await owner.get_tree().process_frame
	return result

func _build_skeleton(config):
	var skeleton = WorldSkeletonScript.new()
	skeleton.seed = config.seed
	skeleton.big_map_size = config.big_map_size
	skeleton.sub_map_size = config.sub_map_size
	skeleton.ocean_ratio = clampf(float(config.ocean_ratio), 0.0, 0.95)
	skeleton.continent_bias = float(config.generation_params.get("continent_bias", skeleton.continent_bias))
	return skeleton

func _run_skeleton_steps(owner: Node, config, skeleton) -> bool:
	_emit_progress("生成山脉骨架", completed_units)
	await owner.get_tree().process_frame
	if cancelled:
		return true
	WorldMountainGeneratorScript.new().generate(config, skeleton)
	_advance_progress("山脉骨架完成")
	await owner.get_tree().process_frame
	if cancelled:
		return true

	_emit_progress("解析海洋和海平面", completed_units)
	await owner.get_tree().process_frame
	if cancelled:
		return true
	skeleton.sea_level = WorldOceanResolverScript.new().resolve_sea_level(config, skeleton)
	_advance_progress("海洋解析完成")
	await owner.get_tree().process_frame
	if cancelled:
		return true

	_emit_progress("生成河流骨架", completed_units)
	await owner.get_tree().process_frame
	if cancelled:
		return true
	var river_cancelled: bool = await WorldRiverGeneratorScript.new().generate_async(
		owner,
		config,
		skeleton,
		Callable(self, "_on_river_source_generated"),
		Callable(self, "_is_cancelled")
	)
	if river_cancelled:
		return true
	_emit_progress("河流骨架完成", completed_units)
	await owner.get_tree().process_frame
	if cancelled:
		return true

	_emit_progress("建立骨架索引", completed_units)
	await owner.get_tree().process_frame
	if cancelled:
		return true
	WorldSkeletonTileIndexerScript.new().build(skeleton)
	_advance_progress("骨架索引完成")
	await owner.get_tree().process_frame
	return cancelled

func _on_summary_row_generated(row: int, total_rows: int, stage_id: String) -> void:
	var label := PipelineResultScript.new().get_label(stage_id)
	completed_units = SKELETON_FIXED_STEP_COUNT + _river_progress_units_from_current_total(total_rows) + PipelineResultScript.STAGE_ORDER.find(stage_id) * total_rows + row
	_emit_progress("生成%s摘要：%d/%d 行" % [label, row, total_rows], completed_units)

func _on_river_source_generated(done: int, total: int) -> void:
	completed_units = 2 + done
	_emit_progress("生成河流骨架：%d/%d 源头" % [done, total], completed_units)

func _advance_progress(message: String) -> void:
	completed_units += 1
	_emit_progress(message, completed_units)

func _emit_progress(message: String, current: int) -> void:
	progress_changed.emit(message, clampi(current, 0, total_units), max(1, total_units))

func _is_cancelled() -> bool:
	return cancelled

func _river_progress_units(config) -> int:
	return max(1, int(config.river_source_count))

func _river_progress_units_from_current_total(stage_rows: int) -> int:
	return max(1, int((total_units - SKELETON_FIXED_STEP_COUNT) - PipelineResultScript.STAGE_ORDER.size() * stage_rows))
