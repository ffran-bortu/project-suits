"""
FILE: camera_preset_manager.gd
PURPOSE: Manages saving, loading, and restoring camera view presets for quick switching between common views.

OVERVIEW:
This manager persists camera presets to JSON file, allowing players to save favorite camera configurations
and quickly restore them later. Presets store direction, FOV, and offset. The system auto-creates default
presets (Overview, Close, Wide) on first run and provides full CRUD operations with signal notifications.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Finds camera controller, loads presets from file, creates defaults if none exist
   - Uses: Called automatically when node enters scene tree
   - Returns: void

2. _find_dependencies() -> void
   - What it does: Locates camera_controller via groups if not assigned
   - Uses: Called during initialization
   - Returns: void

3. save_current_preset(preset_name: String) -> void
   - What it does: Captures current camera state and saves as named preset, emits preset_saved signal
   - Uses: Called when player wants to save current view
   - Returns: void

4. load_preset(preset_name: String) -> bool
   - What it does: Applies saved camera settings from preset, emits preset_loaded signal
   - Uses: Called to restore a saved view
   - Returns: bool - true if successful, false if preset not found

5. delete_preset(preset_name: String) -> bool
   - What it does: Removes preset from dictionary and file, emits preset_deleted signal
   - Uses: Called to remove unwanted preset
   - Returns: bool - true if successful, false if not found

6. get_preset_names() -> Array[String]
   - What it does: Returns list of all saved preset names
   - Uses: Query method for UI preset selection
   - Returns: Array[String] - preset names

7. has_preset(preset_name: String) -> bool
   - What it does: Checks if preset exists in dictionary
   - Uses: Validation before load/delete operations
   - Returns: bool - true if exists

8. save_presets() -> void
   - What it does: Serializes presets dictionary to JSON and writes to user://camera_presets.json
   - Uses: Called after any preset modification
   - Returns: void

9. load_presets() -> void
   - What it does: Reads JSON file, parses presets dictionary, and populates in-memory data
   - Uses: Called during initialization
   - Returns: void

10. create_default_presets() -> void
    - What it does: Creates Overview (default), Close (min FOV), and Wide (max FOV) presets
    - Uses: Called when no presets file exists
    - Returns: void

11. get_debug_summary() -> String
    - What it does: Returns formatted string with preset count, current preset, and details of all presets
    - Uses: Debugging and logging
    - Returns: String - debug information

12. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging preset state
    - Returns: void

NOTES:
- Depends on CameraController for camera state access and manipulation
- Presets stored at user://camera_presets.json
- Preset data structure: {direction: CameraDirection, fov: float, offset: {x, y, z}}
- Emits preset_saved, preset_loaded, and preset_deleted signals
- Default presets created automatically: Overview (reset state), Close (min FOV), Wide (max FOV)
- Restores original camera state after creating defaults
- Current preset name tracked for UI indication
- Uses JSON.stringify with tab indentation for readable file format
- Validates preset_name is not empty before saving
- All file operations use FileAccess with error checking
"""

# camera_preset_manager.gd - Save and load camera presets
extends Node
class_name CameraPresetManager

## Manages camera presets for quick view switching

# --- Constants ---
const SAVE_PATH: String = "user://camera_presets.json"

# --- Dependencies ---
@export var camera_controller: CameraController

# --- Presets ---
var presets: Dictionary = {}
var current_preset_name: String = ""

# --- Signals ---
signal preset_saved(preset_name: String)
signal preset_loaded(preset_name: String)
signal preset_deleted(preset_name: String)


func _ready() -> void:
	_find_dependencies()
	load_presets()
	
	# Create default presets if none exist
	if presets.is_empty():
		create_default_presets()


## Find dependencies
func _find_dependencies() -> void:
	if not camera_controller:
		camera_controller = get_tree().get_first_node_in_group("camera_controller")
		if not camera_controller:
			push_warning("CameraPresetManager: No camera controller found!")


## Save current camera settings as preset
## @param preset_name: Name for the preset
func save_current_preset(preset_name: String) -> void:
	if not camera_controller:
		push_error("CameraPresetManager: No camera controller!")
		return
	
	if preset_name.is_empty():
		push_warning("CameraPresetManager: Preset name cannot be empty!")
		return
	
	var preset := {
		"direction": camera_controller.get_camera_direction(),
		"fov": camera_controller.target_fov,
		"offset": {
			"x": camera_controller.target_offset.x,
			"y": camera_controller.target_offset.y,
			"z": camera_controller.target_offset.z
		}
	}
	
	presets[preset_name] = preset
	current_preset_name = preset_name
	
	save_presets()
	preset_saved.emit(preset_name)
	
	print("CameraPresetManager: Saved preset '%s'" % preset_name)


