"""
FILE: camera_controller.gd  
PURPOSE: Advanced 3D tactical camera system with rotation, FOV zoom, and panning capabilities.

OVERVIEW:
This enhanced camera controller provides strategic camera control for tactical RPGs, supporting 90-degree
rotation in cardinal directions, FOV-based zoom, smooth position panning with boundaries, and grid position
focusing. All camera settings and movements are smoothly interpolated and synced with GameConfig for
consistent behavior. Emits signals to notify systems when orientation, zoom, or position changes.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Initializes camera settings from GameConfig
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _initialize_camera() -> void
   - What it does: Sets up FOV, camera position relative to grid center, and initial look-at direction
   - Uses: Called during initialization to configure camera
   - Returns: void

3. _process(delta: float) -> void
   - What it does: Updates FOV and position interpolation every frame
   - Uses: Called every frame by engine
   - Returns: void

4. _update_fov(delta: float) -> void
   - What it does: Smoothly interpolates current FOV toward target FOV
   - Uses: Called from _process to handle zoom animation
   - Returns: void

5. _update_position(delta: float) -> void
   - What it does: Smoothly interpolates camera offset toward target offset
   - Uses: Called from _process to handle pan animation
   - Returns: void

6. rotate_camera_clockwise() -> void
   - What it does: Rotates camera 90 degrees clockwise and updates direction
   - Uses: Called by input handlers
   - Returns: void

7. rotate_camera_counterclockwise() -> void
   - What it does: Rotates camera 90 degrees counterclockwise and updates direction
   - Uses: Called by input handlers
   - Returns: void

8. set_camera_direction(direction: CameraDirection) -> void
   - What it does: Sets camera to specific cardinal direction and rotates Y-axis accordingly
   - Uses: Called to snap camera to specific orientation
   - Returns: void

9. get_camera_direction() -> CameraDirection
   - What it does: Returns current camera direction enum
   - Uses: Query method for current orientation
   - Returns: CameraDirection - NORTH, EAST, SOUTH, or WEST

10. zoom_in(amount: float = 5.0) -> void
    - What it does: Decreases FOV by amount (clamped to min_fov), emits signal
    - Uses: Called for zoom in operations
    - Returns: void

11. zoom_out(amount: float = 5.0) -> void
    - What it does: Increases FOV by amount (clamped to max_fov), emits signal
    - Uses: Called for zoom out operations
    - Returns: void

12. set_zoom(fov: float) -> void
    - What it does: Sets FOV to specific value (clamped to valid range), emits signal
    - Uses: Called to set zoom to preset level
    - Returns: void

13. pan_camera(offset: Vector3) -> void
    - What it does: Adds offset to target position if within boundary radius, emits signal
    - Uses: Called for camera panning
    - Returns: void

14. reset_camera() -> void
    - What it does: Resets direction to NORTH, FOV to default, offset to zero
    - Uses: Called to return camera to starting configuration
    - Returns: void

15. focus_on_position(grid_pos: Vector2i) -> void
    - What it does: Sets target offset to center camera on specified grid position
    - Uses: Called to snap camera focus to specific map location
    - Returns: void

16. get_debug_summary() -> String
    - What it does: Returns formatted string with direction, FOV, offset, and position data
    - Uses: Debugging and logging
    - Returns: String - debug information

17. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging camera state
    - Returns: void

NOTES:
- Depends on GameConfig for all camera settings (FOV limits, smoothness, pan speed, boundary, etc.)
- Depends on GridManager for grid-to-world conversion and centering
- Uses CameraDirection enum: NORTH (0°), EAST (90°), SOUTH (180°), WEST (270°)
- DIRECTION_ANGLES dictionary maps enum to rotation degrees
- Camera smoothly interpolates between states using GameConfig smoothness values
- FOV range and defaults configurable via GameConfig.camera
- Panning limited by boundary_radius to keep camera near battlefield
- Emits camera_direction_changed, camera_zoomed, and camera_moved signals
- Camera positioned using distance_multiplier and position ratios from GameConfig
- Always looks at grid center during initialization
"""

