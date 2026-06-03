class_name MapGeneratorPreview
extends Control

const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const MapGeneratorScript := preload("res://game/scripts/map_generation/map_generator.gd")
const LocalMapGeneratorScript := preload("res://game/scripts/local_map/local_map_generator.gd")

const VIEW_TERRAIN := 0
const VIEW_ELEVATION := 1
const VIEW_RAINFALL := 2
const VIEW_TEMPERATURE := 3
const VIEW_RIVER := 4
const VIEW_FEATURES := 5
const MODE_WORLD := 0
const MODE_LOCAL := 1
const MIN_ZOOM := 0.5
const MAX_ZOOM := 16.0
const ZOOM_STEP := 1.10
const BASE_TILE_SIZE := 16.0
const LOCAL_MAP_DISPLAY_SIZE := Vector2(640.0, 640.0)

const TERRAIN_COLORS := {
	"grassland": Color("#6fb35f"),
	"plains": Color("#cdbb73"),
	"ocean": Color("#3f87c6"),
	"desert": Color("#d7c176"),
	"tundra": Color("#b9c4bd")
}

@onready var seed_input: SpinBox = %SeedInput
@onready var width_input: SpinBox = %WidthInput
@onready var height_input: SpinBox = %HeightInput
@onready var river_count_input: SpinBox = %RiverCountInput
@onready var continent_bias_input: SpinBox = %ContinentBiasInput
@onready var view_mode_button: OptionButton = %ViewModeButton
@onready var generate_button: Button = %GenerateButton
@onready var random_seed_button: Button = %RandomSeedButton
@onready var local_map_button: Button = %LocalMapButton
@onready var preview_viewport: Control = %PreviewViewport
@onready var map_texture: TextureRect = %MapTexture
@onready var selection_marker: ColorRect = %SelectionMarker
@onready var summary_label: Label = %SummaryLabel
@onready var tile_info_label: Label = %TileInfoLabel

var map_state
var local_map_state
var preview_mode := MODE_WORLD
var base_map_size := Vector2.ZERO
var zoom_level := 1.0
var pan_offset := Vector2.ZERO
var is_panning := false
var selected_tile := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)

func _ready() -> void:
	_setup_view_modes()
	generate_button.pressed.connect(_generate_preview)
	random_seed_button.pressed.connect(_randomize_seed)
	local_map_button.pressed.connect(_toggle_local_map)
	view_mode_button.item_selected.connect(func(_index: int) -> void: _render_preview())
	preview_viewport.resized.connect(_apply_view_transform)
	preview_viewport.gui_input.connect(_handle_preview_gui_input)
	_generate_preview()

func _handle_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _setup_view_modes() -> void:
	view_mode_button.clear()
	view_mode_button.add_item("基础地貌", VIEW_TERRAIN)
	view_mode_button.add_item("海拔", VIEW_ELEVATION)
	view_mode_button.add_item("降水", VIEW_RAINFALL)
	view_mode_button.add_item("温度", VIEW_TEMPERATURE)
	view_mode_button.add_item("河流", VIEW_RIVER)
	view_mode_button.add_item("特征", VIEW_FEATURES)
	view_mode_button.select(0)

func _generate_preview() -> void:
	var config = _build_config_from_inputs()
	map_state = MapGeneratorScript.new().generate(config)
	local_map_state = null
	preview_mode = MODE_WORLD
	selected_tile = Vector2i(-1, -1)
	selected_cell = Vector2i(-1, -1)
	local_map_button.text = "查看小地图"
	local_map_button.disabled = true
	view_mode_button.disabled = false
	_render_preview()
	_update_summary(config)
	_show_empty_tile_info()
	_reset_view_deferred()

func _randomize_seed() -> void:
	seed_input.value = randi_range(1, 999999999)
	_generate_preview()

func _build_config_from_inputs():
	var config = MapGenerationConfigScript.new()
	config.seed = int(seed_input.value)
	config.width = int(width_input.value)
	config.height = int(height_input.value)
	config.start_city_col = clampi(int(config.width / 2), 0, max(0, config.width - 1))
	config.start_city_row = clampi(int(config.height / 2), 0, max(0, config.height - 1))
	config.start_city_name = "Preview"
	config.generation_params["river_count"] = int(river_count_input.value)
	config.generation_params["continent_bias"] = float(continent_bias_input.value)
	config.generated_output_path = "user://generated_map_preview.json"
	return config

