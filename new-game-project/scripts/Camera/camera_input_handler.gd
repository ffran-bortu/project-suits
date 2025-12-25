"""
FILE: camera_input_handler.gd
PURPOSE: Handles all camera-related input including rotation, mouse/keyboard panning, and zoom.

OVERVIEW:
This input handler processes keyboard shortcuts for camera rotation (Q/E), reset (R), focus (F), mouse
middle-button drag for panning, mouse wheel for zoom, and WASD/action keys for keyboard panning. All
input is routed through the camera controller with appropriate direction transformations based on current
camera orientation. Handles viewport input consumption to prevent conflicts.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Finds camera and cursor controller dependencies
   - Uses: Called automatically when node enters scene tree
   - Returns: void

2. _find_dependencies() -> void
   - What it does: Locates camera_controller and cursor_controller via groups if not assigned
   - Uses: Called during initialization
   - Returns: void

3. _input(event: InputEvent) -> void
   - What it does: Dispatches input events to rotation, mouse pan, and zoom handlers
   - Uses: Godot input callback
   - Returns: void

4. _handle_camera_rotation(event: InputEvent) -> void
   - What it does: Processes Q (CCW), E (CW), R (Reset), F (Focus on cursor) key presses
   - Uses: Called from _input for keyboard events
   - Returns: void

5. _handle_mouse_pan(event: InputEvent) -> void
   - What it does: Handles middle mouse button press/release and drag for camera panning
   - Uses: Called from _input for mouse events
   - Returns: void

6. _handle_zoom(event: InputEvent) -> void
   - What it does: Processes mouse wheel up/down for zoom in/out with GameConfig speed
   - Uses: Called from _input for mouse wheel events
   - Returns: void

7. _start_panning(mouse_pos: Vector2) -> void
   - What it does: Begins pan drag operation, storing start position and offset
   - Uses: Called when middle mouse pressed
   - Returns: void

8. _stop_panning() -> void
   - What it does: Ends pan drag operation
   - Uses: Called when middle mouse released
   - Returns: void

9. _handle_pan_drag(current_mouse_pos: Vector2) -> void
   - What it does: Calculates pan delta from mouse movement, adjusts for zoom factor and camera direction, applies with boundary check
   - Uses: Called during mouse motion while panning
   - Returns: void

10. _rotate_pan_delta(delta: Vector3) -> Vector3
    - What it does: Transforms pan vector based on current camera direction for correct screen-space mapping
    - Uses: Helper for both mouse and keyboard panning
    - Returns: Vector3 - rotated pan delta

11. _focus_on_cursor() -> void
    - What it does: Queries cursor position and commands camera to focus on that grid cell
    - Uses: Called when F key pressed
    - Returns: void

12. _process(delta: float) -> void
    - What it does: Calls keyboard pan handler every frame
    - Uses: Called every frame by engine
    - Returns: void

13. _handle_keyboard_pan(delta: float) -> void
    - What it does: Processes WASD or action keys for continuous keyboard panning with speed and direction rotation
    - Uses: Called from _process
    - Returns: void

NOTES:
- Depends on CameraController for all camera operations
- Optionally depends on cursor_controller for focus functionality
- Uses GameConfig for zoom_speed and pan_speed values
- Mouse pan sensitivity scaled by zoom factor (fov / default_fov) for consistent feel
- Keyboard pan uses action keys: camera_pan_up/down/left/right
- All pan deltas rotated based on camera direction for intuitive controls
- Middle mouse button drag for mouse panning
- Mouse wheel for zoom
- Q/E for rotation, R for reset, F for focus
- Viewport input marked as handled to prevent propagation
- Panning limited by boundary check in camera controller
"""

# camera_input_handler.gd - Comprehensive input handling for camera system
extends Node
class_name CameraInputHandler

## Handles all camera-related input with keyboard and mouse support

# --- Dependencies ---
@export var camera_controller: CameraController
@export var cursor_controller: Node  # Optional cursor integration

# --- Pan State ---
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var pan_start_camera_offset: Vector3 = Vector3.ZERO

# --- Configuration ---
var mouse_pan_sensitivity: float = 0.01
var keyboard_pan_speed: float = 0.5


func _ready() -> void:
	_find_dependencies()


## Find component dependencies
func _find_dependencies() -> void:
	if not camera_controller:
		camera_controller = get_tree().get_first_node_in_group("camera_controller")
		if not camera_controller:
			push_warning("CameraInputHandler: No camera controller found!")
	
	if not cursor_controller:
		cursor_controller = get_tree().get_first_node_in_group("cursor_controller")


func _input(event: InputEvent) -> void:
	_handle_camera_rotation(event)
	_handle_mouse_pan(event)
	_handle_zoom(event)


## Handle camera rotation input
## @param event: Input event
func _handle_camera_rotation(event: InputEvent) -> void:
	if not camera_controller:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q:
				camera_controller.rotate_camera_counterclockwise()
				get_viewport().set_input_as_handled()
			KEY_E:
				camera_controller.rotate_camera_clockwise()
				get_viewport().set_input_as_handled()
			KEY_R:
				camera_controller.reset_camera()
				get_viewport().set_input_as_handled()
			KEY_F:
				_focus_on_cursor()
				get_viewport().set_input_as_handled()


