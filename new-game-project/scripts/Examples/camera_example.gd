"""
FILE: camera_example.gd
PURPOSE: Demo/example showing complete camera system usage with rotation, zoom, panning, presets, and focus.
FUNCTIONS: _ready, _setup_camera_system, example_rotation, example_zoom, example_panning, example_presets, example_focus, example_complete_workflow, signal handlers, print_camera_info - 13+ total
NOTES: Creates CameraController, CameraInputHandler, CameraPresetManager. Demonstrates all 4 directions, zoom in/out, panning, preset save/load, focus on grid positions, complete tactical workflow from overview→unit selection→combat→restoration.
"""


extends Node3D

## Demonstrates tactical camera system features

var camera_controller: CameraController
var input_handler: CameraInputHandler
var preset_manager: CameraPresetManager


func _ready() -> void:
	print("=== Camera System Examples ===\n")
	
	_setup_camera_system()
	await get_tree().create_timer(1.0).timeout
	
	example_rotation()
	await get_tree().create_timer(2.0).timeout
	
	example_zoom()
	await get_tree().create_timer(2.0).timeout
	
	example_panning()
	await get_tree().create_timer(2.0).timeout
	
	example_presets()
	await get_tree().create_timer(2.0).timeout
	
	example_focus()


## Setup camera system
func _setup_camera_system() -> void:
	print("SETUP: Creating Camera System")
	print("-" * 30)
	
	# Create camera controller
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera_controller.add_child(camera)
	camera_controller.add_to_group("camera_controller")
	
	add_child(camera_controller)
	
	# Create input handler
	input_handler = CameraInputHandler.new()
	input_handler.name = "CameraInputHandler"
	input_handler.camera_controller = camera_controller
	add_child(input_handler)
	
	# Create preset manager
	preset_manager = CameraPresetManager.new()
	preset_manager.name = "CameraPresetManager"
	preset_manager.camera_controller = camera_controller
	add_child(preset_manager)
	
	# Connect signals
	camera_controller.camera_direction_changed.connect(_on_direction_changed)
	camera_controller.camera_zoomed.connect(_on_zoomed)
	preset_manager.preset_saved.connect(_on_preset_saved)
	preset_manager.preset_loaded.connect(_on_preset_loaded)
	
	print("✓ Camera system created")
	camera_controller.debug_print()


## Example 1: Camera Rotation
func example_rotation() -> void:
	print("\nEXAMPLE 1: Camera Rotation")
	print("-" * 30)
	
	# Rotate through all directions
	for direction in CameraController.CameraDirection.values():
		camera_controller.set_camera_direction(direction)
		print("Rotated to: %s" % CameraController.CameraDirection.keys()[direction])
		await get_tree().create_timer(0.5).timeout
	
	# Reset to north
	camera_controller.set_camera_direction(CameraController.CameraDirection.NORTH)
	print("Reset to NORTH")


## Example 2: Zoom
func example_zoom() -> void:
	print("\nEXAMPLE 2: Zoom System")
	print("-" * 30)
	
	var original_fov := camera_controller.target_fov
	
	# Zoom in
	print("Zooming in...")
	for i in range(3):
		camera_controller.zoom_in(10.0)
		await get_tree().create_timer(0.5).timeout
		print("  FOV: %.1f" % camera_controller.target_fov)
	
	# Zoom out
	print("Zooming out...")
	for i in range(3):
		camera_controller.zoom_out(10.0)
		await get_tree().create_timer(0.5).timeout
		print("  FOV: %.1f" % camera_controller.target_fov)
	
	# Reset
	camera_controller.set_zoom(original_fov)
	print("Reset to FOV: %.1f" % original_fov)


## Example 3: Panning
func example_panning() -> void:
	print("\nEXAMPLE 3: Panning")
	print("-" * 30)
	
	# Pan in different directions
	print("Panning right...")
	camera_controller.pan_camera(Vector3(10, 0, 0))
	await get_tree().create_timer(1.0).timeout
	
	print("Panning forward...")
	camera_controller.pan_camera(Vector3(0, 0, -10))
	await get_tree().create_timer(1.0).timeout
	
	# Reset to center
	print("Resetting to center...")
	camera_controller.target_offset = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	
	print("Camera offset: %s" % camera_controller.camera_offset)


