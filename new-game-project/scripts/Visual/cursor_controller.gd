"""
FILE: cursor_controller.gd
PURPOSE: Handles tactical cursor movement, input processing, and target cycling during gameplay.

OVERVIEW:
This controller manages the cursor on the tactical grid, processing keyboard input for movement with
camera-relative controls, handling selection and cancellation events, and delegating target cycling
to the TargetSelector during attack/pair/split targeting states. Movement uses a delay timer for
smooth repeated input and validates against grid boundaries. Input is context-aware based on game state.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Validates autoload dependencies, gets camera controller reference, and connects to state changes
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. set_camera_controller(controller: Node)
   - What it does: Dependency injection setter for camera controller reference
   - Uses: Called by main scene to establish camera connection
   - Returns: void

3. _input(event: InputEvent) -> void
   - What it does: Processes Z (select) and X (cancel) key presses with special handling for targeting states
   - Uses: Godot input callback for keypress events
   - Returns: void

4. _process(delta)
   - What it does: Decrements move timer and calls handle_input when ready for next movement
   - Uses: Called every frame to manage movement timing
   - Returns: void

5. _on_state_changed(new_state)
   - What it does: Updates cursor activity state based on game state changes
   - Uses: Signal callback from GameStateManager when state transitions occur
   - Returns: void

6. handle_input()
   - What it does: Processes cursor movement via arrow keys/WASD with camera-relative mapping, handles target cycling delegation
   - Uses: Called from _process when move timer expires
   - Returns: void

7. update_cursor_position()
   - What it does: Converts grid position to world 3D coordinates and updates cursor parent Node3D's transform
   - Uses: Called after cursor moves to sync visual position
   - Returns: void

8. get_position() -> Vector2i
   - What it does: Returns current cursor grid position
   - Uses: Query method for other systems needing cursor location
   - Returns: Vector2i - current grid coordinates

9. set_position(grid_pos: Vector2i)
   - What it does: Directly sets cursor to specified grid position and updates visual
   - Uses: Called to snap cursor to specific location (e.g., unit selection)
   - Returns: void

10. on_camera_direction_changed()
    - What it does: Refreshes cursor visual when camera rotates
    - Uses: Called by camera controller when orientation changes
    - Returns: void

NOTES:
- Depends on GameStateManager autoload for state-based input blocking
- Depends on GridManager autoload for coordinate conversion and boundary validation
- Depends on CameraController for camera-relative movement direction mapping
- Emits cursor_moved signal with grid position when cursor moves
- Emits cursor_selected signal with grid position on Z key press
- Emits cursor_cancelled signal on X key cancellation
- Input rotated 90 degrees clockwise: Up→Right, Right→Forward, Down→Left, Left→Backward relative to camera
- Blocks input when combat forecast visible or ACTION_SELECT state active
- Blocks input when mouse is over UI elements (via UIHelper)
- Delegates target cycling to main node's TargetSelector in ATTACK_TARGETING, PAIR_TARGETING, SPLIT_TARGETING states
- Movement delay of 0.15s prevents too-rapid repeated movement
"""

# cursor_controller.gd - Handles cursor movement and input
extends Node
class_name CursorController

signal cursor_moved(new_position)
signal cursor_selected(position)
signal cursor_cancelled
signal unit_hovered(unit: Unit)  # For character status panel
signal unit_unhovered()  # For character status panel

var grid_position: Vector2i = Vector2i(4, 4)
var move_delay: float = 0.15
var move_timer: float = 0.0
var is_active: bool = true

@onready var game_state: GameStateManager = get_node("/root/GlobalGameState")
@onready var cursor_parent: Node3D = get_parent()  # The Cursor Node3D parent
var camera_controller: Node = null

# Target cycling for attack targeting
var valid_targets: Array = []
var current_target_index: int = 0

# Deployment tile snapping
var deployment_spawn_tiles: Array[Vector2i] = []
var current_deployment_tile_index: int = 0
var cursor_visual: MeshInstance3D = null

# Track last hovered unit for status panel
var _last_hovered_unit: Unit = null

func _ready() -> void:
	# Validate game_state autoload
	if not game_state:
		push_error("CursorController: GameStateManager autoload not found!")
		return
	
	# Validate parent exists
	if not cursor_parent:
		push_error("CursorController: Parent Node3D not found!")
		return
	
	# Validate GridManager autoload
	if not GridManager:
		push_error("CursorController: GridManager autoload not found!")
		return
	
	# Get camera controller reference (will be set from main.gd if available)
	if get_tree().get_root().has_node("Main/CameraController"):
		camera_controller = get_tree().get_root().get_node("Main/CameraController")
	
	update_cursor_position()
	
	# Listen to state changes
	if game_state.state_changed and not game_state.state_changed.is_connected(_on_state_changed):
		game_state.state_changed.connect(_on_state_changed)
	
	# Listen to deployment started
	if not SignalBus.deployment_started.is_connected(_on_deployment_started):
		SignalBus.deployment_started.connect(_on_deployment_started)
	
	# Create visual cursor indicator if missing
	_ensure_cursor_visual()