## Load a camera preset
## @param preset_name: Name of preset to load
## @return: true if successful
func load_preset(preset_name: String) -> bool:
	if not camera_controller:
		push_error("CameraPresetManager: No camera controller!")
		return false
	
	if preset_name not in presets:
		push_warning("CameraPresetManager: Preset '%s' not found!" % preset_name)
		return false
	
	var preset: Dictionary = presets[preset_name]
	
	# Apply preset
	camera_controller.set_camera_direction(preset.direction)
	camera_controller.target_fov = preset.fov
	
	var offset_data: Dictionary = preset.offset
	camera_controller.target_offset = Vector3(
		offset_data.x,
		offset_data.y,
		offset_data.z
	)
	
	current_preset_name = preset_name
	preset_loaded.emit(preset_name)
	
	print("CameraPresetManager: Loaded preset '%s'" % preset_name)
	return true


## Delete a preset
## @param preset_name: Name of preset to delete
## @return: true if successful
func delete_preset(preset_name: String) -> bool:
	if preset_name not in presets:
		push_warning("CameraPresetManager: Preset '%s' not found!" % preset_name)
		return false
	
	presets.erase(preset_name)
	save_presets()
	preset_deleted.emit(preset_name)
	
	print("CameraPresetManager: Deleted preset '%s'" % preset_name)
	return true


## Get all preset names
## @return: Array of preset names
func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for name in presets.keys():
		names.append(name)
	return names


## Check if preset exists
## @param preset_name: Preset name to check
## @return: true if exists
func has_preset(preset_name: String) -> bool:
	return preset_name in presets


## Save presets to file
func save_presets() -> void:
	var save_data := {
		"presets": presets,
		"current_preset": current_preset_name
	}
	
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not save_file:
		push_error("CameraPresetManager: Failed to open save file!")
		return
	
	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.close()
	
	print("CameraPresetManager: Saved %d presets" % presets.size())


## Load presets from file
func load_presets() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("CameraPresetManager: No presets file found")
		return
	
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not save_file:
		push_error("CameraPresetManager: Failed to open presets file!")
		return
	
	var json_text := save_file.get_as_text()
	save_file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	
	if parse_result != OK:
		push_error("CameraPresetManager: Failed to parse presets JSON!")
		return
	
	var save_data: Dictionary = json.get_data()
	presets = save_data.get("presets", {})
	current_preset_name = save_data.get("current_preset", "")
	
	print("CameraPresetManager: Loaded %d presets" % presets.size())


## Create default presets
func create_default_presets() -> void:
	if not camera_controller:
		return
	
	# Save current as Overview
	var current_dir: CameraController.CameraDirection = camera_controller.get_camera_direction()
	var current_fov: float = camera_controller.target_fov
	var current_offset: Vector3 = camera_controller.target_offset
	
	# Overview preset (default)
	camera_controller.reset_camera()
	save_current_preset("Overview")
	
	# Close-up preset
	camera_controller.set_zoom(GameConfig.camera.get("min_fov", 30.0))
	save_current_preset("Close")
	
	# Wide preset
	camera_controller.set_zoom(GameConfig.camera.get("max_fov", 90.0))
	save_current_preset("Wide")
	
	# Restore original
	camera_controller.set_camera_direction(current_dir)
	camera_controller.target_fov = current_fov
	camera_controller.target_offset = current_offset
	
	print("CameraPresetManager: Created default presets")


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Camera Presets ===\n"
	summary += "Presets: %d\n" % presets.size()
	summary += "Current: %s\n" % current_preset_name
	
	if not presets.is_empty():
		summary += "\nAvailable Presets:\n"
		for preset_name in presets:
			var preset: Dictionary = presets[preset_name]
			var marker := " [*]" if preset_name == current_preset_name else ""
			summary += "  - %s%s\n" % [preset_name, marker]
			summary += "      Direction: %s\n" % CameraController.CameraDirection.keys()[preset.direction]
			summary += "      FOV: %.1f\n" % preset.fov
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