## Example 4: Presets
func example_presets() -> void:
	print("\nEXAMPLE 4: Camera Presets")
	print("-" * 30)
	
	# Save current as custom preset
	camera_controller.set_zoom(45.0)
	camera_controller.set_camera_direction(CameraController.CameraDirection.EAST)
	preset_manager.save_current_preset("Custom View")
	
	# Load default presets
	print("\nAvailable presets:")
	for preset_name in preset_manager.get_preset_names():
		print("  - %s" % preset_name)
	
	# Cycle through presets
	for preset_name in ["Overview", "Close", "Wide", "Custom View"]:
		if preset_manager.has_preset(preset_name):
			print("\nLoading '%s'..." % preset_name)
			preset_manager.load_preset(preset_name)
			await get_tree().create_timer(1.0).timeout
			camera_controller.debug_print()
	
	# Reset to overview
	preset_manager.load_preset("Overview")


## Example 5: Focus on Position
func example_focus() -> void:
	print("\nEXAMPLE 5: Focus on Positions")
	print("-" * 30)
	
	# Focus on different grid positions
	var positions := [
		Vector2i(0, 0),      # Top-left
		Vector2i(7, 0),      # Top-right
		Vector2i(0, 7),      # Bottom-left
		Vector2i(7, 7),      # Bottom-right
		Vector2i(3, 3)       # Center
	]
	
	for grid_pos in positions:
		print("Focusing on %s..." % grid_pos)
		camera_controller.focus_on_position(grid_pos)
		await get_tree().create_timer(1.0).timeout
	
	# Reset to center
	camera_controller.reset_camera()
	print("Reset to default view")


## Example 6: Complete Workflow
func example_complete_workflow() -> void:
	print("\nEXAMPLE 6: Complete Tactical Workflow")
	print("-" * 30)
	
	# 1. Player phase start - overview
	print("\n1. Player Phase - Overview")
	preset_manager.load_preset("Overview")
	await get_tree().create_timer(1.0).timeout
	
	# 2. Unit selected - focus and zoom
	print("\n2. Unit Selected - Focus and Zoom")
	var selected_unit_pos := Vector2i(2, 3)
	camera_controller.focus_on_position(selected_unit_pos)
	camera_controller.set_zoom(50.0)
	await get_tree().create_timer(1.0).timeout
	
	# 3. Combat starts - close view
	print("\n3. Combat Start - Close View")
	preset_manager.save_current_preset("_temp")
	camera_controller.set_zoom(35.0)
	camera_controller.set_camera_direction(CameraController.CameraDirection.EAST)
	await get_tree().create_timer(1.0).timeout
	
	# 4. Combat ends - restore view
	print("\n4. Combat End - Restore View")
	preset_manager.load_preset("_temp")
	await get_tree().create_timer(1.0).timeout
	
	# 5. Enemy phase - wide view
	print("\n5. Enemy Phase - Wide View")
	preset_manager.load_preset("Wide")
	await get_tree().create_timer(1.0).timeout
	
	# 6. Back to player phase
	print("\n6. Back to Player Phase")
	preset_manager.load_preset("Overview")
	print("\nWorkflow complete!")


## Signal handlers
func _on_direction_changed(direction: CameraController.CameraDirection) -> void:
	print("  → Direction changed: %s" % CameraController.CameraDirection.keys()[direction])


func _on_zoomed(fov: float) -> void:
	print("  → FOV changed: %.1f" % fov)


func _on_preset_saved(preset_name: String) -> void:
	print("  ✓ Preset saved: %s" % preset_name)


func _on_preset_loaded(preset_name: String) -> void:
	print("  ✓ Preset loaded: %s" % preset_name)


## Bonus: Print all camera info
func print_camera_info() -> void:
	print("\n=== Complete Camera State ===")
	camera_controller.debug_print()
	print()
	preset_manager.debug_print()
