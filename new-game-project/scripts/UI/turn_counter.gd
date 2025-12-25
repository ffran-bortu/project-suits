"""
FILE: turn_counter.gd
PURPOSE: Displays and tracks the current turn number during battle with animated updates.

OVERVIEW:
This label shows "Turn: X" to indicate how many turns have passed in the current battle. It increments
automatically when each player turn starts and plays a bouncy pulse animation when the turn changes.
Useful for tracking battle progress and objectives that depend on turn counts.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects to GameStateManager's player_turn_started signal and initializes display
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _on_player_turn_started()
   - What it does: Increments turn counter, updates display, and plays pulse animation
   - Uses: Signal callback triggered when player's turn begins
   - Returns: void

3. update_display()
   - What it does: Refreshes the label text to show current turn number
   - Uses: Called when turn changes or counter is reset
   - Returns: void

4. reset_turn()
   - What it does: Resets turn counter back to 1 and updates display
   - Uses: Called when starting a new battle
   - Returns: void

NOTES:
- Depends on GameStateManager autoload for turn notifications
- Uses elastic tween animation for satisfying bounce effect when turn changes
- Turn counter starts at 1 and increments at beginning of each player turn
- Animation shrinks scale to zero then bounces back to original size over 0.5 seconds
"""

# turn_counter.gd - Turn counter display
"""
FILE: turn_counter.gd
PURPOSE: Turn counter display showing current turn number.
NOTES: Turn # UI display.
"""
extends Label

var current_turn: int = 1
var active_tween: Tween = null

func _ready() -> void:
	# Connect to game state
	var game_state: GameStateManager = get_node("/root/GlobalGameState")
	if game_state:
		game_state.player_turn_started.connect(_on_player_turn_started)
	
	update_display()

func _on_player_turn_started() -> void:
	current_turn += 1
	update_display()
	
	# Pulse animation when turn changes
	# Pulse animation when turn changes
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.set_trans(Tween.TRANS_ELASTIC)
	active_tween.set_ease(Tween.EASE_OUT)
	
	var original_scale = scale
	scale = Vector2.ZERO
	active_tween.tween_property(self, "scale", original_scale, 0.5)

func update_display() -> void:
	text = "Turn: " + str(current_turn)

func reset_turn() -> void:
	current_turn = 1
	update_display()