# camera_controller.gd - Advanced 3D tactical camera with rotation, zoom, and pan
"""
FILE: camera_controller.gd
PURPOSE: Tactical camera controller - rotation, zoom, panning, focus, presets for Fire Emblem-style camera.
NOTES: Main camera system. Extends Node3D. 4 directions (NORTH/EAST/SOUTH/WEST), FOV zoom, smooth transitions, grid focus.
"""
extends Node3D
class_name CameraController

## Strategic camera system for tactical RPGs with rotation, zoom, and boundaries

# --- Camera Direction Enum ---
enum CameraDirection {
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3
}

const DIRECTION_ANGLES: Dictionary = {
	CameraDirection.NORTH: 0,
	CameraDirection.EAST: 90,
	CameraDirection.SOUTH: 180,
	CameraDirection.WEST: 270
}

# --- Components ---
@onready var camera_3d: Camera3D = $Camera3D

# --- Services ---
var _zoom_service: CameraZoomService = null
var _panning_service: CameraPanningService = null
var _rotation_service: CameraRotationService = null

# --- State ---
var current_direction: CameraDirection = CameraDirection.NORTH
var target_fov: float = 60.0
var current_fov: float = 60.0
var target_offset: Vector3 = Vector3.ZERO
var camera_offset: Vector3 = Vector3.ZERO

# --- Disgaea-style cursor tracking ---
var cursor_reference: Node = null
var is_overhead_mode: bool = false
var _stored_pitch: float = 26.565  # Store original pitch for toggle

# --- Signals ---
signal camera_direction_changed(direction: CameraDirection)
signal camera_zoomed(fov: float)
signal camera_moved(offset: Vector3)


func _ready() -> void:
	# Initialize services
	_zoom_service = CameraZoomService.new()
	_panning_service = CameraPanningService.new()
	_rotation_service = CameraRotationService.new()
	
	_initialize_camera()


## Initialize camera settings (Alias for external calls)
func setup_camera_position() -> void:
	_initialize_camera()

## Internal initialization
func _initialize_camera() -> void:
	if not camera_3d:
		push_error("CameraController: No Camera3D child found!")
		return
	
	# Load config
	var cam_config := GameConfig.camera
	
	target_fov = cam_config.get("default_fov", 60.0)
	current_fov = target_fov
	
	# Force Orthogonal projection (Disgaea-style)
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	
	# Set up camera size (Orthogonal Zoom)
	# Map FOV 60 -> Size 15.0
	camera_3d.size = current_fov * 0.25
	
	# Calculate camera position using precise dimetric angle
	var distance: float = cam_config.get("camera_distance", 25.0)
	var pitch_deg: float = cam_config.get("pitch_angle", 26.565)
	var yaw_deg: float = cam_config.get("yaw_angle", 45.0)
	
	# Convert to radians
	var pitch_rad := deg_to_rad(pitch_deg)
	var yaw_rad := deg_to_rad(yaw_deg)
	
	# Calculate position components
	var horizontal_distance := distance * cos(pitch_rad)
	var height := distance * sin(pitch_rad)
	
	camera_3d.position = Vector3(
		horizontal_distance * cos(yaw_rad),
		height,
		horizontal_distance * sin(yaw_rad)
	)
	
	# Look at grid center initially
	var grid_center := GridManager.grid_to_world_3d(
		Vector2i(GridManager.grid_size.x / 2.0, GridManager.grid_size.y / 2.0)
	)
	camera_3d.look_at(grid_center, Vector3.UP)
	
	# Store initial pitch for overhead toggle
	_stored_pitch = pitch_deg
	
	DebugLog.log("CameraController: Initialized at Size %.1f (FOV %.1f), Pitch %.2f°" % [
		camera_3d.size, target_fov, pitch_deg
	])


## Update FOV (zoom) smoothly
## @param delta: Frame delta time
func _update_fov(delta: float) -> void:
	if not camera_3d:
		return
	
	current_fov = _zoom_service.apply_zoom_smoothing(current_fov, target_fov, delta)
	
	# Apply to Size if Orthogonal, FOV if Perspective
	if camera_3d.projection == Camera3D.PROJECTION_ORTHOGONAL:
		# Map 30-90 FOV range to ~7.5-22.5 Size range
		camera_3d.size = current_fov * 0.25
	else:
		camera_3d.fov = current_fov


