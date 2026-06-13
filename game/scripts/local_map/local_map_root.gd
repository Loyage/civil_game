class_name LocalMapRoot
extends CanvasLayer

signal return_to_world_requested
signal local_cell_selected(cell_info)

const MIN_ZOOM := 0.5
const MAX_ZOOM := 8.0
const ZOOM_STEP := 1.10
const BASE_MAP_DISPLAY_SIZE := Vector2(640.0, 640.0)

@onready var root: Control = $Root
@onready var map_viewport: Control = %MapViewport
@onready var map_texture: TextureRect = %MapTexture
@onready var hover_marker: ColorRect = %HoverMarker
@onready var selection_marker: ColorRect = %SelectionMarker
@onready var title_label: Label = %TitleLabel

var local_map_state
var zoom_level := 1.0
var pan_offset := Vector2.ZERO
var is_panning := false
var selected_cell := Vector2i(-1, -1)
var hovered_cell := Vector2i(-1, -1)

func _ready() -> void:
	visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_viewport.resized.connect(_apply_view_transform)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func show_local_map(state) -> void:
	local_map_state = state
	selected_cell = Vector2i(-1, -1)
	hovered_cell = Vector2i(-1, -1)
	visible = true
	_render()
	_update_cell_markers()
	_reset_view_deferred()

func hide_local_map() -> void:
	visible = false
	is_panning = false

func request_return_to_world() -> void:
	return_to_world_requested.emit()

func _render() -> void:
	if local_map_state == null:
		return

	title_label.text = "小地图：%s  平均高度：%d" % [local_map_state.tile_key, local_map_state.average_height]
	var image = Image.create(local_map_state.width, local_map_state.height, false, Image.FORMAT_RGBA8)
	for y in range(local_map_state.height):
		for x in range(local_map_state.width):
			var index: int = local_map_state.index(x, y)
			image.set_pixel(x, y, _cell_color(index))
	map_texture.texture = ImageTexture.create_from_image(image)
	map_texture.size = BASE_MAP_DISPLAY_SIZE

func _cell_color(index: int) -> Color:
	if local_map_state.river_flags[index] == 1:
		return Color("#2fb8ff")
	if local_map_state.water_flags[index] == 1:
		return Color("#2f79b7")
	if local_map_state.terrain_flags.size() == local_map_state.heights.size():
		return _terrain_color(int(local_map_state.terrain_flags[index]), int(local_map_state.heights[index]))

	var height: int = local_map_state.heights[index]
	if height >= 176:
		return Color("#e0e0d8")
	if height >= 112:
		return Color("#a8a094")
	if height >= 48:
		return Color("#7a8b55")

	var t = inverse_lerp(0.0, 176.0, float(max(0, height)))
	return Color("#5f9b4d").lerp(Color("#b9b06e"), t)

