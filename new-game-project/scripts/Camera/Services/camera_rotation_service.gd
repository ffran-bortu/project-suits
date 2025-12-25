"""
FILE: camera_rotation_service.gd
PURPOSE: Service for handling camera rotation logic and direction calculations.

OVERVIEW:
Provides utility functions for camera rotation operations including direction cycling,
angle calculations, and direction-to-angle mappings. Complements the CameraController's
rotation functionality.

PUBLIC API:
- get_next_direction_clockwise(current: int) -> int: Calculate next direction CW
- get_next_direction_counterclockwise(current: int) -> int: Calculate next direction CCW
- get_angle_for_direction(direction: int) -> float: Get rotation angle for direction

NOTES:
- Extends RefCounted (lightweight service)
- Works with CameraController.CameraDirection enum
- Uses DIRECTION_ANGLES dictionary for mapping
"""

class_name CameraRotationService
extends RefCounted

## Service for camera rotation operations

# Direction to angle mapping (matches CameraController.DIRECTION_ANGLES)
const DIRECTION_ANGLES: Dictionary = {
	0: 0,    # NORTH
	1: 90,   # EAST
	2: 180,  # SOUTH
	3: 270   # WEST
}


## Get next direction clockwise
## @param current: Current camera direction (0-3)
## @return: Next direction clockwise
func get_next_direction_clockwise(current: int) -> int:
	return (current + 1) % 4


## Get next direction counterclockwise
## @param current: Current camera direction (0-3)
## @return: Next direction counterclockwise
func get_next_direction_counterclockwise(current: int) -> int:
	return (current - 1 + 4) % 4


## Get rotation angle for direction
## @param direction: Camera direction (0-3)
## @return: Angle in degrees
func get_angle_for_direction(direction: int) -> float:
	return DIRECTION_ANGLES.get(direction, 0.0)
