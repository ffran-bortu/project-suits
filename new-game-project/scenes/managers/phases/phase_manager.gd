"""
FILE: phase_manager.gd
PURPOSE: Turn flow orchestration system managing player and enemy turn phases with batch enemy processing.

OVERVIEW:
This manager coordinates the flow of battle turns, transitioning between player and enemy phases, resetting
unit states at turn start, processing all enemy actions with batch optimization (3 enemies per frame), and
checking victory/defeat conditions. Uses dependency injection for all managers and connects to GameState
signals to drive turn progression. Critical for battle pacing and AI execution.

FUNCTIONS IN THIS FILE:

1. set_dependencies(grid_node, menu, combat_mgr, unit_mgr, ai_mgr)
   - What it does: Injects all required dependencies (Grid3D, ActionMenu,  CombatManager, UnitManager, EnemyAI)
   - Uses: Called by Main during initialization
   - Returns: void

2. _on_state_changed(new_state)
   - What it does: Signal handler for GameState changes, starts new player phase when entering PLAYER_TURN
   - Uses: Connected to GameStateManager.state_changed signal
   - Returns: void

3. _start_new_player_phase()
   - What it does: Begins player turn, increments turn counter, resets player units, cleans up UI
   - Uses: Called when transitioning from enemy turn or initial state
   - Returns: void

4. _reset_team_units(team)
   - What it does: Calls reset_turn_state() on all alive units for  a team
   - Uses: At start of player/enemy turn to clear has_acted/has_moved flags
   - Returns: void

5. _on_enemy_turn_started()
   - What it does: Begins enemy turn, gets alive enemies, processes them in batches
   - Uses: Connected to GameStateManager.enemy_turn_started signal
   - Returns: void (async)

6. _process_enemy_actions_batch(enemy_units)
   - What it does: Processes enemies in batches of MAX_ENEMIES_PER_FRAME (3) to avoid frame drops
   - Uses: Called by _on_enemy_turn_started() to execute all enemy actions
   - Returns: void (async)

7. _process_single_enemy_turn(enemy)
   - What it does: Gets AI decision, executes movement/attack, marks as acted, delays between actions
   - Uses: Called for each enemy in batch processing
   - Returns: void (async)

8. _get_enemy_decision(enemy)
   - What it does: Calls EnemyAI.decide_action() or falls back to simple AI
   - Uses: To determine what each enemy should do
   - Returns: Dictionary {action, target, move_to}

9. _simple_ai_decision(enemy)
   - What it does: Fallback AI that finds closest player and approaches/attacks
   - Uses: When EnemyAI is not available or as backup
   - Returns: Dictionary

10. _execute_enemy_decision(enemy, decision)
    - What it does: Executes movement and attack based on AI decision
    - Uses: After getting decision from AI
    - Returns: void (async)

11. _execute_enemy_movement(enemy, move_to)
    - What it does: Calls UnitManager.move_unit_to(), waits for animation
    - Uses: To move enemy units during their turn
    - Returns: void (async)

12. _execute_enemy_attack(enemy, target)
    - What it does: Validates range, calls CombatManager.perform_attack(), waits for animation
    - Uses: To execute enemy attacks
    - Returns: void (async)

13. _end_enemy_turn()
    - What it does: Clears AI caches, delays, transitions to player turn
    - Uses: After all enemies processed
    - Returns: void (async)

14. end_current_unit_turn()
    - What it does: Marks unit as acted/moved, deselects, checks if all player units done
    - Uses: Called after player unit finishes action
    - Returns: void

15. _check_all_player_units_completed()
    - What it does: Checks if all alive player units have acted, starts enemy turn if so
    - Uses: After each player unit finishes turn
    - Returns: void

16. _check_adjacency_bonds()
    - What it does: Awards bond points to adjacent units at end of player turn
    - Uses: Called before starting enemy turn (Fire Emblem support mechanic)
    - Returns: void

NOTES:
- Single instance manager (one per battle scene)
- Uses dependency injection for all managers
- Performance constants: MAX_ENEMIES_PER_FRAME=3, ENEMY_ACTION_DELAY=0.5s, COMBAT_ANIMATION_DELAY=1.0s
- Batch processing prevents frame drops when many enemies act
- Enum TurnPhase: IDLE, PLAYER_TURN_START, PLAYER_ACTION, PLAYER_TURN_END, ENEMY_TURN_START, ENEMY_ACTION, ENEMY_TURN_END
- Enum GamePhase: PLAYER_TURN, ENEMY_TURN (for signal compatibility)
- Team constants: TEAM_PLAYER=0, TEAM_ENEMY=1
- Emits: phase_changed(new_phase)
- Depends on: UnitManager, GameStateManager, Grid3D, ActionMenu, CombatManager, EnemyAI (optional)
"""