func _ensure_cursor_visual() -> void:
	"""Create a visual indicator for the cursor if one doesn't exist"""
	if not cursor_parent:
		return
	
	# Check if cursor already has a visual child
	for child in cursor_parent.get_children():
		if child is MeshInstance3D and child != self:
			cursor_visual = child
			return
	
	# Create a simple ring mesh as cursor indicator
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CursorVisual"
	
	var torus = TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.4
	torus.rings = 16
	torus.ring_segments = 8
	
	mesh_instance.mesh = torus
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow with transparency
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh_instance.material_override = material
	
	cursor_parent.call_deferred("add_child", mesh_instance)
	cursor_visual = mesh_instance

func _on_deployment_started(tiles: Array[Vector2i]) -> void:
	"""Handle deployment mode start - stores spawn tiles for snapping"""
	deployment_spawn_tiles = tiles
	current_deployment_tile_index = 0
	
	# Snap cursor to first deployment tile
	if not tiles.is_empty():
		set_position(tiles[0])

func set_camera_controller(controller: Node) -> void:
	"""Set camera controller reference (dependency injection)"""
	camera_controller = controller

func _input(event: InputEvent) -> void:
	
	if not is_active:
		return
	
	# Don't process input if combat forecast is visible (let it handle input instead)
	var combat_forecast = get_tree().get_root().get_node_or_null("Main/UICanvas/CombatForecast")
	if combat_forecast and combat_forecast.visible:
		return
	
	if not game_state or not game_state.is_input_allowed():
		return
	
	if not event is InputEventKey or not event.pressed:
		return
	
	print("_input processing key: %s, current_state=%s" % [event.keycode, game_state.current_state])
	
	# Handle Z key for selection AND target confirmation
	if event.keycode == KEY_Z:
		# In pair/split targeting - confirm target
		if game_state.current_state in [
			game_state.GameState.PAIR_TARGETING,
			game_state.GameState.SPLIT_TARGETING
		]:
			var main_node = get_tree().get_first_node_in_group("main")
			if main_node and main_node.target_selector:
				main_node.target_selector.confirm_target()
				get_viewport().set_input_as_handled()
				return
		
		# Normal selection
		if game_state.current_state != game_state.GameState.ACTION_SELECT:
			cursor_selected.emit(grid_position)
			get_viewport().set_input_as_handled()
	
	# Handle X key for cancel AND targeting cancel
	elif event.keycode == KEY_X:
		# In pair/split targeting - cancel targeting
		if game_state.current_state in [
			game_state.GameState.PAIR_TARGETING,
			game_state.GameState.SPLIT_TARGETING
		]:
			var main_node = get_tree().get_first_node_in_group("main")
			if main_node and main_node.target_selector:
				main_node.target_selector.cancel()
				get_viewport().set_input_as_handled()
				return
		
		# Normal cancel behavior
		if game_state.current_state == game_state.GameState.UNIT_SELECTED:
			cursor_cancelled.emit()
			get_viewport().set_input_as_handled()
		elif game_state.current_state == game_state.GameState.ATTACK_TARGETING:
			cursor_cancelled.emit()
			get_viewport().set_input_as_handled()

func _process(delta) -> void:
	if not is_active:
		return
	
	if move_timer > 0:
		move_timer -= delta
		return
	
	handle_input()

func _on_state_changed(new_state: GameStateManager.GameState) -> void:
	# Update cursor activity based on state
	# Disable cursor during ACTION_SELECT (action menu handles input)
	if new_state == game_state.GameState.ACTION_SELECT:
		is_active = false
	else:
		is_active = game_state.is_cursor_allowed()
	# Visual feedback is handled by grid highlight, no sprite needed

