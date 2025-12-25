"""
FILE: unit_manager.gd
PURPOSE: Core unit management system with team indexing, caching, selection, movement, and pathfinding.

OVERVIEW:
This central manager tracks all units on the battlefield, provides O(1) position lookups via dictionary,
maintains team indices for fast team queries, handles unit selection and movement, caches pathfinding
results for performance, and provides integrity validation. Uses dependency injection for Grid3D and
GameStateManager. Critical for all battle flow - selection, movement, AI targeting, and combat.

FUNCTIONS IN THIS FILE:

1. set_grid_3d(grid_node)
   - What it does: Injects Grid3D dependency for visual highlighting
   - Uses: Called by Main at initialization
   - Returns: void

2. add_unit(unit_node)
   - What it does: Adds unit to all tracking structures (array, lookup, team index), connects signals
   - Uses: Called when spawning units at battle start or as reinforcements
   - Returns: void

3. register_unit(unit_node)
   - What it does: Alias for add_unit()
   - Uses: Convenience method for unit factories
   - Returns: void

4. remove_unit(unit_node)
   - What it does: Removes unit from all structures, disconnects signals, clears caches
   - Uses: Called when unit dies or is removed from battle
   - Returns: void

5. clear_all_units()
   - What it does: Removes and frees all units, clears all structures (for loading saves)
   - Uses: Before loading a saved game
   - Returns: void

6. get_unit_at_position(grid_pos)
   - What it does: O(1) lookup of unit at grid position via dictionary
   - Uses: For occupancy checks, pathfinding, combat targeting
   - Returns: Node (Unit) or null

7. get_units_by_team(team_id)
   - What it does: O(1) retrieval of all units on a team via index
   - Uses: For AI (get all enemies), phase transitions (reset all player units)
   - Returns: Array

8. get_all_units()
   - What it does: Returns copy of all units array
   - Uses: For displaying unit count, iterating all units
   - Returns: Array

9. select_unit(unit)
   - What it does: Selects unit, calculates/displays movement range, updates game state
   - Uses: When player clicks on friendly unit
   - Returns: bool (true if selected successfully)

10. deselect_current_unit()
    - What it does: Deselects unit, clears highlights, returns to PLAYER_TURN state
    - Uses: When player cancels selection or completes action
    - Returns: void

11. display_movement_range()
    - What it does: Calls Grid3D to highlight reachable cells
    - Uses: After calculating movement range
    - Returns: void

12. clear_movement_range()
    - What it does: Clears highlights on Grid3D
    - Uses: After movement confirmed or selection cancelled
    - Returns: void

13. is_position_in_movement_range(grid_pos)
    - What it does: Checks if position is in current_reachable_cells array
    - Uses: For validating movement destinations
    - Returns: bool

14. get_path_to_target(target_pos)
    - What it does: Gets cached or calculated path from selected unit to target
    - Uses: For displaying path preview, executing movement
    - Returns: Array[Vector2i]

15. move_selected_unit_to(target_pos)
    - What it does: Validates, gets path, executes movement animation for selected unit
    - Uses: When player confirms movement destination
    - Returns: bool (true if movement started)

16. move_unit_to(unit, target_pos)
    - What it does: Moves any unit (for AI use, no selection state)
    - Uses: Enemy AI movement execution
    - Returns: bool

17. find_closest_player_unit(enemy_unit)
    - What it does: Returns player unit closest to enemy via Manhattan distance
    - Uses: AI target selection
    - Returns: Node (Unit) or null

18. get_best_move_towards_target(unit, target_pos)
    - What it does: Finds reachable position closest to target (for AI movement)
    - Uses: AI deciding where to move to approach target
    - Returns: Vector2i

19. validate_integrity()
    - What it does: Checks for duplicate positions, lookup mismatches, team index errors
    - Uses: Debug tool for catching data structure corruption
    - Returns: Array[String] (error messages, empty if valid)

20. repair_corruption()
    - What it does: Rebuilds data structures from units array, removes invalid units
    - Uses: Attempt to recover from corrupted state
    - Returns: bool (true if repaired)

NOTES:
- Single instance manager (one per battle scene)
- Uses dependency injection for grid_3d and game_state (set by Main)
- Team constants: TEAM_PLAYER=0, TEAM_ENEMY=1
- Data structures: units (Array), unit_lookup (Dict: Vector2i->Node), team_index (Dict: int->Array)
- Path caching: LRU cache with max 100 entries, disabled via ENABLE_PATH_CACHE constant
- Dirty flag optimization: clears path cache when units move
- Emits no signals (listens to unit.unit_moved signal)
- Depends on: GridManager (pathfinding), Grid3D (highlighting), GameStateManager, SignalBus
"""


