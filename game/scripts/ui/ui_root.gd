class_name UIRoot
extends CanvasLayer

signal save_requested
signal load_requested
signal end_turn_requested
signal debug_symbols_toggle_requested
signal return_to_world_requested
signal new_game_config_confirmed(config)

const USER_CONFIG_PATH := "user://map_generation_config.json"
const DEFAULT_CONFIG_PATH := "res://game/data/maps/map_generation_config.json"
const MapGenerationConfigScript := preload("res://game/scripts/map_generation/map_generation_config.gd")
const MapGeneratorScript := preload("res://game/scripts/map_generation/map_generator.gd")

const TERRAIN_COLORS := {
	"grassland": Color("#6fb35f"),
	"plain": Color("#cdbb73"),
	"ocean": Color("#3f87c6"),
	"desert": Color("#d7c176"),
	"tundra": Color("#b9c4bd"),
	"forest": Color("#2f7f3f"),
	"rainforest": Color("#1f6f3a"),
	"hill": Color("#a99062"),
	"mountain": Color("#b8b8b0"),
	"snow_mountain": Color("#dddddd"),
	"river": Color("#2fb8ff")
}

@onready var hud_bar: PanelContainer = $Root/HudBar
@onready var tile_info_panel: PanelContainer = $Root/TileInfoPanel
@onready var root: Control = $Root

var main_menu: Control
var map_setup: Control
var seed_input: SpinBox
var map_size_input: SpinBox
var sub_map_size_input: SpinBox
var ocean_ratio_input: SpinBox
var mountain_count_input: SpinBox
var river_source_count_input: SpinBox
var continent_bias_input: SpinBox
var preview_texture: TextureRect
var setup_summary_label: Label
var setup_status_label: Label
var current_preview_map_state
var current_preview_config

func _ready() -> void:
	_build_main_menu()
	_build_map_setup()
	hud_bar.save_requested.connect(func() -> void: save_requested.emit())
	hud_bar.load_requested.connect(func() -> void: load_requested.emit())
	hud_bar.end_turn_requested.connect(func() -> void: end_turn_requested.emit())
	hud_bar.debug_symbols_toggle_requested.connect(func() -> void: debug_symbols_toggle_requested.emit())
	hud_bar.return_to_world_requested.connect(func() -> void: return_to_world_requested.emit())
	_load_inputs_from_config(_load_config_from_path(DEFAULT_CONFIG_PATH))
	show_main_menu()

func show_main_menu() -> void:
	main_menu.visible = true
	map_setup.visible = false
	hud_bar.visible = false
	tile_info_panel.visible = false

func show_initial_state() -> void:
	main_menu.visible = false
	map_setup.visible = false
	hud_bar.visible = true
	tile_info_panel.visible = true
	hud_bar.show_initial_state()
	tile_info_panel.show_empty()

func show_tile(tile) -> void:
	hud_bar.show_world_mode()
	hud_bar.show_selected_tile(tile)
	tile_info_panel.show_tile(tile)

func show_local_map(tile_key: String) -> void:
	hud_bar.show_local_map_mode(tile_key)
	tile_info_panel.show_local_cell_empty(tile_key)

func show_local_cell(cell_info: Dictionary) -> void:
	tile_info_panel.show_local_cell(cell_info)

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.name = "MainMenu"
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(main_menu)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#181b18")
	main_menu.add_child(background)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 360)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -180
	panel.offset_right = 210
	panel.offset_bottom = 180
	panel.add_theme_stylebox_override("panel", _panel_style())
	main_menu.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.text = "文明原型"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	var start_button := _menu_button("开始游戏")
	start_button.pressed.connect(_show_map_setup)
	column.add_child(start_button)

	var load_game_button := _menu_button("读取游戏")
	load_game_button.disabled = true
	load_game_button.tooltip_text = "暂未实现"
	column.add_child(load_game_button)

	var quit_button := _menu_button("退出")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit_button)