func _render_preview() -> void:
	if map_state == null:
		return
	if preview_mode == MODE_LOCAL:
		_render_local_map()
		return

	var image = Image.create(map_state.width, map_state.height, false, Image.FORMAT_RGBA8)
	var view_id = view_mode_button.get_selected_id()
	for row in range(map_state.height):
		for col in range(map_state.width):
			var tile = map_state.get_tile_by_offset(col, row)
			image.set_pixel(col, row, _tile_color(tile, view_id))

	map_texture.texture = ImageTexture.create_from_image(image)
	base_map_size = Vector2(float(map_state.width), float(map_state.height)) * BASE_TILE_SIZE
	map_texture.size = base_map_size
	_update_selection_marker()

func _render_local_map() -> void:
	if local_map_state == null:
		return

	var image = Image.create(local_map_state.width, local_map_state.height, false, Image.FORMAT_RGBA8)
	for y in range(local_map_state.height):
		for x in range(local_map_state.width):
			image.set_pixel(x, y, _local_cell_color(local_map_state.index(x, y)))

	map_texture.texture = ImageTexture.create_from_image(image)
	base_map_size = LOCAL_MAP_DISPLAY_SIZE
	map_texture.size = base_map_size
	_update_selection_marker()

func _local_cell_color(index: int) -> Color:
	if local_map_state.river_flags[index] == 1:
		return Color("#2fb8ff")
	if local_map_state.water_flags[index] == 1:
		return Color("#2f79b7")

	var height: int = local_map_state.heights[index]
	if height >= 176:
		return Color("#e0e0d8")
	if height >= 112:
		return Color("#a8a094")
	if height >= 48:
		return Color("#7a8b55")

	var t = inverse_lerp(0.0, 176.0, float(max(0, height)))
	return Color("#5f9b4d").lerp(Color("#b9b06e"), t)

func _tile_color(tile, view_id: int) -> Color:
	match view_id:
		VIEW_ELEVATION:
			return _gradient_color(tile.elevation, Color("#16345f"), Color("#f0f0dc"))
		VIEW_RAINFALL:
			return _gradient_color(tile.rainfall, Color("#d7c176"), Color("#2f78c4"))
		VIEW_TEMPERATURE:
			return _gradient_color(tile.temperature, Color("#4b72c2"), Color("#d45a34"))
		VIEW_RIVER:
			if tile.has_river:
				return Color("#2fb8ff").lerp(Color("#ffffff"), clampf(tile.river_strength, 0.0, 1.0) * 0.35)
			return _gradient_color(tile.elevation, Color("#26394f"), Color("#7f876e"))
		VIEW_FEATURES:
			return _feature_color(tile)
		_:
			return TERRAIN_COLORS.get(tile.terrain_id, Color("#cdbb73"))

func _gradient_color(value: float, low: Color, high: Color) -> Color:
	return low.lerp(high, clampf(value, 0.0, 1.0))

func _feature_color(tile) -> Color:
	if tile.is_mountain():
		return Color("#dddddd")
	if tile.is_hill():
		return Color("#a99062")
	if tile.is_lake():
		return Color("#2f79d0")
	if tile.is_swamp():
		return Color("#3f8d77")
	if tile.has_feature("forest"):
		return Color("#2f7f3f")
	if tile.has_river:
		return Color("#2fb8ff")
	return Color("#444444")

