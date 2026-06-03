class_name TileInfoPanel
extends PanelContainer

const TERRAIN_NAMES := {
	"grassland": "草地",
	"plains": "平原",
	"ocean": "海洋",
	"desert": "荒漠",
	"tundra": "苔原"
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

func _ready() -> void:
	_apply_panel_style()

func show_tile(tile) -> void:
	title_label.text = "地块信息"
	coord_label.text = "坐标：%d, %d" % [tile.offset.col, tile.offset.row]
	terrain_label.text = "基础地形：%s" % TERRAIN_NAMES.get(tile.terrain_id, tile.terrain_id)
	features_label.text = "特征：%s" % _feature_text(tile.features)
	river_label.text = "河流：%s" % _river_text(tile)
	environment_label.text = "海拔 %.2f  降水 %.2f\n温度 %.2f  起伏 %.2f" % [
		tile.elevation,
		tile.rainfall,
		tile.temperature,
		tile.ruggedness
	]

func show_empty() -> void:
	title_label.text = "地块信息"
	coord_label.text = "坐标：未选择"
	terrain_label.text = "基础地形：-"
	features_label.text = "特征：-"
	river_label.text = "河流：-"
	environment_label.text = "海拔 -  降水 -\n温度 -  起伏 -"

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