extends Node
class_name PhaseManager

# --- Signals ---
signal phase_changed(new_phase: int)

# --- Team Constants ---
const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

# --- Performance Constants ---
const MAX_ENEMIES_PER_FRAME: int = 3      # Batch size for enemy processing
const ENEMY_ACTION_DELAY: float = 0.5     # Delay between enemy actions
const COMBAT_ANIMATION_DELAY: float = 1.0  # Wait time for combat animations
const TURN_TRANSITION_DELAY: float = 1.0   # Delay before turn transitions

# --- Turn Phase Enum ---
enum TurnPhase {
	IDLE,
	PLAYER_TURN_START,
	PLAYER_ACTION,
	PLAYER_TURN_END,
	ENEMY_TURN_START,
	ENEMY_ACTION,
	ENEMY_TURN_END
}

# --- Game Phase Enum (for compatibility with BattleManager) ---
enum GamePhase {
	PLAYER_TURN,
	ENEMY_TURN
}

# --- Dependencies (Injected) ---
var unit_manager: UnitManager = null
var game_state: Node = null
var grid_3d: Node = null
var action_menu: Panel = null
var combat_manager: CombatManager = null
var enemy_ai: Node = null

# --- State Tracking ---
var current_phase: TurnPhase = TurnPhase.IDLE
var previous_game_state: int = -1
var turn_number: int = 0
var _is_processing_enemies: bool = false


func _ready() -> void:
	# Dependencies injected via set_dependencies()
	# GameState is now injected, so we don't need to look it up
	pass


## Unified dependency injection
## @param grid_node: Grid3D reference
## @param menu: ActionMenu reference
## @param combat_mgr: CombatManager reference
## @param _unit_mgr: UnitManager reference (unused - obtained via get_node)
## @param ai_mgr: EnemyAI reference
## @param _game_state_node: GameStateManager reference (unused - obtained via get_node)
func set_dependencies(grid_node: Node, menu: Panel, combat_mgr: Node, _unit_mgr: Node, ai_mgr: Node, _game_state_node: Node) -> void:
	grid_3d = grid_node
	action_menu = menu
	combat_manager = combat_mgr
	unit_manager = _unit_mgr
	game_state = _game_state_node
	
	if ai_mgr:
		enemy_ai = ai_mgr
	else:
		enemy_ai = get_node_or_null("../EnemyAI")
	
	# Inject dependencies into EnemyAI if available
	if enemy_ai and enemy_ai.has_method("set_dependencies"):
		# We need to pass UnitManager and CombatManager
		# unit_manager is local var _unit_mgr
		# combat_manager is local var combat_mgr
		enemy_ai.set_dependencies(_unit_mgr, combat_mgr)
	
	_validate_dependencies()
	_connect_signals()


## Locate autoload dependencies (GameState)
func _locate_autoload_dependencies() -> void:
	game_state = get_node_or_null("/root/GlobalGameState")
	if not game_state:
		push_error("PhaseManager: GameStateManager autoload not found!")