func _update_summary(config) -> void:
	var counts = {
		"ocean": 0,
		"mountain": 0,
		"forest": 0,
		"river": 0
	}
	var elevation_total = 0.0
	for tile in map_state.tiles_by_key.values():
		if tile.terrain_id == "ocean":
			counts["ocean"] += 1
		if tile.is_mountain():
			counts["mountain"] += 1
		if tile.has_feature("forest"):
			counts["forest"] += 1
		if tile.has_river:
			counts["river"] += 1
		elevation_total += tile.elevation

	var total = max(1.0, float(map_state.width * map_state.height))
	summary_label.text = "seed %d | %dx%d | river_count %d | continent_bias %.2f\n海洋 %.1f%%  山脉 %.1f%%  森林 %.1f%%  河流地块 %d  平均海拔 %.2f" % [
		config.seed,
		config.width,
		config.height,
		int(config.generation_params.get("river_count", 0)),
		float(config.generation_params.get("continent_bias", 0.0)),
		float(counts["ocean"]) / total * 100.0,
		float(counts["mountain"]) / total * 100.0,
		float(counts["forest"]) / total * 100.0,
		int(counts["river"]),
		elevation_total / total
	]

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		is_panning = event.pressed
		preview_viewport.accept_event()
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if preview_mode == MODE_WORLD:
			var coord := _tile_from_viewport_position(event.position)
			if coord != Vector2i(-1, -1):
				selected_tile = coord
				_update_selection_marker()
				_show_tile_info(coord)
				preview_viewport.accept_event()
				if event.double_click:
					_show_selected_tile_local_map()
		else:
			var cell := _cell_from_viewport_position(event.position)
			if cell != Vector2i(-1, -1):
				selected_cell = cell
				_update_selection_marker()
				_show_cell_info(cell)
				preview_viewport.accept_event()
		return

	if not event.pressed or not Input.is_key_pressed(KEY_CTRL):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_viewport_position(ZOOM_STEP, event.position)
		preview_viewport.accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_viewport_position(1.0 / ZOOM_STEP, event.position)
		preview_viewport.accept_event()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return
	pan_offset += event.relative
	_clamp_pan_offset()
	_apply_view_transform()
	preview_viewport.accept_event()

func _zoom_at_viewport_position(factor: float, viewport_position: Vector2) -> void:
	var old_zoom := zoom_level
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var focus_from_center := viewport_position - preview_viewport.size / 2.0
	var map_point_before := (focus_from_center - pan_offset) / old_zoom
	zoom_level = new_zoom
	pan_offset = focus_from_center - map_point_before * zoom_level
	_clamp_pan_offset()
	_apply_view_transform()

func _reset_view_deferred() -> void:
	await get_tree().process_frame
	zoom_level = _fit_zoom()
	pan_offset = Vector2.ZERO
	_apply_view_transform()

func _fit_zoom() -> float:
	if base_map_size == Vector2.ZERO or preview_viewport.size.x <= 0.0 or preview_viewport.size.y <= 0.0:
		return 1.0
	return min(preview_viewport.size.x / base_map_size.x, preview_viewport.size.y / base_map_size.y)

func _apply_view_transform() -> void:
	if preview_viewport == null or map_texture == null:
		return
	_clamp_pan_offset()
	var scaled_size := base_map_size * zoom_level
	map_texture.scale = Vector2.ONE * zoom_level
	map_texture.position = preview_viewport.size / 2.0 - scaled_size / 2.0 + pan_offset
	_update_selection_marker()

func _clamp_pan_offset() -> void:
	var scaled_size := base_map_size * zoom_level
	var viewport_size := preview_viewport.size
	var max_offset := Vector2(
		max(0.0, (scaled_size.x - viewport_size.x) / 2.0),
		max(0.0, (scaled_size.y - viewport_size.y) / 2.0)
	)
	pan_offset.x = clampf(pan_offset.x, -max_offset.x, max_offset.x)
	pan_offset.y = clampf(pan_offset.y, -max_offset.y, max_offset.y)

func _tile_from_viewport_position(viewport_position: Vector2) -> Vector2i:
	if map_state == null or base_map_size == Vector2.ZERO or preview_mode != MODE_WORLD:
		return Vector2i(-1, -1)

	var texture_local := (viewport_position - map_texture.position) / zoom_level
	if texture_local.x < 0.0 or texture_local.y < 0.0 or texture_local.x >= base_map_size.x or texture_local.y >= base_map_size.y:
		return Vector2i(-1, -1)

	return Vector2i(
		clampi(int(floor(texture_local.x / BASE_TILE_SIZE)), 0, map_state.width - 1),
		clampi(int(floor(texture_local.y / BASE_TILE_SIZE)), 0, map_state.height - 1)
	)

func _cell_from_viewport_position(viewport_position: Vector2) -> Vector2i:
	if local_map_state == null or base_map_size == Vector2.ZERO or preview_mode != MODE_LOCAL:
		return Vector2i(-1, -1)

	var texture_local := (viewport_position - map_texture.position) / zoom_level
	if texture_local.x < 0.0 or texture_local.y < 0.0 or texture_local.x >= base_map_size.x or texture_local.y >= base_map_size.y:
		return Vector2i(-1, -1)

	return Vector2i(
		clampi(int(floor(texture_local.x / base_map_size.x * float(local_map_state.width))), 0, local_map_state.width - 1),
		clampi(int(floor(texture_local.y / base_map_size.y * float(local_map_state.height))), 0, local_map_state.height - 1)
	)