extends Node
class_name UnitManager

# --- Team Constants ---
const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

# --- Cache Settings ---
const PATH_CACHE_MAX_SIZE: int = 100
const ENABLE_PATH_CACHE: bool = true

# --- Unit Storage ---
var units: Array[Unit] = []                          # All units
var unit_lookup: Dictionary[Vector2i, Unit] = {}     # Vector2i -> Unit mapping (O(1) position lookup)
var team_index: Dictionary[int, Array] = {}          # int -> Array[Unit] (O(1) team queries)

# --- Selection State ---
var selected_unit: Unit = null
var current_reachable_cells: Array[Vector2i] = []
var _selected_unit_start_pos: Vector2i = Vector2i.ZERO # Track start position for reversion

# --- Path Cache ---
var _path_cache: Dictionary = {}                     # Cache key -> Array[Vector2i]
var _path_cache_keys: Array = []                     # For LRU management

# --- Dependencies (Injected) ---
var grid_3d: Node = null
var game_state: Node = null

# --- Validation Tracking ---
# Removed: _integrity_check_pending (unused)



func _ready() -> void:
	# Dependencies are injected by Main, so we don't validate here
	_initialize_team_index()


## Set unit manager dependencies
## @param grid_node: Grid3D node reference
## @param game_state_node: GameStateManager reference
func set_dependencies(grid_node: Node, game_state_node: Node) -> void:
	grid_3d = grid_node
	game_state = game_state_node
	_validate_dependencies()


## Validate required dependencies
func _validate_dependencies() -> void:
	if not grid_3d:
		push_warning("UnitManager: Grid3D not set - call set_dependencies()")
	if not game_state:
		push_warning("UnitManager: GameStateManager not set - call set_dependencies()")


## Initialize team index structure
func _initialize_team_index() -> void:
	team_index.clear()
	team_index[TEAM_PLAYER] = []
	team_index[TEAM_ENEMY] = []


## Add unit with validation and indexing
## @param unit_node: Unit to add
func add_unit(unit_node: Unit) -> void:
	if not _validate_unit_for_addition(unit_node):
		return
	
	# Inject dependencies if unit supports it
	if unit_node.has_method("set_dependencies") and game_state:
		unit_node.set_dependencies(game_state)
	
	# Add to main arrays
	units.append(unit_node)
	unit_lookup[unit_node.grid_position] = unit_node
	
	# Add to team index
	var team: int = unit_node.get("team") if "team" in unit_node else TEAM_PLAYER
	if not team_index.has(team):
		team_index[team] = []
	team_index[team].append(unit_node)
	
	# Connect signals
	_connect_unit_signals(unit_node)
	
	DebugLog.log("Added unit: %s (Team %d) at %s" % [
		unit_node.unit_name,
		team,
		unit_node.grid_position
	], "cyan")


## Validate unit before addition
## @param unit_node: Unit to validate
## @return: true if valid, false otherwise
func _validate_unit_for_addition(unit_node: Node) -> bool:
	if not unit_node:
		push_error("UnitManager: Cannot add null unit")
		return false
	
	if not "unit_name" in unit_node:
		push_error("UnitManager: Unit missing unit_name property")
		return false
	
	if not "grid_position" in unit_node:
		push_error("UnitManager: Unit missing grid_position property")
		return false
	
	if unit_node in units:
		push_warning("UnitManager: Unit already registered: %s" % unit_node.unit_name)
		return false
	
	# Check for position conflict
	var existing_unit := get_unit_at_position(unit_node.grid_position)
	if existing_unit:
		push_error("UnitManager: Position %s already occupied by %s" % [
			unit_node.grid_position,
			existing_unit.unit_name
		])
		return false
	
	return true


## Connect unit signals safely
## @param unit_node: Unit to connect
func _connect_unit_signals(unit_node: Node) -> void:
	if not unit_node.has_signal("unit_moved"):
		return
	
	if unit_node.unit_moved.is_connected(_on_unit_moved):
		return
	
	unit_node.unit_moved.connect(_on_unit_moved.bind(unit_node))


