# unit_manager.gd - Manages all units on the grid
extends Node

var units: Array = []  # Array of all units
var selected_unit = null
var current_reachable_cells: Array = []

# Dependencies - set from main.gd (dependency injection)
var grid_3d: Node = null

@onready var game_state = get_node("/root/GameStateManager")

func set_grid_3d(grid_node: Node):
	"""Set grid_3d reference (dependency injection)"""
	grid_3d = grid_node

func _ready():
	pass

# Add a unit to the manager
func add_unit(unit_node):
	if not unit_node:
		push_error("UnitManager: Cannot add null unit")
		return
	if unit_node in units:
		push_error("UnitManager: Unit already in list: ", unit_node.unit_name)
		return
	units.append(unit_node)

# Remove a unit from the manager
func remove_unit(unit_node):
	var index = units.find(unit_node)
	if index >= 0:
		units.remove_at(index)
		# If it was selected, deselect it
		if selected_unit == unit_node:
			deselect_current_unit()

# Get unit at specific grid position
func get_unit_at_position(grid_pos: Vector2i):
	if not GridManager or not GridManager.is_within_grid(grid_pos):
		return null
	for unit in units:
		if unit and unit.is_at_position(grid_pos):
			return unit
	return null

# Select a unit (deselects previous if any)
func select_unit(unit) -> bool:
	if not unit:
		push_error("UnitManager: Cannot select null unit")
		return false
	
	if not GridManager:
		push_error("UnitManager: GridManager not available!")
		return false
	
	if not game_state.is_input_allowed():
		return false
	
	# Prevent selecting units that have already acted
	if unit.has_acted:
		print("UnitManager: Cannot select unit ", unit.unit_name, " - already acted this turn")
		return false
	
	# Prevent selecting dead units
	if not unit.is_alive():
		print("UnitManager: Cannot select unit ", unit.unit_name, " - unit is dead")
		return false
	
	# Prevent selecting enemy units
	if unit.team != 0:
		print("UnitManager: Cannot select unit ", unit.unit_name, " - not a player unit")
		return false
	
	if selected_unit and selected_unit != unit:
		selected_unit.deselect()
		clear_movement_range()
	
	selected_unit = unit
	unit.select()
	
	# Calculate and display movement range
	if selected_unit:
		current_reachable_cells = GridManager.get_movement_range(
			selected_unit.grid_position, 
			selected_unit.movement_range,
			selected_unit  # Pass unit to check for enemy blocking
		)
		display_movement_range()
		game_state.start_unit_selection()
	
	game_state.unit_selected.emit(unit)
	return true

# Deselect current unit
func deselect_current_unit():
	if selected_unit:
		selected_unit.deselect()
		selected_unit = null
	
	clear_movement_range()
	game_state.cancel_unit_selection()

# Display movement range on grid
func display_movement_range():
	if not grid_3d:
		push_error("UnitManager: Grid3D not set! Call set_grid_3d() from main.gd")
		return
	if grid_3d.has_method("highlight_movement_range"):
		grid_3d.highlight_movement_range(current_reachable_cells)

func clear_movement_range():
	current_reachable_cells.clear()
	
	if not grid_3d:
		return
	if grid_3d.has_method("clear_highlights"):
		grid_3d.clear_highlights()
	if grid_3d.has_method("clear_path"):
		grid_3d.clear_path()

# Check if position is in movement range
func is_position_in_movement_range(grid_pos: Vector2i) -> bool:
	for cell in current_reachable_cells:
		if cell == grid_pos:
			return true
	return false

# Get path to target position
func get_path_to_target(target_pos: Vector2i) -> Array:
	if not selected_unit:
		return []
	if not GridManager:
		push_error("UnitManager: GridManager not available!")
		return []
	if not GridManager.is_within_grid(target_pos):
		return []
	return GridManager.get_grid_path(
		selected_unit.grid_position, 
		target_pos,
		selected_unit  # Pass unit to check for enemy blocking
	)

