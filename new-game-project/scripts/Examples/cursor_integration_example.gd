"""
FILE: cursor_integration_example.gd
PURPOSE: Demo showing complete cursor system integration with CursorController, CursorVisual, PathDisplay, and game states.
FUNCTIONS: _ready, _connect_signals, example_basic_cursor, example_unit_hover, example_path_preview, example_state_changes, example_combat_targeting, signal handlers, _update_path_to_cursor, print_debug_info - 13+ total
NOTES: Demonstrates all 8 cursor states (NORMAL, HOVER_UNIT, HOVER_ENEMY, VALID_TARGET, INVALID_TARGET, SELECTED, MOVING, ATTACKING), path preview with color changes, complete combat workflow simulation, state-based visual changes.
"""


extends Node3D

## Demonstrates complete cursor system integration with game states

# --- Components ---
@onready var cursor_controller: Node = $Cursor/CursorController
@onready var cursor_visual: CursorVisual = $Cursor/CursorVisual
@onready var path_display: PathDisplay = $Cursor/PathDisplay

# --- Managers ---
@onready var game_state = get_node("/root/GameStateManager")
@onready var unit_manager = get_tree().get_first_node_in_group("unit_manager")

# --- State ---
var selected_unit: Node = null
var hovered_unit: Node = null


func _ready() -> void:
	print("=== Cursor Integration Example ===\n")
	
	_connect_signals()
	example_basic_cursor()
	
	await get_tree().create_timer(2.0).timeout
	example_unit_hover()
	
	await get_tree().create_timer(2.0).timeout
	example_path_preview()
	
	await get_tree().create_timer(2.0).timeout
	example_state_changes()


## Connect all signals
func _connect_signals() -> void:
	if cursor_controller:
		cursor_controller.cursor_moved.connect(_on_cursor_moved)
		cursor_controller.cursor_selected.connect(_on_cursor_selected)
		cursor_controller.cursor_cancelled.connect(_on_cursor_cancelled)
	
	if game_state and game_state.has_signal("state_changed"):
		game_state.state_changed.connect(_on_game_state_changed)
	
	print("✓ Signals connected")


## Example 1: Basic Cursor Movement
func example_basic_cursor() -> void:
	print("\nEXAMPLE 1: Basic Cursor Movement")
	print("-" * 30)
	
	# Set to normal state
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
		print("Cursor state: NORMAL (Cyan, bobbing)")
	
	# Move cursor around
	var positions := [
		Vector2i(0, 0),
		Vector2i(2, 0),
		Vector2i(2, 2),
		Vector2i(0, 2),
		Vector2i(1, 1)
	]
	
	for pos in positions:
		if cursor_controller and cursor_controller.has_method("set_position"):
			cursor_controller.set_position(pos)
			print("  Moved to: %s" % pos)
			await get_tree().create_timer(0.5).timeout


## Example 2: Unit Hover Detection
func example_unit_hover() -> void:
	print("\nEXAMPLE 2: Unit Hover Detection")
	print("-" * 30)
	
	# Simulate hovering over friendly unit
	print("Hovering over friendly unit...")
	if cursor_visual:
		# Create mock unit
		var mock_unit := Node.new()
		mock_unit.name = "MockPlayerUnit"
		mock_unit.add_to_group("player")
		
		cursor_visual.set_hovered_unit(mock_unit)
		print("  State: HOVER_UNIT (Green)")
		await get_tree().create_timer(1.0).timeout
		
		mock_unit.queue_free()
	
	# Simulate hovering over enemy
	print("Hovering over enemy unit...")
	if cursor_visual:
		var mock_enemy := Node.new()
		mock_enemy.name = "MockEnemyUnit"
		mock_enemy.add_to_group("enemy")
		
		cursor_visual.set_hovered_unit(mock_enemy)
		print("  State: HOVER_ENEMY (Red, pulsing)")
		await get_tree().create_timer(1.0).timeout
		
		mock_enemy.queue_free()
	
	# Clear hover
	print("Clearing hover...")
	if cursor_visual:
		cursor_visual.set_hovered_unit(null)
		print("  State: NORMAL")


## Example 3: Path Preview
func example_path_preview() -> void:
	print("\nEXAMPLE 3: Path Preview")
	print("-" * 30)
	
	if not path_display:
		print("  ✗ PathDisplay not found")
		return
	
	# Create sample path
	var sample_path: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(2, 2)
	]
	
	print("Displaying movement path:")
	for pos in sample_path:
		print("  → %s" % pos)
	
	path_display.display_path(sample_path)
	print("  ✓ Path displayed with %d nodes" % sample_path.size())
	
	await get_tree().create_timer(2.0).timeout
	
	# Change color
	print("Changing path color to GREEN...")
	path_display.update_path_color(Color.GREEN)
	
	await get_tree().create_timer(1.0).timeout
	
	# Clear path
	print("Clearing path...")
	path_display.clear_path()
	print("  ✓ Path cleared")