## Register unit (alias for add_unit)
## @param unit_node: Unit to register
func register_unit(unit_node: Node) -> void:
	add_unit(unit_node)


## Handle unit movement signal
## @param old_pos: Previous position
## @param new_pos: New position
## @param unit: Unit that moved
func _on_unit_moved(old_pos: Vector2i, new_pos: Vector2i, unit: Node) -> void:
	# Update lookup
	unit_lookup.erase(old_pos)
	unit_lookup[new_pos] = unit
	
	# Clear path cache (unit positions changed)
	_clear_path_cache()


## Remove unit with cleanup
## @param unit_node: Unit to remove
func remove_unit(unit_node: Node) -> void:
	if not unit_node:
		return
	
	# Remove from main array
	var index := units.find(unit_node)
	if index >= 0:
		units.remove_at(index)
	
	# Remove from position lookup
	if "grid_position" in unit_node:
		unit_lookup.erase(unit_node.grid_position)
	
	# Remove from team index
	var team: int = unit_node.get("team") if "team" in unit_node else TEAM_PLAYER
	if team_index.has(team):
		var team_units: Array = team_index[team]
		var team_index_pos := team_units.find(unit_node)
		if team_index_pos >= 0:
			team_units.remove_at(team_index_pos)
	
	# Disconnect signals
	if unit_node.has_signal("unit_moved") and unit_node.unit_moved.is_connected(_on_unit_moved):
		unit_node.unit_moved.disconnect(_on_unit_moved)
	
	# Deselect if selected
	if selected_unit == unit_node:
		deselect_current_unit()
	
	# Clear caches
	_clear_path_cache()
	
	DebugLog.log("Removed unit: %s" % unit_node.unit_name, "yellow")


## Clear all units (for loading saves)
func clear_all_units() -> void:
	# Queue free all units
	for unit in units:
		if is_instance_valid(unit):
			unit.queue_free()
	
	# Clear all data structures
	units.clear()
	unit_lookup.clear()
	team_index[TEAM_PLAYER].clear()
	team_index[TEAM_ENEMY].clear()
	current_reachable_cells.clear()
	selected_unit = null
	
	# Clear caches
	_clear_path_cache()
	
	DebugLog.log("Cleared all units", "yellow")


## Get unit at position (O(1) lookup)
## @param grid_pos: Grid position
## @return: Unit at position or null
func get_unit_at_position(grid_pos: Vector2i) -> Unit:
	var unit: Unit = unit_lookup.get(grid_pos, null)
	
	# Validate unit is still valid
	if unit and not _is_unit_valid(unit):
		# Cleanup corrupted entry
		unit_lookup.erase(grid_pos)
		return null
	
	return unit


## Check if unit is valid and in scene tree
## @param unit: Unit to check
## @return: true if valid, false otherwise
func _is_unit_valid(unit: Node) -> bool:
	if not unit:
		return false
	
	if not is_instance_valid(unit):
		return false
	
	if not unit.is_inside_tree():
		return false
	
	return true


## Get all units for a team (O(1) with index)
## @param team_id: Team ID
## @return: Array of units on that team
func get_units_by_team(team_id: int) -> Array:
	if not team_index.has(team_id):
		return []
	
	# Return copy to prevent external modification
	return team_index[team_id].duplicate()


## Get all units (returns copy)
## @return: Array of all units
func get_all_units() -> Array:
	return units.duplicate()


## Select unit with validation
## @param unit: Unit to select
## @return: true if selected, false if invalid
func select_unit(unit: Unit) -> bool:
	if not _validate_unit_for_selection(unit):
		return false
	
	# Deselect previous
	if selected_unit and selected_unit != unit:
		selected_unit.deselect()
		clear_movement_range()
	
	# Select new unit
	selected_unit = unit
	_selected_unit_start_pos = unit.grid_position # Store for reversion
	if unit.has_method("select"):
		unit.select()
	
	# Calculate movement range
	_calculate_and_display_movement_range()
	
	# Update game state
	if game_state and game_state.has_method("start_unit_selection"):
		game_state.start_unit_selection()
	
	return true