## Validate all required dependencies
func _validate_dependencies() -> void:
	var missing_deps: Array[String] = []
	
	if not unit_manager:
		missing_deps.append("UnitManager")
	if not game_state:
		missing_deps.append("GameStateManager")
	if not grid_3d:
		missing_deps.append("Grid3D")
	if not combat_manager:
		missing_deps.append("CombatManager")
	if not action_menu:
		missing_deps.append("ActionMenu")
	
	if missing_deps.size() > 0:
		push_error("PhaseManager: Missing required dependencies: %s" % ", ".join(missing_deps))
		return
	
	# Warn about optional dependencies
	if not enemy_ai:
		push_warning("PhaseManager: EnemyAI not found - using fallback AI")


## Connect to game state signals
func _connect_signals() -> void:
	if not game_state:
		return
	
	if game_state.has_signal("state_changed") and not game_state.state_changed.is_connected(_on_state_changed):
		game_state.state_changed.connect(_on_state_changed)
	
	if game_state.has_signal("enemy_turn_started") and not game_state.enemy_turn_started.is_connected(_on_enemy_turn_started):
		game_state.enemy_turn_started.connect(_on_enemy_turn_started)


## Handle game state changes
## @param new_state: New game state
func _on_state_changed(new_state: int) -> void:
	# Only handle PLAYER_TURN entry
	if new_state == game_state.GameState.PLAYER_TURN:
		# Check if coming from enemy turn or initial state
		if previous_game_state == game_state.GameState.ENEMY_TURN or previous_game_state == -1:
			_start_new_player_phase()
		else:
			DebugLog.log("Returning to PLAYER_TURN from %s" % _get_state_name(previous_game_state), "cyan")
			_cleanup_ui_for_player_input()
	
	previous_game_state = new_state


## Get human-readable state name
## @param state: State value
## @return: State name string
func _get_state_name(state: int) -> String:
	if game_state and game_state.has_method("get_state_name"):
		return game_state.get_state_name(state)
	return "Unknown(%d)" % state


## Start a new player phase
func _start_new_player_phase() -> void:
	current_phase = TurnPhase.PLAYER_TURN_START
	turn_number += 1
	
	DebugLog.log("=== STARTING PLAYER TURN %d ===" % turn_number, "green")
	
	# Emit phase change signal
	phase_changed.emit(GamePhase.PLAYER_TURN)
	
	# Reset all player units
	_reset_team_units(TEAM_PLAYER)
	
	_cleanup_ui_for_player_input()
	
	current_phase = TurnPhase.PLAYER_ACTION
	DebugLog.success("=== READY FOR PLAYER INPUT ===")


## Reset all units for a team
## @param team: Team ID to reset
func _reset_team_units(team: int) -> void:
	if not unit_manager or not unit_manager.has_method("get_units_by_team"):
		return
	
	var units: Array = unit_manager.get_units_by_team(team)
	var reset_count := 0
	
	for unit in units:
		if not unit:
			continue
		
		if not unit.has_method("is_alive"):
			continue
		
		if unit.is_alive():
			if unit.has_method("reset_turn_state"):
				unit.reset_turn_state()
				reset_count += 1
	
	var team_name := "Player" if team == TEAM_PLAYER else "Enemy"
	DebugLog.log("Reset %d %s units" % [reset_count, team_name], "cyan")


## Cleanup UI for player input
func _cleanup_ui_for_player_input() -> void:
	if action_menu:
		action_menu.hide()
	
	if grid_3d:
		if grid_3d.has_method("clear_attack_highlights"):
			grid_3d.clear_attack_highlights()
		if grid_3d.has_method("clear_path"):
			grid_3d.clear_path()


