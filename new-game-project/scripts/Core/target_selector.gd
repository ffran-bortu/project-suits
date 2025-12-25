"""
FILE: target_selector.gd
PURPOSE: Modular target selection system with auto-snap cursor and arrow key cycling through valid targets.

OVERVIEW:
This generic target selector handles selecting from a list of valid targets (for attack, pair up, split, etc.).
It auto-snaps the cursor to the first target, allows cycling through targets with arrow keys, and emits
signals on confirm/cancel. Eliminates code duplication across attack targeting, pair targeting, and other
selection modes. Handles both Vector2i positions and Node references (with grid_position property).

FUNCTIONS IN THIS FILE:

1. start_targeting(targets, cursor)
   - What it does: Initializes targeting mode with list of valid targets, snaps to first
   - Uses: Called when entering attack/pair/split mode to begin target selection
   - Returns: void

2. cycle_next()
   - What it does: Moves to next target in list (wraps to first after last)
   - Uses: Called when player presses right arrow or Tab
   - Returns: void

3. cycle_previous()
   - What it does: Moves to previous target in list (wraps to last from first)
   - Uses: Called when player presses left arrow or Shift+Tab
   - Returns: void

4. confirm_target()
   - What it does: Confirms current target selection and emits target_confirmed signal
   - Uses: Called when player presses Confirm/Enter key
   - Returns: void

5. cancel()
   - What it does: Cancels targeting, clears state, emits targeting_cancelled signal
   - Uses: Called when player presses Cancel/Escape key
   - Returns: void

6. get_current_target()
   - What it does: Returns the currently selected target from the list
   - Uses: For previewing combat forecast or showing selection
   - Returns: current target (Vector2i or Node) or null

7. _snap_to_current_target() [private]
   - What it does: Helper that moves cursor to current target position
   - Uses: Called after cycling or initializing
   - Returns: void

NOTES:
- Class_name TargetSelector (can be instantiated)
- Emits: target_confirmed(target), targeting_cancelled
- Depends on: CursorController (for cursor movement)
- Works with both Vector2i grid positions and Node objects (checks for grid_position property)
- Used by: attack targeting, pair up targeting, split targeting
"""

# target_selector.gd - Modular target selection system
extends Node
class_name TargetSelector

## Generic target selection with auto-snap and arrow cycling
## Usable for attack, pair, split, and any similar target selection

signal target_confirmed(target)
signal targeting_cancelled


var valid_targets: Array = []
var current_target_index: int = -1
var cursor_controller: Node = null
var is_active: bool = false

## Start target selection with given targets
## @param targets: Array of Vector2i positions or Node references
## @param cursor: CursorController reference
func start_targeting(targets: Array, cursor: Node) -> void:
	valid_targets = targets
	current_target_index = -1
	cursor_controller = cursor
	is_active = true
	
	if valid_targets.size() > 0:
		# Auto-snap to first target
		current_target_index = 0
		_snap_to_current_target()

## Cycle to next target
func cycle_next() -> void:
	if not is_active or valid_targets.is_empty():
		return
	
	current_target_index = (current_target_index + 1) % valid_targets.size()
	_snap_to_current_target()

## Cycle to previous target
func cycle_previous() -> void:
	if not is_active or valid_targets.is_empty():
		return
	
	current_target_index = (current_target_index - 1 + valid_targets.size()) % valid_targets.size()
	_snap_to_current_target()

## Confirm current target
func confirm_target() -> void:
	if not is_active or current_target_index < 0:
		return
	
	var target = valid_targets[current_target_index]
	is_active = false
	target_confirmed.emit(target)

## Cancel targeting
func cancel() -> void:
	is_active = false
	valid_targets.clear()
	current_target_index = -1
	targeting_cancelled.emit()

## Snap cursor to current target
func _snap_to_current_target() -> void:
	if not cursor_controller or current_target_index < 0:
		return
	
	var target = valid_targets[current_target_index]
	
	# Handle both Vector2i positions and Node references
	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target is Node and "grid_position" in target:
		target_pos = target.grid_position
	else:
		return
	
	cursor_controller.grid_position = target_pos
	cursor_controller.update_cursor_position()
	if cursor_controller.has_signal("cursor_moved"):
		cursor_controller.cursor_moved.emit(target_pos)

## Get current target
func get_current_target() -> Variant:
	if current_target_index >= 0 and current_target_index < valid_targets.size():
		return valid_targets[current_target_index]
	return null
