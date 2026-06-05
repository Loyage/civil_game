class_name MapGenerationPipelineResult
extends RefCounted

const STAGE_BASE := "base"
const STAGE_OCEAN := "ocean"
const STAGE_MOUNTAINS := "mountains"
const STAGE_RIVERS := "rivers"
const STAGE_ENVIRONMENT := "environment"
const STAGE_FINAL := "final"

const STAGE_ORDER := [
	STAGE_BASE,
	STAGE_OCEAN,
	STAGE_MOUNTAINS,
	STAGE_RIVERS,
	STAGE_ENVIRONMENT,
	STAGE_FINAL
]

var final_map
var stage_maps: Dictionary
var stage_labels: Dictionary

func _init() -> void:
	final_map = null
	stage_maps = {}
	stage_labels = {
		STAGE_BASE: "基础地形",
		STAGE_OCEAN: "海洋",
		STAGE_MOUNTAINS: "山脉",
		STAGE_RIVERS: "河流",
		STAGE_ENVIRONMENT: "环境",
		STAGE_FINAL: "最终地貌"
	}

func set_stage(stage_id: String, map_state) -> void:
	stage_maps[stage_id] = map_state
	if stage_id == STAGE_FINAL:
		final_map = map_state

func get_stage(stage_id: String):
	return stage_maps.get(stage_id)

func get_label(stage_id: String) -> String:
	return String(stage_labels.get(stage_id, stage_id))
