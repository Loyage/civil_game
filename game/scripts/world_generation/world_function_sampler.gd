class_name WorldFunctionSampler
extends RefCounted

const MIN_HEIGHT := -256
const MAX_HEIGHT := 256
const SHALLOW_LAND_HEIGHT_ABOVE_SEA := 4
const MAX_OCEAN_DEPTH_BONUS := 64

var skeleton

func _init(init_skeleton = null) -> void:
	skeleton = init_skeleton

func sample_height(world_x: int, world_y: int) -> int:
	return sample_final_height(world_x, world_y)

func sample_base_height(world_x: int, world_y: int) -> int:
	return clampi(int(round(_sample_base_height_float(world_x, world_y))), MIN_HEIGHT, MAX_HEIGHT)

func sample_ocean_height(world_x: int, world_y: int) -> int:
	var mountain_height := sample_height_after_mountains(world_x, world_y)
	if not _is_ocean_world_point(world_x, world_y):
		if mountain_height < skeleton.sea_level:
			return clampi(skeleton.sea_level + SHALLOW_LAND_HEIGHT_ABOVE_SEA, MIN_HEIGHT, MAX_HEIGHT)
		return mountain_height
	var depth := clampf(float(skeleton.sea_level - mountain_height) / 180.0, 0.0, 1.0)
	var distance_depth := clampf(float(_ocean_distance(world_x, world_y)) / 8.0, 0.0, 1.0)
	var depth_bonus := int(round(distance_depth * float(MAX_OCEAN_DEPTH_BONUS)))
	var reshaped: int = min(mountain_height, skeleton.sea_level - 4 - int(round(pow(depth, 1.35) * 48.0)) - depth_bonus)
	return clampi(reshaped, MIN_HEIGHT, MAX_HEIGHT)

func sample_mountain_delta(world_x: int, world_y: int) -> int:
	return int(round(sample_mountain_influence(world_x, world_y) * 150.0))

func sample_height_after_mountains(world_x: int, world_y: int) -> int:
	return clampi(sample_base_height(world_x, world_y) + sample_mountain_delta(world_x, world_y), MIN_HEIGHT, MAX_HEIGHT)

func sample_final_height(world_x: int, world_y: int) -> int:
	return sample_ocean_height(world_x, world_y)

func sample_temperature(world_x: int, world_y: int) -> float:
	var world_size := float(skeleton.big_map_size * skeleton.sub_map_size)
	var latitude: float = float(world_y) / max(1.0, world_size)
	var latitude_temp: float = 1.0 - abs(latitude - 0.5) * 2.0
	var height := sample_height(world_x, world_y)
	var altitude_penalty: float = max(0.0, float(height) / float(MAX_HEIGHT)) * 0.34
	var noise := (_hash01(101, world_x / 8, world_y / 8) - 0.5) * 0.16
	return clampf(latitude_temp - altitude_penalty + noise, 0.0, 1.0)

func sample_moisture(world_x: int, world_y: int) -> float:
	var base := 0.45 + (_hash01(202, world_x / 8, world_y / 8) - 0.5) * 0.42
	var ocean_bonus := 0.16 if sample_height(world_x, world_y) < skeleton.sea_level else 0.0
	return clampf(base + ocean_bonus, 0.0, 1.0)

func sample_river_strength(world_x: int, world_y: int) -> float:
	var point := Vector2(float(world_x), float(world_y))
	var result := 0.0
	for river in skeleton.rivers:
		var sample: Vector2 = _river_distance_and_width(point, river)
		var distance: float = sample.x
		var width: float = max(1.0, sample.y)
		var t: float = distance / width
		if t < 1.0:
			result = max(result, float(river["flow"]) * _falloff(t))
	return clampf(result, 0.0, 1.0)

func sample_mountain_influence(world_x: int, world_y: int) -> float:
	var point := Vector2(float(world_x), float(world_y))
	var result := 0.0
	for ridge in skeleton.mountain_ridges:
		var distance := _distance_to_polyline(point, ridge["points"])
		var t := distance / float(ridge["width"])
		if t < 1.0:
			result += float(ridge["strength"]) * _falloff(t)
	return clampf(result, 0.0, 1.0)

