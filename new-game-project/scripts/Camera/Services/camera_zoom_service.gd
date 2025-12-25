"""
FILE: camera_zoom_service.gd
PURPOSE: Lightweight service for handling camera zoom logic using FOV adjustments.

OVERVIEW:
This service encapsulates all zoom-related calculations and smoothing. It manages target
and current FOV values, applies smooth interpolation, and enforces min/max zoom limits
from GameConfig. Designed as a RefCounted for optimal performance.

PUBLIC API:
- zoom_camera(amount: float) -> void: Adjust target FOV by amount
- apply_zoom_smoothing(camera_controller: CameraController, delta: float) -> void: Smooth FOV interpolation
- reset_zoom() -> void: Reset to default FOV

NOTES:
- Extends RefCounted (no need to be a Node)
- Reads min_fov, max_fov, default_fov from GameConfig.camera
- Uses lerp for smooth zoom transitions
- Lower FOV = more zoomed in, Higher FOV = more zoomed out
"""

class_name CameraZoomService
extends RefCounted

## Service for camera zoom operations

const DELTA_SMOOTHING: int = 10

## Adjust the target FOV for zooming
## @param amount: Amount to change FOV (negative = zoom in, positive = zoom out)
func zoom_camera(amount: float, current_target: float) -> float:
	var min_fov: float = GameConfig.camera.get("min_fov", 30.0)
	var max_fov: float = GameConfig.camera.get("max_fov", 90.0)
	return clamp(current_target + amount, min_fov, max_fov)


## Smoothly interpolate current FOV to target FOV
## @param camera_controller: Reference to camera controller
## @param delta: Frame delta time
## @return: New current FOV value
func apply_zoom_smoothing(current_fov: float, target_fov: float, _delta: float) -> float:
	if abs(current_fov - target_fov) < 0.1:
		return target_fov
	
	var smoothness: float = GameConfig.camera.get("zoom_smoothness", 0.15)
	return lerp(current_fov, target_fov, smoothness)


## Reset zoom to default value
## @return: Default FOV value
func get_default_zoom() -> float:
	return GameConfig.camera.get("default_fov", 60.0)
