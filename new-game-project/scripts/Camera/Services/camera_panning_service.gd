"""
FILE: camera_panning_service.gd
PURPOSE: Service for camera panning including keyboard, mouse, and edge panning detection.

OVERVIEW:
Handles all camera panning operations including boundary checking, edge panning detection,
and panning delay to prevent accidental panning. Supports both manual panning (WASD, mouse)
and automatic edge panning when cursor is near screen edges.

PUBLIC API:
- pan_camera(offset: Vector3, current_offset: Vector3, boundary: float) -> Vector3: Apply pan with boundary
- is_cursor_near_edge(viewport: Viewport) -> bool: Check if cursor near screen edge
- get_edge_pan_direction(viewport: Viewport) -> Vector2: Get pan direction from cursor position
- edge_pan(viewport: Viewport, delta: float, pan_speed: float, current_offset: Vector3) -> Vector3: Handle edge panning

NOTES:
- Extends RefCounted (lightweight service)
- Edge panning threshold and delay configurable via GameConfig
- Panning delay prevents accidental activation
- Returns new offset values (functional approach)
"""

class_name CameraPanningService
extends RefCounted

## Service for camera panning operations

# Edge panning state
var _panning_timer: float = 0.0
var _viewport_size: Vector2i = Vector2i.ZERO
var _mouse_pos: Vector2 = Vector2.ZERO


## Apply camera pan with boundary check
## @param offset: World space offset to add
## @param current_offset: Current camera offset
## @param boundary: Maximum distance from origin
## @return: New camera offset (clamped to boundary)
func pan_camera(offset: Vector3, current_offset: Vector3, boundary: float) -> Vector3:
	var new_offset := current_offset + offset
	
	# Check boundary
	if new_offset.length() <= boundary:
		return new_offset
	
	return current_offset


## Check if cursor is near screen edge for edge panning
## @param viewport: Current viewport
## @return: True if cursor is near any edge
func is_cursor_near_edge(viewport: Viewport) -> bool:
	_refresh_viewport_size(viewport)
	_mouse_pos = viewport.get_mouse_position()
	
	var threshold: float = GameConfig.camera.get("edge_pan_threshold", 20)
	
	return (_mouse_pos.x <= threshold or 
			_mouse_pos.x >= _viewport_size.x - threshold or
			_mouse_pos.y <= threshold or 
			_mouse_pos.y >= _viewport_size.y - threshold)


## Get edge pan direction based on cursor position
## @param viewport: Current viewport
## @return: Normalized pan direction (Vector2)
func get_edge_pan_direction(viewport: Viewport) -> Vector2:
	_refresh_viewport_size(viewport)
	_mouse_pos = viewport.get_mouse_position()
	
	var threshold: float = GameConfig.camera.get("edge_pan_threshold", 20)
	var h: float = 0.0
	var v: float = 0.0
	
	# Horizontal
	if _mouse_pos.x <= threshold:
		h = -1.0
	elif _mouse_pos.x >= _viewport_size.x - threshold:
		h = 1.0
	
	# Vertical
	if _mouse_pos.y <= threshold:
		v = -1.0  # Up (negative Z in world)
	elif _mouse_pos.y >= _viewport_size.y - threshold:
		v = 1.0  # Down (positive Z in world)
	
	if h != 0.0 or v != 0.0:
		return Vector2(h, v).normalized()
	
	return Vector2.ZERO


## Handle edge panning with delay
## @param viewport: Current viewport
## @param delta: Frame delta time
## @param pan_speed: Panning speed multiplier
## @param current_offset: Current camera offset
## @return: New camera offset after edge pan applied
func edge_pan(viewport: Viewport, delta: float, pan_speed: float, current_offset: Vector3) -> Vector3:
	if not is_cursor_near_edge(viewport):
		_panning_timer = 0.0
		return current_offset
	
	# Apply delay
	var delay: float = GameConfig.camera.get("edge_pan_delay", 0.2)
	_panning_timer += delta
	
	if _panning_timer < delay:
		return current_offset
	
	# Calculate pan offset
	var direction := get_edge_pan_direction(viewport)
	if direction.length() == 0:
		return current_offset
	
	var speed_multiplier: float = GameConfig.camera.get("edge_pan_speed_multiplier", 0.8)
	var pan_offset := Vector3(direction.x, 0, direction.y) * pan_speed * speed_multiplier * delta
	
	return current_offset + pan_offset


## Update viewport size if changed
## @param viewport: Current viewport
func _refresh_viewport_size(viewport: Viewport) -> void:
	var vp_size: Vector2 = viewport.size
	if Vector2i(vp_size) != _viewport_size:
		_viewport_size = Vector2i(vp_size)


## Reset panning timer (call when panning stops)
func reset_timer() -> void:
	_panning_timer = 0.0