func _terrain_color(flags: int, height: int) -> Color:
	if (flags & LocalMapState.TERRAIN_SNOW) != 0:
		return Color("#e8edf0")
	if (flags & LocalMapState.TERRAIN_WETLAND) != 0:
		return Color("#4f8d77")
	if (flags & LocalMapState.TERRAIN_FOREST) != 0:
		return Color("#286f3a")
	if (flags & LocalMapState.TERRAIN_ROCK) != 0:
		return Color("#8f8a7f")
	if (flags & LocalMapState.TERRAIN_SAND) != 0:
		return Color("#d8bf73")
	if (flags & LocalMapState.TERRAIN_GRASS) != 0:
		return Color("#6eaa55")
	var t: float = inverse_lerp(0.0, 176.0, float(max(0, height)))
	return Color("#5f9b4d").lerp(Color("#b9b06e"), t)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		is_panning = event.pressed and _is_in_map_viewport(event.position)
		if is_panning or not event.pressed:
			get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_in_map_viewport(event.position):
		var cell = _cell_from_screen_position(event.position)
		if cell != Vector2i(-1, -1):
			selected_cell = cell
			_update_cell_markers()
			local_cell_selected.emit(_cell_info(cell))
			get_viewport().set_input_as_handled()
		return

	if not event.pressed or not Input.is_key_pressed(KEY_CTRL) or not _is_in_map_viewport(event.position):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_screen_position(ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_screen_position(1.0 / ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		if _is_in_map_viewport(event.position):
			hovered_cell = _cell_from_screen_position(event.position)
		else:
			hovered_cell = Vector2i(-1, -1)
		_update_cell_markers()
		return
	pan_offset += event.relative
	_clamp_pan_offset()
	_apply_view_transform()
	_update_cell_markers()
	get_viewport().set_input_as_handled()

func _zoom_at_screen_position(factor: float, screen_position: Vector2) -> void:
	var old_zoom := zoom_level
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var viewport_center := map_viewport.global_position + map_viewport.size / 2.0
	var focus_from_center := screen_position - viewport_center
	var map_point_before := (focus_from_center - pan_offset) / old_zoom
	zoom_level = new_zoom
	pan_offset = focus_from_center - map_point_before * zoom_level
	_clamp_pan_offset()
	_apply_view_transform()
	_update_cell_markers()

func _reset_view_deferred() -> void:
	await get_tree().process_frame
	zoom_level = _fit_zoom()
	pan_offset = Vector2.ZERO
	_apply_view_transform()

func _fit_zoom() -> float:
	var viewport_size := map_viewport.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return min(viewport_size.x / BASE_MAP_DISPLAY_SIZE.x, viewport_size.y / BASE_MAP_DISPLAY_SIZE.y)

func _apply_view_transform() -> void:
	if map_texture == null or map_viewport == null:
		return
	_clamp_pan_offset()
	var scaled_size := BASE_MAP_DISPLAY_SIZE * zoom_level
	map_texture.scale = Vector2.ONE * zoom_level
	map_texture.position = map_viewport.size / 2.0 - scaled_size / 2.0 + pan_offset
	_update_cell_markers()

func _clamp_pan_offset() -> void:
	var scaled_size := BASE_MAP_DISPLAY_SIZE * zoom_level
	var viewport_size := map_viewport.size
	var max_offset := Vector2(
		max(0.0, (scaled_size.x - viewport_size.x) / 2.0),
		max(0.0, (scaled_size.y - viewport_size.y) / 2.0)
	)
	pan_offset.x = clampf(pan_offset.x, -max_offset.x, max_offset.x)
	pan_offset.y = clampf(pan_offset.y, -max_offset.y, max_offset.y)

func _is_in_map_viewport(screen_position: Vector2) -> bool:
	return map_viewport.get_global_rect().has_point(screen_position)

func _cell_from_screen_position(screen_position: Vector2) -> Vector2i:
	if local_map_state == null:
		return Vector2i(-1, -1)
	var texture_local := (screen_position - map_texture.global_position) / zoom_level
	if texture_local.x < 0.0 or texture_local.y < 0.0 or texture_local.x >= BASE_MAP_DISPLAY_SIZE.x or texture_local.y >= BASE_MAP_DISPLAY_SIZE.y:
		return Vector2i(-1, -1)

	return Vector2i(
		clampi(int(floor(texture_local.x / BASE_MAP_DISPLAY_SIZE.x * float(local_map_state.width))), 0, local_map_state.width - 1),
		clampi(int(floor(texture_local.y / BASE_MAP_DISPLAY_SIZE.y * float(local_map_state.height))), 0, local_map_state.height - 1)
	)

func _cell_info(cell: Vector2i) -> Dictionary:
	var cell_state = local_map_state.cell_state_at(cell.x, cell.y)
	return {
		"tile_key": local_map_state.tile_key,
		"x": cell_state.x,
		"y": cell_state.y,
		"global_x": cell_state.global_x,
		"global_y": cell_state.global_y,
		"height": cell_state.height,
		"is_water": cell_state.is_water,
		"has_river": cell_state.has_river,
		"terrain_flags": cell_state.terrain_flags,
		"terrain_labels": _terrain_text(cell_state.terrain_flags),
		"slope": cell_state.slope
	}

func _terrain_text(flags: int) -> String:
	var labels: Array[String] = []
	if (flags & LocalMapState.TERRAIN_GRASS) != 0:
		labels.append("草地")
	if (flags & LocalMapState.TERRAIN_FOREST) != 0:
		labels.append("森林")
	if (flags & LocalMapState.TERRAIN_WETLAND) != 0:
		labels.append("湿地")
	if (flags & LocalMapState.TERRAIN_ROCK) != 0:
		labels.append("岩石")
	if (flags & LocalMapState.TERRAIN_SAND) != 0:
		labels.append("沙地")
	if (flags & LocalMapState.TERRAIN_SNOW) != 0:
		labels.append("雪地")
	if labels.is_empty():
		return "无"
	return "、".join(labels)

func _update_cell_markers() -> void:
	_update_marker(hover_marker, hovered_cell)
	_update_marker(selection_marker, selected_cell)

func _update_marker(marker: ColorRect, cell: Vector2i) -> void:
	if marker == null:
		return
	if local_map_state == null or cell == Vector2i(-1, -1):
		marker.visible = false
		return

	var cell_size := BASE_MAP_DISPLAY_SIZE / Vector2(local_map_state.width, local_map_state.height)
	marker.visible = true
	marker.size = cell_size
	marker.scale = Vector2.ONE * zoom_level
	marker.position = map_texture.position + Vector2(cell) * cell_size * zoom_level