func _build_map_setup() -> void:
	map_setup = Control.new()
	map_setup.name = "MapSetup"
	map_setup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_setup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(map_setup)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#101411")
	map_setup.add_child(background)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_top = 16
	row.offset_right = -16
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 16)
	map_setup.add_child(row)

	var controls_panel := PanelContainer.new()
	controls_panel.custom_minimum_size = Vector2(340, 0)
	controls_panel.add_theme_stylebox_override("panel", _panel_style())
	row.add_child(controls_panel)

	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 14)
	controls_margin.add_theme_constant_override("margin_top", 14)
	controls_margin.add_theme_constant_override("margin_right", 14)
	controls_margin.add_theme_constant_override("margin_bottom", 14)
	controls_panel.add_child(controls_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	controls_margin.add_child(column)

	var title := Label.new()
	title.text = "地图选择"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	seed_input = _add_spin_box(column, "Seed", 1, 999999999, 1, 260603)
	map_size_input = _add_spin_box(column, "大地图尺寸", 8, 256, 1, 40)
	sub_map_size_input = _add_spin_box(column, "小地图边长", 32, 512, 1, 64)
	ocean_ratio_input = _add_spin_box(column, "海洋比例", 0, 0.95, 0.01, 0.3)
	mountain_count_input = _add_spin_box(column, "山脉数量", 0, 64, 1, 6)
	river_source_count_input = _add_spin_box(column, "河流源数量", 0, 64, 1, 8)
	continent_bias_input = _add_spin_box(column, "大陆倾向", 0, 2, 0.01, 0.42)
	for input in [seed_input, map_size_input, sub_map_size_input, ocean_ratio_input, mountain_count_input, river_source_count_input, continent_bias_input]:
		input.value_changed.connect(func(_value: float) -> void: _mark_preview_stale())

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 8)
	button_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(button_grid)

	var generate_button := Button.new()
	generate_button.text = "生成预览"
	generate_button.pressed.connect(_generate_preview)
	button_grid.add_child(generate_button)

	var random_seed_button := Button.new()
	random_seed_button.text = "随机 Seed"
	random_seed_button.pressed.connect(func() -> void: seed_input.value = randi_range(1, 999999999))
	button_grid.add_child(random_seed_button)

	var save_config_button := Button.new()
	save_config_button.text = "保存参数"
	save_config_button.pressed.connect(_save_current_config)
	button_grid.add_child(save_config_button)

	var load_config_button := Button.new()
	load_config_button.text = "读取参数"
	load_config_button.pressed.connect(_load_user_config)
	button_grid.add_child(load_config_button)

	var start_button := Button.new()
	start_button.text = "开始本局"
	start_button.pressed.connect(_confirm_current_config)
	column.add_child(start_button)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.pressed.connect(show_main_menu)
	column.add_child(back_button)

	setup_status_label = Label.new()
	setup_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_status_label.text = "调整参数后生成预览。"
	column.add_child(setup_status_label)

	setup_summary_label = Label.new()
	setup_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_summary_label.text = "-"
	column.add_child(setup_summary_label)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _panel_style())
	row.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 12)
	preview_margin.add_theme_constant_override("margin_top", 12)
	preview_margin.add_theme_constant_override("margin_right", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 12)
	preview_panel.add_child(preview_margin)

	preview_texture = TextureRect.new()
	preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_margin.add_child(preview_texture)

func _show_map_setup() -> void:
	main_menu.visible = false
	map_setup.visible = true
	hud_bar.visible = false
	tile_info_panel.visible = false
	if current_preview_map_state == null:
		setup_status_label.text = "调整参数后点击生成预览。"
		setup_summary_label.text = "-"
		preview_texture.texture = null

func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 64)
	button.text = text
	button.add_theme_font_size_override("font_size", 22)
	return button

