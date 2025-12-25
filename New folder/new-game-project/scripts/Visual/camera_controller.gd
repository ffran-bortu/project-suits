# camera_controller.gd - Handles camera rotation around the map
extends Node3D

enum CameraDirection {
	NORTH,  # Looking from North (top of map)
	EAST,   # Looking from East (right side)
	SOUTH,  # Looking from South (bottom of map)
	WEST    # Looking from West (left side)
}

var current_direction: CameraDirection = CameraDirection.NORTH
var camera_3d: Camera3D
var grid_size: Vector2i
var cell_size: Vector2
var zoom_level: float = 1.0  # Zoom multiplier (1.0 = default)
var min_zoom: float = 0.3    # Minimum zoom (closer)
var max_zoom: float = 3.0    # Maximum zoom (farther)
var cursor_controller: Node = null  # Reference to cursor controller

signal camera_direction_changed(new_direction)

func _ready():
	camera_3d = $Camera3D
	grid_size = GridManager.grid_size
	cell_size = GridManager.cell_size
	
	# Get cursor controller reference
	if get_tree().get_root().has_node("Main/World/Cursor/CursorController"):
		cursor_controller = get_tree().get_root().get_node("Main/World/Cursor/CursorController")
		# Connect to cursor movement to update camera
		if cursor_controller.has_signal("cursor_moved"):
			cursor_controller.cursor_moved.connect(_on_cursor_moved)
	
	setup_camera_position()

func _input(event):
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = clamp(zoom_level - 0.1, min_zoom, max_zoom)
			update_camera_position()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = clamp(zoom_level + 0.1, min_zoom, max_zoom)
			update_camera_position()
			get_viewport().set_input_as_handled()

func _on_cursor_moved(grid_pos: Vector2i):
	# Update camera when cursor moves
	update_camera_position()

func setup_camera_position():
	update_camera_position()

func update_camera_position():
	# Get cursor position (or default to center if cursor not available)
	var focus_grid_pos: Vector2i
	if cursor_controller and cursor_controller.has_method("get_position"):
		focus_grid_pos = cursor_controller.get_position()
	else:
		# Fallback to center of map
		focus_grid_pos = Vector2i(grid_size.x / 2, grid_size.y / 2)
	
	# Convert grid position to world 3D position
	var world_pos_3d = GridManager.grid_to_world_3d(focus_grid_pos)
	var focus_height = GridManager.get_height(focus_grid_pos) * GridManager.height_unit_scale
	var look_at_pos = Vector3(world_pos_3d.x, focus_height, world_pos_3d.z)
	
	# Calculate base distance and apply zoom
	var base_distance = max(grid_size.x, grid_size.y) * cell_size.x * 0.6
	var distance = base_distance * zoom_level
	
	var camera_pos: Vector3
	
	match current_direction:
		CameraDirection.NORTH:
			# Looking from North (top) - camera at negative Z
			camera_pos = Vector3(look_at_pos.x - distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z - distance * 0.7)
		CameraDirection.EAST:
			# Looking from East (right) - camera at positive X
			camera_pos = Vector3(look_at_pos.x + distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z - distance * 0.7)
		CameraDirection.SOUTH:
			# Looking from South (bottom) - camera at positive Z
			camera_pos = Vector3(look_at_pos.x + distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z + distance * 0.7)
		CameraDirection.WEST:
			# Looking from West (left) - camera at negative X
			camera_pos = Vector3(look_at_pos.x - distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z + distance * 0.7)
	
	camera_3d.position = camera_pos
	camera_3d.look_at(look_at_pos, Vector3.UP)
	
	camera_direction_changed.emit(current_direction)

func rotate_camera_clockwise():
	current_direction = (current_direction + 1) % 4
	update_camera_position()

func rotate_camera_counterclockwise():
	current_direction = (current_direction - 1 + 4) % 4
	update_camera_position()

func set_camera_direction(direction: CameraDirection):
	current_direction = direction
	update_camera_position()

func get_camera_direction() -> CameraDirection:
	return current_direction

# Get the grid direction that corresponds to "forward" from camera perspective
func get_forward_grid_direction() -> Vector2i:
	match current_direction:
		CameraDirection.NORTH:
			return Vector2i(0, 1)   # South (down on screen)
		CameraDirection.EAST:
			return Vector2i(-1, 0)  # West (left on screen)
		CameraDirection.SOUTH:
			return Vector2i(0, -1)  # North (up on screen)
		CameraDirection.WEST:
			return Vector2i(1, 0)   # East (right on screen)
	return Vector2i(0, 1)

# Get the grid direction that corresponds to "backward" from camera perspective
func get_backward_grid_direction() -> Vector2i:
	match current_direction:
		CameraDirection.NORTH:
			return Vector2i(0, -1)  # North (up on screen)
		CameraDirection.EAST:
			return Vector2i(1, 0)   # East (right on screen)
		CameraDirection.SOUTH:
			return Vector2i(0, 1)    # South (down on screen)
		CameraDirection.WEST:
			return Vector2i(-1, 0)  # West (left on screen)
	return Vector2i(0, -1)

# Get the grid direction that corresponds to "right" from camera perspective
func get_right_grid_direction() -> Vector2i:
	match current_direction:
		CameraDirection.NORTH:
			return Vector2i(1, 0)   # East (right on screen)
		CameraDirection.EAST:
			return Vector2i(0, 1)   # South (down on screen)
		CameraDirection.SOUTH:
			return Vector2i(-1, 0)  # West (left on screen)
		CameraDirection.WEST:
			return Vector2i(0, -1)  # North (up on screen)
	return Vector2i(1, 0)

# Get the grid direction that corresponds to "left" from camera perspective
func get_left_grid_direction() -> Vector2i:
	match current_direction:
		CameraDirection.NORTH:
			return Vector2i(-1, 0)  # West (left on screen)
		CameraDirection.EAST:
			return Vector2i(0, -1)  # North (up on screen)
		CameraDirection.SOUTH:
			return Vector2i(1, 0)   # East (right on screen)
		CameraDirection.WEST:
			return Vector2i(0, 1)    # South (down on screen)
	return Vector2i(-1, 0)
