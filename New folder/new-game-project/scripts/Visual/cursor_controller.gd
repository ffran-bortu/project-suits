# cursor_controller.gd - Handles cursor movement and input
extends Node

signal cursor_moved(new_position)
signal cursor_selected(position)
signal cursor_cancelled

var grid_position: Vector2i = Vector2i(4, 4)
var move_delay: float = 0.15
var move_timer: float = 0.0
var is_active: bool = true

@onready var game_state = get_node("/root/GameStateManager")
@onready var cursor_parent: Node3D = get_parent()  # The Cursor Node3D parent
var camera_controller: Node = null

func _ready():
	# Validate parent exists
	if not cursor_parent:
		push_error("CursorController: Parent Node3D not found!")
		return
	
	# Get camera controller reference (will be set from main.gd if available)
	if get_tree().get_root().has_node("Main/CameraController"):
		camera_controller = get_tree().get_root().get_node("Main/CameraController")
	
	update_cursor_position()
	# Listen to state changes
	game_state.state_changed.connect(_on_state_changed)

func set_camera_controller(controller: Node):
	"""Set camera controller reference (dependency injection)"""
	camera_controller = controller

func _process(delta):
	if not is_active:
		return
	
	if move_timer > 0:
		move_timer -= delta
		return
	
	handle_input()

func _on_state_changed(new_state, old_state):
	# Update cursor activity based on state
	# Disable cursor during ACTION_SELECT (action menu handles input)
	if new_state == game_state.GameState.ACTION_SELECT:
		is_active = false
	else:
		is_active = game_state.is_cursor_allowed()
	# Visual feedback is handled by grid highlight, no sprite needed

func handle_input():
	# Don't process input if in ACTION_SELECT state (action menu handles input)
	if game_state.current_state == game_state.GameState.ACTION_SELECT:
		return
	
	var moved = false
	var new_pos = grid_position
	
	# Handle movement based on state
	if game_state.current_state == game_state.GameState.PLAYER_TURN or \
	   game_state.current_state == game_state.GameState.UNIT_SELECTED or \
	   game_state.current_state == game_state.GameState.ATTACK_TARGETING:
		
		# Get camera-relative directions
		var forward_dir: Vector2i
		var backward_dir: Vector2i
		var right_dir: Vector2i
		var left_dir: Vector2i
		
		if camera_controller:
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
		
		# Map input to camera-relative movement (rotated 90 degrees clockwise)
		# Up → Right, Right → Forward, Down → Left, Left → Backward
		if Input.is_action_pressed("move_up"):  # Up Arrow - moves right relative to camera
			new_pos += right_dir
			moved = true
		elif Input.is_action_pressed("move_down"):  # Down Arrow - moves left relative to camera
			new_pos += left_dir
			moved = true
		elif Input.is_action_pressed("move_left"):  # Left Arrow - moves backward (away from camera)
			new_pos += backward_dir
			moved = true
		elif Input.is_action_pressed("move_right"):  # Right Arrow - moves forward (toward camera)
			new_pos += forward_dir
			moved = true
	
	if moved and GridManager.is_within_grid(new_pos):
		grid_position = new_pos
		update_cursor_position()
		cursor_moved.emit(grid_position)
		move_timer = move_delay
	
	# Handle selection based on state
	if Input.is_action_just_pressed("select"):
		# Only process if not in ACTION_SELECT (action menu handles its own input)
		if game_state.current_state != game_state.GameState.ACTION_SELECT:
			cursor_selected.emit(grid_position)
	
	# Handle cancel based on state
	if Input.is_action_just_pressed("cancel"):
		if game_state.current_state == game_state.GameState.UNIT_SELECTED:
			cursor_cancelled.emit()
		elif game_state.current_state == game_state.GameState.ATTACK_TARGETING:
			cursor_cancelled.emit()
		elif game_state.current_state == game_state.GameState.PLAYER_TURN:
			# Could be used for menu or other actions
			pass

func update_cursor_position():
	# Convert grid position to world 3D position
	var world_pos = GridManager.grid_to_world_3d(grid_position)
	world_pos.y += 0.1  # Lift cursor slightly above terrain
	
	# Move the cursor parent Node3D to world position
	if cursor_parent:
		cursor_parent.position = world_pos
		
		# Scale cursor appropriately (slightly smaller than units)
		cursor_parent.scale = GridManager.get_unit_scale() * 0.8

func get_position() -> Vector2i:
	return grid_position

func set_position(grid_pos: Vector2i):
	if GridManager.is_within_grid(grid_pos):
		grid_position = grid_pos
		update_cursor_position()

func on_camera_direction_changed():
	# Camera direction changed - cursor position stays the same
	# but visual representation might need updating
	update_cursor_position()
