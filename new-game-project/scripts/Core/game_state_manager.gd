"""
FILE: game_state_manager.gd
PURPOSE: Controls the game state machine for tactical battle flow (PLAYER_TURN → UNIT_SELECTED → ACTION → etc).

OVERVIEW:
This autoload manages the high-level state of the battle, tracking what the player can currently do
(select units, move, attack, etc.). It enforces valid state transitions using bitwise validation for
performance, emits signals when states change so UI/input systems can react, and provides helper
methods for common state checks (is cursor allowed? can player give input?). This prevents the game
from accepting invalid actions (like moving during enemy turn).

FUNCTIONS IN THIS FILE:

1. change_state(new_state, force)
   - What it does: Transitions to a new state after validation, emits signals
   - Uses: Called by input/action systems when player completes an action
   - Returns: void

2. is_valid_transition(from_state, to_state)
   - What it does: Checks if transitioning between two states is allowed (bitwise check)
   - Uses: Called by change_state() to prevent illegal transitions
   - Returns: bool

3. is_input_allowed()
   - What it does: Returns true if player input should be processed in current state
   - Uses: Input system checks this before handling keyboard/mouse
   - Returns: bool

4. is_cursor_allowed()
   - What it does: Returns true if cursor movement is allowed in current state
   - Uses: Cursor controller checks this before allowing movement
   - Returns: bool

5. is_movement_allowed()
   - What it does: Returns true if unit movement is valid (UNIT_SELECTED state)
   - Uses: Unit selection system checks before showing movement range
   - Returns: bool

6. start_unit_selection()
   - What it does: Transitions to UNIT_SELECTED state
   - Uses: Called when player clicks on a friendly unit
   - Returns: void

7. cancel_unit_selection()
   - What it does: Returns to PLAYER_TURN (deselects unit)
   - Uses: Called when player cancels or right-clicks
   - Returns: void

8. start_unit_movement()
   - What it does: Transitions to UNIT_MOVING state
   - Uses: Called when player confirms movement destination
   - Returns: void

9. finish_unit_movement()
   - What it does: Transitions to ACTION_SELECT (show Attack/Wait menu)
   - Uses: Called when unit reaches destination
   - Returns: void

10. start_enemy_turn()
    - What it does: Transitions to ENEMY_TURN state
    - Uses: Called by PhaseManager when player ends turn
    - Returns: void

11. finish_enemy_turn()
    - What it does: Returns to PLAYER_TURN after AI completes actions
    - Uses: Called by EnemyAI when all enemies have moved
    - Returns: void

12. transition_to_action_select()
    - What it does: Transitions to ACTION_SELECT state
    - Uses: For situations that skip movement and go straight to action menu
    - Returns: void

13. start_attack_targeting()
    - What it does: Transitions to ATTACK_TARGETING state
	- Uses: Called when player chooses "Attack" from action menu
    - Returns: void

14. end_unit_turn()
    - What it does: Returns to PLAYER_TURN (unit action complete)
    - Uses: Called after Wait, attack completed, or item used
    - Returns: void

15. get_state_name(state)
    - What it does: Converts GameState enum to readable string for debugging
    - Uses: Debug logging, UI state display
    - Returns: String

16. get_current_state_name()
    - What it does: Returns name of current state
    - Uses: Debug panels, state display UI
    - Returns: String

NOTES:
- Autoload singleton (accessible globally as GameStateManager)
- Contains enum GameState with all possible states
- Uses bit flags (STATE_TRANSITIONS dict) for fast O(1) validation
- Emits: state_changed(new_state), player_turn_started(), enemy_turn_started(), attack_targeting_started()
- Input/Cursor systems depend on state checks from this manager
- No dependencies (except emitting signals)
"""


extends Node
class_name GameStateManager

enum GameState {
	PLAYER_TURN,        # Player can move cursor, select units
	UNIT_SELECTED,      # Unit is selected, showing movement range
	UNIT_MOVING,        # Unit is currently moving
	ACTION_SELECT,      # After movement, choose action
	ATTACK_TARGETING,   # Selecting target for attack
	PAIR_TARGETING,     # Selecting ally to pair with
	SPLIT_TARGETING,    # Selecting position to split into
	ITEM_SELECTION,     # Selecting item to use
	COMBAT_RESOLUTION,  # Resolving combat (locked input)
	ENEMY_TURN,         # Enemy AI turn
	DEPLOYMENT          # Choosing unit positions
}

var current_state = GameState.PLAYER_TURN

# Core signals - keep these minimal and essential
signal state_changed(new_state)
signal player_turn_started()
signal enemy_turn_started()
signal attack_targeting_started()