## Validate unit can be selected
## @param unit: Unit to validate
## @return: true if can select, false otherwise
func _validate_unit_for_selection(unit: Node) -> bool:
	if not unit:
		push_warning("UnitManager: Cannot select null unit")
		return false
	
	if not _is_unit_valid(unit):
		push_warning("UnitManager: Cannot select invalid unit")
		return false
	
	if game_state and game_state.has_method("is_input_allowed"):
		if not game_state.is_input_allowed():
			return false
	
	# Check if unit can act
	if "has_acted" in unit and unit.has_acted:
		DebugLog.log("Cannot select %s - already acted" % unit.unit_name, "yellow")
		return false
	
	# Check if alive
	if unit.has_method("is_alive") and not unit.is_alive():
		DebugLog.log("Cannot select %s - dead" % unit.unit_name, "yellow")
		return false
	
	# Check if player unit
	var team: int = unit.get("team") if "team" in unit else TEAM_PLAYER
	if team != TEAM_PLAYER:
		DebugLog.log("Cannot select %s - enemy unit" % unit.unit_name, "yellow")
		return false
	
	return true


## Calculate and display movement range
func _calculate_and_display_movement_range() -> void:
	print("UnitManager: Calculating movement range...")
	if not selected_unit:
		print("UnitManager: No selected unit!")
		return
	
	if not GridManager:
		push_error("UnitManager: GridManager not available")
		return
	
	var movement_range: int = selected_unit.get("movement_range") if "movement_range" in selected_unit else 3
	print("UnitManager: Unit %s movement_range=%d at pos %s" % [selected_unit.unit_name, movement_range, selected_unit.grid_position])
	
	current_reachable_cells = GridManager.get_movement_range(
		selected_unit.grid_position,
		movement_range,
		selected_unit
	)
	
	print("UnitManager: Got %d reachable cells" % current_reachable_cells.size())
	display_movement_range()


## Display movement range on grid
func display_movement_range() -> void:
	print("UnitManager: display_movement_range called, grid_3d=%s" % grid_3d)
	if not grid_3d:
		print("UnitManager: No grid_3d reference!")
		return
	
	if grid_3d.has_method("highlight_movement_range"):
		print("UnitManager: Calling grid_3d.highlight_movement_range with %d cells" % current_reachable_cells.size())
		grid_3d.highlight_movement_range(current_reachable_cells)
	else:
		print("UnitManager: grid_3d doesn't have highlight_movement_range method!")


## Deselect current unit
func deselect_current_unit() -> void:
	if selected_unit:
		if selected_unit.has_method("deselect"):
			selected_unit.deselect()
		selected_unit = null
	
	clear_movement_range()
	
	if game_state and game_state.has_method("cancel_unit_selection"):
		game_state.cancel_unit_selection()


## Clear movement range display
func clear_movement_range() -> void:
	current_reachable_cells.clear()
	
	if not grid_3d:
		return
	
	if grid_3d.has_method("clear_highlights"):
		grid_3d.clear_highlights()
	if grid_3d.has_method("clear_path"):
		grid_3d.clear_path()


## Check if position is in movement range
## @param grid_pos: Position to check
## @return: true if in range, false otherwise
func is_position_in_movement_range(grid_pos: Vector2i) -> bool:
	return grid_pos in current_reachable_cells


## Get path to target with caching
## @param target_pos: Destination position
## @return: Array of path positions
func get_path_to_target(target_pos: Vector2i) -> Array[Vector2i]:
	if not selected_unit:
		return []
	
	return _get_cached_path(selected_unit.grid_position, target_pos, selected_unit)


## Get cached path or calculate new one
## @param start: Start position
## @param end: End position
## @param unit: Unit for path validation
## @return: Array of path positions
func _get_cached_path(start: Vector2i, end: Vector2i, unit: Node) -> Array:
	if not ENABLE_PATH_CACHE:
		return _calculate_path(start, end, unit)
	
	# Create cache key
	var cache_key := "%s-%s-%s" % [start, end, unit.get_instance_id()]
	
	# Check cache
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	
	# Calculate path
	var path := _calculate_path(start, end, unit)
	
	# Cache result
	_add_to_path_cache(cache_key, path)
	
	return path


## Calculate path using GridManager
## @param start: Start position
## @param end: End position
## @param unit: Unit for validation
## @return: Array of path positions
func _calculate_path(start: Vector2i, end: Vector2i, unit: Node) -> Array:
	if not GridManager:
		return []
	
	if not GridManager.is_within_grid(end):
		return []
	
	return GridManager.get_grid_path(start, end, unit)