func sample_biome(world_x: int, world_y: int) -> String:
	var height := sample_height(world_x, world_y)
	var temperature := sample_temperature(world_x, world_y)
	var moisture := sample_moisture(world_x, world_y)
	var river_strength := sample_river_strength(world_x, world_y)
	if _is_ocean_world_point(world_x, world_y):
		return "ocean"
	if river_strength > 0.70:
		return "river"
	if height > 210:
		return "snow_mountain"
	if height > 150:
		return "mountain"
	if height > 86:
		return "hill"
	if temperature < 0.18:
		return "tundra"
	if moisture < 0.22 and temperature > 0.55:
		return "desert"
	if moisture > 0.75 and temperature > 0.55:
		return "rainforest"
	if moisture > 0.55:
		return "forest"
	if moisture > 0.35:
		return "grassland"
	return "plain"

func _is_ocean_world_point(world_x: int, world_y: int) -> bool:
	if skeleton == null or skeleton.ocean_tiles.is_empty():
		return false
	var tile_x: int = int(floor(float(world_x) / float(maxi(1, skeleton.sub_map_size))))
	var tile_y: int = int(floor(float(world_y) / float(maxi(1, skeleton.sub_map_size))))
	return skeleton.ocean_tiles.has("%d:%d" % [tile_x, tile_y])

func _ocean_distance(world_x: int, world_y: int) -> int:
	var tile_x: int = int(floor(float(world_x) / float(maxi(1, skeleton.sub_map_size))))
	var tile_y: int = int(floor(float(world_y) / float(maxi(1, skeleton.sub_map_size))))
	return int(skeleton.ocean_distance_by_tile.get("%d:%d" % [tile_x, tile_y], 0))

func _sample_continent_height(world_x: int, world_y: int) -> float:
	var world_size := float(skeleton.big_map_size * skeleton.sub_map_size)
	var normalized := Vector2(float(world_x) / world_size - 0.5, float(world_y) / world_size - 0.5)
	var bias: float = clampf(float(skeleton.continent_bias), 0.0, 1.0)
	var island_falloff := 1.0 - clampf(normalized.length() * lerpf(1.80, 1.15, bias), 0.0, 1.0)
	return lerpf(-140.0, 130.0, island_falloff)

func _sample_height_noise(world_x: int, world_y: int) -> float:
	return (
		(_hash01(301, world_x / 64, world_y / 64) - 0.5) * 92.0 +
		(_hash01(302, world_x / 24, world_y / 24) - 0.5) * 48.0 +
		(_hash01(303, world_x / 8, world_y / 8) - 0.5) * 20.0
	)

func _sample_base_height_float(world_x: int, world_y: int) -> float:
	return _sample_continent_height(world_x, world_y) + _sample_height_noise(world_x, world_y)

func _distance_to_polyline(point: Vector2, points: Array) -> float:
	if points.is_empty():
		return INF
	var best := INF
	for index in range(points.size() - 1):
		best = min(best, _distance_to_segment(point, points[index], points[index + 1]))
	return best

func _river_distance_and_width(point: Vector2, river: Dictionary) -> Vector2:
	var points: Array = river["points"]
	var width_profile: Array = river.get("width_profile", [])
	if points.is_empty():
		return Vector2(INF, float(river.get("width", 1.0)))
	var best_distance := INF
	var best_width: float = float(river.get("width", 1.0))
	for index in range(points.size() - 1):
		var segment_sample: Vector2 = _distance_width_to_segment(point, points[index], points[index + 1])
		if segment_sample.x < best_distance:
			best_distance = segment_sample.x
			var start_width := float(width_profile[index]) if index < width_profile.size() else best_width
			var end_width := float(width_profile[index + 1]) if index + 1 < width_profile.size() else start_width
			best_width = lerpf(start_width, end_width, segment_sample.y)
	return Vector2(best_distance, best_width)

func _distance_width_to_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var length_sq: float = ab.length_squared()
	if is_zero_approx(length_sq):
		return Vector2(point.distance_to(a), 0.0)
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return Vector2(point.distance_to(a + ab * t), t)

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if is_zero_approx(length_sq):
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _falloff(t: float) -> float:
	if t >= 1.0:
		return 0.0
	return (1.0 - t) * (1.0 - t)

func _hash01(salt: int, x: int, y: int) -> float:
	var n := int(skeleton.seed) ^ int(salt * 1442695041) ^ int(x * 374761393) ^ int(y * 668265263)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0