## Handle mouse pan (middle mouse button)
## @param event: Input event
func _handle_mouse_pan(event: InputEvent) -> void:
	if not camera_controller:
		return
	
	# Start/stop panning with middle mouse button
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_start_panning(event.position)
			else:
				_stop_panning()
			get_viewport().set_input_as_handled()
	
	# Handle pan drag
	if event is InputEventMouseMotion and is_panning:
		_handle_pan_drag(event.position)


## Handle mouse wheel zoom
## @param event: Input event
func _handle_zoom(event: InputEvent) -> void:
	if not camera_controller:
		return
	
	if event is InputEventMouseButton:
		var zoom_amount := GameConfig.camera.get("zoom_speed", 5.0)
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_controller.zoom_in(zoom_amount)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_controller.zoom_out(zoom_amount)
			get_viewport().set_input_as_handled()


## Start mouse panning
## @param mouse_pos: Mouse position when starting
func _start_panning(mouse_pos: Vector2) -> void:
	is_panning = true
	pan_start_pos = mouse_pos
	pan_start_camera_offset = camera_controller.target_offset
	CursorHelper.set_move()  # Change cursor to move shape


## Stop mouse panning
func _stop_panning() -> void:
	is_panning = false
	CursorHelper.set_arrow()  # Reset cursor to arrow


## Handle pan drag movement
## @param current_mouse_pos: Current mouse position
func _handle_pan_drag(current_mouse_pos: Vector2) -> void:
	var delta := current_mouse_pos - pan_start_pos
	
	# Adjust sensitivity based on zoom
	var zoom_factor := camera_controller.camera_3d.fov / GameConfig.camera.get("default_fov", 60.0)
	var sensitivity := mouse_pan_sensitivity * zoom_factor
	
	# Convert screen delta to world pan (inverted Y)
	var world_delta := Vector3(
		-delta.x * sensitivity,
		0,
		-delta.y * sensitivity
	)
	
	# Rotate delta based on camera direction
	world_delta = _rotate_pan_delta(world_delta)
	
	# Apply pan with boundary check
	var new_offset := pan_start_camera_offset + world_delta
	var boundary := GameConfig.camera.get("boundary_radius", 30.0)
	
	if new_offset.length() <= boundary:
		camera_controller.target_offset = new_offset


## Rotate pan delta based on camera direction
## @param delta: Pan delta to rotate
## @return: Rotated delta
func _rotate_pan_delta(delta: Vector3) -> Vector3:
	var direction := camera_controller.get_camera_direction()
	
	match direction:
		CameraController.CameraDirection.NORTH:
			return delta
		CameraController.CameraDirection.EAST:
			return Vector3(delta.z, 0, -delta.x)
		CameraController.CameraDirection.SOUTH:
			return Vector3(-delta.x, 0, -delta.z)
		CameraController.CameraDirection.WEST:
			return Vector3(-delta.z, 0, delta.x)
	
	return delta


## Focus camera on cursor position
func _focus_on_cursor() -> void:
	if not cursor_controller or not camera_controller:
		return
	
	if cursor_controller.has_method("get_position"):
		var grid_pos: Vector2i = cursor_controller.get_position()
		camera_controller.focus_on_position(grid_pos)
		print("CameraInputHandler: Focused on cursor at %s" % grid_pos)


## Handle keyboard panning (WASD) and edge panning
func _process(delta: float) -> void:
	if not camera_controller:
		return
	
	_handle_keyboard_pan(delta)
	_handle_edge_pan(delta)


## Handle keyboard pan movement
## @param delta: Frame delta time
func _handle_keyboard_pan(delta: float) -> void:
	var pan_vector := Vector3.ZERO
	
	# Get input direction
	if Input.is_action_pressed("camera_pan_up"):
		pan_vector.z -= 1
	if Input.is_action_pressed("camera_pan_down"):
		pan_vector.z += 1
	if Input.is_action_pressed("camera_pan_left"):
		pan_vector.x -= 1
	if Input.is_action_pressed("camera_pan_right"):
		pan_vector.x += 1
	
	if pan_vector.length() > 0:
		pan_vector = pan_vector.normalized()
		
		# Rotate based on camera direction
		pan_vector = _rotate_pan_delta(pan_vector)
		
		# Apply pan speed
		var pan_speed := GameConfig.camera.get("pan_speed", 20.0)
		pan_vector *= pan_speed * delta
		
		camera_controller.pan_camera(pan_vector)


## Handle edge panning (mouse near screen edge)
## @param delta: Frame delta time
func _handle_edge_pan(delta: float) -> void:
	# Check if edge panning is enabled
	if not GameConfig.camera.get("edge_pan_enabled", true):
		return
	
	# Don't edge pan while manually panning
	if is_panning:
		return
	
	# Get panning service from camera controller
	if not camera_controller._panning_service:
		return
	
	var viewport := get_viewport()
	if not viewport:
		return
	
	# Get edge pan result
	var pan_speed := GameConfig.camera.get("pan_speed", 20.0)
	var new_offset := camera_controller._panning_service.edge_pan(
		viewport,
		delta,
		pan_speed,
		camera_controller.target_offset
	)
	
	# Apply if changed
	if new_offset != camera_controller.target_offset:
		var boundary := GameConfig.camera.get("boundary_radius", 30.0)
		
		# Check boundary before applying
		if new_offset.length() <= boundary:
			camera_controller.target_offset = new_offset
			camera_controller.camera_moved.emit(new_offset)
