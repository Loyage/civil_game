class_name MapGeneratorPreview
extends Control

const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const MapGeneratorScript := preload("res://game/scripts/map_generation/map_generator.gd")

const VIEW_TERRAIN := 0
const VIEW_ELEVATION := 1
const VIEW_RAINFALL := 2
const VIEW_TEMPERATURE := 3
const VIEW_RIVER := 4
const VIEW_FEATURES := 5

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
@onready var map_texture: TextureRect = %MapTexture
@onready var summary_label: Label = %SummaryLabel

var map_state

func _ready() -> void:
	_setup_view_modes()
	generate_button.pressed.connect(_generate_preview)
	random_seed_button.pressed.connect(_randomize_seed)
	view_mode_button.item_selected.connect(func(_index: int) -> void: _render_preview())
	_generate_preview()

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
	_render_preview()
	_update_summary(config)

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

	var image = Image.create(map_state.width, map_state.height, false, Image.FORMAT_RGBA8)
	var view_id = view_mode_button.get_selected_id()
	for row in range(map_state.height):
		for col in range(map_state.width):
			var tile = map_state.get_tile_by_offset(col, row)
			image.set_pixel(col, row, _tile_color(tile, view_id))

	map_texture.texture = ImageTexture.create_from_image(image)

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
