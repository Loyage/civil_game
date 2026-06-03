class_name CoreRoot
extends Node2D

@onready var map_root: Node = $MapRoot
@onready var ui_root: CanvasLayer = $UIRoot

func _ready() -> void:
	map_root.tile_selected.connect(_on_map_tile_selected)
	ui_root.debug_symbols_toggle_requested.connect(_on_debug_symbols_toggle_requested)
	ui_root.show_initial_state()

	var start_tile = map_root.map_state.get_tile(map_root.map_state.start_city_tile_key)
	if start_tile != null:
		ui_root.show_tile(start_tile)

func _on_map_tile_selected(tile) -> void:
	ui_root.show_tile(tile)

func _on_debug_symbols_toggle_requested() -> void:
	map_root.toggle_debug_symbols()