func _update_selection_marker() -> void:
	if selection_marker == null:
		return
	if preview_mode == MODE_WORLD:
		if map_state == null or selected_tile == Vector2i(-1, -1):
			selection_marker.visible = false
			return
		selection_marker.visible = true
		selection_marker.size = Vector2.ONE * BASE_TILE_SIZE
		selection_marker.scale = Vector2.ONE * zoom_level
		selection_marker.position = map_texture.position + Vector2(selected_tile) * BASE_TILE_SIZE * zoom_level
	else:
		if local_map_state == null or selected_cell == Vector2i(-1, -1):
			selection_marker.visible = false
			return
		var cell_size := base_map_size / Vector2(local_map_state.width, local_map_state.height)
		selection_marker.visible = true
		selection_marker.size = cell_size
		selection_marker.scale = Vector2.ONE * zoom_level
		selection_marker.position = map_texture.position + Vector2(selected_cell) * cell_size * zoom_level

func _show_empty_tile_info() -> void:
	tile_info_label.text = "选中地块：未选择"
	local_map_button.disabled = true

func _show_tile_info(coord: Vector2i) -> void:
	var tile = map_state.get_tile_by_offset(coord.x, coord.y)
	if tile == null:
		_show_empty_tile_info()
		return
	local_map_button.disabled = false

	tile_info_label.text = "选中地块：%d, %d\n地形：%s\n特征：%s\n海拔 %.2f  降水 %.2f\n温度 %.2f  起伏 %.2f\n湿度 %.2f\n河流：%s  强度 %.2f\n流向：%d, %d" % [
		tile.offset.col,
		tile.offset.row,
		tile.terrain_id,
		_feature_text(tile.features),
		tile.elevation,
		tile.rainfall,
		tile.temperature,
		tile.ruggedness,
		tile.moisture,
		"有" if tile.has_river else "无",
		tile.river_strength,
		tile.river_flow.x,
		tile.river_flow.y
	]

func _feature_text(features: PackedStringArray) -> String:
	if features.is_empty():
		return "无"
	return "、".join(Array(features))

func _toggle_local_map() -> void:
	if preview_mode == MODE_LOCAL:
		_show_world_map()
	else:
		_show_selected_tile_local_map()

func _show_selected_tile_local_map() -> void:
	if selected_tile == Vector2i(-1, -1):
		return
	var tile = map_state.get_tile_by_offset(selected_tile.x, selected_tile.y)
	if tile == null:
		return

	local_map_state = LocalMapGeneratorScript.new(int(seed_input.value)).generate(tile)
	preview_mode = MODE_LOCAL
	selected_cell = Vector2i(-1, -1)
	local_map_button.text = "返回大地图"
	view_mode_button.disabled = true
	_render_local_map()
	_update_summary_for_local_map(tile)
	_show_empty_cell_info(tile.tile_key)
	_reset_view_deferred()

func _show_world_map() -> void:
	preview_mode = MODE_WORLD
	local_map_button.text = "查看小地图"
	view_mode_button.disabled = false
	_render_preview()
	_update_summary(_build_config_from_inputs())
	_show_tile_info(selected_tile)
	_reset_view_deferred()

func _update_summary_for_local_map(tile) -> void:
	summary_label.text = "小地图 %s | seed %d | 平均高度 %d" % [
		tile.tile_key,
		int(seed_input.value),
		local_map_state.average_height
	]

func _show_empty_cell_info(tile_key: String) -> void:
	tile_info_label.text = "小地图：%s\n地格：未选择" % tile_key

func _show_cell_info(cell: Vector2i) -> void:
	var index: int = local_map_state.index(cell.x, cell.y)
	tile_info_label.text = "小地图：%s\n地格：%d, %d\n全局坐标：%d, %d\n高度 %d  坡度 %d\n水体：%s  河流：%s" % [
		local_map_state.tile_key,
		cell.x,
		cell.y,
		local_map_state.global_cell_x(cell.x),
		local_map_state.global_cell_y(cell.y),
		local_map_state.heights[index],
		local_map_state.slope_values[index],
		"是" if local_map_state.water_flags[index] == 1 else "否",
		"是" if local_map_state.river_flags[index] == 1 else "否"
	]
