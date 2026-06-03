class_name UIRoot
extends CanvasLayer

signal save_requested
signal load_requested
signal end_turn_requested
signal debug_symbols_toggle_requested
signal return_to_world_requested

@onready var hud_bar: PanelContainer = $Root/HudBar
@onready var tile_info_panel: PanelContainer = $Root/TileInfoPanel

func _ready() -> void:
	hud_bar.save_requested.connect(func() -> void: save_requested.emit())
	hud_bar.load_requested.connect(func() -> void: load_requested.emit())
	hud_bar.end_turn_requested.connect(func() -> void: end_turn_requested.emit())
	hud_bar.debug_symbols_toggle_requested.connect(func() -> void: debug_symbols_toggle_requested.emit())
	hud_bar.return_to_world_requested.connect(func() -> void: return_to_world_requested.emit())
	show_initial_state()

func show_initial_state() -> void:
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