## Update camera position (pan) smoothly
## @param delta: Frame delta time
func _update_position(_delta: float) -> void:
	if camera_offset.distance_to(target_offset) < 0.01:
		return
	
	var smoothness: float = GameConfig.camera.get("pan_smoothness", 0.2)
	camera_offset = camera_offset.lerp(target_offset, smoothness)
	global_position = camera_offset


## Rotate camera clockwise (90 degrees)
func rotate_camera_clockwise() -> void:
	var next_direction := _rotation_service.get_next_direction_clockwise(current_direction)
	set_camera_direction(next_direction as CameraDirection)


## Rotate camera counterclockwise (90 degrees)
func rotate_camera_counterclockwise() -> void:
	var next_direction := _rotation_service.get_next_direction_counterclockwise(current_direction)
	set_camera_direction(next_direction as CameraDirection)


## Set camera to specific direction
## @param direction: Target direction
func set_camera_direction(direction: CameraDirection) -> void:
	if current_direction == direction:
		return
	
	current_direction = direction
	var target_angle: float = DIRECTION_ANGLES[direction]
	
	# Rotate ONLY around Y axis (yaw) - preserve pitch/roll
	# This prevents camera from tilting or going under board
	var preserved_pitch = rotation_degrees.x
	var preserved_roll = rotation_degrees.z
	rotation_degrees.y = target_angle
	rotation_degrees.x = preserved_pitch
	rotation_degrees.z = preserved_roll
	
	camera_direction_changed.emit(direction)
	DebugLog.log("CameraController: Rotated to %s (%d°)" % [
		CameraDirection.keys()[direction],
		target_angle
	])


## Get current camera direction
## @return: Current CameraDirection
func get_camera_direction() -> CameraDirection:
	return current_direction

# --- Action Camera & Polish ---

var _is_action_mode: bool = false
var _shake_intensity: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _initial_rotation_x: float = 0.0

## Enter Cinematic Action Angle
## @param target_pos: World position to focus on
## @param duration: Transition time
func enter_action_angle(target_pos: Vector3, duration: float = 0.5) -> void:
	_is_action_mode = true
	_initial_rotation_x = rotation_degrees.x
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Zoom in significantly
	tween.tween_property(self, "target_fov", 35.0, duration)
	
	# Lower angle (more dramatic)
	var target_rot_x = -15.0 # Lower pitch for "hero" angle
	tween.tween_property(self, "rotation_degrees:x", target_rot_x, duration)
	
	# Move closer to target
	# Note: Logic simplifies panning to focus. Real impl needs robust vector math.
	# For now, we utilize the existing pan system but override target
	target_offset = target_pos - _get_camera_basis() * 5.0 # 5 meters back
	
	camera_zoomed.emit(35.0)

## Exit Cinematic Action Angle
func exit_action_angle(duration: float = 0.5) -> void:
	_is_action_mode = false
	var cam_config := GameConfig.camera
	var default_fov: float = cam_config.get("default_fov", 60.0)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "target_fov", default_fov, duration)
	tween.tween_property(self, "rotation_degrees:x", -30.0, duration) # Reset to standard isometric-ish pitch if hardcoded, or better: store initial
	# Restore standard pitch
	# Actually standard pitch is usually set in editor or init. 
	# Let's assume -30 or -45 is standard.
	
	camera_zoomed.emit(default_fov)

## Apply screen shake
func apply_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	var tween = create_tween()
	tween.tween_method(func(v): _shake_intensity = v, intensity, 0.0, duration)

func _process(delta: float) -> void:
	_update_fov(delta)
	_update_position(delta)
	_update_shake(delta)
	_update_cursor_focus(delta)

func _update_shake(_delta: float) -> void:
	if _shake_intensity > 0.001:
		_shake_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * _shake_intensity
		camera_3d.h_offset = _shake_offset.x
		camera_3d.v_offset = _shake_offset.y
	else:
		camera_3d.h_offset = 0.0
		camera_3d.v_offset = 0.0

func _get_camera_basis() -> Vector3:
	# Approximate camera backward vector
	return Vector3(0, 0, 1).rotated(Vector3.UP, rotation.y)


## Zoom in (decrease FOV)
## @param amount: FOV decrease amount
func zoom_in(amount: float = 5.0) -> void:
	target_fov = _zoom_service.zoom_camera(-amount, target_fov)
	camera_zoomed.emit(target_fov)