## Handle enemy turn start
func _on_enemy_turn_started() -> void:
	if _is_processing_enemies:
		push_warning("PhaseManager: Enemy turn already in progress")
		return
	
	current_phase = TurnPhase.ENEMY_TURN_START
	DebugLog.log("=== STARTING ENEMY TURN %d ===" % turn_number, "yellow")
	
	# Emit phase change signal
	phase_changed.emit(GamePhase.ENEMY_TURN)
	
	# Reset enemy units
	_reset_team_units(TEAM_ENEMY)
	
	# Get enemy units
	var enemy_units := _get_alive_enemy_units()
	
	DebugLog.log("PHASE DEBUG: Found %d enemy units" % enemy_units.size(), "yellow")
	DebugLog.log("PHASE DEBUG: EnemyAI node: %s" % enemy_ai, "yellow")
	if enemy_ai:
		DebugLog.log("PHASE DEBUG: EnemyAI has decide_action: %s" % enemy_ai.has_method("decide_action"), "yellow")
	
	if enemy_units.is_empty():
		DebugLog.log("No enemy units, skipping enemy turn", "yellow")
		_end_enemy_turn()
		return
	
	DebugLog.log("Processing %d enemy units" % enemy_units.size(), "cyan")
	
	# Process enemies
	_is_processing_enemies = true
	current_phase = TurnPhase.ENEMY_ACTION
	await _process_enemy_actions_batch(enemy_units)
	_is_processing_enemies = false
	
	_end_enemy_turn()


## Get all alive enemy units
## @return: Array of alive enemy units
func _get_alive_enemy_units() -> Array:
	if not unit_manager or not unit_manager.has_method("get_units_by_team"):
		return []
	
	var enemy_units: Array = unit_manager.get_units_by_team(TEAM_ENEMY)
	var alive_enemies: Array = []
	
	for enemy in enemy_units:
		if enemy and enemy.has_method("is_alive") and enemy.is_alive():
			alive_enemies.append(enemy)
	
	return alive_enemies


## Process enemy actions with batch optimization
## @param enemy_units: Array of enemy units
func _process_enemy_actions_batch(enemy_units: Array) -> void:
	var batch_index := 0
	
	while batch_index < enemy_units.size():
		var batch_end: int = min(batch_index + MAX_ENEMIES_PER_FRAME, enemy_units.size())
		var batch: Array = enemy_units.slice(batch_index, batch_end)
		
		# Process batch
		for enemy in batch:
			if not enemy or not enemy.has_method("is_alive") or not enemy.is_alive():
				continue
			
			await _process_single_enemy_turn(enemy)
		
		batch_index = batch_end
		
		# Yield to next frame if more batches to process
		if batch_index < enemy_units.size():
			await get_tree().process_frame


## Process a single enemy's turn
## @param enemy: Enemy unit
func _process_single_enemy_turn(enemy: Unit) -> void:
	if not _validate_enemy_unit(enemy):
		return
	
	DebugLog.log("%s taking turn (HP: %d/%d)" % [
		enemy.unit_name,
		enemy.get("current_health") if "current_health" in enemy else 0,
		enemy.get("max_health") if "max_health" in enemy else 0
	], "yellow")
	
	# Get AI decision
	var decision := _get_enemy_decision(enemy)
	
	# Execute decision
	await _execute_enemy_decision(enemy, decision)
	
	# Mark as acted
	if enemy.has_method("mark_as_acted"):
		enemy.mark_as_acted()
	
	# Clear AI cache for this unit
	if enemy_ai and enemy_ai.has_method("invalidate_cache_for_unit"):
		enemy_ai.invalidate_cache_for_unit(enemy)
	
	# Small delay between actions
	await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout


## Validate enemy unit for processing
## @param enemy: Enemy unit to validate
## @return: true if valid, false otherwise
func _validate_enemy_unit(enemy: Node) -> bool:
	if not enemy:
		push_warning("PhaseManager: Null enemy unit")
		return false
	
	if not enemy.has_method("is_alive"):
		push_error("PhaseManager: Enemy missing is_alive() method")
		return false
	
	if not enemy.is_alive():
		DebugLog.log("Skipping dead enemy: %s" % enemy.unit_name, "yellow")
		return false
	
	return true


## Get enemy AI decision
## @param enemy: Enemy unit
## @return: Decision dictionary
func _get_enemy_decision(enemy: Node) -> Dictionary:
	if enemy_ai and enemy_ai.has_method("decide_action"):
		return enemy_ai.decide_action(enemy)
	
	# Fallback to simple AI
	return _simple_ai_decision(enemy)


