class_name WorldGenerationMath
extends RefCounted

const MIN_HEIGHT := -256
const MAX_HEIGHT := 256
const SHALLOW_LAND_HEIGHT_ABOVE_SEA := 4
const MAX_OCEAN_DEPTH_BONUS := 64

static func hash01(seed: int, salt: int, x: int, y: int) -> float:
	var n := int(seed) ^ int(salt * 1442695041) ^ int(x * 374761393) ^ int(y * 668265263)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0

static func tile_center(config, tile: Vector2i) -> Vector2:
	return Vector2(
		(float(tile.x) + 0.5) * float(config.sub_map_size),
		(float(tile.y) + 0.5) * float(config.sub_map_size)
	)

static func tile_coord_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

static func tile_height(config, skeleton, tile: Vector2i) -> int:
	var point: Vector2 = tile_center(config, tile)
	return sample_layered_height(config.seed, skeleton, int(point.x), int(point.y))

static func is_ocean_tile(config, skeleton, tile: Vector2i) -> bool:
	return skeleton.ocean_tiles.has(tile_coord_key(tile))

static func sample_base_height(seed: int, skeleton, world_x: int, world_y: int) -> float:
	var world_size := float(skeleton.big_map_size * skeleton.sub_map_size)
	var normalized := Vector2(float(world_x) / world_size - 0.5, float(world_y) / world_size - 0.5)
	var bias: float = clampf(float(skeleton.continent_bias), 0.0, 1.0)
	var island_falloff := 1.0 - clampf(normalized.length() * lerpf(1.80, 1.15, bias), 0.0, 1.0)
	var continent := lerpf(-140.0, 130.0, island_falloff)
	var detail := (
		(hash01(seed, 301, int(world_x / 64), int(world_y / 64)) - 0.5) * 92.0 +
		(hash01(seed, 302, int(world_x / 24), int(world_y / 24)) - 0.5) * 48.0 +
		(hash01(seed, 303, int(world_x / 8), int(world_y / 8)) - 0.5) * 20.0
	)
	return continent + detail

static func sample_layered_height(seed: int, skeleton, world_x: int, world_y: int) -> int:
	var height_after_mountains: int = sample_height_after_mountains(seed, skeleton, world_x, world_y)
	if not is_ocean_world_point(skeleton, world_x, world_y):
		if height_after_mountains < skeleton.sea_level:
			return clampi(skeleton.sea_level + SHALLOW_LAND_HEIGHT_ABOVE_SEA, MIN_HEIGHT, MAX_HEIGHT)
		return height_after_mountains
	var depth := clampf(float(skeleton.sea_level - height_after_mountains) / 180.0, 0.0, 1.0)
	var distance_depth := clampf(float(ocean_distance(skeleton, world_x, world_y)) / 8.0, 0.0, 1.0)
	var depth_bonus := int(round(distance_depth * float(MAX_OCEAN_DEPTH_BONUS)))
	return clampi(min(height_after_mountains, skeleton.sea_level - 4 - int(round(pow(depth, 1.35) * 48.0)) - depth_bonus), MIN_HEIGHT, MAX_HEIGHT)

static func is_ocean_world_point(skeleton, world_x: int, world_y: int) -> bool:
	if skeleton == null or skeleton.ocean_tiles.is_empty():
		return false
	var tile_x: int = int(floor(float(world_x) / float(maxi(1, skeleton.sub_map_size))))
	var tile_y: int = int(floor(float(world_y) / float(maxi(1, skeleton.sub_map_size))))
	return skeleton.ocean_tiles.has("%d:%d" % [tile_x, tile_y])

static func ocean_distance(skeleton, world_x: int, world_y: int) -> int:
	var tile_x: int = int(floor(float(world_x) / float(maxi(1, skeleton.sub_map_size))))
	var tile_y: int = int(floor(float(world_y) / float(maxi(1, skeleton.sub_map_size))))
	return int(skeleton.ocean_distance_by_tile.get("%d:%d" % [tile_x, tile_y], 0))

static func sample_height_after_mountains(seed: int, skeleton, world_x: int, world_y: int) -> int:
	return clampi(
		int(round(sample_base_height(seed, skeleton, world_x, world_y))) + int(round(sample_mountain_influence(skeleton, world_x, world_y) * 150.0)),
		MIN_HEIGHT,
		MAX_HEIGHT
	)

static func sample_mountain_influence(skeleton, world_x: int, world_y: int) -> float:
	var point := Vector2(float(world_x), float(world_y))
	var result := 0.0
	for ridge in skeleton.mountain_ridges:
		var distance := distance_to_polyline(point, ridge["points"])
		var t := distance / float(ridge["width"])
		if t < 1.0:
			result += float(ridge["strength"]) * falloff(t)
	return clampf(result, 0.0, 1.0)

static func distance_to_polyline(point: Vector2, points: Array) -> float:
	if points.is_empty():
		return INF
	var best := INF
	for index in range(points.size() - 1):
		best = min(best, distance_to_segment(point, points[index], points[index + 1]))
	return best

static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if is_zero_approx(length_sq):
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

static func falloff(t: float) -> float:
	if t >= 1.0:
		return 0.0
	return (1.0 - t) * (1.0 - t)

static func directions8() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(Vector2i(1, 0))
	result.append(Vector2i(1, -1))
	result.append(Vector2i(0, -1))
	result.append(Vector2i(-1, -1))
	result.append(Vector2i(-1, 0))
	result.append(Vector2i(-1, 1))
	result.append(Vector2i(0, 1))
	result.append(Vector2i(1, 1))
	return result
