class_name MapCameraController
extends Camera2D

const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.10

var map_pixel_size := Vector2.ZERO
var is_panning := false

func setup(init_map_pixel_size: Vector2) -> void:
	map_pixel_size = init_map_pixel_size
	enabled = true
	make_current()
	limit_left = 0
	limit_top = 0
	limit_right = int(map_pixel_size.x)
	limit_bottom = int(map_pixel_size.y)
	position = map_pixel_size / 2.0
	_clamp_to_map()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		is_panning = event.pressed
		get_viewport().set_input_as_handled()
		return

	if not event.pressed or not Input.is_key_pressed(KEY_CTRL):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_mouse(ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_mouse(1.0 / ZOOM_STEP)
		get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return
	position -= event.relative / zoom
	_clamp_to_map()
	get_viewport().set_input_as_handled()

func _zoom_at_mouse(factor: float) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var mouse_before := get_global_mouse_position()
	zoom = Vector2.ONE * new_zoom
	var mouse_after := get_global_mouse_position()
	position += mouse_before - mouse_after
	_clamp_to_map()

func _clamp_to_map() -> void:
	if map_pixel_size == Vector2.ZERO:
		return

	var viewport_size := get_viewport_rect().size / zoom
	var half_viewport := viewport_size / 2.0
	var min_position := half_viewport
	var max_position := map_pixel_size - half_viewport

	if max_position.x < min_position.x:
		position.x = map_pixel_size.x / 2.0
	else:
		position.x = clampf(position.x, min_position.x, max_position.x)

	if max_position.y < min_position.y:
		position.y = map_pixel_size.y / 2.0
	else:
		position.y = clampf(position.y, min_position.y, max_position.y)
