class_name WorldResourceGenerator
extends RefCounted

const ResourceDefinitionCatalogScript := preload("res://game/scripts/resources/resource_definition_catalog.gd")

var catalog

func _init(init_catalog = null) -> void:
	catalog = init_catalog if init_catalog != null else ResourceDefinitionCatalogScript.new()

func apply_to_map(map_state, seed: int) -> void:
	for tile in map_state.tiles_by_key.values():
		apply_to_tile(tile, seed)

func apply_to_tile(tile, seed: int) -> void:
	tile.resource_ids = _resources_for_tile(tile, seed)

func _resources_for_tile(tile, seed: int) -> PackedStringArray:
	var candidates: Array[Dictionary] = []
	for definition in catalog.all_definitions():
		if _tile_matches_definition(tile, definition):
			candidates.append(definition)
	if candidates.is_empty():
		return PackedStringArray()

	var best_id: String = ""
	var best_score: float = 1.0
	for definition in candidates:
		var resource_id: String = String(definition.get("id", ""))
		var chance: float = float(definition.get("spawn_chance", 0.0))
		var roll: float = _hash01(seed, tile.tile_key, resource_id)
		if roll <= chance and roll < best_score:
			best_score = roll
			best_id = resource_id

	var result: PackedStringArray = PackedStringArray()
	if best_id != "":
		result.append(best_id)
	return result

func _tile_matches_definition(tile, definition: Dictionary) -> bool:
	var allowed_biomes: Array = definition.get("allowed_biomes", [])
	if not allowed_biomes.is_empty() and not allowed_biomes.has(tile.biome):
		return false
	var allowed_tags: Array = definition.get("allowed_terrain_tags", [])
	if allowed_tags.is_empty():
		return true
	for tag in allowed_tags:
		if tile.terrain_tags.has(String(tag)):
			return true
	return false

func _hash01(seed: int, tile_key: String, salt: String) -> float:
	var text: String = "%d:%s:%s" % [seed, tile_key, salt]
	var hash: int = int(text.hash())
	hash = (hash ^ (hash >> 13)) * 1274126177
	hash = hash ^ (hash >> 16)
	return float(hash & 0xffff) / 65535.0
