class_name ResourceDefinitionCatalog
extends RefCounted

const ANIMALS_PATH := "res://game/data/resources/animals.json"
const MINERALS_PATH := "res://game/data/resources/minerals.json"

var definitions_by_id: Dictionary
var definitions: Array

func _init() -> void:
	definitions_by_id = {}
	definitions = []
	_load_definitions(ANIMALS_PATH)
	_load_definitions(MINERALS_PATH)

func all_definitions() -> Array:
	return definitions

func get_definition(resource_id: String) -> Dictionary:
	return definitions_by_id.get(resource_id, {})

func display_name(resource_id: String) -> String:
	var definition: Dictionary = get_definition(resource_id)
	return String(definition.get("name", resource_id))

func display_names(resource_ids: PackedStringArray) -> String:
	if resource_ids.is_empty():
		return "无"
	var names: Array[String] = []
	for resource_id in resource_ids:
		names.append(display_name(resource_id))
	return "、".join(names)

func color(resource_id: String) -> Color:
	var definition: Dictionary = get_definition(resource_id)
	return Color(String(definition.get("color", "#ffffff")))

func _load_definitions(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot load resource definitions: %s" % path)
		return

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_ARRAY:
		push_warning("Invalid resource definitions: %s" % path)
		return

	for raw_definition in json.data:
		if typeof(raw_definition) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = raw_definition
		var resource_id: String = String(definition.get("id", ""))
		if resource_id == "":
			continue
		definitions.append(definition)
		definitions_by_id[resource_id] = definition
