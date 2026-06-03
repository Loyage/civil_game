class_name HudBar
extends PanelContainer

signal save_requested
signal load_requested
signal end_turn_requested
signal debug_symbols_toggle_requested

@onready var turn_label: Label = %TurnLabel
@onready var gold_label: Label = %GoldLabel
@onready var selected_tile_label: Label = %SelectedTileLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var debug_symbols_button: Button = %DebugSymbolsButton

func _ready() -> void:
	_apply_panel_style()
	save_button.disabled = true
	load_button.disabled = true
	end_turn_button.disabled = true
	save_button.tooltip_text = "暂未实现"
	load_button.tooltip_text = "暂未实现"
	end_turn_button.tooltip_text = "暂未实现"
	save_button.pressed.connect(func() -> void: save_requested.emit())
	load_button.pressed.connect(func() -> void: load_requested.emit())
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	debug_symbols_button.pressed.connect(func() -> void: debug_symbols_toggle_requested.emit())

func show_initial_state() -> void:
	turn_label.text = "回合 1"
	gold_label.text = "金币 0"
	selected_tile_label.text = "选中：未选择"

func show_selected_tile(tile) -> void:
	selected_tile_label.text = "选中：%d, %d" % [tile.offset.col, tile.offset.row]

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#d8c28ccc")
	panel_style.border_color = Color("#5c3f22")
	panel_style.border_width_bottom = 3
	add_theme_stylebox_override("panel", panel_style)