# Move selected unit to position (with validation)
func move_selected_unit_to(target_pos: Vector2i) -> bool:
	if not selected_unit:
		return false
	
	if not game_state.is_movement_allowed():
		return false
	
	# Prevent moving to current position
	if target_pos == selected_unit.grid_position:
		return false
	
	if not is_position_in_movement_range(target_pos):
		return false
	
	# Check if another unit is at the target position
	var unit_at_target = get_unit_at_position(target_pos)
	if unit_at_target and unit_at_target != selected_unit:
		return false
	
	# Get path to target
	var path = get_path_to_target(target_pos)
	if path.size() == 0:
		return false
	
	# Start movement and clear visuals
	game_state.start_unit_movement()
	clear_movement_range()
	
	# Move unit along path
	selected_unit.move_along_path(path)
	
	# Connect to movement completion
	selected_unit.movement_finished.connect(_on_unit_movement_finished, CONNECT_ONE_SHOT)
	
	return true

func _on_unit_movement_finished():
	game_state.finish_unit_movement()
	
	if selected_unit:
		selected_unit.mark_as_moved()
	
	# Transition to action selection instead of immediately deselecting
	game_state.transition_to_action_select()
	
	# Request action menu at unit's position
	if selected_unit:
		var unit_world_pos = GridManager.grid_to_world_3d(selected_unit.grid_position)
		game_state.action_menu_requested.emit(unit_world_pos)

# Get all units on a specific team
func get_units_by_team(team_id: int):
	var team_units = []
	for unit in units:
		if unit.team == team_id:
			team_units.append(unit)
	return team_units

# Move a unit to a position (for AI use)
func move_unit_to(unit, target_pos: Vector2i) -> bool:
	if not unit:
		push_error("UnitManager: Cannot move null unit")
		return false
	
	if not GridManager:
		push_error("UnitManager: GridManager not available!")
		return false
	
	if not GridManager.is_within_grid(target_pos):
		return false
	
	# Check if another unit is at the target position
	var unit_at_target = get_unit_at_position(target_pos)
	if unit_at_target and unit_at_target != unit:
		return false
	
	# Get path to target
	var path = GridManager.get_grid_path(
		unit.grid_position, 
		target_pos,
		unit  # Pass unit to check for enemy blocking
	)
	if path.size() == 0:
		return false
	
	# Move unit along path
	unit.move_along_path(path)
	
	return true

# Find the closest player unit to an enemy unit
func find_closest_player_unit(enemy_unit) -> Node:
	var player_units = get_units_by_team(0)  # Team 0 is player
	if player_units.size() == 0:
		return null
	
	var closest_unit = null
	var closest_distance = INF
	
	for player_unit in player_units:
		var distance = abs(player_unit.grid_position.x - enemy_unit.grid_position.x) + \
					   abs(player_unit.grid_position.y - enemy_unit.grid_position.y)
		if distance < closest_distance:
			closest_distance = distance
			closest_unit = player_unit
	
	return closest_unit

# Get the best position to move towards a target (within movement range)
func get_best_move_towards_target(unit, target_pos: Vector2i) -> Vector2i:
	if not unit or not GridManager:
		return unit.grid_position if unit else Vector2i.ZERO
	
	var reachable_cells = GridManager.get_movement_range(
		unit.grid_position, 
		unit.movement_range,
		unit  # Pass unit to check for enemy blocking
	)
	
	if reachable_cells.size() == 0:
		return unit.grid_position
	
	var best_pos = unit.grid_position
	var best_distance = abs(target_pos.x - unit.grid_position.x) + abs(target_pos.y - unit.grid_position.y)
	
	# Find the reachable cell closest to the target
	for cell in reachable_cells:
		# Check if cell is occupied
		var unit_at_cell = get_unit_at_position(cell)
		if unit_at_cell and unit_at_cell != unit:
			continue
		
		var distance = abs(target_pos.x - cell.x) + abs(target_pos.y - cell.y)
		if distance < best_distance:
			best_distance = distance
			best_pos = cell
	
	return best_pos
