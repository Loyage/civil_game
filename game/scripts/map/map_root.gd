class_name MapRoot
extends Node2D

const MapLoaderScript := preload("res://game/scripts/map/map_loader.gd")
const MapQueryServiceScript := preload("res://game/scripts/map/map_query_service.gd")
const MapInputControllerScript := preload("res://game/scripts/map/map_input_controller.gd")
const HexLayoutScript := preload("res://game/scripts/map/hex_layout.gd")

const TERRAIN_ATLAS := {
	"grassland": Vector2i(0, 0),
	"plains": Vector2i(1, 0),
	"ocean": Vector2i(2, 0),
	"mountain": Vector2i(3, 0)
}

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var border_overlay: Node2D = $BorderOverlay
@onready var river_overlay: Node2D = $RiverOverlay
@onready var selection_overlay: Node2D = $SelectionOverlay
@onready var city_marker_layer: Node2D = $CityMarkerLayer

var map_state
var query_service
var input_controller

func _ready() -> void:
	map_state = MapLoaderScript.new().load_start_map()
	query_service = MapQueryServiceScript.new(map_state)
	input_controller = MapInputControllerScript.new(map_state, terrain_layer)
	_setup_tile_set()
	_render_terrain()
	_setup_overlays()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile = input_controller.tile_from_global_position(event.global_position)
		if tile != null:
			selection_overlay.set_selected_tile(tile.tile_key)

func _setup_tile_set() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = HexLayoutScript.TILE_PIXEL_SIZE

	var source := TileSetAtlasSource.new()
	source.texture = _build_terrain_atlas()
	source.texture_region_size = HexLayoutScript.TILE_PIXEL_SIZE

	for atlas_coord in TERRAIN_ATLAS.values():
		source.create_tile(atlas_coord)

	tile_set.add_source(source, 0)
	terrain_layer.tile_set = tile_set

func _build_terrain_atlas() -> Texture2D:
	var tile_size: Vector2i = HexLayoutScript.TILE_PIXEL_SIZE
	var image := Image.create(tile_size.x * TERRAIN_ATLAS.size(), tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	_paint_hex_tile(image, 0, Color("#6fb35f"), Color("#4e8b45"))
	_paint_hex_tile(image, 1, Color("#cdbb73"), Color("#9f8c4d"))
	_paint_hex_tile(image, 2, Color("#3f87c6"), Color("#2769a4"))
	_paint_hex_tile(image, 3, Color("#8f9293"), Color("#5e6264"))

	return ImageTexture.create_from_image(image)

func _paint_hex_tile(image: Image, tile_index: int, fill_color: Color, border_color: Color) -> void:
	var tile_size: Vector2i = HexLayoutScript.TILE_PIXEL_SIZE
	var origin_x: int = tile_index * tile_size.x
	var center := Vector2(origin_x + tile_size.x / 2.0, tile_size.y / 2.0)
	var radius := 42.0

	for y in range(tile_size.y):
		for x in range(tile_size.x):
			var point := Vector2(origin_x + x, y)
			var local := point - center
			var q: float = abs(local.x) / radius
			var r: float = abs(local.y) / (radius * 0.8660254)
			var inside: bool = q <= 1.0 and r <= 1.0 and q + r * 0.5 <= 1.0
			if not inside:
				continue

			var color := fill_color
			if q > 0.88 or r > 0.88 or q + r * 0.5 > 0.92:
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
	for overlay in [border_overlay, river_overlay, selection_overlay, city_marker_layer]:
		overlay.setup(map_state, terrain_layer, overlay.mode)

	city_marker_layer.set_city_tile(map_state.start_city_tile_key)
	selection_overlay.set_selected_tile(map_state.start_city_tile_key)
