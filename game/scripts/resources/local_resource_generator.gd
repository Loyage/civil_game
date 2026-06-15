class_name LocalResourceGenerator
extends RefCounted

const LocalMapStateScript := preload("res://game/scripts/local_map/local_map_state.gd")
const ResourceDefinitionCatalogScript := preload("res://game/scripts/resources/resource_definition_catalog.gd")

var catalog

func _init(init_catalog = null) -> void:
	catalog = init_catalog if init_catalog != null else ResourceDefinitionCatalogScript.new()

func apply_to_local_map(state, tile, seed: int) -> void:
	state.resource_instances = []
	if tile == null or tile.resource_ids.is_empty():
		return

	var occupied_by_type: Dictionary = {}
	for resource_id in tile.resource_ids:
		var definition: Dictionary = catalog.get_definition(resource_id)
		if definition.is_empty():
			continue
		if String(definition.get("category", "")) == "animal":
			_place_animals(state, definition, seed, occupied_by_type)
		elif String(definition.get("category", "")) == "mineral":
			_place_minerals(state, definition, seed, occupied_by_type)

func _place_animals(state, definition: Dictionary, seed: int, occupied_by_type: Dictionary) -> void:
	var candidates: Array[int] = _matching_cells(state, definition, false)
	if candidates.is_empty():
		return
	var resource_id: String = String(definition.get("id", ""))
	var min_count: int = int(definition.get("min_count", 1))
	var max_count: int = int(definition.get("max_count", 3))
	var count: int = _range_from_hash(seed, state.tile_key, resource_id + ":count", min_count, max_count)
	for index in range(count):
		var cell_index: int = _pick_available_cell(candidates, occupied_by_type, resource_id, seed, state.tile_key, resource_id + ":%d" % index)
		if cell_index < 0:
			return
		occupied_by_type[_occupied_key(resource_id, cell_index)] = true
		state.resource_instances.append({
			"resource_id": resource_id,
			"category": "animal",
			"instance_id": "%s:%s:%d" % [state.tile_key, resource_id, index],
			"x": cell_index % state.width,
			"y": int(cell_index / state.width)
		})

func _place_minerals(state, definition: Dictionary, seed: int, occupied_by_type: Dictionary) -> void:
	var resource_id: String = String(definition.get("id", ""))
	var candidates: Array[int] = _matching_cells(state, definition, true)
	if candidates.is_empty():
		candidates = _land_cells(state)
	if candidates.is_empty():
		return
	var min_cells: int = int(definition.get("min_cells", 2))
	var max_cells: int = int(definition.get("max_cells", 5))
	var cell_count: int = _range_from_hash(seed, state.tile_key, resource_id + ":cells", min_cells, max_cells)
	var start_cell: int = _pick_available_cell(candidates, occupied_by_type, resource_id, seed, state.tile_key, resource_id + ":start")
	if start_cell < 0:
		return
	var placed: Array[int] = [start_cell]
	occupied_by_type[_occupied_key(resource_id, start_cell)] = true
	for step in range(cell_count - 1):
		var next_cell: int = _pick_neighbor_cell(state, placed, candidates, occupied_by_type, resource_id, seed, resource_id + ":%d" % step)
		if next_cell < 0:
			break
		placed.append(next_cell)
		occupied_by_type[_occupied_key(resource_id, next_cell)] = true
	for cell_index in placed:
		state.resource_instances.append({
			"resource_id": resource_id,
			"category": "mineral",
			"x": cell_index % state.width,
			"y": int(cell_index / state.width)
		})

func _matching_cells(state, definition: Dictionary, allow_fallback_rules: bool) -> Array[int]:
	var result: Array[int] = []
	var allowed_flags: Array = definition.get("allowed_terrain_flags", [])
	for y in range(state.height):
		for x in range(state.width):
			var index: int = state.index(x, y)
			if state.water_flags[index] == 1:
				continue
			if _cell_matches_flags(int(state.terrain_flags[index]), allowed_flags):
				result.append(index)
	if result.is_empty() and allow_fallback_rules:
		return _land_cells(state)
	return result

func _land_cells(state) -> Array[int]:
	var result: Array[int] = []
	for index in range(state.heights.size()):
		if state.water_flags[index] == 0:
			result.append(index)
	return result

func _cell_matches_flags(flags: int, allowed_flags: Array) -> bool:
	if allowed_flags.is_empty():
		return true
	for flag_name in allowed_flags:
		if (flags & _terrain_flag(String(flag_name))) != 0:
			return true
	return false

func _terrain_flag(flag_name: String) -> int:
	match flag_name:
		"grass":
			return LocalMapStateScript.TERRAIN_GRASS
		"forest":
			return LocalMapStateScript.TERRAIN_FOREST
		"wetland":
			return LocalMapStateScript.TERRAIN_WETLAND
		"rock":
			return LocalMapStateScript.TERRAIN_ROCK
		"sand":
			return LocalMapStateScript.TERRAIN_SAND
		"snow":
			return LocalMapStateScript.TERRAIN_SNOW
		_:
			return 0

func _pick_available_cell(candidates: Array[int], occupied_by_type: Dictionary, resource_id: String, seed: int, tile_key: String, salt: String) -> int:
	if candidates.is_empty():
		return -1
	var start: int = _range_from_hash(seed, tile_key, salt, 0, candidates.size() - 1)
	for offset in range(candidates.size()):
		var cell_index: int = candidates[(start + offset) % candidates.size()]
		if not occupied_by_type.has(_occupied_key(resource_id, cell_index)):
			return cell_index
	return -1

func _pick_neighbor_cell(state, placed: Array[int], candidates: Array[int], occupied_by_type: Dictionary, resource_id: String, seed: int, salt: String) -> int:
	var candidate_lookup: Dictionary = {}
	for cell_index in candidates:
		candidate_lookup[cell_index] = true
	var neighbor_candidates: Array[int] = []
	for placed_cell in placed:
		var px: int = int(placed_cell) % state.width
		var py: int = int(int(placed_cell) / state.width)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = px + dx
				var ny: int = py + dy
				if not state.is_valid_cell(nx, ny):
					continue
				var next_index: int = state.index(nx, ny)
				if candidate_lookup.has(next_index) and not occupied_by_type.has(_occupied_key(resource_id, next_index)):
					neighbor_candidates.append(next_index)
	if neighbor_candidates.is_empty():
		return _pick_available_cell(candidates, occupied_by_type, resource_id, seed, state.tile_key, salt + ":fallback")
	return _pick_available_cell(neighbor_candidates, occupied_by_type, resource_id, seed, state.tile_key, salt)

func _range_from_hash(seed: int, tile_key: String, salt: String, min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	var value: float = _hash01(seed, tile_key, salt)
	return min_value + int(floor(value * float(max_value - min_value + 1))) % (max_value - min_value + 1)

func _hash01(seed: int, tile_key: String, salt: String) -> float:
	var text: String = "%d:%s:%s" % [seed, tile_key, salt]
	var hash: int = int(text.hash())
	hash = (hash ^ (hash >> 13)) * 1274126177
	hash = hash ^ (hash >> 16)
	return float(hash & 0xffff) / 65535.0

func _occupied_key(resource_id: String, cell_index: int) -> String:
	return "%s:%d" % [resource_id, cell_index]
