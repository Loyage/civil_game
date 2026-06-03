class_name MapRoot
extends Node2D

signal tile_selected(tile)

const MapLoaderScript := preload("res://game/scripts/map/map_loader.gd")
const MapQueryServiceScript := preload("res://game/scripts/map/map_query_service.gd")
const MapInputControllerScript := preload("res://game/scripts/map/map_input_controller.gd")
const GridLayoutScript := preload("res://game/scripts/map/grid_layout.gd")
const MapCameraControllerScript := preload("res://game/scripts/map/map_camera_controller.gd")

const TERRAIN_ATLAS := {
	"grassland": Vector2i(0, 0),
	"plains": Vector2i(1, 0),
	"ocean": Vector2i(2, 0),
	"desert": Vector2i(3, 0),
	"tundra": Vector2i(4, 0)
}

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var border_overlay: Node2D = $BorderOverlay
@onready var feature_overlay: Node2D = $FeatureOverlay
@onready var river_overlay: Node2D = $RiverOverlay
@onready var debug_symbol_overlay: Node2D = $DebugSymbolOverlay
@onready var selection_overlay: Node2D = $SelectionOverlay
@onready var city_marker_layer: Node2D = $CityMarkerLayer
@onready var map_camera: Camera2D = $MapCamera

var map_state
var query_service
var input_controller
var show_debug_symbols := true

func _ready() -> void:
	map_state = MapLoaderScript.new().load_generated_map()
	query_service = MapQueryServiceScript.new(map_state)
	input_controller = MapInputControllerScript.new(map_state, terrain_layer, map_camera)
	_setup_tile_set()
	_render_terrain()
	_setup_overlays()
	_setup_camera()
	_emit_initial_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile = input_controller.tile_from_screen_position(event.position)
		if tile != null:
			select_tile(tile)

func _process(_delta: float) -> void:
	feature_overlay.queue_redraw()
	river_overlay.queue_redraw()

func _setup_tile_set() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tile_set.tile_size = GridLayoutScript.TILE_PIXEL_SIZE

	var source := TileSetAtlasSource.new()
	source.texture = _build_terrain_atlas()
	source.texture_region_size = GridLayoutScript.TILE_PIXEL_SIZE

	for atlas_coord in TERRAIN_ATLAS.values():
		source.create_tile(atlas_coord)

	tile_set.add_source(source, 0)
	terrain_layer.tile_set = tile_set

func _build_terrain_atlas() -> Texture2D:
	var tile_size: Vector2i = GridLayoutScript.TILE_PIXEL_SIZE
	var image := Image.create(tile_size.x * TERRAIN_ATLAS.size(), tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	_paint_square_tile(image, 0, Color("#6fb35f"), Color("#4e8b45"))
	_paint_square_tile(image, 1, Color("#cdbb73"), Color("#9f8c4d"))
	_paint_square_tile(image, 2, Color("#3f87c6"), Color("#2769a4"))
	_paint_square_tile(image, 3, Color("#d7c176"), Color("#aa9252"))
	_paint_square_tile(image, 4, Color("#b9c4bd"), Color("#87948d"))

	return ImageTexture.create_from_image(image)

func _paint_square_tile(image: Image, tile_index: int, fill_color: Color, border_color: Color) -> void:
	var tile_size: Vector2i = GridLayoutScript.TILE_PIXEL_SIZE
	var origin_x: int = tile_index * tile_size.x

	for y in range(tile_size.y):
		for x in range(tile_size.x):
			var color := fill_color
			if x == 0 or y == 0 or x == tile_size.x - 1 or y == tile_size.y - 1:
				color = border_color
			elif (x + y + tile_index * 7) % 19 == 0:
				color = fill_color.lightened(0.08)

			image.set_pixel(origin_x + x, y, color)

func _render_terrain() -> void:
	terrain_layer.clear()
	for tile in map_state.tiles_by_key.values():
		var atlas_coord: Vector2i = TERRAIN_ATLAS.get(tile.terrain_id, TERRAIN_ATLAS["plains"])
		terrain_layer.set_cell(tile.offset.to_vector(), 0, atlas_coord, 0)

func _setup_overlays() -> void:
	border_overlay.setup(map_state, terrain_layer, border_overlay.mode)
	feature_overlay.setup(map_state, terrain_layer, map_camera)
	river_overlay.setup(map_state, terrain_layer, map_camera)
	debug_symbol_overlay.setup(map_state, terrain_layer, debug_symbol_overlay.mode)
	selection_overlay.setup(map_state, terrain_layer, selection_overlay.mode)
	city_marker_layer.setup(map_state, terrain_layer, city_marker_layer.mode)

	city_marker_layer.set_city_tile(map_state.start_city_tile_key)
	selection_overlay.set_selected_tile(map_state.start_city_tile_key)
	debug_symbol_overlay.set_selected_tile(map_state.start_city_tile_key)
	_apply_debug_symbol_visibility()

func _setup_camera() -> void:
	var map_pixel_size := Vector2(
		float(map_state.width * GridLayoutScript.TILE_PIXEL_SIZE.x),
		float(map_state.height * GridLayoutScript.TILE_PIXEL_SIZE.y)
	)
	map_camera.setup(map_pixel_size)

func select_tile(tile) -> void:
	selection_overlay.set_selected_tile(tile.tile_key)
	debug_symbol_overlay.set_selected_tile(tile.tile_key)
	tile_selected.emit(tile)

func toggle_debug_symbols() -> void:
	show_debug_symbols = not show_debug_symbols
	_apply_debug_symbol_visibility()

func _apply_debug_symbol_visibility() -> void:
	debug_symbol_overlay.set_debug_symbols_visible(show_debug_symbols)

func _emit_initial_selection() -> void:
	var tile = map_state.get_tile(map_state.start_city_tile_key)
	if tile != null:
		tile_selected.emit(tile)