func handle_input() -> void:
	# CRITICAL: Block input if combat forecast is visible
	# This check is needed here because handle_input uses Input.is_key_pressed()
	# which bypasses the _input() event system
	var combat_forecast = get_tree().get_root().get_node_or_null("Main/UICanvas/CombatForecast")
	if combat_forecast and combat_forecast.visible:
		return
	
	# Don't process input if in ACTION_SELECT state (action menu handles input)
	if game_state.current_state == game_state.GameState.ACTION_SELECT:
		return
	
	# NEW: Don't process if mouse is over UI
	if UIHelper.is_mouse_over_ui():
		return
		
	# NEW: Don't process if a UI element has focus (e.g. Unit Picker)
	if get_viewport().gui_get_focus_owner():
		return
	
	# Check for open PopupMenu (unit picker during deployment)
	var unit_picker = get_tree().get_root().get_node_or_null("Main/UICanvas/PrepScreen/UnitPicker")
	if unit_picker and unit_picker.visible:
		return
	
	var moved = false
	var new_pos = grid_position
	
	# Handle movement in DEPLOYMENT - snap to deployment tiles only
	if game_state.current_state == game_state.GameState.DEPLOYMENT:
		if deployment_spawn_tiles.is_empty():
			return  # No tiles to snap to
		
		var cycle_direction = 0
		
		# Any directional input cycles through tiles
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or \
		   Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			cycle_direction = 1  # Next tile
		elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or \
			 Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			cycle_direction = -1  # Previous tile
		
		if cycle_direction != 0:
			# Cycle through deployment tiles
			current_deployment_tile_index = (current_deployment_tile_index + cycle_direction) % deployment_spawn_tiles.size()
			if current_deployment_tile_index < 0:
				current_deployment_tile_index = deployment_spawn_tiles.size() - 1
			
			# Snap to the new tile
			var new_tile_pos = deployment_spawn_tiles[current_deployment_tile_index]
			grid_position = new_tile_pos
			update_cursor_position()
			cursor_moved.emit(grid_position)
			move_timer = move_delay
	
	# Handle movement in PLAYER_TURN and UNIT_SELECTED - free camera-relative movement
	elif game_state.current_state == game_state.GameState.PLAYER_TURN or \
		 game_state.current_state == game_state.GameState.UNIT_SELECTED:
		
		# Get camera-relative directions
		var forward_dir: Vector2i
		var backward_dir: Vector2i
		var right_dir: Vector2i
		var left_dir: Vector2i
		
		if camera_controller and camera_controller.has_method("get_forward_grid_direction"):
			forward_dir = camera_controller.get_forward_grid_direction()
			backward_dir = camera_controller.get_backward_grid_direction()
			right_dir = camera_controller.get_right_grid_direction()
			left_dir = camera_controller.get_left_grid_direction()
		else:
			# Fallback to default directions if camera controller not found
			forward_dir = Vector2i(0, 1)   # Down
			backward_dir = Vector2i(0, -1)  # Up
			right_dir = Vector2i(1, 0)      # Right
			left_dir = Vector2i(-1, 0)      # Left
		
		# Map input to camera-relative movement
		# RIGHT/LEFT swapped to match expected behavior
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):  # Up - now moves LEFT (reversed)
			new_pos += left_dir
			moved = true
		elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):  # Down - now moves RIGHT (reversed)
			new_pos += right_dir
			moved = true
		elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):  # Left - moves FORWARD
			new_pos += forward_dir
			moved = true
		elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):  # Right - moves BACKWARD
			new_pos += backward_dir
			moved = true
	
	# Handle target cycling in all targeting states (delegated to TargetSelector)
	elif game_state.current_state in [
		game_state.GameState.ATTACK_TARGETING,
		game_state.GameState.PAIR_TARGETING,
		game_state.GameState.SPLIT_TARGETING
	]:
		# Get main node's TargetSelector
		var main_node = get_tree().get_first_node_in_group("main")
		if main_node and main_node.target_selector and main_node.target_selector.is_active:
			var cycle_direction = 0
			
			if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or \
			   Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
				cycle_direction = 1  # Next target
			elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or \
			   Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
				cycle_direction = -1  # Previous target
			
			if cycle_direction == 1:
				main_node.target_selector.cycle_next()
				move_timer = move_delay
				return
			elif cycle_direction == -1:
				main_node.target_selector.cycle_previous()
				move_timer = move_delay
				return
	
	if moved and GridManager.is_within_grid(new_pos):
		grid_position = new_pos
		update_cursor_position()
		cursor_moved.emit(grid_position)
		_check_unit_hover()  # NEW: Check for unit at cursor position
		move_timer = move_delay

func update_cursor_position() -> void:
	# Convert grid position to world 3D position
	var world_pos = GridManager.grid_to_world_3d(grid_position)
	# Cursor at exact ground level for proper centering
	# world_pos.y += 0.1  # REMOVED: This lifted cursor above ground
	
	# Move the cursor parent Node3D to world position
	if cursor_parent:
		cursor_parent.position = world_pos
		
		# Scale cursor appropriately (slightly smaller than units)
		cursor_parent.scale = GridManager.get_unit_scale() * 0.8

func get_position() -> Vector2i:
	return grid_position

func set_position(grid_pos: Vector2i) -> void:
	grid_position = grid_pos
	update_cursor_position()
	_check_unit_hover() # Enable hover stats when snapping/spawning


func on_camera_direction_changed() -> void:
	# Camera direction changed - cursor position stays the same
	# but visual representation might need updating
	update_cursor_position()


## Check if cursor is hovering over a unit and emit signals
func _check_unit_hover() -> void:
	var unit_at_cursor: Unit = _get_unit_at_position(grid_position)
	
	# If unit changed (or went from unit to no unit, or vice versa)
	if unit_at_cursor != _last_hovered_unit:
		# Unhover previous unit
		if _last_hovered_unit:
			unit_unhovered.emit()
		
		# Hover new unit
		_last_hovered_unit = unit_at_cursor
		if unit_at_cursor:
			unit_hovered.emit(unit_at_cursor)


## Helper to get unit at grid position (uses UnitManager's O(1) lookup)
## @param pos: Grid position to check
## @return: Unit at position or null
func _get_unit_at_position(pos: Vector2i) -> Unit:
	# UnitManager already maintains Dictionary lookup (unit_lookup)
	# This is O(1) instead of iterating all units
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.has_node("UnitManager"):
		return null
	
	var unit_manager = main_node.get_node("UnitManager")
	if unit_manager and unit_manager.has_method("get_unit_at_position"):
		return unit_manager.get_unit_at_position(pos)
	
	return null