func _add_spin_box(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin_box := SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = step
	spin_box.value = value
	spin_box.rounded = is_equal_approx(step, 1.0)
	parent.add_child(spin_box)
	return spin_box

func _generate_preview() -> void:
	current_preview_config = _build_config_from_inputs()
	current_preview_map_state = MapGeneratorScript.new().generate(current_preview_config)
	_apply_auto_start_city(current_preview_map_state, current_preview_config)
	_render_preview_map()
	_update_setup_summary()
	setup_status_label.text = "预览已生成。"

func _render_preview_map() -> void:
	if current_preview_map_state == null:
		preview_texture.texture = null
		return
	var image = Image.create(current_preview_map_state.width, current_preview_map_state.height, false, Image.FORMAT_RGBA8)
	for row_index in range(current_preview_map_state.height):
		for col_index in range(current_preview_map_state.width):
			var tile = current_preview_map_state.get_tile_by_offset(col_index, row_index)
			var color: Color = TERRAIN_COLORS.get(tile.biome, Color("#cdbb73"))
			if tile.tile_key == current_preview_map_state.start_city_tile_key:
				color = Color("#f2d76b")
			image.set_pixel(col_index, row_index, color)
	preview_texture.texture = ImageTexture.create_from_image(image)

func _update_setup_summary() -> void:
	if current_preview_map_state == null:
		setup_summary_label.text = "-"
		return
	var ocean_count := 0
	var mountain_count := 0
	var river_count := 0
	for tile in current_preview_map_state.tiles_by_key.values():
		if tile.biome == "ocean":
			ocean_count += 1
		if tile.is_mountain():
			mountain_count += 1
		if tile.has_river:
			river_count += 1
	var start_tile = current_preview_map_state.get_tile(current_preview_map_state.start_city_tile_key)
	var total: float = maxf(1.0, float(current_preview_map_state.width * current_preview_map_state.height))
	setup_summary_label.text = "seed %d | %dx%d | 海洋 %.1f%% | 山脉 %.1f%% | 河流地块 %d\n建议起始地块：%d, %d" % [
		current_preview_config.seed,
		current_preview_config.big_map_size,
		current_preview_config.big_map_size,
		float(ocean_count) / total * 100.0,
		float(mountain_count) / total * 100.0,
		river_count,
		start_tile.offset.col if start_tile != null else -1,
		start_tile.offset.row if start_tile != null else -1
	]

func _build_config_from_inputs():
	var config = MapGenerationConfigScript.new()
	config.seed = int(seed_input.value)
	config.big_map_size = int(map_size_input.value)
	config.width = config.big_map_size
	config.height = config.big_map_size
	config.sub_map_size = int(sub_map_size_input.value)
	config.ocean_ratio = float(ocean_ratio_input.value)
	config.mountain_count = int(mountain_count_input.value)
	config.river_source_count = int(river_source_count_input.value)
	config.generation_params["continent_bias"] = float(continent_bias_input.value)
	config.generated_output_path = "user://generated_map.json"
	config.start_city_col = int(config.big_map_size / 2)
	config.start_city_row = int(config.big_map_size / 2)
	config.start_city_name = "Capital"
	return config

func _confirm_current_config() -> void:
	current_preview_config = _build_config_from_inputs()
	new_game_config_confirmed.emit(current_preview_config)

func _save_current_config() -> void:
	var config = _build_config_from_inputs()
	var file := FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		setup_status_label.text = "保存参数失败。"
		return
	file.store_string(JSON.stringify(config.to_dictionary(), "\t"))
	setup_status_label.text = "参数已保存到 user://map_generation_config.json。"

func _load_user_config() -> void:
	var config = _load_config_from_path(USER_CONFIG_PATH)
	if config == null:
		setup_status_label.text = "未找到已保存的参数。"
		return
	_load_inputs_from_config(config)
	current_preview_map_state = null
	current_preview_config = null
	setup_status_label.text = "参数已读取，点击生成预览查看结果。"
	setup_summary_label.text = "-"
	preview_texture.texture = null

func _mark_preview_stale() -> void:
	current_preview_config = null
	current_preview_map_state = null
	if setup_status_label != null:
		setup_status_label.text = "参数已变更，点击生成预览查看结果。"

func _load_config_from_path(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		return null
	var config = MapGenerationConfigScript.new()
	config.load_from_dictionary(json.data)
	return config

func _load_inputs_from_config(config) -> void:
	if config == null:
		return
	seed_input.value = config.seed
	map_size_input.value = config.big_map_size
	sub_map_size_input.value = config.sub_map_size
	ocean_ratio_input.value = config.ocean_ratio
	mountain_count_input.value = config.mountain_count
	river_source_count_input.value = config.river_source_count
	continent_bias_input.value = float(config.generation_params.get("continent_bias", 0.42))

func _apply_auto_start_city(map_state, config) -> void:
	if map_state == null:
		return
	var tile = _find_start_city_tile(map_state)
	if tile == null:
		return
	for existing_tile in map_state.tiles_by_key.values():
		existing_tile.is_city_center = false
		existing_tile.owner_city_id = ""
	tile.is_city_center = true
	tile.owner_city_id = "player_capital"
	map_state.start_city_tile_key = tile.tile_key
	map_state.start_city_name = "Capital"
	config.start_city_col = tile.offset.col
	config.start_city_row = tile.offset.row
	config.start_city_name = "Capital"

func _find_start_city_tile(map_state):
	var center := Vector2((float(map_state.width) - 1.0) * 0.5, (float(map_state.height) - 1.0) * 0.5)
	var best_tile = null
	var best_score := INF
	for tile in map_state.tiles_by_key.values():
		if tile.biome == "ocean" or tile.is_mountain():
			continue
		var score := Vector2(float(tile.offset.col), float(tile.offset.row)).distance_squared_to(center)
		if tile.has_river:
			score -= 8.0
		if tile.has_feature("forest"):
			score -= 3.0
		if tile.is_hill():
			score += 6.0
		if tile.elevation < 0:
			score += 20.0
		if score < best_score:
			best_score = score
			best_tile = tile
	if best_tile != null:
		return best_tile
	return map_state.get_tile_by_offset(int(map_state.width / 2), int(map_state.height / 2))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#d8c28ccc")
	style.border_color = Color("#5c3f22")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