## Add path to cache with LRU management
## @param key: Cache key
## @param path: Path to cache
func _add_to_path_cache(key: String, path: Array) -> void:
	# Manage cache size
	if _path_cache_keys.size() >= PATH_CACHE_MAX_SIZE:
		var oldest_key: String = _path_cache_keys.pop_front()
		_path_cache.erase(oldest_key)
	
	_path_cache[key] = path
	_path_cache_keys.append(key)


## Clear path cache
func _clear_path_cache() -> void:
	_path_cache.clear()
	_path_cache_keys.clear()


## Move selected unit to target position
## @param target_pos: Destination position
## @return: true if movement started, false otherwise
func move_selected_unit_to(target_pos: Vector2i) -> bool:
	if not _validate_movement(target_pos):
		return false
	
	# Get path
	var path := get_path_to_target(target_pos)
	if path.is_empty():
		return false
	
	# Update game state
	if game_state and game_state.has_method("start_unit_movement"):
		game_state.start_unit_movement()
	
	clear_movement_range()
	
	# Execute movement
	if selected_unit.has_method("move_along_path"):
		selected_unit.move_along_path(path)
	
	# Connect to completion
	if selected_unit.has_signal("movement_finished"):
		if not selected_unit.movement_finished.is_connected(_on_unit_movement_finished):
			selected_unit.movement_finished.connect(_on_unit_movement_finished, CONNECT_ONE_SHOT)
	
	return true


## Revert selected unit to start position (undo move)
func revert_selected_unit_movement() -> void:
	if not selected_unit:
		return
		
	if selected_unit.grid_position == _selected_unit_start_pos:
		return
	
	print("UnitManager: Reverting move for %s to %s" % [selected_unit.unit_name, _selected_unit_start_pos])
	
	# Use set_grid_position to handle visual update and signal emission (which updates unit_lookup)
	if selected_unit.has_method("set_grid_position"):
		selected_unit.set_grid_position(_selected_unit_start_pos)
	else:
		# Fallback just in case
		selected_unit.grid_position = _selected_unit_start_pos
		if selected_unit.has_method("snap_to_grid"):
			selected_unit.snap_to_grid()
	
	# Reset movement state so it can move again
	if "has_moved" in selected_unit:
		selected_unit.has_moved = false
	
	# Clear path cache
	_clear_path_cache()


## Validate movement request
## @param target_pos: Target position
## @return: true if valid, false otherwise
func _validate_movement(target_pos: Vector2i) -> bool:
	if not selected_unit:
		return false
	
	if game_state and game_state.has_method("is_movement_allowed"):
		if not game_state.is_movement_allowed():
			return false
	
	if target_pos == selected_unit.grid_position:
		return false
	
	if not is_position_in_movement_range(target_pos):
		return false
	
	# Check occupation
	var unit_at_target := get_unit_at_position(target_pos)
	if unit_at_target and unit_at_target != selected_unit:
		return false
	
	return true


## Handle movement completion
func _on_unit_movement_finished() -> void:
	if game_state and game_state.has_method("finish_unit_movement"):
		game_state.finish_unit_movement()
	
	if selected_unit and selected_unit.has_method("mark_as_moved"):
		selected_unit.mark_as_moved()
	
	# Transition to action selection
	if game_state and game_state.has_method("transition_to_action_select"):
		game_state.transition_to_action_select()
	
	# Request action menu
	if selected_unit:
		var unit_world_pos: Vector3 = GridManager.grid_to_world_3d(selected_unit.grid_position)
		SignalBus.action_menu_requested.emit(unit_world_pos)
		
		# Ensure camera focuses on unit after movement
		if game_state and game_state.has_method("request_camera_focus"):
			game_state.request_camera_focus(selected_unit.grid_position)


## Move unit to position (AI use)
## @param unit: Unit to move
## @param target_pos: Target position
## @return: true if movement started, false otherwise
func move_unit_to(unit: Node, target_pos: Vector2i) -> bool:
	if not unit or not GridManager:
		return false
	
	if not GridManager.is_within_grid(target_pos):
		return false
	
	# Check occupation
	var unit_at_target := get_unit_at_position(target_pos)
	if unit_at_target and unit_at_target != unit:
		return false
	
	# Get path
	var path := _get_cached_path(unit.grid_position, target_pos, unit)
	if path.is_empty():
		return false
	
	# Execute movement
	if unit.has_method("move_along_path"):
		unit.move_along_path(path)
	
	return true


