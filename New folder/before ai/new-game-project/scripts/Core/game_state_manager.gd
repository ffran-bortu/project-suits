# game_state_manager.gd - Optimized state machine (Singleton/Autoload)
extends Node

enum GameState {
	PLAYER_TURN,        # Player can move cursor, select units
	UNIT_SELECTED,      # Unit is selected, showing movement range
	UNIT_MOVING,        # Unit is currently moving
	ACTION_SELECT,      # After movement, choose action
	ATTACK_TARGETING,   # Selecting target for attack
	ENEMY_TURN          # Enemy AI turn
	# TODO: Add ANIMATION_LOCK state when implementing attack animations
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
	GameState.ATTACK_TARGETING: true
}

const INPUT_ALLOWED_STATES = {
	GameState.PLAYER_TURN: true,
	GameState.UNIT_SELECTED: true,
	GameState.ACTION_SELECT: true,
	GameState.ATTACK_TARGETING: true
}

# Optimized state transitions using bit flags for validation
const STATE_TRANSITIONS = {
	GameState.PLAYER_TURN: (
		1 << GameState.UNIT_SELECTED |
		1 << GameState.ENEMY_TURN
	),
	GameState.UNIT_SELECTED: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.UNIT_MOVING |
		1 << GameState.ACTION_SELECT |
		1 << GameState.ATTACK_TARGETING
	),
	GameState.UNIT_MOVING: (
		1 << GameState.ACTION_SELECT
	),
	GameState.ACTION_SELECT: (
		1 << GameState.PLAYER_TURN |
		1 << GameState.ATTACK_TARGETING
	),
	GameState.ATTACK_TARGETING: (
		1 << GameState.PLAYER_TURN
	),
	GameState.ENEMY_TURN: (
		1 << GameState.PLAYER_TURN
	),

}

# Change state with validation (simplified)
func change_state(new_state: GameState, force: bool = false):
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
func start_unit_selection():
	change_state(GameState.UNIT_SELECTED)

func cancel_unit_selection():
	change_state(GameState.PLAYER_TURN)

func start_unit_movement():
	change_state(GameState.UNIT_MOVING)

func finish_unit_movement():
	# Movement finished, go to action select
	change_state(GameState.ACTION_SELECT)

func start_enemy_turn():
	change_state(GameState.ENEMY_TURN)

func finish_enemy_turn():
	change_state(GameState.PLAYER_TURN)

func transition_to_action_select():
	change_state(GameState.ACTION_SELECT)

func start_attack_targeting():
	change_state(GameState.ATTACK_TARGETING)

func end_unit_turn():
	# Unit action completed, return to player turn
	change_state(GameState.PLAYER_TURN)

# Helper to get state name
func get_state_name(state: GameState = current_state) -> String:
	return GameState.keys()[state]

func get_current_state_name() -> String:
	return get_state_name()
