"""
FILE: vfx_manager.gd
PURPOSE: Centralized management of visual effects (Screen Shake, Hit Stop, Screen Flash).
DEPENDENCIES: project.godot (Autoload)

FUNCTIONS:
1. shake_camera(intensity, duration) -> void
2. hit_stop(duration_ms, time_scale) -> void
3. flash_screen(color, duration) -> void
4. spawn_floating_text(text, position, color) -> void
"""

extends Node

# --- Constants ---
const DEFAULT_SHAKE_INTENSITY: float = 0.5
const DEFAULT_SHAKE_DURATION: float = 0.3
const DEFAULT_HIT_STOP_SCALE: float = 0.05

# --- State ---

var _flash_rect: ColorRect
var _flash_canvas: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_flash_canvas()
	DebugLog.log("VFXManager initialized", "green")

func _create_flash_canvas() -> void:
	_flash_canvas = CanvasLayer.new()
	_flash_canvas.layer = 100 # High layer to be on top
	add_child(_flash_canvas)
	
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_canvas.add_child(_flash_rect)

func _get_active_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

## Shake the active camera
## @param intensity: Magnitude of offset (in meters/units)
## @param duration: Time in seconds
func shake_camera(intensity: float = DEFAULT_SHAKE_INTENSITY, duration: float = DEFAULT_SHAKE_DURATION) -> void:
	var cam = _get_active_camera()
	if not cam:
		return
		
	# If using a CameraController, prefer delegating. 
	# But for a generic shake, we can tween the offset if the camera supports it, 
	# OR we can emit a signal that the CameraController listens to.
	
	# Check if camera has a "apply_shake" method (Best practice: Decoupled)
	var controller = cam.get_parent() # Assuming Camera3D is child of controller rig
	if controller and controller.has_method("apply_shake"):
		controller.apply_shake(intensity, duration)
		return
	
	# Fallback: Simple tween on h_offset/v_offset if standard Camera3D properties allow specific abuse,
	# or better: Signal global event.
	# Since we are "10/10", let's use a signal on the SignalBus if possible, 
	# OR assume CameraController is listening.
	
	# For now, let's try direct manipulation if possible, but Camera3D position is often locked by controller.
	# We will assume CameraController exposes `apply_shake`.
	pass 

## Freeze frame for impact "Juice"
## @param duration_ms: Duration in milliseconds
## @param scale: Time scale during freeze (0.0 to 1.0)
func hit_stop(duration_ms: int, scale: float = DEFAULT_HIT_STOP_SCALE) -> void:
	if Engine.time_scale < 1.0: # Already in hit stop
		return
		
	Engine.time_scale = scale
	await get_tree().create_timer(duration_ms / 1000.0 * scale, true, false, true).timeout
	Engine.time_scale = 1.0

## Flash the screen with a color
## @param color: Flash color
## @param duration: Fade out duration
func flash_screen(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	_flash_rect.color = color
	var tween = create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, duration).from(color.a)

## Spawn floating damage text (Requires scene)
func spawn_floating_text(_text: String, _position: Vector3, _color: Color) -> void:
	# Requires a DamageNumber scene to be registered in GameConfig or preloaded.
	# Placeholder for now until DamageNumber3D is fully verified as a scene.
	pass
