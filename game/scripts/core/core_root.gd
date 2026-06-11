class_name CoreRoot
extends Node2D

const LocalMapServiceScript := preload("res://game/scripts/local_map/local_map_service.gd")

@onready var map_root: Node = $MapRoot
@onready var ui_root: CanvasLayer = $UIRoot
@onready var local_map_root: CanvasLayer = $LocalMapRoot

var local_map_service
var selected_tile

func _ready() -> void:
	map_root.tile_selected.connect(_on_map_tile_selected)
	map_root.tile_enter_requested.connect(_on_map_tile_enter_requested)
	ui_root.new_game_config_confirmed.connect(_on_new_game_config_confirmed)
	ui_root.debug_symbols_toggle_requested.connect(_on_debug_symbols_toggle_requested)
	ui_root.return_to_world_requested.connect(_on_return_to_world_requested)
	local_map_root.return_to_world_requested.connect(_on_return_to_world_requested)
	local_map_root.local_cell_selected.connect(_on_local_cell_selected)
	ui_root.show_main_menu()

func _on_new_game_config_confirmed(config) -> void:
	map_root.start_new_game(config)
	local_map_service = LocalMapServiceScript.new(_world_seed())
	ui_root.show_initial_state()
	var start_tile = map_root.map_state.get_tile(map_root.map_state.start_city_tile_key)
	if start_tile != null:
		selected_tile = start_tile
		ui_root.show_tile(start_tile)

func _on_map_tile_selected(tile) -> void:
	selected_tile = tile
	ui_root.show_tile(tile)

func _on_debug_symbols_toggle_requested() -> void:
	map_root.toggle_debug_symbols()

func _on_map_tile_enter_requested(tile) -> void:
	selected_tile = tile
	var local_map_state = local_map_service.load_or_generate(tile)
	map_root.visible = false
	map_root.process_mode = Node.PROCESS_MODE_DISABLED
	local_map_root.show_local_map(local_map_state)
	ui_root.show_local_map(tile.tile_key)

func _on_local_cell_selected(cell_info: Dictionary) -> void:
	ui_root.show_local_cell(cell_info)

func _on_return_to_world_requested() -> void:
	local_map_root.hide_local_map()
	map_root.process_mode = Node.PROCESS_MODE_INHERIT
	map_root.visible = true
	if selected_tile != null:
		ui_root.show_tile(selected_tile)

func _world_seed() -> int:
	return int(map_root.map_state.world_seed)