## Find closest player unit to given position
## @param enemy_unit: Reference unit
## @return: Closest player unit or null
func find_closest_player_unit(enemy_unit: Node) -> Node:
	var player_units := get_units_by_team(TEAM_PLAYER)
	if player_units.is_empty():
		return null
	
	var closest_unit: Node = null
	var closest_distance: float = INF
	
	for player_unit in player_units:
		if not _is_unit_valid(player_unit):
			continue
		
		var distance := _manhattan_distance(
			player_unit.grid_position,
			enemy_unit.grid_position
		)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_unit = player_unit
	
	return closest_unit


## Get best move towards target
## @param unit: Unit to move
## @param target_pos: Target position
## @return: Best position to move to
func get_best_move_towards_target(unit: Node, target_pos: Vector2i) -> Vector2i:
	if not unit or not GridManager:
		return unit.grid_position if unit else Vector2i.ZERO
	
	var movement_range: int = unit.get("movement_range") if "movement_range" in unit else 3
	var reachable_cells: Array = GridManager.get_movement_range(
		unit.grid_position,
		movement_range,
		unit
	)
	
	if reachable_cells.is_empty():
		return unit.grid_position
	
	var best_pos: Vector2i = unit.grid_position
	var best_distance := _manhattan_distance(unit.grid_position, target_pos)
	
	for cell in reachable_cells:
		# Check occupation
		var unit_at_cell: Node = get_unit_at_position(cell)
		if unit_at_cell and unit_at_cell != unit:
			continue
		
		var distance := _manhattan_distance(cell, target_pos)
		if distance < best_distance:
			best_distance = distance
			best_pos = cell
	
	return best_pos


## Calculate Manhattan distance
## @param a: First position
## @param b: Second position
## @return: Manhattan distance
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Validate unit manager integrity
## @return: Array of error messages (empty if valid)
func validate_integrity() -> Array[String]:
	var issues: Array[String] = []
	
	# Check for duplicate positions
	var position_counts := {}
	for unit in units:
		if not _is_unit_valid(unit):
			issues.append("Invalid unit in units array")
			continue
		
		var pos_key := str(unit.grid_position)
		position_counts[pos_key] = position_counts.get(pos_key, 0) + 1
		
		if position_counts[pos_key] > 1:
			issues.append("Multiple units at %s" % unit.grid_position)
	
	# Check lookup consistency
	for pos in unit_lookup.keys():
		var unit: Node = unit_lookup[pos]
		if not _is_unit_valid(unit):
			issues.append("Invalid unit in lookup at %s" % pos)
		elif unit.grid_position != pos:
			issues.append("Lookup position mismatch for %s" % unit.unit_name)
	
	# Check team index consistency
	for team in team_index.keys():
		var team_units: Array = team_index[team]
		for unit in team_units:
			if not _is_unit_valid(unit):
				issues.append("Invalid unit in team %d index" % team)
			elif unit.get("team") != team:
				issues.append("Unit %s in wrong team index" % unit.unit_name)
	
	return issues


## Attempt to repair corrupted state
## @return: true if repaired, false if unfixable
func repair_corruption() -> bool:
	DebugLog.log("Attempting to repair unit manager state...", "yellow")
	
	# Rebuild lookup from units array
	unit_lookup.clear()
	for unit in units:
		if _is_unit_valid(unit):
			unit_lookup[unit.grid_position] = unit
	
	# Rebuild team index
	_initialize_team_index()
	for unit in units:
		if not _is_unit_valid(unit):
			continue
		
		var team: int = unit.get("team") if "team" in unit else TEAM_PLAYER
		if not team_index.has(team):
			team_index[team] = []
		team_index[team].append(unit)
	
	# Remove invalid units
	units = units.filter(func(u): return _is_unit_valid(u))
	
	# Validate repair
	var issues := validate_integrity()
	if issues.is_empty():
		DebugLog.success("Unit manager state repaired successfully")
		return true
	else:
		DebugLog.log("Repair failed: %s" % ", ".join(issues), "red")
		return false
