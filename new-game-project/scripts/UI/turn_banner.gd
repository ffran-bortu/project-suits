"""
FILE: turn_banner.gd
PURPOSE: Displays animated phase transition banners when switching between player and enemy turns.

OVERVIEW:
This UI element shows bold "PLAYER PHASE" or "ENEMY PHASE" banners with color coding (blue for player,
red for enemy) when turn phases change. The banner animates in from the top, holds briefly, then fades
out. Provides clear visual feedback for phase transitions in tactical gameplay.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Initializes banner as hidden and connects to GameStateManager turn signals
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _on_player_turn_started()
   - What it does: Triggers the "PLAYER PHASE" banner display in blue
   - Uses: Signal callback when GameStateManager starts player turn
   - Returns: void

3. _on_enemy_turn_started()
   - What it does: Triggers the "ENEMY PHASE" banner display in red
   - Uses: Signal callback when GameStateManager starts enemy turn
   - Returns: void

4. show_banner(text: String, color: Color)
   - What it does: Animates banner in from top with specified text and color, holds briefly, then fades out
   - Uses: Called by turn phase callbacks to display transition animations
   - Returns: void

NOTES:
- Depends on GameStateManager autoload for turn change signals
- Uses Tween animations for smooth slide-in and fade effects
- Color constants defined: COLOR_PLAYER_PHASE (blue), COLOR_ENEMY_PHASE (red), COLOR_NEUTRAL (grey)
- Banner slides in with back easing from y=-200, holds for 1.5 seconds, then fades out over 0.4 seconds
- Automatically resets position after animation completes
"""

# turn_banner.gd - Phase transition banner
"""
FILE: turn_banner.gd
PURPOSE: Turn phase transition banner - animates "Player Phase"/"Enemy Phase" display.
NOTES: Phase transition UI animation.
"""
extends Control

# --- Components ---
@onready var label = $Panel/Label
@onready var panel = $Panel
var game_state: GameStateManager

# --- Constants ---
# Colors moved to GameConfig

var active_tween: Tween = null

func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	hide()
	
	# Connect to game state changes
	game_state = get_node("/root/GlobalGameState")
	if game_state:
		game_state.player_turn_started.connect(_on_player_turn_started)
		game_state.enemy_turn_started.connect(_on_enemy_turn_started)

func _on_player_turn_started() -> void:
	var color = GameConfig.get_color("phase_player")
	show_banner("PLAYER PHASE", color)

func _on_enemy_turn_started() -> void:
	var color = GameConfig.get_color("phase_enemy")
	show_banner("ENEMY PHASE", color)

func show_banner(text: String, color: Color) -> void:
	if not label or not panel:
		return
	
	label.text = text
	panel.modulate = color
	
	# Animate banner in from top
	var start_pos = position
	position.y = -200
	
	show()
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.set_trans(Tween.TRANS_BACK)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.set_parallel(true)
	
	# Fade in
	modulate.a = 0.0
	active_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Slide in from top
	active_tween.tween_property(self, "position:y", start_pos.y, 0.5)
	
	await active_tween.finished
	
	# Hold for a moment
	await get_tree().create_timer(1.5).timeout
	
	# Fade out
	# Fade out
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	
	await active_tween.finished
	hide()
	position = start_pos