## Simple fallback AI
## @param enemy: Enemy unit
## @return: Decision dictionary
func _simple_ai_decision(enemy: Node) -> Dictionary:
	if not unit_manager:
		return {"action": "wait", "target": null, "move_to": enemy.grid_position}
	
	# Find closest player
	var target: Node = null
	if unit_manager.has_method("find_closest_player_unit"):
		target = unit_manager.find_closest_player_unit(enemy)
	
	if not target or not target.has_method("is_alive") or not target.is_alive():
		return {"action": "wait", "target": null, "move_to": enemy.grid_position}
	
	# Get best move
	var move_pos: Vector2i = enemy.grid_position
	if unit_manager.has_method("get_best_move_towards_target"):
		var result = unit_manager.get_best_move_towards_target(enemy, target.grid_position)
		if result is Vector2i:
			move_pos = result
	
	return {
		"action": "attack_approach",
		"target": target,
		"move_to": move_pos
	}


## Execute enemy decision
## @param enemy: Enemy unit
## @param decision: Decision dictionary
func _execute_enemy_decision(enemy: Node, decision: Dictionary) -> void:
	var _action: String = decision.get("action", "wait")
	var target: Node = decision.get("target", null)
	var move_to: Vector2i = decision.get("move_to", enemy.grid_position)
	
	# Execute movement
	if move_to != enemy.grid_position:
		DebugLog.log("Executing move for %s to %s" % [enemy.unit_name, move_to], "cyan")
		await _execute_enemy_movement(enemy, move_to)
	else:
		DebugLog.log("%s staying at %s" % [enemy.unit_name, enemy.grid_position], "cyan")
	
	# Execute attack
	if target:
		if target.has_method("is_alive") and target.is_alive():
			DebugLog.log("Executing attack for %s on %s" % [enemy.unit_name, target.unit_name], "cyan")
			await _execute_enemy_attack(enemy, target)
		else:
			DebugLog.log("Target %s is dead or invalid, skipping attack" % target.name, "yellow")


## Execute enemy movement
## @param enemy: Enemy unit
## @param move_to: Target position
func _execute_enemy_movement(enemy: Node, move_to: Vector2i) -> void:
	if not unit_manager or not unit_manager.has_method("move_unit_to"):
		return
	
	DebugLog.log("%s moving to %s" % [enemy.unit_name, move_to], "cyan")
	if unit_manager.move_unit_to(enemy, move_to):
		# Wait for movement animation only if movement actually started
		if enemy.has_signal("movement_finished"):
			# Fallback timer to prevent infinite hang
			var timeout_time = 3.0 # Seconds
			var timer = get_tree().create_timer(timeout_time)
			var move_state = { "completed": false }
			
			# Lambda to capture completion
			var on_finish = func(): move_state.completed = true
			enemy.movement_finished.connect(on_finish, CONNECT_ONE_SHOT)
			
			# Wait for signal or timeout
			while not move_state.completed and timer.time_left > 0:
				await get_tree().process_frame
				
			if not move_state.completed:
				DebugLog.log("WARNING: Movement signal timed out for %s. Continuing..." % enemy.unit_name, "yellow")
				# Disconnect to check safety, though ONE_SHOT handles it mostly
				if enemy.movement_finished.is_connected(on_finish):
					enemy.movement_finished.disconnect(on_finish)
	else:
		DebugLog.log("Failed to start movement for %s - skipping animation wait" % enemy.unit_name, "yellow")


## Execute enemy attack
## @param enemy: Enemy unit
## @param target: Target unit
func _execute_enemy_attack(enemy: Node, target: Node) -> void:
	if not combat_manager or not combat_manager.has_method("perform_attack"):
		return
	
	# Validate target is in range
	if not _is_target_in_attack_range(enemy, target):
		DebugLog.log("%s cannot reach target %s" % [enemy.unit_name, target.unit_name], "yellow")
		return
	
	DebugLog.log("%s attacking %s" % [enemy.unit_name, target.unit_name], "yellow")
	
	# Await the actual combat execution to ensure synchronization
	await combat_manager.perform_attack(enemy, target)
	
	# Small buffer after combat ends
	await get_tree().create_timer(0.2).timeout


