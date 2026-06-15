class_name TileInfoPanel
extends PanelContainer

const ResourceDefinitionCatalogScript := preload("res://game/scripts/resources/resource_definition_catalog.gd")

const TERRAIN_NAMES := {
	"grassland": "草地",
	"plain": "平原",
	"ocean": "海洋",
	"desert": "荒漠",
	"tundra": "苔原",
	"forest": "森林",
	"rainforest": "雨林",
	"hill": "丘陵",
	"mountain": "山脉",
	"snow_mountain": "雪山",
	"river": "河流"
}

const FEATURE_NAMES := {
	"mountain": "山脉",
	"hill": "丘陵",
	"lake": "湖泊",
	"swamp": "沼泽",
	"forest": "森林"
}

@onready var title_label: Label = %TitleLabel
@onready var coord_label: Label = %CoordLabel
@onready var terrain_label: Label = %TerrainLabel
@onready var features_label: Label = %FeaturesLabel
@onready var river_label: Label = %RiverLabel
@onready var environment_label: Label = %EnvironmentLabel

var resource_catalog

func _ready() -> void:
	resource_catalog = ResourceDefinitionCatalogScript.new()
	_apply_panel_style()

func show_tile(tile) -> void:
	title_label.text = "地块信息"
	coord_label.text = "坐标：%d, %d" % [tile.offset.col, tile.offset.row]
	terrain_label.text = "生物群系：%s" % TERRAIN_NAMES.get(tile.biome, tile.biome)
	features_label.text = "标签：%s\n资源：%s" % [_feature_text(tile.terrain_tags), resource_catalog.display_names(tile.resource_ids)]
	river_label.text = "河流：%s" % _river_text(tile)
	environment_label.text = "海拔 %d  最低 %d  最高 %d\n温度 %.2f  湿度 %.2f" % [
		tile.elevation,
		tile.min_height,
		tile.max_height,
		tile.temperature,
		tile.moisture
	]

func show_empty() -> void:
	title_label.text = "地块信息"
	coord_label.text = "坐标：未选择"
	terrain_label.text = "基础地形：-"
	features_label.text = "特征：-"
	river_label.text = "河流：-"
	environment_label.text = "海拔 -  降水 -\n温度 -  起伏 -"

func show_local_cell_empty(tile_key: String) -> void:
	title_label.text = "地格信息"
	coord_label.text = "地格：未选择"
	terrain_label.text = "全局坐标：-"
	features_label.text = "所属地块：%s" % tile_key
	river_label.text = "水体：-  河流：-"
	environment_label.text = "高度 -  坡度 -"

func show_local_cell(cell_info: Dictionary) -> void:
	title_label.text = "地格信息"
	coord_label.text = "地格：%d, %d" % [int(cell_info.get("x", 0)), int(cell_info.get("y", 0))]
	terrain_label.text = "全局坐标：%d, %d" % [int(cell_info.get("global_x", 0)), int(cell_info.get("global_y", 0))]
	features_label.text = "所属地块：%s\n地貌：%s\n资源：%s" % [
		String(cell_info.get("tile_key", "")),
		String(cell_info.get("terrain_labels", "无")),
		String(cell_info.get("resource_labels", "无"))
	]
	river_label.text = "水体：%s  河流：%s" % [
		"是" if bool(cell_info.get("is_water", false)) else "否",
		"是" if bool(cell_info.get("has_river", false)) else "否"
	]
	environment_label.text = "高度 %d  坡度 %d" % [
		int(cell_info.get("height", 0)),
		int(cell_info.get("slope", 0))
	]

func _feature_text(features: PackedStringArray) -> String:
	if features.is_empty():
		return "无"

	var names: Array[String] = []
	for feature in features:
		names.append(FEATURE_NAMES.get(feature, feature))
	return "、".join(names)

func _river_text(tile) -> String:
	if not tile.has_river:
		return "无"
	return "有，强度 %.2f" % tile.river_strength

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#e3cf9ee0")
	panel_style.border_color = Color("#5c3f22")
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel_style)
