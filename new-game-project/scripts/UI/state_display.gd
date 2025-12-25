"""
FILE: state_display.gd
PURPOSE: Displays the current game state with color-coded visual feedback for debugging and player awareness.

OVERVIEW:
This simple UI label shows the current game state name and uses color coding to indicate different
states at a glance. Green indicates player turn, yellow for unit selected, orange for unit moving,
and red for enemy turn. Useful for debugging state transitions and providing visual feedback.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects to the game state manager's state_changed signal and initializes display
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _on_state_changed(_new_state)
   - What it does: Updates the display when game state changes
   - Uses: Signal callback triggered by GameStateManager when state transitions occur
   - Returns: void

3. update_display()
   - What it does: Refreshes the text and color based on current game state
   - Uses: Called when state changes to update visual representation
   - Returns: void

NOTES:
- Depends on GameStateManager autoload for state information
- Color scheme: Green (Player Turn), Yellow (Unit Selected), Orange (Unit Moving), Red (Enemy Turn), White (Other)
- Automatically updates via signal connection to state changes
- Primarily used for debugging and player feedback
"""

# state_display.gd - Simple UI to show current state
"""
FILE: state_display.gd
PURPOSE: Game state/turn indicator display showing current phase.
NOTES: Phase/state UI display.
"""
extends Label

# --- Constants ---
const COLOR_DEFAULT = Color(1, 1, 1) # White

@onready var game_state: GameStateManager = get_node("/root/GlobalGameState")

func _ready() -> void:
	game_state.state_changed.connect(_on_state_changed)
	update_display()

func _on_state_changed(_new_state) -> void:
	update_display()

func update_display() -> void:
	text = "State: " + game_state.get_state_name()
	
	# Color coding based on state
	match game_state.current_state:
		game_state.GameState.PLAYER_TURN:
			modulate = GameConfig.get_color("state_player_turn")
		game_state.GameState.UNIT_SELECTED:
			modulate = GameConfig.get_color("state_unit_selected")
		game_state.GameState.UNIT_MOVING:
			modulate = GameConfig.get_color("state_unit_moving")
		game_state.GameState.ENEMY_TURN:
			modulate = GameConfig.get_color("state_enemy_turn")
		_:
			modulate = COLOR_DEFAULT