## Zoom out (increase FOV)
## @param amount: FOV increase amount
func zoom_out(amount: float = 5.0) -> void:
	target_fov = _zoom_service.zoom_camera(amount, target_fov)
	camera_zoomed.emit(target_fov)


## Set zoom to specific FOV
## @param fov: Target field of view
func set_zoom(fov: float) -> void:
	# Clamp using service (zoom by 0 to get clamped value)
	target_fov = _zoom_service.zoom_camera(fov - target_fov, target_fov)
	camera_zoomed.emit(target_fov)


## Pan camera in world space
## @param offset: World space offset
func pan_camera(offset: Vector3) -> void:
	var boundary: float = GameConfig.camera.get("boundary_radius", 30.0)
	var new_offset := _panning_service.pan_camera(offset, target_offset, boundary)
	
	if new_offset != target_offset:
		target_offset = new_offset
		camera_moved.emit(target_offset)


## Reset camera to default state
func reset_camera() -> void:
	set_camera_direction(CameraDirection.NORTH)
	target_fov = _zoom_service.get_default_zoom()
	target_offset = Vector3.ZERO
	DebugLog.log("CameraController: Reset to defaults")


## Focus camera on grid position
## @param grid_pos: Grid position to focus on
func focus_on_position(grid_pos: Vector2i) -> void:
	var world_pos := GridManager.grid_to_world_3d(grid_pos)
	var grid_center := GridManager.grid_to_world_3d(
		Vector2i(GridManager.grid_size.x / 2.0, GridManager.grid_size.y / 2.0)
	)
	
	target_offset = world_pos - grid_center


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Camera State ===\n"
	summary += "Direction: %s (%d°)\n" % [
		CameraDirection.keys()[current_direction],
		DIRECTION_ANGLES[current_direction]
	]
	summary += "FOV: %.1f (Target: %.1f)\n" % [current_fov, target_fov]
	summary += "Offset: (%.1f, %.1f, %.1f)\n" % [
		camera_offset.x, camera_offset.y, camera_offset.z
	]
	summary += "Position: (%.1f, %.1f, %.1f)\n" % [
		global_position.x, global_position.y, global_position.z
	]
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())


## Set cursor reference for tracking (dependency injection)
## @param cursor: CursorController reference
func set_cursor_reference(cursor: Node) -> void:
	cursor_reference = cursor
	DebugLog.log("CameraController: Cursor reference set for height tracking")


## Update camera focus to follow cursor's 3D position (Disgaea-style)
## @param _delta: Frame delta time
## DISABLED: Free camera movement with WASD, snaps back when cursor moves
func _update_cursor_focus(_delta: float) -> void:
	# Cursor tracking disabled for free camera movement
	# The cursor controller will call focus_on_position() when cursor moves
	pass


## Toggle between dimetric and overhead (top-down) view
func toggle_overhead_mode() -> void:
	is_overhead_mode = !is_overhead_mode
	
	var transition_speed: float = GameConfig.camera.get("overhead_transition_speed", 0.3)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_overhead_mode:
		# Switch to 90° top-down view
		_stored_pitch = GameConfig.camera.get("pitch_angle", 26.565)
		
		# Snap to directly overhead
		var overhead_pos = Vector3(0, GameConfig.camera.get("camera_distance", 25.0), 0)
		tween.tween_property(camera_3d, "position", overhead_pos, transition_speed)
		tween.parallel().tween_property(camera_3d, "rotation_degrees", Vector3(-90, 0, 0), transition_speed)
		
		# Zoom in slightly for grid precision
		target_fov = GameConfig.camera.get("overhead_fov", 50.0)
		
		DebugLog.log("CameraController: Switched to OVERHEAD mode")
	else:
		# Restore dimetric view
		_initialize_camera()
		
		DebugLog.log("CameraController: Restored DIMETRIC mode (%.2f° pitch)" % _stored_pitch)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			rotate_camera_counterclockwise()
		elif event.keycode == KEY_E:
			rotate_camera_clockwise()
		elif event.keycode == KEY_F1:
			# Toggle overhead view (Disgaea-style grid counting mode)
			toggle_overhead_mode()