## Check if target is in attack range
## @param attacker: Attacking unit
## @param target: Target unit
## @return: true if in range, false otherwise
func _is_target_in_attack_range(attacker: Node, target: Node) -> bool:
	if not attacker or not target:
		return false
	
	var min_range := 1
	var max_range: int = attacker.get("attack_range") if "attack_range" in attacker else 1
	
	if attacker.has_method("get_attack_range_min"):
		min_range = attacker.get_attack_range_min()
	if attacker.has_method("get_attack_range_max"):
		max_range = attacker.get_attack_range_max()
	
	var attack_cells: Array = GridManager.get_attack_range(attacker.grid_position, max_range, min_range)
	return target.grid_position in attack_cells


## End enemy turn and transition to player turn
func _end_enemy_turn() -> void:
	current_phase = TurnPhase.ENEMY_TURN_END
	DebugLog.success("=== ENEMY TURN FINISHED ===")
	
	# Small delay before transitioning
	await get_tree().create_timer(TURN_TRANSITION_DELAY).timeout
	
	# Clear AI caches
	if enemy_ai and enemy_ai.has_method("clear_caches"):
		enemy_ai.clear_caches()
	
	current_phase = TurnPhase.IDLE
	
	# Start next player turn
	if game_state and game_state.has_method("finish_enemy_turn"):
		game_state.finish_enemy_turn()


## End current unit's turn
func end_current_unit_turn() -> void:
	DebugLog.log("=== ENDING CURRENT UNIT TURN ===", "cyan")
	
	# Get and mark current unit
	if unit_manager and unit_manager.has_method("get") and "selected_unit" in unit_manager:
		var current_unit: Node = unit_manager.selected_unit
		
		if current_unit:
			DebugLog.log("Unit %s ending turn" % current_unit.unit_name, "cyan")
			
			if current_unit.has_method("mark_as_moved"):
				current_unit.mark_as_moved()
			if current_unit.has_method("mark_as_acted"):
				current_unit.mark_as_acted()
	
	# Deselect unit
	if unit_manager and unit_manager.has_method("deselect_current_unit"):
		unit_manager.deselect_current_unit()
	
	# Cleanup UI
	_cleanup_ui_for_player_input()
	
	# Check if all player units completed
	_check_all_player_units_completed()


## Check if all player units have completed their turns
func _check_all_player_units_completed() -> void:
	if not unit_manager or not unit_manager.has_method("get_units_by_team"):
		return
	
	var player_units: Array = unit_manager.get_units_by_team(TEAM_PLAYER)
	
	# Check for adjacency bonds between player units
	for i in range(player_units.size()):
		for j in range(i + 1, player_units.size()):
			var unit_a: Unit = player_units[i]
			var unit_b: Unit = player_units[j]
			
			if not unit_a or not unit_b:
				continue
	
	var all_completed := true
	
	for unit in player_units:
		if not unit or not unit.has_method("is_alive"):
			continue
		
		if unit.is_alive() and not unit.get("has_acted"):
			all_completed = false
			break
	
	if all_completed:
		DebugLog.success("=== ALL PLAYER UNITS COMPLETED ===")
		
		# Check adjacency bonds before ending turn
		_check_adjacency_bonds()
		
		DebugLog.log("Starting enemy turn...", "yellow")
		if game_state and game_state.has_method("start_enemy_turn"):
			game_state.start_enemy_turn()
	else:
		DebugLog.log("=== MORE PLAYER UNITS CAN ACT ===", "cyan")
		if game_state and game_state.has_method("end_unit_turn"):
			game_state.end_unit_turn()

## Check adjacency bonds at turn end
func _check_adjacency_bonds():
	# Get BondSystem
	var bond_system = get_node_or_null("/root/Main/GameManager/BondSystem")
	if not bond_system:
		return
	
	if not unit_manager or not unit_manager.has_method("get_units_by_team"):
		return
	
	# TODO: Implement bond checking logic