# Use dictionaries for O(1) lookups instead of arrays
const CURSOR_ALLOWED_STATES = {
	GameState.PLAYER_TURN: true,
	GameState.UNIT_SELECTED: true,
	GameState.ATTACK_TARGETING: true,
	GameState.PAIR_TARGETING: true,
	GameState.SPLIT_TARGETING: true,
	GameState.DEPLOYMENT: true
}

const INPUT_ALLOWED_STATES = {
	GameState.PLAYER_TURN: true,
	GameState.UNIT_SELECTED: true,
	GameState.ACTION_SELECT: true,
	GameState.ATTACK_TARGETING: true,
	GameState.PAIR_TARGETING: true,
	GameState.SPLIT_TARGETING: true,
	GameState.ITEM_SELECTION: true,
	GameState.DEPLOYMENT: true
}

# Optimized state transitions using bit flags for validation
const STATE_TRANSITIONS = {
	GameState.PLAYER_TURN: (
		1 << GameState.UNIT_SELECTED |
		1 << GameState.ENEMY_TURN |
		1 << GameState.DEPLOYMENT
	),
	GameState.UNIT_SELECTED: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.UNIT_MOVING |
		1 << GameState.ACTION_SELECT |
		1 << GameState.ATTACK_TARGETING |
		1 << GameState.ITEM_SELECTION # Added
	),
	GameState.UNIT_MOVING: (
		1 << GameState.ACTION_SELECT
	),
	GameState.ACTION_SELECT: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ATTACK_TARGETING |
		1 << GameState.PAIR_TARGETING |
		1 << GameState.SPLIT_TARGETING |
		1 << GameState.ITEM_SELECTION # Added
	),
	GameState.ATTACK_TARGETING: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ACTION_SELECT |
		1 << GameState.COMBAT_RESOLUTION
	),
	GameState.ITEM_SELECTION: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ACTION_SELECT
	),
	GameState.PAIR_TARGETING: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ACTION_SELECT
	),
	GameState.SPLIT_TARGETING: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ACTION_SELECT
	),
	GameState.COMBAT_RESOLUTION: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ENEMY_TURN | 
		1 << GameState.ACTION_SELECT
	),
	GameState.ENEMY_TURN: (
		1 << GameState.PLAYER_TURN
	),
	GameState.DEPLOYMENT: (
		1 << GameState.PLAYER_TURN
	)
}

# Change state with validation (simplified)
func change_state(new_state: GameState, force: bool = false) -> void:
	if new_state == current_state and not force:
		return
	
	if not force and not is_valid_transition(current_state, new_state):
		print("Invalid state transition: ", get_state_name(current_state), " -> ", get_state_name(new_state))
		return
	
	current_state = new_state
	state_changed.emit(new_state)
	
	# Emit specific signals based on new state
	match new_state:
		GameState.PLAYER_TURN:
			player_turn_started.emit()
		GameState.ENEMY_TURN:
			enemy_turn_started.emit()
		GameState.ATTACK_TARGETING:
			attack_targeting_started.emit()
		_:
			pass  # No specific signal for other states

# Fast bitwise transition validation
func is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	return STATE_TRANSITIONS.get(from_state, 0) & (1 << to_state) != 0

# Quick state checks (O(1) lookups)
func is_input_allowed() -> bool:
	return INPUT_ALLOWED_STATES.get(current_state, false)

func is_cursor_allowed() -> bool:
	return CURSOR_ALLOWED_STATES.get(current_state, false)

func is_movement_allowed() -> bool:
	return current_state == GameState.UNIT_SELECTED

# State transition helpers (simplified and more intuitive)
func start_unit_selection() -> void:
	change_state(GameState.UNIT_SELECTED)

func cancel_unit_selection() -> void:
	change_state(GameState.PLAYER_TURN)

func start_unit_movement() -> void:
	change_state(GameState.UNIT_MOVING)

func finish_unit_movement() -> void:
	# Movement finished, go to action select
	change_state(GameState.ACTION_SELECT)

func start_enemy_turn() -> void:
	change_state(GameState.ENEMY_TURN)

func finish_enemy_turn() -> void:
	change_state(GameState.PLAYER_TURN)

func transition_to_action_select() -> void:
	change_state(GameState.ACTION_SELECT)

func start_attack_targeting() -> void:
	change_state(GameState.ATTACK_TARGETING)

func end_unit_turn() -> void:
	# Unit action completed, return to player turn
	change_state(GameState.PLAYER_TURN)

func cancel_attack_targeting() -> void:
	change_state(GameState.ACTION_SELECT)

# Helper to get state name
func get_state_name(state: GameState = current_state) -> String:
	return GameState.keys()[state]

func get_current_state_name() -> String:
	return get_state_name()