## Example 4: State Changes
func example_state_changes() -> void:
	print("\nEXAMPLE 4: State-Based Visuals")
	print("-" * 30)
	
	if not cursor_visual:
		print("  ✗ CursorVisual not found")
		return
	
	# Cycle through all states
	var states := [
		CursorVisual.CursorState.NORMAL,
		CursorVisual.CursorState.HOVER_UNIT,
		CursorVisual.CursorState.HOVER_ENEMY,
		CursorVisual.CursorState.VALID_TARGET,
		CursorVisual.CursorState.INVALID_TARGET,
		CursorVisual.CursorState.SELECTED,
		CursorVisual.CursorState.MOVING,
		CursorVisual.CursorState.ATTACKING
	]
	
	for state in states:
		var state_name := CursorVisual.STATE_NAMES.get(state, "Unknown")
		print("State: %s" % state_name)
		cursor_visual.set_state(state)
		await get_tree().create_timer(1.0).timeout
	
	# Back to normal
	cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
	print("  ✓ Returned to NORMAL")


## Example 5: Complete Combat Targeting Workflow
func example_combat_targeting() -> void:
	print("\nEXAMPLE 5: Combat Targeting Workflow")
	print("-" * 30)
	
	# 1. Player selects unit
	print("1. Unit selected")
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.SELECTED)
	await get_tree().create_timer(1.0).timeout
	
	# 2. Show movement path
	print("2. Showing movement path")
	if path_display:
		var move_path: Array[Vector2i] = [
			Vector2i(1, 1),
			Vector2i(2, 1),
			Vector2i(3, 1)
		]
		path_display.display_path(move_path)
		path_display.update_path_color(Color.GREEN)
	await get_tree().create_timer(1.0).timeout
	
	# 3. Enter attack targeting
	print("3. Entering attack targeting")
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.ATTACKING)
	await get_tree().create_timer(1.0).timeout
	
	# 4. Valid target found
	print("4. Valid target found")
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.VALID_TARGET)
		cursor_visual.flash(Color.YELLOW, 0.5)
	await get_tree().create_timer(1.0).timeout
	
	# 5. Combat confirmed
	print("5. Combat confirmed")
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.ATTACKING)
	if path_display:
		path_display.clear_path()
	await get_tree().create_timer(1.0).timeout
	
	# 6. Return to normal
	print("6. Combat complete, return to normal")
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
	
	print("  ✓ Workflow complete!")


## Signal Handlers

func _on_cursor_moved(grid_pos: Vector2i) -> void:
	print("Cursor moved to: %s" % grid_pos)
	
	# Update hover detection
	if unit_manager and unit_manager.has_method("get_unit_at_position"):
		var unit = unit_manager.get_unit_at_position(grid_pos)
		hovered_unit = unit
		
		if cursor_visual:
			cursor_visual.set_hovered_unit(unit)
	
	# Update path preview if unit selected
	if selected_unit and path_display:
		_update_path_to_cursor(grid_pos)


func _on_cursor_selected(grid_pos: Vector2i) -> void:
	print("Cursor selected at: %s" % grid_pos)
	
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.SELECTED)
		cursor_visual.flash(Color.WHITE, 0.3)
	
	# Check for unit at position
	if hovered_unit:
		selected_unit = hovered_unit
		print("  Selected unit: %s" % selected_unit.name)


func _on_cursor_cancelled() -> void:
	print("Cursor cancelled")
	
	selected_unit = null
	
	if cursor_visual:
		cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
	
	if path_display:
		path_display.clear_path()


func _on_game_state_changed(new_state) -> void:
	print("Game state changed: %s" % new_state)
	
	if not cursor_visual:
		return
	
	# Update cursor visual based on game state
	match new_state:
		0:  # PLAYER_TURN
			cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
		1:  # UNIT_SELECTED
			cursor_visual.set_state(CursorVisual.CursorState.SELECTED)
		2:  # ATTACK_TARGETING
			cursor_visual.set_state(CursorVisual.CursorState.ATTACKING)


## Helper: Update path preview
func _update_path_to_cursor(target_pos: Vector2i) -> void:
	if not selected_unit or not path_display:
		return
	
	# Get unit position (assuming it has grid_position)
	var start_pos: Vector2i
	if selected_unit.has("grid_position"):
		start_pos = selected_unit.grid_position
	else:
		return
	
	# Calculate path using GridManager
	var path := GridManager.get_grid_path(start_pos, target_pos, selected_unit)
	
	if path.size() > 0:
		# Show path
		path_display.display_path(path)
		
		# Color based on movement range
		var movement_range := 4  # Example
		if path.size() <= movement_range + 1:
			path_display.update_path_color(Color.GREEN)
		else:
			path_display.update_path_color(Color.YELLOW)
	else:
		path_display.clear_path()


## Print debug info
func print_debug_info() -> void:
	print("\n=== Cursor System Debug ===")
	
	if cursor_visual:
		cursor_visual.debug_print()
	
	if path_display:
		path_display.debug_print()
	
	if cursor_controller and cursor_controller.has_method("get_position"):
		print("Cursor Position: %s" % cursor_controller.get_position())
